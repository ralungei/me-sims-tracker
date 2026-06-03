#!/usr/bin/env swift
//
// CalibrationCheck.swift
//
// Runnable calibration harness for My Sims Life. Mirrors the constants
// from `MySimsLife/Models/NeedType.swift` and asserts that user-facing
// behaviour stays within sensible ranges. Run after any change to:
//
//   - `decayRatePerHour` for any NeedType
//   - `moodWeight` for any NeedType
//   - any quick action boost / +xp / vital formula
//   - the vital score formula in NeedStore
//
// Usage:
//   swift Tools/CalibrationCheck.swift
//
// Exit code: 0 on pass, 1 on any failed assertion.
// See `docs/CALIBRATION.md` for what each scenario verifies and why.
//
// IMPORTANT: if you change a constant in the app, copy it here too — this
// file is intentionally self-contained so it can run without the Xcode
// project. Drift between this and the app code = false confidence.

import Foundation

// MARK: - Constants (kept in sync with MySimsLife/Models/NeedType.swift)

let decayRates: [String: Double] = [
    "health": 0,
    "mentalHealth": 1.5,
    "energy": 6.25,
    "nutrition": 6.0,
    "hydration": 7.0,
    "bladder": 12.5,
    "exercise": 4.17,
    "hygiene": 4.17,
    "environment": 2.5,
    "social": 2.08,
    "leisure": 3.5
]

let moodWeights: [String: Double] = [
    "health": 1.8,
    "mentalHealth": 1.6,
    "energy": 1.5,
    "nutrition": 1.3,
    "hydration": 1.2,
    "bladder": 1.0,
    "exercise": 1.0,
    "hygiene": 0.8,
    "environment": 0.7,
    "social": 1.1,
    "leisure": 0.9
]

// Sum of positive boosts available per need — used to verify each
// category has enough levers to recover from 0 → 100 in a day.
let positiveBoostBudget: [String: Double] = [
    "health":       130,  // 100 + 30
    "mentalHealth": 240,  // Tranquilo 20 + Medité 35 + Diario 25 + Terapia 50 + Respi 20 + Gratitud 25 + Naturaleza 30 + Desahogo 25 + (room)
    "energy":       220,  // 100+85+70+40+25+10
    "nutrition":    240,  // 50+55+50+30+20
    "hydration":    100,  // 30+18+22+22
    "exercise":     270,  // 65+35+55+50+40+65+20
    "hygiene":      145,  // 65+20+15+20+25
    "environment":  145,  // 55+30+20+25+15
    "social":       210,  // 55+50+30+15+60
    "leisure":      210,  // 40+35+20+45+30+40
    "bladder":      460   // 100+80+60+100+60+60
]

// Mirrors `NeedPlan.essentialSet` in NeedType.swift: the four
// lowest-logging-effort pillars. Nutrition is NOT here — it needs 3-5 logs/day,
// too heavy for the default tier, so it lives in `balancedPlan`.
let essentialPlan: Set<String> = ["energy", "exercise", "hygiene", "mentalHealth"]
// Mirrors `NeedPlan.balancedSet`: essential + nutrition, social, health.
// Scenarios that exercise nutrition run under this plan, since in the app you
// only track nutrition once you've opted into Equilibrado or above.
let balancedPlan: Set<String> = essentialPlan.union(["nutrition", "social", "health"])
let completePlan: Set<String> = Set(decayRates.keys)

// MARK: - Simulation helpers

typealias Bars = [String: Double]

func freshBars() -> Bars {
    var b: Bars = [:]
    for (need, rate) in decayRates {
        b[need] = rate > 0 ? 0.5 : 1.0   // manual-only needs (health) start full
    }
    return b
}

func applyDecay(_ bars: inout Bars, hours: Double, enabled: Set<String>) {
    for need in bars.keys {
        guard enabled.contains(need), let rate = decayRates[need], rate > 0 else { continue }
        bars[need] = max(0, (bars[need] ?? 0) - rate * hours / 100.0)
    }
}

func boost(_ bars: inout Bars, _ need: String, _ delta: Double) {
    bars[need] = max(0, min(1, (bars[need] ?? 0) + delta / 100.0))
}

func overallMood(_ bars: Bars, enabled: Set<String>) -> Double {
    var weighted = 0.0, total = 0.0
    for need in enabled {
        let v = bars[need] ?? 0
        let w = moodWeights[need] ?? 1
        weighted += v * w
        total += w
    }
    return total > 0 ? weighted / total : 0.5
}

