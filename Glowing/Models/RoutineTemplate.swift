import Foundation

// MARK: - Template Data Structures

enum Season: String, CaseIterable, Codable {
    case yearRound
    case winter
    case spring
    case summer
    case fall

    var displayName: String {
        switch self {
        case .yearRound: "Year-Round"
        case .winter: "Winter (Dec – Feb)"
        case .spring: "Spring (Mar – May)"
        case .summer: "Summer (Jun – Aug)"
        case .fall: "Fall (Sep – Nov)"
        }
    }

    var icon: String {
        switch self {
        case .yearRound: "calendar"
        case .winter: "snowflake"
        case .spring: "leaf.fill"
        case .summer: "sun.max.fill"
        case .fall: "wind"
        }
    }

    /// Months belonging to this season (1=Jan ... 12=Dec)
    var months: Set<Int> {
        switch self {
        case .yearRound: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        case .winter: [12, 1, 2]
        case .spring: [3, 4, 5]
        case .summer: [6, 7, 8]
        case .fall: [9, 10, 11]
        }
    }

    /// Whether the given date falls within this season
    func isCurrent(on date: Date = Date()) -> Bool {
        if self == .yearRound { return true }
        let month = Calendar.current.component(.month, from: date)
        return months.contains(month)
    }
}

/// A package groups related routines together (e.g. "Face Care" contains morning, evening, weekly).
struct RoutinePackage: Identifiable {
    let id = UUID()
    let name: String
    let category: Category
    let icon: String
    let description: String
    let routines: [RoutineTemplate]

    var totalSteps: Int {
        routines.reduce(0) { $0 + $1.steps.count }
    }
}

/// A single routine template within a package.
struct RoutineTemplate: Identifiable {
    let id = UUID()
    let name: String
    let timeOfDay: TimeOfDay
    let season: Season
    let scheduledWeekdays: Set<Int>  // 1=Sun ... 7=Sat, empty = every day
    let displayOrder: Int            // controls ordering within same category + timeOfDay
    let icon: String
    let steps: [StepTemplate]

    init(name: String, timeOfDay: TimeOfDay, season: Season = .yearRound, scheduledWeekdays: Set<Int> = [], displayOrder: Int = 0, icon: String, steps: [StepTemplate]) {
        self.name = name
        self.timeOfDay = timeOfDay
        self.season = season
        self.scheduledWeekdays = scheduledWeekdays
        self.displayOrder = displayOrder
        self.icon = icon
        self.steps = steps
    }
}

struct StepTemplate {
    let title: String
    let productName: String?
    let notes: String?
    let timerDuration: Int?
    let dayVariants: [DayVariantTemplate]

    init(title: String, productName: String? = nil, notes: String? = nil, timerDuration: Int? = nil, dayVariants: [DayVariantTemplate] = []) {
        self.title = title
        self.productName = productName
        self.notes = notes
        self.timerDuration = timerDuration
        self.dayVariants = dayVariants
    }
}

struct DayVariantTemplate {
    let weekday: Int  // 1=Sun ... 7=Sat
    let productName: String?
    let notes: String?
    let skip: Bool

    init(weekday: Int, productName: String? = nil, notes: String? = nil, skip: Bool = false) {
        self.weekday = weekday
        self.productName = productName
        self.notes = notes
        self.skip = skip
    }
}

// MARK: - Default Packages

