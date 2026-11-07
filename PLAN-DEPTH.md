# Plan: Depth-Aware Fit Advice, and the Architecture It Needs

> **Status: proposal for review.** Nothing here is implemented. The session that wrote it had no Swift toolchain, so no Swift in this document has been compiled or run. "How This Plan Was Checked" says what was verified and what was not. Facts are cited in square brackets by section and id, for example [body-apis:Q8-1], and listed with their verification status under "Facts This Plan Rests On". The full text and sources of every cited fact are in `docs/depth/facts-cited.json`.

## Summary

**The question.** Can the iPhone's LiDAR sensor make the Style tab's fit advice more accurate, and what should change in the app's architecture to support it?

**The answer, in five points.**

1. **The accuracy problem is measurement.** The model reads a flat photo of at most 1280 px and is asked where hems and cuffs land. OpenAI documents that it "struggles with tasks requiring precise spatial localization" and that it ignores file metadata, so depth stored in a photo never reaches it [privacy-platform:C1]. Whatever depth adds has to be measured on the phone and handed over as words.
2. **Most of the gain does not need LiDAR.** A 2D body-pose request and a person mask run on every iPhone that can run iOS 26, and on library photos. They can say that a sleeve ends about a tenth of its length past the wrist. That is the plan's headline feature (B1b).
3. **LiDAR is a refinement for Pro phones.** Twelve of the 31 iPhone models that run iOS 26 have it [body-apis:Q8-1, body-apis:Q8-2], and only on the rear camera [depth-capture:Q1-d]. Apple publishes no accuracy figure [depth-capture:Q2-e], so centimetre facts ship only if a bench on real garments passes a stated gate (B0, B3). The trouser-break rule moves in quarter-inch steps [fit-rules:F1], which is finer than LiDAR is likely to resolve. Even then the plan reports classes ("cropped", "at the ankle", "breaks on the shoe"), not millimetres.
4. **One architectural change: separate measuring from describing.** A pure, on-device **measure** stage turns the photo into a small `GarmentFacts` object made of closed enums. The type has no field that can hold a body dimension, so "clothes, never the body" is enforced by the type system as well as by the prompt. The model's **describe** step reads those facts as text.
5. **Foundations come first and pay off with or without depth.** They are a CI check that runs the tests (there is none today), a store that no longer wipes user data when a migration fails, the explicit third-party-AI consent that App Review requires [privacy-platform:A11], prompt versioning, and one shared camera core.

**Order of work.** Foundations (Track A) and the bench (B0) start together. Then B1a (an inert contract) and B1b (ratio facts for everyone). Only if their gates pass: B2 (a hands-free "Timer shot" camera) and B3 (LiDAR centimetres).

**Not in this plan.** Sending depth maps, masks or joints to the model. Requiring LiDAR or a stored height. ARKit body tracking. A garment-segmentation model. Per-card "Measured" badges. Per-zone "volume" facts. Saving looks, which needs A2 first.

**Not known.** LiDAR precision on a clothed person at 2 to 2.5 m. How well a hand-built garment-edge scanner copes with patterns and loose clothing. Whether people will prop a phone two metres away. Each has an experiment under "Assumptions and Experiments".

---

## Problem Statement

### Where the advice is blind today

- The model sees a JPEG of at most 1280 px on the long side with EXIF and GPS removed (`OutfitImagePreparer.swift:26-27`). It cannot be given depth, and it is weak at spatial reasoning [privacy-platform:C1].
- The prompt asks it for judgements that are really measurements: where hems and waistlines land, whether they divide the outfit into thirds, whether two hems stack at one height (`FashionAdvicePrompt.swift:39`, with the hem-stacking example at `:93`).
- The rules behind those judgements are fine-grained. Trouser break moves in quarter-inch steps, about 6 mm [fit-rules:F1]. A jacket sleeve ends just above the wrist bone with a quarter to half inch of cuff showing [fit-rules:F3]. Shoulder seams sit about a quarter inch past the shoulder bone on each side [fit-rules:F5].
- Camera height and tilt change the proportions the model sees. Shooting from above shortens the legs [fit-rules:F11]. A pinhole model puts the leg-to-torso error between about -4% and -38% depending on pitch and distance [fit-rules:F14]. That model is unverified.

### What depth can honestly add

- **Metric scale.** LiDAR depth is absolute, not relative [depth-capture:Q2-c]. A photo carries a 768x576 depth map [depth-capture:Q2-a], and Apple's stated range is 5 m [depth-capture:Q2-d]. At 2 to 2.5 m that is roughly 4 to 5 mm per depth pixel, derived from [fit-rules:F16] and the unverified [fit-rules:F17].
- **A precision nobody has published.** Third-party measurements put LiDAR at about 1 cm for small objects and about 2 cm RMSE for scanning [depth-capture:Q2-e]. Neither is a clothed person at 2 m. Hence a bench before any centimetre claim.
- **Limited reach.** Pro phones only: 12 of 31 iOS 26 models [body-apis:Q8-1, body-apis:Q8-2]. Pro models were 24% of US iPhone unit sales in the September 2026 quarter and 21% in the September 2025 quarter [privacy-platform:D2]. They were 48.7% of the top ten models in one usage panel, which overstates the installed base [privacy-platform:D4]. The planning assumption is one third to one half of users at most.
- **What depth does not fix.** Vision's pose accuracy drops for flowing clothing [body-apis:Q3-3]. Its 3D skeleton has no acromion landmark, so the shoulder-seam rule cannot be measured precisely [fit-rules:F20].

### What in the codebase gets in the way

| Gap | Evidence | Why it matters here |
|---|---|---|
| Nothing verifies a change | No `.github`, no shared scheme, no `.gitignore`. One `xcuserdata` file is tracked. | A change to capture, concurrency or the request body cannot be checked off a developer's machine. |
| A failed migration deletes the user's data | `GlowingApp.swift:27-45` removes the store and re-seeds. The model types are listed in four places: `GlowingApp.swift:14-22`, `ContentView.swift:32`, `ViewModelTests.swift:14`, `SettingsView.swift:167-180`. | Any later persistence (kept looks, saved settings) is unsafe until schema versions exist. Depth itself does not need this. |
| The advisor protocol is `(photoJPEG, goal)` | `OutfitAdviceViewModel.swift:7-9` | Every new input widens the protocol, its stubs and the tests. |
| The prompt is client-side and the release backend is not in the repo | [privacy-platform:C4]; `FashionAdvicePrompt.swift:5-6` | Prompt and backend can drift with no signal. |
| Capture logic is copied between screens | `startAutoCapture` in `ProgressPhotoCaptureView.swift:252` and `OnboardingCaptureView.swift:205`. The readiness rule appears in `ProgressPhotoCaptureView.swift:32-37`, `OnboardingCaptureView.swift:21-26` and `CameraOverlayView.swift:9-14`. `CameraViewModel.swift:136-163` writes main-actor state from the video queue. | A new camera would copy the same problems. |
| Explicit consent for third-party AI is missing | `StyleView.swift:71` discloses in a caption only. [privacy-platform:A11] requires explicit permission. | Adding a second kind of data to the same flow raises the stakes. |
| `FeatureFlags` is empty | `Services/FeatureFlags.swift` | There is no kill switch for a measurement feature. |

---

## Proposed Architecture: Measure on the Phone, Describe with the Model

### Overview

```
photo bytes ──► OutfitImagePreparer ──► photoJPEG (<= 1280 px) ─────────────────┐
(library, system camera, Timer shot)           │                                 │
                                               ▼                                 │
                                MEASURE (on device, nonisolated, no network)     │
                                 PoseExtractor      2D pose, person mask, people count
                                 SilhouetteScanner  garment edges along limb axes
                                 DepthLift          LiDAR only (B3)
                                 GarmentGeometry    ──► GarmentFacts?             │
                                               │                                 │
                                               ▼                                 │
                                 FashionAdvicePrompt.factsText                   │
                                 (the one renderer: fixed templates)             │
                                               │                                 │
                                               ▼                                 ▼
 only when the person taps Get Advice:   OutfitAdviceInput(photoJPEG, goal, factsText?)
                                               │
                                               ▼
                       OutfitAdvising ──► model ──► OutfitAdvice.parse ──► AdviceGuard ──► result
```

The measure stage reads the same prepared JPEG the model receives, so the facts can never describe pixels the model did not see. It is a pure function of plain values, with no UIKit, SwiftUI or network in it, so it is tested with fixtures and no device.

### Principles

These five constraints shaped every choice below.

