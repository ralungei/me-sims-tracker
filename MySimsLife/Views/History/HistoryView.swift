import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityLog.timestamp, order: .reverse)
    private var activities: [ActivityLog]

    @State private var filterNeed: NeedType?

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.background.ignoresSafeArea()

                if filteredActivities.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedByDay, id: \.key) { day, dayActivities in
                            Section {
                                ForEach(dayActivities) { activity in
                                    activityRow(activity)
                                        .listRowBackground(SimsTheme.panelBackground)
                                }
                                .onDelete { offsets in
                                    deleteActivities(dayActivities, at: offsets)
                                }
                            } header: {
                                Text(day)
                                    .font(SimsTheme.labelFont)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
        }
    }

    // MARK: - Filter

    private var filterMenu: some View {
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
            Image(systemName: filterNeed == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(filterNeed == nil ? .white.opacity(0.5) : SimsTheme.accentGreen)
        }
    }

    // MARK: - Data

    private var filteredActivities: [ActivityLog] {
        guard let filter = filterNeed else { return activities }
        return activities.filter { $0.needType == filter.rawValue }
    }

    private var groupedByDay: [(key: String, value: [ActivityLog])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "es_ES")

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
            let tint = isNeg ? SimsTheme.negativeTint : SimsTheme.barColor(for: 0.7)

            HStack(spacing: 12) {
                Image(systemName: needType.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(tint.opacity(0.15)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.actionName)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                    Text(needType.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(isNeg ? "\(Int(activity.boostAmount))%" : "+\(Int(activity.boostAmount))%")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(isNeg ? SimsTheme.negativeTint : SimsTheme.accentGreen)
                    Text(activity.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.2))
            Text("Sin actividad registrada")
                .font(SimsTheme.headlineFont)
                .foregroundStyle(.white.opacity(0.5))
            Text("Toca una barra en el panel principal\npara registrar tu primera actividad")
                .font(SimsTheme.labelFont)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
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