func vital(_ bars: Bars, enabled: Set<String>, aspirationsDone: Int = 0) -> Int {
    // Matches `NeedStore.vitalScore` — mood maps 1:1 to 0-100 so neutral
    // bars (all at 50 %) give a centred VITAL of 50 instead of 45.
    let base = overallMood(bars, enabled: enabled) * 100.0
    let bonus = min(10.0, Double(aspirationsDone) * 3.0)
    return Int(min(100.0, base + bonus).rounded())
}

func hoursTo(_ from: Double, _ to: Double, rate: Double) -> Double {
    guard rate > 0, from > to else { return .infinity }
    return (from - to) * 100.0 / rate
}

// MARK: - Assertion plumbing

var passes = 0
var failures = 0

func check(_ name: String,
           _ condition: Bool,
           _ explanation: @autoclosure () -> String = "") {
    if condition {
        print("  [PASS] \(name)")
        passes += 1
    } else {
        let ex = explanation()
        print("  [FAIL] \(name)\(ex.isEmpty ? "" : " — \(ex)")")
        failures += 1
    }
}

func section(_ title: String) {
    print("\n══ \(title) ══")
}

// MARK: - Scenarios

section("1. Arranque fresh install")
do {
    let b = freshBars()
    let v = vital(b, enabled: essentialPlan)
    let mood = overallMood(b, enabled: essentialPlan)
    check("VITAL en rango [40, 55]", (40...55).contains(v),
          "got \(v) (expected 50% mood × 90 + 0 = 45)")
    check("Mood = 50% exacto", abs(mood - 0.5) < 0.001,
          "got \(Int(mood * 100))%")
    check("Health arranca al 100% (no decae)", (b["health"] ?? 0) == 1.0,
          "got \(b["health"] ?? 0)")
    check("Bars decaying arrancan al 50%",
          (b["energy"] ?? 0) == 0.5 &&
          (b["nutrition"] ?? 0) == 0.5,
          "got energy=\(b["energy"] ?? 0), nutrition=\(b["nutrition"] ?? 0)")
}

section("2. Decay rates en rangos sensatos")
do {
    // hours from 100% to 0% sin acciones
    // - Decaying needs should drain in a sensible time horizon.
    // - Acceptable ranges are subjective but conservative; if you need to
    //   adjust, justify in CALIBRATION.md.
    let expectedHoursToZero: [(String, ClosedRange<Double>)] = [
        ("mentalHealth", 50.0  ... 100.0), // 2-4 days of neglect
        ("energy",       14.0  ... 20.0),  // 1 day of being awake
        ("nutrition",    14.0  ... 20.0),  // 1 day of fasting
        ("hydration",    12.0  ... 18.0),  // <1 day without drinking
        ("bladder",       6.0  ... 12.0),  // a few hours
        ("exercise",     20.0  ... 30.0),  // 1 day of sedentary
        ("hygiene",      20.0  ... 30.0),  // 1 day without shower
        ("environment",  30.0  ... 50.0),  // few days mess accumulates
        ("social",       40.0  ... 60.0),  // few days alone
        ("leisure",      24.0  ... 36.0)   // 1-1.5 day of all-work
    ]
    for (need, range) in expectedHoursToZero {
        let rate = decayRates[need] ?? 0
        let hours = hoursTo(1.0, 0.0, rate: rate)
        check("\(need) drena en \(Int(range.lowerBound))-\(Int(range.upperBound))h",
              range.contains(hours),
              "got \(String(format: "%.1f", hours))h (rate \(rate)/h)")
    }
}

section("3. Cada need tiene presupuesto de positivos ≥ 100")
do {
    // If a need can't be recovered from 0→100 in a day with the available
    // quick actions, the user is permanently stuck. Health is manual-only
    // so it's bounded by user logging — still expected > 100.
    for (need, budget) in positiveBoostBudget {
        check("\(need) — positivos suman \(Int(budget))",
              budget >= 100,
              "only \(budget) total — can't fully recover from 0%")
    }
}