1. **Clothes, never the body.** No fact describes a body dimension, a height, a weight or a shape. Landmarks (wrist, ankle, shoe top) appear only as the reference point a garment edge is compared with.
2. **Works when it fails.** Every tier degrades to today's behaviour. The Style tab never asks for hardware, and the photo picker stays at every tier.
3. **Minimum attention.** No new required step, no new screen on the happy path, no wait added to the photo.
4. **Privacy by minimisation.** Depth, masks, joints, camera intrinsics and tilt stay on the phone. Only a short garment-relative text leaves, and only at the existing Get Advice tap.
5. **Testable without a device.** The engine takes values and returns values. Real captures become JSON fixtures.

### What stays on the phone and what leaves

| Stays on the phone | Leaves, only at Get Advice |
|---|---|
| Pose joints, person mask, depth map, intrinsics, tilt angle, the `GarmentFacts` object | The JPEG (as today), the goal (as today), and `factsText`: at most 1,200 characters of fixed-template sentences about garments |

Keeping raw depth and body geometry on the device and sending only garment-relative facts is the lowest-exposure position under the biometric and health-data laws the research covered [privacy-platform:B11]. That is a design assessment, not a legal opinion.

### Tiers

Tiers are capabilities. Each adds to the one before it, so a lower tier is always a subset of a higher one, and one renderer, one prompt and one result screen serve all of them.

| Tier | Applies when | The model is told | Confidence ceiling |
|---|---|---|---|
| T0 | No person found. More than one full-body person. Subject under a third of the frame height. Needed joints unusable. Measurement switched off. | Nothing. Advice is exactly what it is today. | none |
| T1 | Any photo with one usable person: library, system camera, mirror. | Class and ratio facts from 2D pose and the person mask. No centimetres. | medium. Thirds are low when the camera was tilted or the tilt is unknown. |
| T2 | B3 only: a Timer shot on a LiDAR phone, after gate G3 passes. | T1 facts plus centimetre bands set by the bench. | high |

A subject under a third of the frame is the floor in Apple's pose guidance, and flowing clothing lowers accuracy [body-apis:Q3-3, fit-rules:F25]. Several people produce one merged person mask [body-apis:Q4-1] while the 3D pose request follows only the most prominent person [body-apis:Q1-4], so more than one person is T0 rather than a guess.

### What the engine can state

| Fact | Computed from | T1 | T2 | Notes |
|---|---|---|---|---|
| Sleeve end against the wrist | Sleeve edge found on the forearm axis, compared with the wrist joint | Class (short, at, past) and a fraction of the sleeve | Adds a centimetre band | [fit-rules:F3]. Sides are never named: "one sleeve", "the other". |
| Trouser hem against the shoe top (break) or the ankle (cropped) | Hem edge on the shin axis, compared with the ankle joint and shoe top | Class | Adds a centimetre band | [fit-rules:F1, fit-rules:F2] |
| Hem stacking | Two hems landing within a small band of each other | Yes | Yes | An image-plane fact that needs no scale. The current prompt already uses it as its example (`FashionAdvicePrompt.swift:93`). |
| Outfit thirds | Lowest top hem between the shoulder line and the shoe line | Yes, with its confidence lowered by camera tilt | Yes, measured along the vertical | [fit-rules:F7, fit-rules:F14]. Capped at medium until gate G4 passes. |
| Shoulder seam against the silhouette edge | Mask edge at shoulder height against the shoulder joint | Class only, low | Class only, low | [fit-rules:F5]: Vision has no acromion joint [fit-rules:F20]. |
| Framing | Whole outfit visible, which edges are cut off, number of people | Yes | Yes | Cheap and robust. |

A ratio is always the offset divided by the garment's own length along the same axis (shoulder joint to sleeve end, waistband to hem). It is never divided by a body segment: a number normalised by someone's forearm is a body measurement in disguise. The engine keeps its joint-segment parameter private.

**Removed after review:** per-zone volume and stand-off. Both rest on unverified reasoning [fit-rules:F23, fit-rules:F24], and a type that can emit "hips: oversized" lets the model paraphrase a body judgement. The "one relaxed piece, the rest streamlined" call stays with the model, as it is today (`FashionAdvicePrompt.swift:39`).

### How facts reach the model

`FashionAdvicePrompt.factsText(_:)` is the only place facts become words. It is a set of fixed templates over closed enums, so nothing the user typed and nothing read from the photo can reach the model through it. Example for a T1 photo:

```
Checked on the photo by software that measures where garment edges sit (garment edges only):
- [medium] One sleeve ends slightly past the wrist, by about a tenth of the sleeve's length.
- [medium] The trouser hem ends just above the top of the shoe.
- [medium] The top and the jacket end in about the same place, so two hems stack.
- [low] The top ends a bit below the middle of the outfit. The camera was tilted, so treat this as a hint.
- Whole outfit visible: yes.
```

The block sits between the goal sentence and "Here is my outfit:" in `userText`, so the message still has two parts, text and image. The system prompt is roughly 6,200 characters today. It gains one paragraph of about 513 characters, which keeps it under the 9,000-character ceiling the tests enforce (`RequestValidationTests.swift:34`):

```
CHECKED FACTS
- Some messages include a block headed "Checked on the photo". Software measured where garment edges sit.
- A [high] line is reliable: do not contradict it. A [medium] line is a strong hint: weigh it with what you can see. A [low] line is a hint only.
- When advice rests on a line, say so in "observation" in everyday words ("the sleeve runs just past the wrist"). Do not quote numbers or the bracketed tags.
- Describe the clothes, never the person. A line tells you nothing about anyone's body.
```

On T2 a line may also carry a centimetre band, for example "[high] One sleeve ends about 2 cm past the wrist bone, between 1 and 3 cm." The model is still told to answer in everyday words.

Authority follows confidence. Because T1 is capped at medium, T1 facts inform the model but never override what it sees. Only a bench-validated T2 fact can say "do not contradict".

### Wire and backend

- Release body gains an optional `factsText` string, present only when a measurement was ready and the person left the switch on. It follows how `goal` is added (`OutfitAdviceRequest.swift:13-15`).
- `performRequest` (`BackendAPIClient.swift:312`) adds a prompt-version header; the backend echoes `promptVersion`. Debug builds show a mismatch in Settings.
- The backend inserts `factsText` verbatim, after a length and character check, and does not parse it. There is one renderer, not two that must stay in step.
- **Sequencing: backend first.** If the backend rejects unknown keys, the client change must not ship before it. The release path is blocked on backend work that this repo does not contain.
- Debug builds call the AI service directly (`OutfitAdviceRequest.swift:20-42`), so B1a and B1b can be tried end to end without a backend.

---

## Detailed Implementation

Two tracks. **Track A** is foundation work that is worth doing whether or not depth ever ships. **Track B** is the measurement feature. Sizes are rough: S is a day or less, M a few days, L about a week or more.

```
Track A: foundations                                  Track B: measurement
A1  Verification floor (CI)         ───────────────►  B0  Bench (debug-only): go/no-go numbers
A2  Safe schema, no more store wipe                   B1a Contract: inert, producer returns nil
A3  Consent + privacy manifest                        B1b Producer: ratio facts for every phone     [gate G1]
A4  Prompt contract + feature flags ──► B1a needs     B2  Timer shot camera (additive)              [gate G2, needs A5]
A5  One capture core ──► B2 needs                     B3  Metric tier on LiDAR phones               [gate G3, needs B2]
```

### Track A: Foundations

#### A1. Verification floor (size S, do first)

- Commit the shared scheme (`Glowing.xcodeproj/xcshareddata/xcschemes/Glowing.xcscheme`) and a test plan. Add a `.gitignore` for `xcuserdata/`, `DerivedData/` and `.build/`, and untrack the committed `xcuserdata` file.
- Add `.github/workflows/test.yml`: `xcodebuild test` on a macOS runner whose image ships an iOS 26 simulator. Check the runner image label when writing it. Make the check required on `main`.
- Turn on `SWIFT_STRICT_CONCURRENCY = complete` for the app target. `SWIFT_VERSION = 5.0` today (`project.pbxproj:444`) downgrades isolation violations to warnings. That is how `CameraViewModel.swift:136-163`, which writes main-actor state from the video queue, goes unnoticed.
- Later: a non-hosted unit-test target for the pure suites. Tests are hosted in the app today (`TEST_HOST`, `project.pbxproj:520`), so every run first launches the app and builds the on-disk container.
- **Done when** the existing tests (about 3,600 lines) run on a clean clone with no human at Xcode. Every later phase depends on this, because nothing in this repository can be compiled in the cloud session that proposes it.

#### A2. Safe schema (size M, not needed by depth)

