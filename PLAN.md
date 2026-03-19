# Plan: Extract Image Details for Personalized Routine Generation

## Problem Statement

Currently, the onboarding flow does everything in **one LLM call**: analyze photos + generate routines simultaneously. This means:
- No opportunity to clarify ambiguous details with the user
- Beard/hair recommendations are guessed without user input
- The LLM tries to do too much in one shot (analysis + routine generation)

## Proposed Architecture: Multi-Step Image Analysis with User Clarification

### Overview

Split the current single LLM call into a **2-3 step flow**:

1. **Step 1 - Image Detail Extraction**: Analyze images to extract structured traits (skin type, hair type, beard status, etc.)
2. **Step 2 - User Clarification** (conditional): If any traits are ambiguous, present options to the user
3. **Step 3 - Routine Generation**: Generate personalized routines using confirmed traits

This applies to both:
- **"Routine" flow** (existing users regenerating routines — use latest progress photos)
- **"Fresh" flow** (new users — prompt them to take/upload new photos)

---

## Detailed Implementation

### Phase 1: New Model — `ImageAnalysisProfile`

**New file**: `Glowing/Models/ImageAnalysisProfile.swift`

A lightweight struct (not persisted) that captures extracted traits:

```swift
struct ImageAnalysisProfile {
    // Skin
    var skinType: SkinType           // oily, dry, combination, normal, sensitive
    var skinTypeConfidence: Confidence
    var acneProne: Bool
    var acneProneConfidence: Confidence
    var hasPigmentation: Bool
    var hasSensitivity: Bool
    var hasDehydration: Bool

    // Hair
    var hairPattern: HairPattern     // straight, wavy, curly, coily
    var hairPatternConfidence: Confidence
    var hairThickness: HairThickness // fine, medium, coarse
    var hairThicknessConfidence: Confidence
    var hairLength: HairLength       // short, medium, long
    var scalpConcerns: [String]      // dandruff, oiliness, dryness, thinning

    // Lips
    var lipsCondition: LipsCondition     // healthy, dry, chapped, cracked, pigmented
    var needsLipCare: Bool               // true if any concern detected

    // Eyebrows
    var eyebrowCondition: EyebrowCondition  // well_groomed, sparse, overgrown, unibrow, asymmetric
    var needsEyebrowGrooming: Bool          // true if grooming/shaping needed

    // Beard/Facial Hair
    var facialHairStatus: FacialHairStatus  // clean_shaven, stubble, short_beard, medium_beard, full_beard, patchy
    var facialHairStatusConfidence: Confidence
    var beardGrowthPattern: BeardGrowthPattern  // even, patchy_cheeks, patchy_chin, neck_heavy
    var beardGrowthPatternConfidence: Confidence
    var canGrowFullBeard: Bool?      // nil = unclear from images
    var beardRecommendation: String   // LLM's assessment: e.g. "patchy cheeks — recommend stubble" or "even growth — ask user preference"
    var needsBeardPreferenceInput: Bool // true only when growth is decent and style is genuinely ambiguous

    // Face
    var faceShape: String

    enum Confidence: String, Codable {
        case high, medium, low
    }
}
```

With enums for `SkinType`, `HairPattern`, `HairThickness`, `HairLength`, `FacialHairStatus`, `BeardGrowthPattern`.

### Phase 2: New API Method — `extractImageDetails`

**File**: `Glowing/Services/BackendAPIClient.swift`

Add a new method `extractImageDetails(images:)` that calls the LLM with a focused prompt asking ONLY for trait extraction (no routine generation). The prompt will:

- Request structured JSON output matching `ImageAnalysisProfile`
- Include a `confidence` field for each trait (high/medium/low)
- Ask the LLM to be explicit about what it **cannot determine** from images
- Example: hair thickness is hard to judge from photos alone → low confidence

**Key traits to extract per category:**

#### Skin Analysis Traits
| Trait | Why It Matters for Routines |
|-------|---------------------------|
| Skin type (oily/dry/combo/normal/sensitive) | Determines cleanser type, moisturizer weight, actives |
| Acne-prone | BPO vs gentle cleanser, salicylic acid inclusion |
| Pigmentation/hyperpigmentation | Vitamin C, niacinamide, sunscreen emphasis |
| Dehydration signs | Hyaluronic acid, barrier repair focus |
| Sensitivity/redness | Fragrance-free, skip harsh actives |
| Sun damage level | SPF urgency, antioxidant priority |

#### Hair Analysis Traits
| Trait | Why It Matters for Routines |
|-------|---------------------------|
| Hair pattern (straight/wavy/curly/coily) | Wash frequency, product type (gel vs cream vs oil) |
| Hair thickness (fine/medium/coarse) | Lightweight vs heavy products, heat protection |
| Hair length | Styling routine complexity, conditioning needs |
| Scalp oiliness | Wash frequency, shampoo type |
| Thinning/receding | Scalp treatment routines, minoxidil consideration |
| Dandruff/flaking | Anti-dandruff wash frequency |

