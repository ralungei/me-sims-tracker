import Foundation
import SwiftData

// MARK: - Adaptive Rhythm Learning (ARL)
//
// Self-calibrating system that learns your personal rhythms and adjusts
// decay rates to match YOUR lifestyle — not a generic template.
//
// HOW IT WORKS:
//
// Phase 1 — Observe (days 1–7):
//   The system uses hardcoded default rates while it collects data on
//   how much total boost you give yourself per day for each need.
//
// Phase 2 — Learn (days 7–14):
//   From the data, it computes an "ideal" decay rate for each need.
//   The key insight: if you typically give yourself 150% of Nutrition
//   boost across 16 waking hours, the decay should be ~8%/h so that
//   a normal day keeps you in the 30–70% comfort zone.
//
//   Formula:
//     idealDecay = (avgDailyBoost × comfortFactor) / activeHours
//
//   Where comfortFactor (0.80) ensures you stay above critical if you
//   do your normal routine.
//
// Phase 3 — Blend (ongoing):
//   The effective rate is a blend of default and ideal, weighted by
//   confidence (how much data we have).
//
//     effectiveRate = default × (1 - confidence) + ideal × confidence
//     confidence = min(1.0, actionCount / 28)  // ~4 actions/day × 7 days
//
//   This means: day 1 = 100% default, day 14+ = mostly personalized.
//
// Phase 4 — Adapt:
//   Every time the app launches, recalibrate from the last 14 days.
//   If your habits change, the system adapts within 1–2 weeks.

@Observable
final class CalibrationEngine {

    // MARK: - Personal Rhythm (per need)

    struct PersonalRhythm {
        let need: NeedType
        let avgDailyBoost: Double        // total positive boost / day
        let idealDecayRate: Double       // computed optimal decay %/h
        let confidence: Double           // 0.0 – 1.0
    }

    var rhythms: [NeedType: PersonalRhythm] = [:]

    // MARK: - Constants

    private let comfortFactor = 0.80
    private let activeHoursPerDay = 16.0
    private let minConfidenceActions = 28  // ~4/day × 7 days
    private let lookbackDays = 14
    private let maxRateMultiplier = 2.0    // never exceed 2× default
    private let minRateMultiplier = 0.3    // never go below 0.3× default

    // MARK: - Calibrate

    func calibrate(from logs: [ActivityLog]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let recentLogs = logs.filter { $0.timestamp >= cutoff && $0.boostAmount > 0 }

        guard !recentLogs.isEmpty else { return }

        // How many unique days have data
        let uniqueDays = Set(recentLogs.map { Calendar.current.startOfDay(for: $0.timestamp) })
        let daysOfData = uniqueDays.count

        for need in NeedType.allCases {
            let needLogs = recentLogs.filter { $0.needType == need.rawValue }

            guard !needLogs.isEmpty else {
                // No data for this need — no personalization
                rhythms[need] = PersonalRhythm(
                    need: need,
                    avgDailyBoost: 0,
                    idealDecayRate: need.decayRatePerHour,
                    confidence: 0
                )
                continue
            }

            // Total boost over the period
            let totalBoost = needLogs.reduce(0.0) { $0 + $1.boostAmount }
            let days = max(1, Double(daysOfData))
            let avgDailyBoost = totalBoost / days

            // Compute ideal decay rate
            // The goal: avgDailyBoost sustains the bar across active hours
            // at the comfort level (bar stays in 30-70% zone most of the day)
            let idealDecay: Double
            if avgDailyBoost > 0 {
                idealDecay = (avgDailyBoost * comfortFactor) / activeHoursPerDay
            } else {
                idealDecay = need.decayRatePerHour
            }

            // Clamp to safety bounds
            let defaultRate = need.decayRatePerHour
            let clampedIdeal = min(defaultRate * maxRateMultiplier,
                                   max(defaultRate * minRateMultiplier, idealDecay))

            // Confidence: based on data volume
            let confidence = min(1.0, Double(needLogs.count) / Double(minConfidenceActions))

            rhythms[need] = PersonalRhythm(
                need: need,
                avgDailyBoost: avgDailyBoost,
                idealDecayRate: clampedIdeal,
                confidence: confidence
            )
        }
    }

    // MARK: - Get Effective Rate

    /// Returns the blended decay rate: default → personalized as confidence grows.
    func effectiveDecayRate(for need: NeedType) -> Double {
        let defaultRate = need.decayRatePerHour
        guard let rhythm = rhythms[need], rhythm.confidence > 0.05 else {
            return defaultRate
        }
        return defaultRate * (1 - rhythm.confidence) + rhythm.idealDecayRate * rhythm.confidence
    }
}