- Add `GlowingSchemaV1: VersionedSchema` listing exactly today's seven models, and a `GlowingMigrationPlan: SchemaMigrationPlan` with no stages yet. Use one `Schema` for the app, previews, tests and `startFresh`.
- Replace the delete-and-reseed fallback (`GlowingApp.swift:27-45`) with: move the store aside, start empty, and say so in one calm sentence. Never delete routines and photos silently.
- No model changes in this plan. Anything that adds persistence later (kept looks, saved settings) is a V2 with a migration stage.

```swift
enum GlowingSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Routine.self, RoutineStep.self, RoutineLog.self, StepDayVariant.self,
         ProgressPhoto.self, SkinAnalysis.self, UserProfile.self]
    }
}

enum GlowingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GlowingSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

- **Risk:** this touches the app's launch path. A1 must land first, and the experiment X11 (open a store written by the current build) must pass.

#### A3. Consent and privacy surface (size S to M)

- One explicit permission step before the first photo is sent: it names the third-party AI service and what is sent (the photo, the goal and, once B1b ships, a short description of where the clothes sit). Guideline 5.1.2(i) requires explicit permission before sharing personal data with third-party AI [privacy-platform:A11]. Today `StyleView.swift:71` only discloses in a caption. Acceptance is stored once and checked before every Get Advice.
- Add a `PrivacyInfo.xcprivacy`. There is none in the repo, and `UserDefaults` is one of the five required-reason API categories [privacy-platform:A6]; the app uses it (`GlowingApp.swift:38`).
- Review the App Store privacy label with the new data in mind. The photo flow already triggers the Face Data clause for any photo that shows a face [privacy-platform:A15].
- No new Info.plist key or entitlement is needed to read LiDAR depth [privacy-platform:A3]. Whether CoreMotion needs a usage string is an open assumption (X10); B2 resolves it.
- Guideline 5.1.2(vi) bars using depth data or facial-mapping data for marketing or data mining [privacy-platform:A12]. The plan keeps measurements on the device and never stores them, which sidesteps the question.

#### A4. Prompt contract and feature flags (size S)

- `FashionAdvicePrompt.version` (an integer), sent as a header from `performRequest` (`BackendAPIClient.swift:312`). The backend echoes `promptVersion`. Debug builds show a mismatch in Settings so skew becomes visible instead of silent.
- A golden corpus of `GarmentFacts` fixtures and the exact `factsText` they must render to. The backend's tests replay it, so there is one specification of the text.
- `FeatureFlags` (`Services/FeatureFlags.swift`) stops being empty, and three different things stop sharing one name: a user switch that is also the kill switch, a compile-time debug flag, and a runtime capability probe.

```swift
enum FeatureFlags {
    /// User-facing switch for on-device garment measurement. On by default, and the kill switch for B1b.
    static var measureClothes: Bool {
        get { UserDefaults.standard.object(forKey: "measureClothes") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "measureClothes") }
    }

    #if DEBUG
    /// Shows the Measurement Lab (B0). Compile-time only.
    static let measurementLab = true
    #endif
}
```

#### A5. One capture core (size M to L, needed only by B2)

- Extract the countdown ring, the readiness capsule and the camera-permission fallback into shared views (`CountdownRing`, `ReadinessCapsule`, `CameraPermissionFallback`). Today the auto-capture countdown is a `private` function copied between two screens (`ProgressPhotoCaptureView.swift:252`, `OnboardingCaptureView.swift:205`), the permission view is a `private` property in each (`ProgressPhotoCaptureView.swift:453`, `OnboardingCaptureView.swift:244`), and the capsule and lighting indicator are `private` to `CameraOverlayView.swift:283`. Adopt the shared pieces in both face-capture screens in the same change, so the net line count falls.
- Define `protocol FrameAnalyzer: Sendable` and a pure `CaptureCountdown` state machine with an injected clock, so the readiness, hold and countdown logic runs in tests without a camera.
- Fix `CameraViewModel.swift:136-163`: analysis results cross to the main actor only as Sendable values, never by touching main-actor properties from the video queue.
- Collapse the readiness rule that exists three times (`ProgressPhotoCaptureView.swift:32-37`, `OnboardingCaptureView.swift:21-26`, `CameraOverlayView.swift:9-14`) into one.

---

### Track B: Measurement

#### B0. Bench: a debug-only Measurement Lab (size M to L)

The aim is to replace opinions with numbers before any edge or centimetre claim ships.

- A `#if DEBUG` screen behind `FeatureFlags.measurementLab`. It captures with the rear LiDAR device (photo, unfiltered depth, calibration), the system camera and the library, runs the engine, and dumps the engine's inputs as JSON (pose, mask rows, depth patches, **never the photo**) beside the facts it produced.
- The tester types in tape-measured truth for each fact: cuff to wrist, hem to shoe, sleeve head to shoulder, outfit thirds. The screen computes the error in pixels, in percent of the segment, and in centimetres, and exports a CSV.
- Protocol (design values, not facts): at least 60 captures, 6 people, and 3 garment classes (shirt and trousers, a jacket, a flowing garment where failure is expected). Include patterned and dark fabric, 2.0 m and 2.5 m, level and about 15 degrees pitched, and at least 10 captures in front of a mirror. Testers consent. The repository receives JSON fixtures only, so no faces are committed.
- The same sessions settle the frame and capture-format questions (X2, X3, X9), the pitch, shoulder and mirror questions (X5, X6, X8), and the flowing-garment and latency questions (X7, X12).
- **Done when** the error tables exist per fact and distance band and gates G1 to G4 are decided.

#### B1a. The contract, inert (size M)

- `OutfitAdviceInput` replaces `(photoJPEG, goal)` on `OutfitAdvising`. New inputs go into the struct instead of widening the protocol. The three stubs in `FashionAdviceTestSupport.swift` record `lastInput`.
- `GarmentFacts`, `FashionAdvicePrompt.factsText`, the prompt paragraph, the `factsText` request key, `AdviceGuard`.
- The producer does not exist yet, so `measurement` stays `.idle` and users see no change. The whole change is CI-verifiable.
- Tests that change on purpose: the pinned key sets and two-part message (`RequestValidationTests.swift:150-171`, `:198-199`), the prompt-size ceiling (`:34`), the three stubs and the four tests that read `lastPhoto` and `lastGoal`. With no facts, the key sets stay exactly as they are.
- New tests: every rendered line matches one of a fixed list of template patterns. A whole-word denylist of body-dimension terms (height, tall, weight, inseam, waist, chest, bust, body, figure, frame) is absent from every rendering of a fixture corpus. Landmark nouns such as wrist and ankle are allowed only inside their own templates. The golden corpus from A4. `AdviceGuard` replayed over recorded responses.

```swift
/// Everything the advisor needs for one request. New inputs go here instead of widening the protocol.
struct OutfitAdviceInput: Sendable, Equatable {
    var photoJPEG: Data
    var goal: StyleGoal?
    /// Fixed-template sentences about garments, produced on the phone. Nil when there is nothing to say.
    var factsText: String?
}

protocol OutfitAdvising {
    func adviseOnOutfit(_ input: OutfitAdviceInput) async throws -> OutfitAdvice
}
```

```swift
/// What the measure stage tells the model. Closed enums on purpose: no case can name a body
/// dimension, so there is nothing to leak. Sides are never named.
nonisolated struct GarmentFacts: Codable, Equatable, Sendable {
    static let version = 1

    enum Confidence: String, Codable, Sendable { case low, medium, high }
    enum Edge: String, Codable, Sendable { case sleeveEnd, trouserHem, topHem, outerHem }
    enum Landmark: String, Codable, Sendable { case wrist, ankle, shoeTop }

    /// Along the limb, from the body outward. "Short" stops before the landmark, "past" runs beyond it.
    enum Position: String, Codable, Sendable { case wellShort, slightlyShort, at, slightlyPast, wellPast }
    enum SeamPosition: String, Codable, Sendable { case inside, at, beyond }

    struct Offset: Codable, Equatable, Sendable {
        var edge: Edge
        var landmark: Landmark
        var position: Position
        /// Offset divided by the garment's own length along the same axis. Always present.
        var garmentFraction: Float
        /// Whole centimetres. Present only on a depth basis, and only once the bench has set a tolerance.
        var centimetres: Int?
        var confidence: Confidence
    }

    struct HemStack: Codable, Equatable, Sendable {
        var edges: [Edge]
        var confidence: Confidence
    }

    struct Thirds: Codable, Equatable, Sendable {
        /// Lowest top hem as a fraction of the distance from the shoulder line to the shoe line.
        var topBlockFraction: Float
        var confidence: Confidence
    }

    struct Context: Codable, Equatable, Sendable {
        enum Source: String, Codable, Sendable { case library, camera, timerShot }
        enum CameraLevel: String, Codable, Sendable { case level, tilted, unknown }
        var source: Source
        var cameraLevel: CameraLevel
        var wholeOutfitVisible: Bool
    }

    var context: Context
    var offsets: [Offset]
    var hemStacks: [HemStack]
    var thirds: Thirds?
    /// Class only, always low confidence: Vision has no acromion joint.
    var shoulderSeam: SeamPosition?
}
```