#### Lips Traits
| Trait | Why It Matters for Routines |
|-------|---------------------------|
| Dryness/chapping/cracking | Lip balm inclusion, lip scrub/exfoliant step |
| Pigmentation/discoloration | Lip treatment with SPF, depigmenting balm |
| Overall condition (healthy vs neglected) | Whether a dedicated lip care step is needed |

#### Eyebrow Traits
| Trait | Why It Matters for Routines |
|-------|---------------------------|
| Sparse/thin brows | Growth serum step (castor oil, peptide serum) |
| Unibrow/stray hairs | Grooming/tweezing step in routine |
| Overgrown/bushy | Trimming/shaping step |
| Asymmetry | Professional shaping recommendation |
| Well-groomed | No eyebrow step needed — skip |

#### Beard/Facial Hair Traits
| Trait | Why It Matters for Routines |
|-------|---------------------------|
| Current facial hair status | Whether to include beard routines at all |
| Growth pattern (even vs patchy) | Full beard recommendation vs stubble/clean shave |
| Growth density | Beard oil vs balm, trimming frequency |
| Neck line definition | Trim routine inclusion |
| Can grow full beard? | Critical for beard vs stubble vs clean-shave recommendation |

### Phase 3: Clarification Question Builder

**New file**: `Glowing/Services/ImageAnalysisClarifier.swift`

A service that inspects the `ImageAnalysisProfile` and generates clarification questions for low/medium-confidence traits:

```swift
struct ClarificationQuestion {
    let id: String
    let category: Category          // face, hair, stubble
    let question: String
    let options: [ClarificationOption]
    let trait: String               // which profile field this resolves
}

struct ClarificationOption {
    let label: String
    let description: String
    let value: String
}
```

**Logic for generating questions:**

1. **Beard style — conditionally ask based on what the LLM sees:**
   - If beard is clearly patchy/uneven → **Don't ask**. The LLM should recommend trimming short (stubble/clean) and explain why. Offering "full beard" when growth is visibly patchy would be bad advice.
   - If beard growth is decent but ambiguous (could work as full beard OR stubble) → **Ask**: "Your facial hair growth looks solid. What style are you going for?" → Full beard / Short beard / Stubble / Clean shaven
   - If clean-shaven with no visible growth → **Don't ask**. Skip beard routines, optionally include shaving routine.
   - The extraction prompt should include a `beardRecommendation` field where the LLM states its assessment (e.g., "patchy on cheeks — recommend stubble or clean" vs. "even growth — user preference needed").

2. **Ask if confidence is low/medium:**
   - Hair thickness: "How would you describe your hair?" → Fine/thin, Medium, Thick/coarse
   - Skin sensitivity: "Does your skin react easily to new products?" → Yes, often / Sometimes / Rarely
   - Scalp concerns: "Do you experience any of these?" → Dandruff / Oily scalp / Dry/itchy scalp / None

3. **Never ask** (always determinable from images):
   - Hair pattern (straight/wavy/curly) — visible
   - Current facial hair status — visible
   - Face shape — visible
   - Lip condition (dry/chapped/healthy) — visible
   - Eyebrow condition (sparse/overgrown/well-groomed) — visible

### Phase 4: Updated Routine Generation Prompt

**File**: `Glowing/Services/BackendAPIClient.swift`

Add a new method `generateRoutines(profile:userPreferences:)` that takes the confirmed `ImageAnalysisProfile` (after user clarification) and generates routines. This is a second LLM call with:

- The confirmed traits as structured input (no images needed!)
- The existing dermatologist system prompt (refined)
- User preferences from clarification answers
- Returns the same routine JSON format as today

### Phase 5: ViewModel — `ImageAnalysisViewModel`

**New file**: `Glowing/ViewModels/ImageAnalysisViewModel.swift`

Orchestrates the multi-step flow:

```
State machine:
  .idle
  → .selectingImages          (fresh: prompt camera, routine: load recent photos)
  → .extractingDetails        (LLM call 1: extract traits)
  → .reviewingDetails         (show extracted traits, highlight low-confidence ones)
  → .clarifying               (show questions for ambiguous traits)
  → .generatingRoutines       (LLM call 2: generate routines with confirmed profile)
  → .showingResults           (display generated routines)
  → .complete
```

Key methods:
- `startFresh()` — prompts user to take new photos
- `startFromExisting()` — loads latest progress photo session
- `extractDetails()` — LLM call 1
- `buildClarificationQuestions()` — inspect profile, build questions
- `submitClarifications(answers:)` — merge answers into profile
- `generateRoutines()` — LLM call 2
- `saveRoutines(modelContext:)` — persist to SwiftData