section("4. Comer ≠ hambre 5 min después")
do {
    var b = freshBars()
    // Nutrition lives in Equilibrado+, so this scenario runs under balancedPlan.
    applyDecay(&b, hours: 5, enabled: balancedPlan)  // hambre antes de almuerzo
    boost(&b, "nutrition", 55)                         // Almuerzo
    let afterAlmuerzo = b["nutrition"] ?? 0
    applyDecay(&b, hours: 5.0 / 60.0, enabled: balancedPlan)  // 5 min después
    let after5min = b["nutrition"] ?? 0
    check("Nutrición tras Almuerzo > 60%", afterAlmuerzo > 0.60,
          "got \(Int(afterAlmuerzo * 100))%")
    check("5 min después sigue > 60% (no se dispara alerta)",
          after5min > 0.60,
          "got \(Int(after5min * 100))%")
    let drop = afterAlmuerzo - after5min
    check("Drop en 5 min < 2%", drop < 0.02,
          "got drop=\(String(format: "%.2f", drop * 100))%")
}

section("5. Día activo logra VITAL alto")
do {
    // The active day logs breakfast + lunch (nutrition), so it represents a
    // user on Equilibrado+ — run under balancedPlan.
    var b = freshBars()
    var peakVital = 0
    applyDecay(&b, hours: 0.5, enabled: balancedPlan)
    boost(&b, "energy", 100)                                    // 07:30 Dormí 8h
    peakVital = max(peakVital, vital(b, enabled: balancedPlan))
    applyDecay(&b, hours: 0.5, enabled: balancedPlan)
    boost(&b, "nutrition", 50)                                  // 08:00 Desayuno
    peakVital = max(peakVital, vital(b, enabled: balancedPlan))
    applyDecay(&b, hours: 0.5, enabled: balancedPlan)
    boost(&b, "mentalHealth", 35)                               // 08:30 Medité
    peakVital = max(peakVital, vital(b, enabled: balancedPlan))
    applyDecay(&b, hours: 4, enabled: balancedPlan)
    boost(&b, "nutrition", 55)                                  // 12:30 Almuerzo
    let midday = vital(b, enabled: balancedPlan)
    peakVital = max(peakVital, midday)

    check("Pico VITAL en la mañana ≥ 70", peakVital >= 70,
          "got peak=\(peakVital) (sleep+desayuno+medité)")
    check("Mediodía tras almorzar VITAL ≥ 60", midday >= 60,
          "got midday=\(midday)")
}

section("6. Día pasivo (sin actions) cae a < 20 en 24h")
do {
    var b = freshBars()
    applyDecay(&b, hours: 24, enabled: essentialPlan)
    let v = vital(b, enabled: essentialPlan)
    check("Día sin tocar la app: VITAL < 20", v < 20,
          "got VITAL=\(v) — el castigo a no usarse debe ser visible")
}

section("7. VITAL máximo alcanzable")
do {
    // Best-case scenario: all bars at 100% AND 4+ aspiraciones done.
    var b = freshBars()
    for need in decayRates.keys where decayRates[need]! > 0 { b[need] = 1.0 }
    let v = vital(b, enabled: essentialPlan, aspirationsDone: 4)
    check("Perfecto + 4 aspiraciones: VITAL = 100", v == 100,
          "got VITAL=\(v) (mood + clamped bonus)")
    let vNoAsp = vital(b, enabled: essentialPlan, aspirationsDone: 0)
    check("Perfecto sin aspiraciones: VITAL = 100", vNoAsp == 100,
          "got VITAL=\(vNoAsp) — mood ahora va 1:1 a 0-100")
    let vNeutral = vital(freshBars(), enabled: essentialPlan, aspirationsDone: 0)
    check("Neutro (todas al 50%): VITAL = 50", vNeutral == 50,
          "got VITAL=\(vNeutral) — el bug que motivó el cambio")
}

section("8. Mental health resiste (es el ancla)")
do {
    var b = freshBars()
    applyDecay(&b, hours: 24, enabled: essentialPlan)
    let mental = b["mentalHealth"] ?? 0
    check("Mental tras 24h sin nada se mantiene ≥ 10%",
          mental >= 0.10,
          "got \(Int(mental * 100))% — mental debe ser la más resiliente")
}

// MARK: - Summary

print("\n══ Resumen ══")
print("  \(passes) checks pasados · \(failures) fallidos")
if failures > 0 {
    print("\n  ❌ Calibración requiere atención. Mira los [FAIL] arriba.")
    exit(1)
} else {
    print("\n  ✅ Calibración sana.")
    exit(0)
}