Types that the detached measure task touches are declared `nonisolated`, because the app target defaults to main-actor isolation (`project.pbxproj:441`). Whether the project's compiler settings accept `nonisolated` on a type is the first thing the CI run on B1a will answer. The fallback is the existing pattern, an explicit `nonisolated init` (`LightingCondition.swift:73`).

#### B1b. The producer: ratio facts for every phone (size L)

- `OutfitMeasurer` is the glue that calls Vision and builds the engine's input. `PoseExtractor` uses the iOS 18 Swift pose request with `detectsHands = false` [body-apis:Q6-1] and drops the five face points (nose, eyes, ears) at its boundary, so no face landmark ever exists downstream [body-apis:Q3-1, privacy-platform:A15]. The person mask comes from `VNGeneratePersonSegmentationRequest` at `.accurate` [body-apis:Q4-1]. The people count comes from `VNDetectHumanRectanglesRequest` with `upperBodyOnly = false` [body-apis:Q3-4].
- `SilhouetteScanner` finds garment edges along each limb axis from mask boundaries and colour transitions. It is the plan's own geometry: Apple ships no garment or clothing API [body-apis:Q6-5]. That is why it is the first thing the bench measures.
- `GarmentGeometry` is a pure function from `GeometryInput` to `GarmentFacts?`. It returns nil (tier T0) on more than one person, on a subject under a third of the frame, and on needed joints below the confidence floor. On a suspected flowing garment, where the mask is far wider than the skeleton at knee and ankle, it keeps the framing fact and drops the hem facts.

```swift
nonisolated struct GeometryInput: Sendable {
    var imageSize: CGSize
    var source: GarmentFacts.Context.Source
    var peopleCount: Int
    var pose: PoseSnapshot             // body joints only. The type has no face points.
    var silhouette: SilhouetteRows     // the person mask as per-row left and right extents
    var pitchDegrees: Double?          // Timer shot only. Bucketed to a CameraLevel before it leaves the engine.
    var depth: DepthLift?              // B3 only
}

nonisolated struct PoseSnapshot: Sendable, Codable {
    enum JointName: String, Codable, Sendable, CaseIterable {
        case neck, leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist
        case leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle
    }
    struct Joint: Sendable, Codable { var x: Double; var y: Double; var confidence: Float }
    var joints: [JointName: Joint]     // absent when Vision reported confidence 0
}

nonisolated struct SilhouetteRows: Sendable, Codable {
    struct Span: Sendable, Codable { var left: Int; var right: Int }
    var rows: [Span?]                  // one per image row, top to bottom. Nil where no person.
}

nonisolated struct DepthLift: Sendable {
    var width: Int
    var height: Int
    var metres: [Float]                // rectified and unfiltered. NaN where the sensor had no confident return.
    var focalLengthPixels: SIMD2<Float>
    var principalPoint: SIMD2<Float>
}

enum GarmentGeometry {
    /// Nil means "say nothing": no usable person, too many people, or too little confidence.
    nonisolated static func facts(from input: GeometryInput) -> GarmentFacts? {
        guard input.peopleCount == 1 else { return nil }
        // 1. Reject a subject under a third of the frame, and joints below the confidence floor.
        // 2. Scan the silhouette along each limb axis for garment edges (SilhouetteScanner).
        // 3. Compare each edge with its landmark and divide by the garment's own length.
        // 4. With input.depth (T2), lift edge and joint through the same depth map.
        // 5. Grade confidence from joint confidence, edge contrast and camera tilt, then cap it by tier.
        return nil
    }
}
```

- **The photo is never blocked by the measurement.** Preview and Get Advice appear as soon as the JPEG is ready, exactly as today. Measurement is a second task under the same photo ticket (`photoLoadTicket`), so every rule that protects the photo from a newer load, a removal or a started analysis also protects the measurement. `analyze()` waits at most `measurementGrace` for a measurement still running and then sends what it has.

```swift
@MainActor @Observable
final class OutfitAdviceViewModel {
    enum MeasurementState: Equatable {
        case idle                      // no photo, or measurement switched off
        case measuring
        case ready(GarmentFacts)
        case unavailable               // tier T0, or the engine had nothing to say
    }

    private(set) var measurement: MeasurementState = .idle

    /// The person's choice for this photo. The facts sheet flips it, and `analyze()` snapshots it.
    var includeFacts = true

    /// The longest `analyze()` waits for a measurement still running. A var so tests can set it to zero.
    static var measurementGrace: Duration = .seconds(1)

    /// Called after `finishPhotoLoad` accepted the photo, under the same ticket.
    func startMeasurement(ticket: Int, photoJPEG: Data, source: GarmentFacts.Context.Source) {
        guard ticket == photoLoadTicket, hasPhoto else { return }
        guard FeatureFlags.measureClothes else {
            measurement = .unavailable
            return
        }
        measurement = .measuring
        Task.detached(priority: .utility) {
            let facts = OutfitMeasurer.measure(photoJPEG: photoJPEG, source: source)
            await self.finishMeasurement(ticket: ticket, facts: facts)
        }
    }

    func finishMeasurement(ticket: Int, facts: GarmentFacts?) {
        guard ticket == photoLoadTicket, hasPhoto, phase == .composing else { return }
        measurement = facts.map(MeasurementState.ready) ?? .unavailable
    }

    /// What can be said about the photo right now, waiting briefly for a measurement still running.
    private func factsTextToSend(includeFacts: Bool) async -> String? {
        guard includeFacts else { return nil }
        let deadline = ContinuousClock.now + Self.measurementGrace
        while case .measuring = measurement, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard case .ready(let facts) = measurement else { return nil }
        return FashionAdvicePrompt.factsText(facts)
    }
}
```

- **Tests** mirror the existing photo-load race tests: a measurement landing after `newPhoto()` is dropped, one landing after `analyze()` starts does not touch the request, and a removed photo clears the state.
- **What the person sees.**
  - While composing, once a measurement is ready, one tertiary caption under the photo: "Checked where your clothes sit". Tapping it opens a short sheet that lists the facts in plain words ("Sleeves: a little past the wrist") with one switch, "Include with photo", on by default.
  - Settings gets one toggle, "Check how clothes sit". It is the kill switch.
  - The result shows one tertiary line under the summary when facts were sent: "Checked where your clothes sit in this photo." There is no per-card badge.
  - The model is told to speak in everyday words and not to quote numbers.
- **Output guard.** `AdviceGuard` runs after parsing, in the view model, and drops (never rewrites) an item that matches a narrow body-referential pattern such as "your frame" or "your figure". It does not match bare adjectives, because "slim-fit chinos" and "broad lapels" describe garments. A replay over recorded responses must wrongly drop at most 2% of items (a design value).
- **Release gate:** G1. Ship to TestFlight behind the switch first.

#### B2. The Timer shot: a hands-free camera, additive (size L, only if G2 passes)