### Phase 6: Views

**New files** in `Glowing/Views/ImageAnalysis/`:

1. **`ImageAnalysisFlowView.swift`** — Container view managing the flow states
2. **`ExtractedDetailsView.swift`** — Shows what the AI detected (skin type, hair type, beard status, etc.) with confidence indicators. User can tap to override any trait.
3. **`ClarificationView.swift`** — Presents clarification questions one-by-one or as a scrollable form. Each question has tappable option cards.
4. **`RoutineResultsView.swift`** — Shows generated routines (can reuse existing `SuggestedRoutineView` pattern)

### Phase 7: Integration Points

1. **Onboarding flow**: Replace the single `analyzeOnboarding()` call in `OnboardingViewModel` with the new multi-step flow. The `OnboardingStep` enum gets new cases: `.extractingDetails`, `.clarifying`.

2. **Routine regeneration**: Add a "Regenerate Routines" button in Settings or Routine List that triggers the flow using latest progress photos.

3. **Progress photo flow**: After a new check-in photo session, optionally offer "Update your routines based on new photos?"

---

## Flow Diagrams

### Fresh Flow (New User / New Photos)
```
[Take Photos] → [Extract Details (LLM 1)] → [Show Detected Traits]
    → [Clarification Questions] → [Generate Routines (LLM 2)] → [Show Results]
```

### Routine Flow (Existing User)
```
[Load Latest Photos] → [Extract Details (LLM 1)] → [Show Detected Traits]
    → [Clarification Questions] → [Generate Routines (LLM 2)] → [Show Results]
```

### Clarification Decision Tree Example — Beard
```
Beard growth detected: "patchy on cheeks, decent on chin and jawline"
  → LLM assessment: "Cannot grow full beard. Recommend short stubble or clean shave."
  → NO question asked. LLM directly recommends:
    → Stubble trim routine (1-1.5mm), neckline cleanup, PFB prevention

Beard growth detected: "even, moderate density across all areas"
  → LLM assessment: "Good growth potential. User preference needed."
  → Question: "Your beard growth looks solid. What style are you going for?"
    → User picks "Full beard"
      → Beard wash, oil, balm, shaping routine
    → User picks "Stubble"
      → Stubble maintenance, trimmer schedule
    → User picks "Clean shaven"
      → Skip beard routines, add shaving routine

Beard growth detected: "clean shaven, no visible growth"
  → LLM assessment: "Clean shaven. No beard routine needed."
  → NO question asked. Skip beard category entirely.
```

---

## Files to Create/Modify

| Action | File | Description |
|--------|------|-------------|
| CREATE | `Models/ImageAnalysisProfile.swift` | Profile struct with traits + confidence |
| CREATE | `Services/ImageAnalysisClarifier.swift` | Builds clarification questions from profile |
| MODIFY | `Services/BackendAPIClient.swift` | Add `extractImageDetails()` and `generateRoutines()` methods |
| CREATE | `ViewModels/ImageAnalysisViewModel.swift` | Multi-step flow orchestrator |
| CREATE | `Views/ImageAnalysis/ImageAnalysisFlowView.swift` | Container view for the flow |
| CREATE | `Views/ImageAnalysis/ExtractedDetailsView.swift` | Shows detected traits |
| CREATE | `Views/ImageAnalysis/ClarificationView.swift` | Clarification question cards |
| MODIFY | `ViewModels/OnboardingViewModel.swift` | Integrate new flow into onboarding |
| MODIFY | `GlowingApp.swift` | Register new model if needed |

---

## Key Design Decisions

1. **Two LLM calls vs one**: Separating extraction from generation allows user input in between. The extraction call is smaller/faster (no routine generation). The generation call doesn't need images (just structured traits), making it cheaper and more reliable.

2. **Confidence-based clarification**: Only ask questions when the AI isn't sure. This keeps the flow short for users with clearly visible traits while catching edge cases.

3. **Beard style is AI-driven, not always user-prompted**: If the LLM can see that beard growth is patchy, it should make the call (recommend stubble/clean) without asking. Only prompt the user when growth is genuinely ambiguous and multiple styles would work. This avoids offering bad options (e.g., "full beard" when cheeks are sparse).

4. **Profile not persisted**: The `ImageAnalysisProfile` is transient — used only during the flow. The `SkinAnalysis` model continues to store the full analysis for progress tracking.

5. **Reuse existing photo infrastructure**: No changes to camera/capture views. For "routine" flow, reuse `ProgressPhoto` sessions. For "fresh" flow, reuse `OnboardingCaptureView` or `ProgressPhotoCaptureView`.
