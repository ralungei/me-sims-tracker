import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityLog.timestamp, order: .reverse)
    private var activities: [ActivityLog]

    @State private var filterNeed: NeedType?

    var body: some View {
        ZStack {
            SimsTheme.backgroundGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                if filteredActivities.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Header (matches DashboardView's tabTitle vibe)

    private var header: some View {
        HStack(spacing: 10) {
            Text("Historial")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(SimsTheme.textPrimary)
            Spacer()
            filterButton
        }
    }

    private var filterButton: some View {
        Menu {
            Button("Todas") { filterNeed = nil }
            Divider()
            ForEach(NeedType.sorted) { need in
                Button {
                    filterNeed = need
                } label: {
                    Label(need.displayName, systemImage: need.icon)
                }
            }
        } label: {
            Image(systemName: filterNeed == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SimsTheme.textSecondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                )
        }
        .accessibilityLabel(Text("Filtrar"))
    }

    // MARK: - List

    private var list: some View {
        // Row content sits 14pt inside the periwinkle card; the periwinkle
        // card sits 20pt inside the screen edge — so the avatar has proper
        // breathing room on the left and the count tag on the right.
        List {
            ForEach(groupedByDay, id: \.key) { day, dayActivities in
                Section {
                    ForEach(dayActivities) { activity in
                        activityRow(activity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(SimsTheme.panelPeriwinkle)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(SimsTheme.frame, lineWidth: 1.2)
                                    )
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 20)
                            )
                    }
                    .onDelete { offsets in
                        deleteActivities(dayActivities, at: offsets)
                    }
                } header: {
                    Text(day)
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(SimsTheme.textSecondary)
                        .padding(.leading, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    // MARK: - Data

    private var filteredActivities: [ActivityLog] {
        guard let filter = filterNeed else { return activities }
        return activities.filter { $0.needType == filter.rawValue }
    }

    private var groupedByDay: [(key: String, value: [ActivityLog])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.current

        let grouped = Dictionary(grouping: filteredActivities) { activity in
            formatter.string(from: activity.timestamp)
        }

        return grouped.sorted {
            ($0.value.first?.timestamp ?? .distantPast) > ($1.value.first?.timestamp ?? .distantPast)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func activityRow(_ activity: ActivityLog) -> some View {
        if let needType = activity.need {
            let isNeg = activity.boostAmount < 0
            let tileTint = isNeg ? SimsTheme.negativeTint : SimsTheme.simsGreen

            HStack(spacing: 12) {
                ZStack {
                    SimsTintedTile(tint: tileTint, cornerRadius: 10, lineWidth: 1.2)
                        .frame(width: 32, height: 32)
                    SimsOutlinedIcon(systemName: needType.icon, size: 14)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Bundle.main.localizedString(forKey: activity.actionName,
                                                     value: activity.actionName,
                                                     table: nil))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                    Text(needType.displayName)
                        .font(.caption2)
                        .foregroundStyle(SimsTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(isNeg ? "\(Int(activity.boostAmount))%" : "+\(Int(activity.boostAmount))%")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(isNeg ? SimsTheme.negativeTint : SimsTheme.accentGreen)
                        .monospacedDigit()
                    Text(activity.timestamp, style: .time)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(SimsTheme.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(SimsTheme.textSecondary)
            Text("Sin actividad registrada")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(SimsTheme.textPrimary)
            Text("Toca una barra en el panel principal\npara registrar tu primera actividad")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Delete

    private func deleteActivities(_ dayActivities: [ActivityLog], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(dayActivities[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: ActivityLog.self, inMemory: true)
}