- `Take Photo` stays on the system camera, which already handles camera flip, flash and permission (`CameraCaptureView.swift:5-7`). The Timer shot is a second button, not a replacement. Half or more of users have no LiDAR, and a stricter camera would only cost them effort.
- `OutfitCameraView` and `OutfitCaptureController` run an `AVCaptureSession` on the rear wide camera at 1x and 12 MP. Depth at 2x is unsettled, so zoom is fixed. Depth delivery is switched on only when the resolved device is the LiDAR camera and B3 is enabled, because turning it on reconfigures the pipeline and adds processing time [depth-capture:Q3-c].
- **Guidance is stated in subject-fraction terms, one band for every phone.** Target 0.45 to 0.70 of the frame height, about 1.6 to 2.5 m at Pro 1x (derived from the unverified [fit-rules:F17]). The hard floor is one third [body-apis:Q3-3]. Level and distance are soft cues that feed the reliability grade rather than gates. The countdown starts when the person is fully in frame and still, or on a manual tap. Two-word captions ("Step back", "Tilt up") appear only while a condition fails.
- **Hands-free cues are audible first.** With the rear camera facing the person, the screen faces away from them. So: three tones, at most three spoken phrases, an AirPods stem click or the volume or Action button through `onCameraCaptureEvent` [privacy-platform:E3, privacy-platform:E4], and a "Take Photo" accessibility label for Voice Control [privacy-platform:E6]. AVFoundation has no timer, so the countdown is the app's own [privacy-platform:E5]. Apple documents Watch Camera Remote only for the built-in Camera, and no API for third-party apps was found [privacy-platform:E2], so a Watch companion is not planned. A visible countdown stays on screen for handheld and mirror use, and the guidelines want a visible or audible indication while recording [privacy-platform:A13].
- Support three ways of holding the phone, and design the handheld and mirror cases first: the cues work with a tap shutter, and the countdown is optional. The product review argued that people lean phones and stand at mirrors more than they walk away from a propped phone. That is an assumption, not a measurement, and the dogfood gate tests it.
- Pitch comes from `CMDeviceMotion` at the shutter [body-apis:Q7-1] and is bucketed to level, tilted or unknown. Library photos carry no documented tilt [body-apis:Q7-2]. The undocumented MakerNote tag is not read.
- The controller returns an `OutfitCapture` value (bytes, source, pitch, optional depth patch and calibration). The bytes still go through `OutfitImagePreparer`. The view model sees the camera through `any OutfitCapturing`, so a stub drives its tests.
- **Gate G2** decides whether this is built at all. There is no analytics in the app, so success is judged by dogfooding: at least 8 of 10 people get a usable photo within two tries.

#### B3. The metric tier on LiDAR phones (size L, only if G3 passes)

- **Capture.** Choose the device by discovery of `builtInLiDARDepthCamera` (iOS 15.4+ [depth-capture:Q3-a]), never by `depthDataAccuracy`, which wrongly reports relative on this device [depth-capture:Q3-f]. Take the photo with `depthData` at 768x576 and its calibration [depth-capture:Q3-c, depth-capture:Q3-e]. Keep depth unfiltered, with its NaN holes [depth-capture:Q2-c, depth-capture:Q3-d]. Pin a 12 MP size, since 24 MP with depth needs deferred-processing opt-ins [depth-capture:Q7-e].
- **Rectify first.** Depth maps are warped to match lens distortion and must not be used to correlate points in 3D until they are rectified with the calibration data [fit-rules:F26].
- **Lift both points through one map.** The garment edge pixel and the joint pixel are lifted through the same rectified depth map with the same intrinsics, so both are surface points in one frame and the offset along the limb is their difference. The plan does not subtract a Vision 3D joint from a lifted pixel: nothing in the research says Vision's metric frame and the calibration's pinhole frame are the same frame, and an iOS 17 beta rotated the camera position from `cameraOriginMatrix` by 180 degrees [body-apis:Q1-7].
- **Sampling rules.** Sample 2 or 3 depth pixels inside the silhouette, never on the boundary pixel, because a window centred on a silhouette edge straddles the background. Require the window's depth spread to be under 3 cm or make no claim. Rescale the intrinsics from `intrinsicMatrixReferenceDimensions` to the depth map, and again for any crop.
- **No dependency on `.measured`.** Vision reports a measured body height only for a live LiDAR capture session, and otherwise returns a fixed 1.8 m reference [body-apis:Q2-4, body-apis:Q1-5]. B0 compares it with the lifted values as a cross-check. If the lifted joints agree with `cameraRelativePosition` within 1 cm on the bench, the 3D skeleton may help with foreshortening and thirds. If not, it is unused.
- **Tolerance comes from the bench.** `centimetres` is filled only when B0 has produced a P90 absolute error for that fact class and distance band, combined with the pose-error term for sleeve facts and rounded to whole centimetres. Until then the engine sends classes and fractions only.
- **Library photos never get T2.** Portrait photos store their depth as disparity [depth-capture:Q6-c], and the plan does not treat that as metric. Whether the photo picker keeps auxiliary depth at all is unverified [depth-capture:Q6-d].
- **Mirrors.** A time-of-flight sensor places a reflection at the mirror-image distance [fit-rules:F21], but the full geometry is unverified [fit-rules:F22]. Until X8 settles it, T2 is offered only for Timer shots, and the Timer shot is designed for propped-phone use.

### Gates

These thresholds are design values chosen for this plan. They are not facts, and B0 should confirm or revise them before work starts.

| Gate | Measured on | Go | Otherwise |
|---|---|---|---|
| **G1** scanner accuracy (B0 to B1b) | 60+ hand-labelled captures | Edge within 0.05 of the segment length on at least 80% of edges that have colour contrast, and a false-edge rate under 10% | Ship framing, hem stacking and thirds only, or stop. No sleeve or hem offsets. |
| **G2** value (B1b to B2) | 30 photos, advice with and without facts, two raters blind to which is which | Facts version preferred on at least 60% of pairs, and no rise in wrong claims | Stop at B1b. The Timer shot is not built. |
| **G3** LiDAR precision (B0 to B3) | Tape-measured cuff-to-wrist and hem-to-shoe at 2.0 m and 2.5 m | P90 absolute error of 2 cm or less: go | 2 to 4 cm: classes only, no centimetres, probably not worth B3. Above 4 cm: drop LiDAR. B2 survives on its own merits. |
| **G4** thirds under tilt (B0) | 3D skeleton against 2D against tape, level and about 15 degrees | Pitched error under 3%: thirds may reach high on T2 | Thirds stay capped at medium. |

A latency budget goes with G1: p95 measure time of 1.5 s or less on an iPhone 11 (A13), among the oldest models that run iOS 26 [body-apis:Q8-2]. If it is over, drop the mask to `.balanced` quality.

### Delivery at a glance

| Phase | Ships on its own? | Testable without a device? | Depends on | Size |
|---|---|---|---|---|
| A1 CI | Yes | n/a | none | S |
| A2 Safe schema | Yes | Mostly | A1 | M |
| A3 Consent and manifest | Yes | Mostly | A1 | S to M |
| A4 Prompt contract and flags | Yes | Yes | A1 | S |
| A5 One capture core | Yes | Partly (state machine yes) | A1 | M to L |
| B0 Bench | Debug only | No, by design | A1 | M to L |
| B1a Contract | Yes, inert | Yes | A1, A4 | M |
| B1b Producer | TestFlight, then release after backend change | Engine yes; real garments no | B0 (G1), B1a | L |
| B2 Timer shot | Yes | State machine yes; camera no | A5, G2 | L |
| B3 Metric tier | Yes | Lift against analytic fixtures yes | B0 (G3), B2 | L |

---

## Flow Diagrams

### Photo to advice, with the measurement as a second task

```
person picks a photo
  │  beginPhotoLoad() ─► ticket n, isLoadingPhoto = true
  ▼
detached: OutfitImagePreparer.prepareJPEG(raw)                              [exists]
  │  finishPhotoLoad(n, jpeg) ─► preview shown, Get Advice enabled           [unchanged: no waiting]
  ▼
detached, same ticket n: OutfitMeasurer ─► GarmentGeometry                   [new]
  │  finishMeasurement(n, facts) ─► .ready(facts) or .unavailable
  │     dropped when n is stale, the photo was removed, or phase is not .composing
  ▼
person taps Get Advice
  │  analyze(): snapshot goal and includeFacts, phase = .analyzing
  │  runAnalysis: if still .measuring, wait up to measurementGrace (stops early when ready)
  │  factsText = includeFacts && .ready ? FashionAdvicePrompt.factsText(facts) : nil
  ▼
advisor.adviseOnOutfit(OutfitAdviceInput(...)) ─► parse ─► AdviceGuard.filter ─► result
```

### Which tier a photo gets

```
photo prepared
 ├─ "Check how clothes sit" switched off?                          ─► T0
 ├─ people count is not exactly one full-body person?               ─► T0
 ├─ subject under a third of the frame, or needed joints unusable?  ─► T0
 ├─ mask far wider than the skeleton at knee and ankle?             ─► keep framing, drop hem facts
 └─ otherwise                                                       ─► T1 facts
        └─ Timer shot on a LiDAR phone, gate G3 passed, depth patch valid? ─► T2 (centimetre bands)
```

### The metric lift (B3)

```
 rectified depth map, unfiltered, NaN holes kept      intrinsics fx, fy, cx, cy (rescaled to the map)
          │                                                   │
 edge pixel e from SilhouetteScanner            joint pixel j from the 2D pose
          │  sample 2 or 3 depth pixels inside the silhouette; spread over 3 cm means no claim
          ▼                                                   ▼
     E = lift(e)                                         J = lift(j)      same map, same intrinsics, same frame
          └──────────────  (E - J) along the limb direction  ──────────────┘
                                  offset in metres
                    ÷ the garment's own length   ─►  fraction (always sent)
                    ─►  class, plus a centimetre band only after the bench has set the tolerance
```

