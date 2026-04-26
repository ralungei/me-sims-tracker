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
//   how often you log each need, how much total boost you give yourself
//   per day, and the average interval between consecutive actions.
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
        let avgActionsPerDay: Double     // positive actions / day
        let avgIntervalHours: Double     // hours between consecutive actions
        let idealDecayRate: Double       // computed optimal decay %/h
        let confidence: Double           // 0.0 – 1.0
        let dataPoints: Int              // total positive actions analyzed
    }

    var rhythms: [NeedType: PersonalRhythm] = [:]
    var lastCalibration: Date?
    var daysOfData: Int = 0

    /// Overall calibration confidence (0–100%).
    var overallConfidence: Double {
        guard !rhythms.isEmpty else { return 0 }
        let sum = rhythms.values.reduce(0.0) { $0 + $1.confidence }
        return sum / Double(rhythms.count) * 100
    }

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
        daysOfData = uniqueDays.count

        for need in NeedType.allCases {
            let needLogs = recentLogs
                .filter { $0.needType == need.rawValue }
                .sorted { $0.timestamp < $1.timestamp }

            guard !needLogs.isEmpty else {
                // No data for this need — no personalization
                rhythms[need] = PersonalRhythm(
                    need: need,
                    avgDailyBoost: 0,
                    avgActionsPerDay: 0,
                    avgIntervalHours: 0,
                    idealDecayRate: need.decayRatePerHour,
                    confidence: 0,
                    dataPoints: 0
                )
                continue
            }

            // Total boost over the period
            let totalBoost = needLogs.reduce(0.0) { $0 + $1.boostAmount }
            let days = max(1, Double(daysOfData))
            let avgDailyBoost = totalBoost / days
            let avgActionsPerDay = Double(needLogs.count) / days

            // Average interval between consecutive actions
            var intervals: [Double] = []
            for i in 1..<needLogs.count {
                let hours = needLogs[i].timestamp.timeIntervalSince(needLogs[i - 1].timestamp) / 3600
                if hours > 0.05 && hours < 24 {  // skip duplicates and cross-day gaps
                    intervals.append(hours)
                }
            }
            let avgInterval = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)

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
                avgActionsPerDay: avgActionsPerDay,
                avgIntervalHours: avgInterval,
                idealDecayRate: clampedIdeal,
                confidence: confidence,
                dataPoints: needLogs.count
            )
        }

        lastCalibration = Date()
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

    // MARK: - Human-readable summaries

    func rhythmSummary(for need: NeedType) -> String? {
        guard let r = rhythms[need], r.dataPoints >= 3 else { return nil }
        let actionsStr = String(format: "%.1f", r.avgActionsPerDay)
        if r.avgIntervalHours > 0.5 {
            let intervalStr = String(format: "%.1f", r.avgIntervalHours)
            return "\(actionsStr)×/día, cada ~\(intervalStr)h"
        }
        return "\(actionsStr)×/día"
    }

    func calibrationLabel(for need: NeedType) -> String {
        guard let r = rhythms[need] else { return "Sin datos" }
        if r.confidence < 0.1 { return "Sin datos" }
        if r.confidence < 0.5 { return "Aprendiendo..." }
        return "Calibrado \(Int(r.confidence * 100))%"
    }
}