extension RoutinePackage {
    static let allPackages: [RoutinePackage] = [
        skinCarePackage,
        stubblePackage,
        hairCarePackage,
    ]

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 1. SKINCARE
    // Optimised for acne-prone / oily skin with PIH
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    static let skinCarePackage = RoutinePackage(
        name: "Skincare",
        category: .face,
        icon: "face.smiling",
        description: "Morning protection + evening treatment with rotating actives. BPO mornings, adapalene evenings — never the same session. Never skip SPF.",
        routines: [
            // ── Morning Skincare ──
            RoutineTemplate(
                name: "Morning Skincare",
                timeOfDay: .morning,
                displayOrder: 0,
                icon: "sun.max.fill",
                steps: [
                    StepTemplate(
                        title: "BPO Face Wash",
                        productName: "BPO 4% Foaming Wash",
                        notes: "Apply to wet skin FIRST in shower. Proceed with all other shower tasks. Rinse face LAST — this gives 5+ min contact time passively. A 20-second lather produces zero P. acnes reduction; 5+ min performs comparably to a leave-on. Alternative: PanOxyl 4%.",
                        timerDuration: 300
                    ),
                    StepTemplate(
                        title: "Vitamin C Serum",
                        productName: "SAP 5% Vitamin C",
                        notes: "Sodium ascorbyl phosphate (SAP) is the right form for oily, acne-prone skin — stable at neutral pH, gentle, antimicrobial, and brightening. Klock et al. showed 5% SAP reduced UVA-induced sebum oxidation by 40%. L-ascorbic acid (like Timeless) requires pH below 3.5 and can paradoxically trigger PIH in darker skin. 4–5 drops, press gently into face and neck."
                    ),
                    StepTemplate(
                        title: "Sunscreen",
                        productName: "EltaMD UV Clear Tinted SPF 46",
                        notes: "Must be TINTED — iron oxides block visible light (400–700nm), which independently triggers pigmentation in Fitzpatrick IV–V skin. Untinted mineral sunscreens leave grey-white cast. Melanin provides only SPF 2–4 equivalent — clinically insufficient while on adapalene. Apply generously to face and neck. Never skip this step."
                    ),
                ]
            ),

            // ── Evening Skincare ──
            RoutineTemplate(
                name: "Evening Skincare",
                timeOfDay: .evening,
                displayOrder: 1,
                icon: "moon.fill",
                steps: [
                    StepTemplate(
                        title: "Gentle Cleanse",
                        productName: "CeraVe Foaming Cleanser",
                        notes: "30–60 seconds on wet skin, gentle circles. Pat dry. This removes SPF, sebum, and pollution from the day. Alternative: Vanicream Gentle Cleanser.",
                        timerDuration: 60
                    ),
                    StepTemplate(
                        title: "Active Treatment",
                        productName: "Differin Adapalene 0.1% Gel",
                        notes: "Pea-size amount, spread across entire face on dry skin. Adapalene normalizes follicular keratinization and accelerates cell turnover — bringing pigmented cells to the surface faster. Wait 10–15 min before the next step to allow full absorption and reduce irritation risk.",
                        timerDuration: 900,
                        dayVariants: [
                            // Mon / Wed / Fri → Adapalene (retinoid)
                            DayVariantTemplate(weekday: 2, productName: "Differin Adapalene 0.1% Gel", notes: "Pea-size amount, whole face on dry skin. Adapalene normalizes follicular keratinization and accelerates turnover. Wait 10–15 min before next step."),
                            DayVariantTemplate(weekday: 4, productName: "Differin Adapalene 0.1% Gel", notes: "Pea-size amount, whole face on dry skin. Wait 10–15 min before next step."),
                            DayVariantTemplate(weekday: 6, productName: "Differin Adapalene 0.1% Gel", notes: "Pea-size amount, whole face on dry skin. Wait 10–15 min before next step."),
                            // Tue / Thu / Sat → Azelaic Acid
                            DayVariantTemplate(weekday: 3, productName: "Finacea 15% Azelaic Acid Gel", notes: "Thin layer, whole face. Azelaic acid directly inhibits tyrosinase (blocking new melanin) and is antimicrobial. 15% gel delivers ~8% skin absorption vs ~3% for cream — significantly more effective for PIH. Wait 10–15 min."),
                            DayVariantTemplate(weekday: 5, productName: "Finacea 15% Azelaic Acid Gel", notes: "Thin layer, whole face. For Fitzpatrick IV–V skin, 15–20% is the clinical recommendation for PIH (Kircik 2011). Wait 10–15 min."),
                            DayVariantTemplate(weekday: 7, productName: "Finacea 15% Azelaic Acid Gel", notes: "Thin layer, whole face. Wait 10–15 min before next step."),
                            // Sunday → Recovery night (skip active)
                            DayVariantTemplate(weekday: 1, skip: true),
                        ]
                    ),
                    StepTemplate(
                        title: "Niacinamide Serum",
                        productName: "La Roche-Posay Mela B3",
                        notes: "5% niacinamide inhibited 35–68% of melanosome transfer in the landmark study (Hakozaki et al., 2002). Every night including recovery nights. Apply to face and neck. Note: Mela B3 contains ~10% niacinamide — if using CeraVe PM (4%) as moisturiser, combined dose is ~14%. This is unnecessary. Use a niacinamide-free gel moisturiser instead (e.g. Sebamed Clear Face Gel)."
                    ),
                    StepTemplate(
                        title: "Moisturise",
                        productName: "Gel Moisturiser",
                        notes: "Use a niacinamide-free gel moisturiser since Mela B3 already provides niacinamide. Options: Sebamed Clear Face Gel, or CeraVe Oil Control Gel-Cream (contains silica for matte finish — better for oily skin than CeraVe PM). Gently pat into skin. This is always the final step."
                    ),
                ]
            ),
        ]
    )

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 2. STUBBLE MAINTENANCE
    // 1–3mm maintenance protocol for PFB
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    static let stubblePackage = RoutinePackage(
        name: "Stubble",
        category: .stubble,
        icon: "line.3.horizontal",
        description: "1–3mm maintenance for pseudofolliculitis barbae. At this length hairs can't curl back into follicles — the PFB sweet spot. No beard oil, no balm, no boar brush — irrelevant at this length.",
        routines: [
            // ── Trim (Mon / Wed / Fri) ──
            RoutineTemplate(
                name: "Stubble Trim",
                timeOfDay: .morning,
                scheduledWeekdays: [2, 4, 6], // Mon, Wed, Fri
                displayOrder: 0,
                icon: "line.3.horizontal",
                steps: [
                    StepTemplate(
                        title: "Full Face Trim",
                        productName: "Trimmer with 1–1.5mm guard",
                        notes: "Always trim on dry, clean skin — wet hair appears shorter, causing over-trimming. Consistent strokes against the grain for even length. The guard controls depth, not pressure — let the tool do the work. Use Andis Slimline Pro Li or Wahl Stainless Steel Lithium."
                    ),
                    StepTemplate(
                        title: "Clean Trimmer",
                        notes: "Brush out hair, spray with blade sanitiser. A dirty trimmer drags and nicks."
                    ),
                ]
            ),

            // ── Edge Cleanup (Mon = neckline, Wed = cheek line) ──
            RoutineTemplate(
                name: "Edge Cleanup",
                timeOfDay: .morning,
                scheduledWeekdays: [2, 4], // Mon, Wed
                displayOrder: 1,
                icon: "scissors",
                steps: [
                    StepTemplate(
                        title: "Define Neckline",
                        productName: "Single-blade safety razor",
                        notes: "One finger above Adam's apple, soft U-shape to each ear. Always WITH the grain — never against. Multi-blade cartridge razors lift hair before cutting, producing re-entry below skin level (the exact PFB mechanism). Use a Merkur 34C or Henson AL13. Hold skin taut where angles change.",
                        dayVariants: [
                            DayVariantTemplate(weekday: 4, skip: true), // Skip neckline on Wed
                        ]
                    ),
                    StepTemplate(
                        title: "Clean Up Cheek Line",
                        notes: "Remove strays above natural cheek line only. Use trimmer without guard or safety razor, always with the grain. Don't create an artificially sharp line — it should look natural.",
                        dayVariants: [
                            DayVariantTemplate(weekday: 2, skip: true), // Skip cheek line on Mon
                        ]
                    ),
                    StepTemplate(
                        title: "Rinse & Apply Azelaic Acid",
                        notes: "Rinse with cool water. Apply azelaic acid AFTER cleaning your razor, not before — avoids the active drying on skin under mechanical pressure. Azelaic acid is one of the best PFB treatments: anti-inflammatory and reduces follicular keratosis."
                    ),
                ]
            ),
        ]
    )

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 3. HAIR CARE & STYLING
    // Thick, slightly coarse, black South Asian hair, oily scalp
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    static let hairCarePackage = RoutinePackage(
        name: "Hair Care",
        category: .hair,
        icon: "scissors",
        description: "Daily/every-other-day washing for oily scalp (the 'wash less' myth has no scientific backing). Three-shampoo rotation, clay styling, blow-dry technique.",
        routines: [
            // ── Daily Wash & Style ──
            RoutineTemplate(
                name: "Hair Wash & Style",
                timeOfDay: .morning,
                displayOrder: 0,
                icon: "drop.fill",
                steps: [
                    StepTemplate(
                        title: "Shampoo — Scalp Only",
                        productName: "Daily: Sulfate-free balancing shampoo",
                        notes: "Massage into scalp with fingertips for 4 minutes — a 2016 study showed daily 4-min scalp massage for 24 weeks significantly increased hair shaft thickness. Never work shampoo through lengths. A study of 1,500 Asian participants found maximum satisfaction at 5–6 washes/week. Oil production is genetic, not frequency-dependent.",
                        timerDuration: 240,
                        dayVariants: [
                            // Wednesday = clarifying shampoo
                            DayVariantTemplate(weekday: 4, productName: "Clarifying: Neutrogena T/Sal", notes: "Deep-clean buildup once a week. Alternative: Bumble & Bumble Sunday Shampoo. Still massage scalp 4 min. Condition after — clarifying strips moisture."),
                            // Sun = skip (every other day pattern allows rest)
                            DayVariantTemplate(weekday: 1, skip: true),
                        ]
                    ),
                    StepTemplate(
                        title: "Condition Mid-Lengths to Ends",
                        notes: "NEVER condition the scalp — only mid-lengths to ends. Avoid shampoos and conditioners labelled 'moisturising' or 'for dry hair.' Mild sulfates are fine for oily scalps in the clarifying step. Leave in for 1–2 minutes.",
                        timerDuration: 120
                    ),
                    StepTemplate(
                        title: "Towel Dry",
                        notes: "Pat dry with a microfiber towel — never rub. Rubbing roughens the cuticle and causes breakage."
                    ),
                    StepTemplate(
                        title: "Apply Clay — First Layer",
                        productName: "Clay (Hanz de Fuko Claymation / Layrite Cement)",
                        notes: "Clay is the right choice for thick, coarse hair: high hold, matte finish, no greasiness, absorbs scalp oil, washes out easily. Work a small amount through DAMP hair. Sea salt spray as a pre-styler adds grip and texture."
                    ),
                    StepTemplate(
                        title: "Blow Dry Into Shape",
                        notes: "Apply heat protectant first (look for dimethicone or squalane). Keep dryer 15cm from hair at all times. Direct airflow root-to-tip to seal the cuticle. A 2011 Yonsei study found air-dried hair showed MORE damage than blow-dried at 15cm — thick hair stays wet for hours, and hair is weakest when wet. Finish with a cool shot to lock the style."
                    ),
                    StepTemplate(
                        title: "Apply Clay — Second Layer",
                        notes: "Light second layer on DRY hair for final definition and hold. Less is more — you can always add but can't remove."
                    ),
                ]
            ),

            // ── Rosemary Oil Treatment (evening, daily) ──
            RoutineTemplate(
                name: "Scalp Oil Treatment",
                timeOfDay: .evening,
                displayOrder: 1,
                icon: "leaf.fill",
                steps: [
                    StepTemplate(
                        title: "Rosemary Oil Scalp Massage",
                        productName: "2–5 drops rosemary oil in jojoba carrier",
                        notes: "A 2015 RCT found rosemary oil performed as well as 2% minoxidil for hair count increase over 6 months, with less scalp irritation. Lab evidence shows rosemary extract inhibits 5-alpha-reductase by 82.4%. Massage into scalp with fingertips for 2–3 minutes. Do this every evening.",
                        timerDuration: 180
                    ),
                ]
            ),

            // ── Weekly Anti-Dandruff (if needed) ──
            RoutineTemplate(
                name: "Anti-Dandruff Wash",
                timeOfDay: .weekly,
                scheduledWeekdays: [7], // Saturday
                displayOrder: 2,
                icon: "sparkles",
                steps: [
                    StepTemplate(
                        title: "Ketoconazole Shampoo",
                        productName: "Nizoral A-D (1% Ketoconazole)",
                        notes: "Use 2–3x/week if needed for dandruff control. Combining salicylic acid + zinc pyrithione is synergistic. Leave on scalp for 3–5 minutes before rinsing.",
                        timerDuration: 240
                    ),
                    StepTemplate(
                        title: "Condition Ends",
                        notes: "Follow with regular conditioner on mid-lengths to ends only."
                    ),
                ]
            ),
        ]
    )

}