---

## Files to Create/Modify

Xcode's synchronized folders pick up new files under `Glowing/` and `GlowingTests/` without edits to `project.pbxproj`. Settings changes (strict concurrency) do edit it.

| File | Change | Phase |
|---|---|---|
| `.gitignore`, `.github/workflows/test.yml`, `Glowing.xcodeproj/xcshareddata/xcschemes/Glowing.xcscheme`, test plan | New | A1 |
| `Glowing.xcodeproj/project.pbxproj` | Modified: strict concurrency | A1 |
| `Glowing/Models/GlowingSchema.swift`, `Glowing/GlowingApp.swift` | New; modified (versioned schema, store moved aside instead of deleted) | A2 |
| `Glowing/PrivacyInfo.xcprivacy`, `Glowing/Views/Style/StyleView.swift` | New; modified (consent step) | A3 |
| `Glowing/Services/FeatureFlags.swift`, `Glowing/Services/BackendAPIClient.swift` | Modified (flags; prompt-version header and echo) | A4 |
| `Glowing/Views/Shared/CountdownRing.swift`, `ReadinessCapsule.swift`, `CameraPermissionFallback.swift` | New (extracted) | A5 |
| `ProgressPhotoCaptureView.swift`, `OnboardingCaptureView.swift`, `CameraOverlayView.swift`, `CameraViewModel.swift` | Modified (shared pieces; Sendable results) | A5 |
| `Glowing/Debug/MeasurementLabView.swift` | New, `#if DEBUG` | B0 |
| `Glowing/Models/GarmentFacts.swift`, `Glowing/Services/AdviceGuard.swift` | New | B1a |
| `Glowing/Services/FashionAdvicePrompt.swift`, `OutfitAdviceRequest.swift`, `BackendAPIClient.swift` | Modified (paragraph, `factsText`, `version`, request key) | B1a |
| `Glowing/ViewModels/OutfitAdviceViewModel.swift` | Modified (`OutfitAdviceInput`, `MeasurementState`, `includeFacts`) | B1a, B1b |
| `Glowing/Services/Measurement/{OutfitMeasurer,PoseExtractor,SilhouetteScanner,GarmentGeometry,GeometryInput}.swift` | New | B1b |
| `Glowing/Views/Style/{StyleView,OutfitAdviceResultView}.swift`, `FactsSheet.swift`, `Views/Settings/SettingsView.swift` | Modified; new sheet | B1b |
| `Glowing/Models/OutfitCapture.swift`, `Services/{OutfitCaptureController,CaptureCountdown,CaptureCapabilities}.swift`, `Views/Style/OutfitCameraView.swift` | New | B2 |
| `Glowing/Services/Measurement/{DepthLift,DepthRectifier}.swift` | New | B3 |
| `GlowingTests/{GarmentFactsTests,FactsTextTests,AdviceGuardTests,MeasurementStateTests,GarmentGeometryTests,SilhouetteScannerTests,CaptureCountdownTests}.swift`, `GlowingTests/Fixtures/` | New | B1a to B3 |
| `GlowingTests/{RequestValidationTests,FashionAdviceTestSupport,AdviceFlowValidationTests,FashionAdviceTests}.swift` | Modified (new protocol shape, pinned key sets) | B1a |

---

## Key Design Decisions

1. **Measure the pixels the model sees.** One prepared JPEG feeds both the model and the measure stage, so facts and picture cannot disagree about where anything is.
2. **Facts are garment-relative and closed.** Every ratio is an offset divided by the garment's own length. The engine's joint-segment parameter stays private. No fact names a body region, and per-zone volume is out of v1.
3. **Classes before centimetres.** Centimetres appear only on T2 and only with a bench-derived tolerance, and the model is told to answer in everyday words. Until the bench exists, `centimetres` is nil.
4. **One renderer, in the client.** `factsText` is the specification. The backend inserts it and does not parse it.
5. **Authority follows confidence.** High means do not contradict, medium means weigh, low means hint. T1 is capped at medium, so it informs the model without overriding it.
6. **Lift in one frame.** Edge and joint go through the same depth map. Vision's 3D frame is a bench cross-check, never an input to the arithmetic.
7. **Capability, never hardware.** Tiers are subsets, the photo picker stays at every tier, and the Style tab never asks for a Pro phone.
8. **The system camera stays.** The Timer shot is additive and exists only if the value gate G2 passes.
9. **Measurement never blocks the photo.** It reuses the photo ticket, and `analyze()` waits at most a second.
10. **The person can see and veto what is sent.** A tappable caption, one switch per photo, and a Settings kill switch.
11. **One provenance line, no badges.** Provenance is decided by the client (facts were sent or not), never by a flag the model returns.
12. **No new persistence.** No stored height, no kept looks, no schema change in this plan. A2 comes first for any that follow.
13. **Fail closed.** More than one person, a small subject, weak joints or a flowing garment all produce less, not a guess.
14. **A narrow output guard.** It drops items that talk about the body, matches phrases rather than bare adjectives, and has a false-positive gate.
15. **Keep the engine liftable.** Engine inputs are plain values with no UIKit, SwiftUI or Vision types, so moving them into a package later is mechanical. They stay in the app target for now.
16. **Cues for a propped rear-camera shot are audible first.** The screen faces away from the person.
17. **Consent before the next kind of data.** A3 lands before B1b sends anything new.

### Where the four proposals disagreed

The plan came from four independent proposals (measurement-first, experience-first, risk-first, incremental-first). Their reviews were only partly completed, as described under "How This Plan Was Checked".

| Topic | Positions | Decision here and why |
|---|---|---|
| Where the pure code lives | Risk-first: a Foundation-only `GlowingCore` Swift package, so tests run on Linux CI. The others: in the app target. | In the app. Moving existing types into a package is a large change that cannot be compiled here, and a macOS runner (A1) answers the verification need. Revisit if CI time hurts. |
| Who renders the text | Measurement-first and incremental-first: the backend renders from JSON. Experience-first: JSON plus a version. Risk-first: JSON checked against a closed schema. | The client renders and the backend inserts verbatim. The engineering review found two renderers add skew to a backend that is not in the repo. |
| An optional stored height | All four included one (a file, a setting or a flag). | Deferred. Ratio facts already carry the rule at the precision available. A height adds an entry screen, a stored body number, a way to mis-scale someone else's photo, and a reset that must remember to delete it. |
| Per-zone volume and stand-off | Three proposals included volume; two named zones after body regions. | Removed. Both reviews found it rests on unverified reasoning [fit-rules:F23, fit-rules:F24] and can emit body-region judgements. |
| Kept looks | Experience-first only: a `StyleLook` model and a "Keep this look" action. | Out of scope. It is a product feature, not an accuracy one, and needs A2 first. |
| The camera | All four put an in-app camera ahead of the system camera when the device allows. | The system camera stays for Take Photo. The product review found the in-app camera adds effort for people who gain nothing. The Timer shot is additive and gated. |
| Countdown cues | Measurement-first: a soft tick. Experience-first: tones, torch pulses and speech. Risk-first: a visible countdown. The product review: visual, not sound. | Audible first for propped rear-camera shots, visual for handheld and mirror. The product review assumed the screen faces the person, and with the rear camera it does not. |
| An output filter | Risk-first and experience-first. | Included, narrow, with a false-positive gate. |
| Children | Risk-first: fail closed when measured height is under 130 cm. | Not adopted; listed as an open decision. It only works where height is measured, which is a live LiDAR session [body-apis:Q1-5, body-apis:Q2-4]. The prompt already forbids guessing age (`FashionAdvicePrompt.swift:31`). |
| Order of work | Measurement-first: ratios, then capture, then metric. Incremental-first: a verification floor first. Risk-first: a gate first. | Foundations and the bench first, an inert contract second, the producer behind a gate, and the camera and metric tier conditional. |

### Considered and rejected

