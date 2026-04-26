import SwiftUI
import SwiftData
import Charts

// MARK: - Insights View

struct InsightsView: View {
    @Environment(NeedStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityLog.timestamp, order: .reverse)
    private var allActivities: [ActivityLog]

    @State private var selectedPeriod: Period = .week

    enum Period: String, CaseIterable {
        case week = "7 días"
        case month = "30 días"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        periodPicker
                        currentStatusCard
                        activityChart
                        needBreakdownChart
                        streakCard
                        patternsSection
                        calibrationSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Período", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Current Status Card

    private var currentStatusCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Estado actual")
                    .font(SimsTheme.headlineFont)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(store.overallMood * 100))%")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.plumbobColor(for: store.overallMood))
            }

            // Mini bars for all needs
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(NeedType.sorted) { need in
                    HStack(spacing: 6) {
                        Image(systemName: need.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(SimsTheme.barColor(for: store.needs[need] ?? 0))
                            .frame(width: 16)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(SimsTheme.barGradient(for: store.needs[need] ?? 0))
                                    .frame(width: max(0, geo.size.width * (store.needs[need] ?? 0)))
                            }
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())

                        Text("\(Int((store.needs[need] ?? 0) * 100))")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SimsTheme.panelBackground)
        )
    }

    // MARK: - Activity Chart (activities per day)

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actividades por día")
                .font(SimsTheme.headlineFont)
                .foregroundStyle(.white)

            if periodActivities.isEmpty {
                noDataPlaceholder
            } else {
                Chart(dailyActivityCounts, id: \.day) { item in
                    BarMark(
                        x: .value("Día", item.day, unit: .day),
                        y: .value("Actividades", item.count)
                    )
                    .foregroundStyle(SimsTheme.accentGreen.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedPeriod == .week ? 1 : 5)) { value in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SimsTheme.panelBackground)
        )
    }

    // MARK: - Need Breakdown Chart

    private var needBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones por categoría")
                .font(SimsTheme.headlineFont)
                .foregroundStyle(.white)

            if periodActivities.isEmpty {
                noDataPlaceholder
            } else {
                Chart(needActivityCounts, id: \.need) { item in
                    BarMark(
                        x: .value("Cantidad", item.count),
                        y: .value("Necesidad", item.need.displayName)
                    )
                    .foregroundStyle(SimsTheme.barColor(for: Double(item.count) / maxNeedCount).gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SimsTheme.panelBackground)
        )
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(currentStreak)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.accentGreen)
                Text("Racha actual")
                    .font(SimsTheme.labelFont)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)
                .overlay(Color.white.opacity(0.1))

            VStack(spacing: 4) {
                Text("\(totalActivitiesCount)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("Total registros")
                    .font(SimsTheme.labelFont)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)
                .overlay(Color.white.opacity(0.1))

            VStack(spacing: 4) {
                Text(mostActiveNeed?.displayName ?? "—")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("Más activa")
                    .font(SimsTheme.labelFont)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SimsTheme.panelBackground)
        )
    }

    // MARK: - Patterns

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patrones detectados")
                .font(SimsTheme.headlineFont)
                .foregroundStyle(.white)

            if patterns.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow.opacity(0.6))
                    Text("Sigue registrando actividades para descubrir patrones")
                        .font(SimsTheme.labelFont)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding()
            } else {
                ForEach(patterns, id: \.self) { pattern in
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text(pattern)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SimsTheme.cardBackground)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SimsTheme.panelBackground)
        )
    }

    // MARK: - No Data

    private var noDataPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.2))
                Text("Aún no hay datos suficientes")
                    .font(SimsTheme.labelFont)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 30)
            Spacer()
        }
    }

    // MARK: - Data Computation

    private var periodActivities: [ActivityLog] {
        let days = selectedPeriod == .week ? 7 : 30
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allActivities.filter { $0.timestamp >= cutoff }
    }

    private struct DailyCount: Equatable {
        let day: Date
        let count: Int
    }

    private var dailyActivityCounts: [DailyCount] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: periodActivities) { activity in
            cal.startOfDay(for: activity.timestamp)
        }
        return grouped.map { DailyCount(day: $0.key, count: $0.value.count) }
            .sorted { $0.day < $1.day }
    }

    private struct NeedCount: Equatable {
        let need: NeedType
        let count: Int
    }

    private var needActivityCounts: [NeedCount] {
        let grouped = Dictionary(grouping: periodActivities) { $0.needType }
        return NeedType.sorted.compactMap { need in
            let count = grouped[need.rawValue]?.count ?? 0
            return count > 0 ? NeedCount(need: need, count: count) : nil
        }
    }

    private var maxNeedCount: Double {
        Double(needActivityCounts.map(\.count).max() ?? 1)
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        while true {
            let dayActivities = allActivities.filter {
                cal.isDate($0.timestamp, inSameDayAs: checkDate)
            }
            if dayActivities.isEmpty { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    private var totalActivitiesCount: Int {
        periodActivities.count
    }

    private var mostActiveNeed: NeedType? {
        needActivityCounts.max(by: { $0.count < $1.count })?.need
    }

    // MARK: - Calibration Section

    private var calibrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auto-calibración")
                    .font(SimsTheme.headlineFont)
                    .foregroundStyle(.white)
                Spacer()
                let pct = Int(store.calibration.overallConfidence)
                Text("\(pct)%")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(pct > 50 ? SimsTheme.accentGreen : .white.opacity(0.4))
            }

            if store.calibration.daysOfData == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Las tasas de decay se ajustarán a tus ritmos reales conforme uses la app")
                        .font(SimsTheme.labelFont)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding()
            } else {
                Text("\(store.calibration.daysOfData) días de datos")
                    .font(SimsTheme.labelFont)
                    .foregroundStyle(.white.opacity(0.4))

                ForEach(NeedType.sorted) { need in
                    if let rhythm = store.calibration.rhythms[need], rhythm.dataPoints >= 2 {
                        HStack(spacing: 8) {
                            Image(systemName: need.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(SimsTheme.barColor(for: store.needs[need] ?? 0.5))
                                .frame(width: 18)

                            Text(need.displayName)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 80, alignment: .leading)

                            if let summary = store.calibration.rhythmSummary(for: need) {
                                Text(summary)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                            Spacer()

                            Text(store.calibration.calibrationLabel(for: need))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(
                                    rhythm.confidence > 0.5
                                        ? SimsTheme.accentGreen.opacity(0.7)
                                        : .white.opacity(0.3)
                                )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SimsTheme.panelBackground)
        )
    }

    private var patterns: [String] {
        var results: [String] = []
        guard periodActivities.count >= 5 else { return results }

        // Pattern: neglected needs
        let needCounts = Dictionary(grouping: periodActivities) { $0.needType }
        for need in NeedType.sorted {
            if needCounts[need.rawValue] == nil || (needCounts[need.rawValue]?.count ?? 0) == 0 {
                results.append("No has registrado \(need.displayName) en este período")
            }
        }

        // Pattern: most active time of day
        let hourCounts = Dictionary(grouping: periodActivities) {
            Calendar.current.component(.hour, from: $0.timestamp)
        }
        if let peakHour = hourCounts.max(by: { $0.value.count < $1.value.count }) {
            let timeStr = String(format: "%02d:00", peakHour.key)
            results.append("Tu hora más activa es alrededor de las \(timeStr)")
        }

        // Pattern: consistency check
        let days = selectedPeriod == .week ? 7 : 30
        let activeDays = Set(periodActivities.map {
            Calendar.current.startOfDay(for: $0.timestamp)
        }).count
        let ratio = Double(activeDays) / Double(days)
        if ratio > 0.8 {
            results.append("¡Gran constancia! Registraste actividad el \(Int(ratio * 100))% de los días")
        } else if ratio < 0.3 {
            results.append("Intenta registrar más seguido — solo el \(Int(ratio * 100))% de los días tienen datos")
        }

        return Array(results.prefix(4))
    }
}

#Preview {
    InsightsView()
        .environment(NeedStore())
        .modelContainer(for: ActivityLog.self, inMemory: true)
}