- **Sending depth maps, masks or joints to the model.** The model accepts RGB images only and ignores file metadata [privacy-platform:C1]. Anything else would have to be rendered as an image or as numbers, and it would carry body geometry off the phone.
- **ARKit body tracking.** It needs a live session rather than a still photo, and a 91-joint skeleton adds nothing the 17-joint request does not already give for this job.
- **A required LiDAR phone or a required height.** The Style tab never asks for hardware or for a body number.
- **A reference object (a card or a sheet of paper) for scale.** It works, but it adds a step to every photo.
- **A custom garment-segmentation model.** There is no first-party API [body-apis:Q6-5], and a model means training data, a licence question and maintenance. The scanner is small, honest about low contrast, and bench-gated.
- **Correcting a tilted photo in 2D.** The residual error is the body's own depth. Grading reliability by tilt says what is known. Correcting would imply precision the plan cannot verify.
- **A "Measured" badge on each card.** It is the word the copy is trying to avoid, and it adds a badge to a deliberately quiet result screen.

---

## Facts This Plan Rests On

The research ran on 2026-11-06 against Apple documentation, WWDC transcripts, App Review guidelines and vendor pages. Each claim was checked by a second reviewer. **Verified** means a primary source was read directly. **Likely** means consistent secondary sources or an inference from verified facts. **Unverified** means reasoning or an open question. Full claim text, sources and notes are in `docs/depth/facts-cited.json`.


### Depth capture

| Fact | Status | In brief | Used for |
|---|---|---|---|
| depth-capture:Q1-d | verified | LiDAR is rear-camera only. | The Timer shot is rear-only. No front-camera depth. |
| depth-capture:Q2-a | verified | Photo depth maps are 768x576. Streaming depth is up to 320x240. | Sampling size and error budget. |
| depth-capture:Q2-c | verified | LiDAR depth is absolute. Unfiltered depth drops low-confidence points. | B3 capture and the metric claim. |
| depth-capture:Q2-d | likely | Apple's only stated range is 5 m. | 2 to 2.5 m framing sits inside range. |
| depth-capture:Q2-e | likely | Apple publishes no accuracy. Third parties report about 1 cm for small objects and about 2 cm RMSE when scanning. | Why gate G3 exists. |
| depth-capture:Q3-a | verified | The LiDAR capture device type exists from iOS 15.4. | Device discovery. |
| depth-capture:Q3-c | verified | Depth delivery is enabled at configuration, reconfigures the pipeline and adds processing time. | Enable it only on the LiDAR device. |
| depth-capture:Q3-d | verified | Depth and disparity maps convert into each other. Holes are NaN. Maps are lens-distorted. | NaN-aware sampling. |
| depth-capture:Q3-e | verified | Calibration data carries intrinsics and their reference dimensions. | The lift, and rescaling for crops. |
| depth-capture:Q3-f | verified | The LiDAR device wrongly reports relative accuracy. Apple support calls it a known issue. | Gate on device type, not on the flag. |
| depth-capture:Q6-c | verified | Portrait photos store their depth as disparity. | Library photos stay at T1. |
| depth-capture:Q6-d | unverified | Whether photo-picker data keeps auxiliary depth is not known. | No tier depends on it. |
| depth-capture:Q7-e | verified | 24 MP capture with depth needs deferred-processing opt-ins. | Pin a 12 MP size. |

### Body and Vision APIs

| Fact | Status | In brief | Used for |
|---|---|---|---|
| body-apis:Q1-4 | verified | The 3D pose request follows only the most prominent person. | More than one person is T0. |
| body-apis:Q1-5 | verified | `bodyHeight` is a fixed 1.8 m reference unless height was measured. | No dependency on height. |
| body-apis:Q1-7 | verified | `cameraOriginMatrix` and `cameraRelativePosition` give camera pose. An iOS 17 beta rotated it by 180 degrees. | Avoid mixing frames. |
| body-apis:Q2-4 | verified | A measured height needs a live LiDAR capture session. | A bench cross-check only. |
| body-apis:Q3-1 | verified | The 2D pose request returns 19 points, including nose, eyes and ears. | Drop the face points at the boundary. |
| body-apis:Q3-3 | verified | Flowing clothing lowers pose accuracy. The subject should be at least a third of the frame height. | T0 rules and the guidance floor. |
| body-apis:Q3-4 | verified | The human-rectangles request is upper-body-only by default. | Set `upperBodyOnly = false`. |
| body-apis:Q4-1 | verified | Person segmentation gives one mask for all people in the frame. | The people count comes from rectangles. |
| body-apis:Q6-1 | verified | The iOS 18 Swift pose API has a `detectsHands` option. | PoseExtractor. |
| body-apis:Q6-5 | likely | Apple ships no first-party garment or clothing API. | The plan builds its own scanner, bench-gated. |
| body-apis:Q7-1 | verified | Device tilt comes from CoreMotion. | Timer shot pitch. |
| body-apis:Q7-2 | verified | Photo metadata has no documented tilt key. | Library photos have unknown tilt. |
| body-apis:Q8-1 | verified | LiDAR iPhones are the Pro and Pro Max from the 12 Pro to the 18 Pro. | Reach. |
| body-apis:Q8-2 | verified | 31 iPhone models run iOS 26. The oldest carry the A13 chip. | Reach, and the latency budget. |

### Fit rules

| Fact | Status | In brief | Used for |
|---|---|---|---|
| fit-rules:F1 | likely | Trouser break moves in quarter-inch steps, about 6 mm. | Classes, not millimetres. |
| fit-rules:F2 | likely | Cropped trousers sit two to three inches above the ankle bone. | The cropped class. |
| fit-rules:F3 | likely | Jacket sleeves end just above the wrist bone, with a quarter to half inch of cuff showing. | The sleeve fact. |
| fit-rules:F5 | likely | Shoulder seams sit about a quarter inch past each shoulder bone. | The shoulder fact. |
| fit-rules:F7 | likely | Outfits divide into thirds, one third and two thirds. | The thirds fact. |
| fit-rules:F11 | likely | Shooting from above shortens the legs. Sources are qualitative. | Why tilt matters. |
| fit-rules:F14 | unverified | A pinhole model puts leg-to-torso error at -4% to -38% depending on pitch and distance. | Reliability grading and gate G4. Unverified. |
| fit-rules:F16 | verified | Pro camera focal lengths are 24 mm and 48 mm equivalents. | Framing. |
| fit-rules:F17 | unverified | Full-body framing distances computed from those focal lengths. | The guidance band. Unverified. |
| fit-rules:F20 | verified | Vision's 3D pose has 17 joints and no acromion. Joint accuracy is unpublished. | The shoulder fact stays class-only. |
| fit-rules:F21 | likely | A time-of-flight sensor places a mirror reflection at the virtual-image distance. | Mirror caution. |
| fit-rules:F22 | unverified | Geometry of mirror depth: a flipped copy at twice the distance. | Experiment X8. Unverified. |
| fit-rules:F23 | unverified | Depth could in principle separate boxy from fitted garments. | Removed from v1. Unverified. |
| fit-rules:F24 | unverified | Thresholds for "one relaxed piece" are inferred, not sourced. | Removed from v1. Unverified. |
| fit-rules:F25 | verified | Apple's pose guidance: subject at least a third of the frame, flowing clothing hurts, crowds hurt. | T0 rules. |
| fit-rules:F26 | verified | Depth maps are lens-distorted. Rectify with calibration before correlating points in 3D. | The B3 rectifier. |

### Privacy and platform

| Fact | Status | In brief | Used for |
|---|---|---|---|
| privacy-platform:A3 | likely | No permission beyond camera access is needed to read depth. | No new Info.plist key for LiDAR. |
| privacy-platform:A6 | verified | There are exactly five required-reason API categories. UserDefaults is one. | The privacy manifest. |
| privacy-platform:A11 | verified | Guideline 5.1.2(i): explicit permission before sharing personal data with third-party AI. | A3. |
| privacy-platform:A12 | verified | Guideline 5.1.2(vi): no marketing or data mining with depth or facial-mapping data. | Measurements stay on the phone. |
| privacy-platform:A13 | verified | Guideline 2.5.14: a visible or audible indication while recording. | The countdown. |
| privacy-platform:A15 | verified | The Face Data clause covers facial landmark data, including from an uploaded photo. | Drop the face points. |
| privacy-platform:B11 | likely | Keeping geometry on the phone and sending garment-relative data improves the position under biometric law. A design assessment. | The boundary. |
| privacy-platform:C1 | verified | Vision input is RGB only, metadata is ignored, and spatial localisation is weak. | The thesis. |
| privacy-platform:C4 | verified | Debug builds call the AI service directly. Release builds post to a backend. | The wire plan. |
| privacy-platform:D2 | verified | Pro models were 24% of US iPhone unit sales in the September 2026 quarter and 21% in the September 2025 quarter. | Reach. |
| privacy-platform:D4 | likely | LiDAR models were 48.7% of the top ten in one usage panel. The true share is probably lower. | Reach. |
| privacy-platform:E2 | verified | Watch Camera Remote is documented for the built-in Camera only. | No Watch plan. |
| privacy-platform:E3 | verified | AirPods can trigger the shutter in supported camera apps on iOS 26. | Hands-free capture. |
| privacy-platform:E4 | verified | `onCameraCaptureEvent` delivers AirPods stem, volume and Action button events while a session runs. | Hands-free capture. |
| privacy-platform:E5 | likely | AVFoundation has no self-timer. | The app owns the countdown. |
| privacy-platform:E6 | verified | Voice Control taps controls by their accessible name. | A "Take Photo" label. |

---

## Assumptions and Experiments

Everything below is something the plan relies on that the research could not settle. Each has an experiment and a fallback, so none of them is a hidden dependency. The bench (B0) runs most of them in one set of sessions.

| # | Assumption | Basis | Experiment | If it fails |
|---|---|---|---|---|
| X1 | LiDAR is precise enough on a clothed person at 2 to 2.5 m to bring cuff and hem offsets inside a 2 cm P90 | Apple publishes no figure; third parties report 1 to 2 cm in other settings [depth-capture:Q2-e] | B0: tape-measured cuff-to-wrist and hem-to-shoe at both distances (G3) | Classes only, or drop LiDAR |
| X2 | The 3D skeleton's metric frame agrees with the calibration frame | Not in the research. The plan does not depend on it [body-apis:Q1-7]. | B0: compare `cameraRelativePosition` with lifted joint pixels on 10 joints of a tape-measured subject | Never use 3D joints in arithmetic. That is already the default. |
| X3 | A still capture (pixel buffer plus depth) can return a measured height | Documented for a live LiDAR session [body-apis:Q2-4] | B0: check `heightEstimation` after a still | A cross-check is lost. No tier changes. |
| X4 | The hand-built edge scanner finds hems and cuffs on real garments | Own geometry; no first-party API [body-apis:Q6-5] | B0: hand-labelled captures with patterns, belts, untucked hems and dark cloth (G1) | Ship framing, hem stacking and thirds only |
| X5 | A 3D skeleton keeps leg-to-torso ratios under camera pitch better than 2D | The pinhole model is unverified [fit-rules:F14] | B0: same subject level and pitched, against tape (G4) | Thirds stay capped at medium |
| X6 | The shoulder joint is a usable proxy for the shoulder point | Vision has no acromion [fit-rules:F20] | B0: tape from the shoulder point against the joint | The shoulder fact stays class-only and low |
| X7 | Mask width at knee and ankle reveals flowing garments | Apple warns pose accuracy drops [body-apis:Q3-3] | B0: flowing-garment captures | Drop hem facts for any suspected flowing garment |
| X8 | Depth in a mirror is a flipped copy at twice the distance | [fit-rules:F21] is likely and [fit-rules:F22] is unverified | B0: Timer shots at a mirror, detection and error | Withhold T2 unless guidance can exclude mirrors |
| X9 | A 12 MP capture delivers depth and calibration together and can become a JPEG for the preparer | Only the 24 MP case is documented [depth-capture:Q7-e] | B0 device check | Capture HEVC with embedded depth instead |
| X10 | CoreMotion tilt needs no usage string, and an asynchronous Vision request behaves on a delegate queue | Not in the research | B2: a five-minute device check | Add `NSMotionUsageDescription` in Info.plist and in the two `INFOPLIST_KEY_` build settings |
| X11 | A store written by today's build opens under `GlowingSchemaV1` | Standard SwiftData behaviour for an identical model set; not checked here | A2: open a store written by the current build | The fallback moves the store aside instead of deleting it |
| X12 | The measure pipeline fits the latency budget on an iPhone 11 | None | B0 timing on an A13 phone | Use `.balanced` mask quality or a smaller image |

Not tested because no tier depends on them: depth at 2x zoom (unsettled, so the camera stays at 1x) and whether the photo picker keeps auxiliary depth [depth-capture:Q6-d].

## Risks

| Risk | Mitigation |
|---|---|
| A wrong fact is stated confidently (patterns, belts, untucked hems, flowing clothes) | Confidence tags. T1 capped at medium. Gate G1. Fail-closed rules. The model is told not to contradict only high lines. A per-photo switch and a Settings kill switch. |
| Body talk reaches the user | Closed enums. One renderer. Template and denylist tests. The prompt paragraph. `AdviceGuard` with a false-positive gate. |
| People feel measured | Copy says "where your clothes sit". No badge, no numbers on cards, no body words, and a tappable veto. |
| Policy and privacy: a second kind of data goes to a third-party AI | A3 consent first. Geometry stays on the phone and is never stored. Face points are dropped at the boundary. A privacy-label review. |
| Backend rejects unknown keys or drifts from the client | One renderer. A prompt-version header and echo. Backend ships first. |
| Latency or heat on older phones | The photo never waits. Budget and fallback quality. Measure at 1280 px. |
| A bench that is too small or too friendly | Mixed fabrics and expected failures in the protocol. Report P90, not the median. Commit JSON fixtures so results can be re-run. |
| Nothing can be compiled in the cloud session that proposes this | A1 first. Each change is small. The sketches here are checked for syntax only. |
| Drift toward a body-scanning product | Principle 1, the closed enums, and the rejected list in the Summary. |

## Open Decisions for the Owner

1. **Default on, or opt-in?** This plan ships B1b on by default with a visible caption, a per-photo switch and a Settings kill switch, because the facts contain no body data. The risk-first proposal made it opt-in. Opt-in is the more conservative choice and costs most of the reach.
2. **Children.** Risk-first proposed failing closed when measured height is under 130 cm. That only works where height is measured, and the prompt already forbids guessing age. Whether to gate on age is a policy and legal call for the owner.
3. **The backend.** The release path needs a backend change that this repo does not contain: accept and insert `factsText`, echo `promptVersion`. Someone has to own it, and it ships first.
4. **CI.** A1 assumes GitHub Actions with a macOS runner. That has a minutes cost.
5. **Scope.** A2 (safe schema) and A5 (one capture core) do not need depth. They are in the plan because they make the app better, but they can be taken or left independently.

---

## How This Plan Was Checked

### How it was made

- **Research.** Four strands (depth capture, body and Vision APIs, fit rules, privacy and platform) produced 142 claims. Each had a researcher and a skeptic pass against primary sources and was marked verified, likely or unverified.
- **Proposals.** Four independent proposals were written from that register and a map of the codebase: measurement-first, experience-first, risk-first and incremental-first.
- **Reviews, partly done.** The measurement-first proposal was reviewed three times (facts, product, engineering) and the experience-first proposal once (facts). The risk-first and incremental-first proposals were never reviewed, because the review run stopped when the session ran out of usage credits. Every idea adopted here appears in at least one reviewed proposal or is named in a review's list of ideas worth keeping. The risk-first ideas that no review touched (the Linux package, the schema-checked wire contract and the child gate) are the ones this plan did not adopt.
- **Where this plan departs from a review.** One product-review point was overruled: it assumed the screen faces the person during a propped rear-camera shot, and it does not (see the countdown row in the disagreement table). One earlier note was corrected: Apple documents Watch Camera Remote only for the built-in Camera [privacy-platform:E2], so the plan says that and no more.

### Checks run on this document

| Check | Result |
|---|---|
| Every bracketed citation resolves to an entry in the research register | 59 distinct facts cited, all found. The facts table lists exactly those 59, and each status matches the register. |
| Every Swift block parses | 6 blocks pass a tree-sitter-swift syntax check. This is syntax only: nothing is type-checked or compiled. |
| Every file and line reference matches the code it describes | Re-read against the repository at the base commit `7fe2bf9`. All resolve. |
| The rendered-text example and the prompt paragraph pass the denylist the plan specifies | One hit in the first draft ("height" in a hem sentence). The sample was reworded. That the plan's own sample failed its own denylist is why the plan specifies the test as fixed templates plus a whole-word denylist. |
| The prompt addition fits the test ceiling | About 6,200 characters plus about 510, against a 9,000 ceiling. |

### Not done

- No Swift was compiled or run. There was no toolchain in the session, and the CI described in A1 does not exist yet.
- No LiDAR measurement was taken. Every threshold in the gates table is a design value for B0 to confirm or revise.
- The distance and sampling figures come from focal-length arithmetic [fit-rules:F16, fit-rules:F17], and the framing part is unverified.
- The sketches may need isolation attributes adjusted. The app defaults to main-actor isolation (`project.pbxproj:441`), and how `nonisolated` on a type behaves under the project's settings is what the first CI run on B1a will show.
