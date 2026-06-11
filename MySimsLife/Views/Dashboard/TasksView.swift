import SwiftUI

// MARK: - Tasks Row (today's agenda — horizontally scrollable)

struct TasksRow: View {
    let tasks: [LifeTask]
    /// Tasks scheduled for a future calendar day. Shown as small capsules
    /// in a "PRÓXIMAMENTE" row so future tasks don't clutter today's view —
    /// tapping a capsule opens the editor (re-date, mark today, etc.).
    var upcoming: [LifeTask] = []
    var horizontalInset: CGFloat = 32
    var onToggle: (LifeTask) -> Void
    var onAdd: () -> Void = {}
    var onEdit: (LifeTask) -> Void = { _ in }
    var onDelete: (LifeTask) -> Void = { _ in }
    var onMove: (UUID, UUID) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Empty-state CTA card. The header's "+" takes over once
                    // the user has at least one task (active or upcoming).
                    if tasks.isEmpty && upcoming.isEmpty {
                        AddTaskCard(onTap: onAdd)
                    }
                    ForEach(tasks) { task in
                        TaskCard(task: task) { onToggle(task) }
                            .simsCardMenu(onEdit: { onEdit(task) },
                                          onDelete: { onDelete(task) })
                            .draggable(task.id.uuidString) {
                                TaskCard(task: task) {}
                                    .opacity(0.85)
                            }
                            .dropDestination(for: String.self) { droppedIds, _ in
                                guard let droppedRaw = droppedIds.first,
                                      let dragged = UUID(uuidString: droppedRaw),
                                      dragged != task.id else { return false }
                                onMove(dragged, task.id)
                                return true
                            }
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -horizontalInset)

            if !upcoming.isEmpty {
                upcomingRow
            }
        }
    }

    private var upcomingRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PRÓXIMAMENTE")
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(SimsTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(upcoming) { task in
                        Button {
                            onEdit(task)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(SimsTheme.frame)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(task.title)
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(SimsTheme.textPrimary)
                                        .lineLimit(1)
                                    if let due = task.dueDate {
                                        Text(due.relativeFutureLabel())
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundStyle(SimsTheme.textDim)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.45))
                                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -horizontalInset)
        }
        .padding(.top, 4)
    }
}

// MARK: - Add card

struct AddTaskCard: View {
    let onTap: () -> Void

    var body: some View {
        SimsCreateCard(label: "Nueva\ntarea",
                       width: 144, height: 148,
                       onTap: onTap)
    }
}

// MARK: - Task Card

struct TaskCard: View {
    let task: LifeTask
    let onToggle: () -> Void

    /// Same dimensions and visual language as AspirationCard so the two
    /// rows feel like a unified system.
    private var cardBG: AnyShapeStyle {
        if task.isDone {
            return AnyShapeStyle(LinearGradient(
                colors: [SimsTheme.simsGreenYellow,
                         SimsTheme.simsGreen],
                startPoint: .top, endPoint: .bottom
            ))
        }
        return AnyShapeStyle(Color.white.opacity(0.45))
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    // Checkbox circle (matches the position/size of the
                    // emoji slot in AspirationCard).
                    ZStack {
                        Circle()
                            .strokeBorder(SimsTheme.frame, lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        if task.isDone {
                            Circle()
                                .fill(SimsTheme.frame.opacity(0.18))
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(SimsTheme.frame)
                        }
                    }
                    Spacer(minLength: 0)
                    // Only render the time chip when the user picked an actual
                    // time — date-only tasks store startOfDay and would show
                    // a meaningless "0:00".
                    if let due = task.dueDate, task.hasSpecificTime {
                        Text(due, format: .dateTime.hour().minute())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(task.isOverdue && !task.isDone
                                             ? SimsTheme.boostNegative
                                             : SimsTheme.textPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.55))
                                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.4), lineWidth: 0.8))
                            )
                            .monospacedDigit()
                    }
                }

                Text(task.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(task.isDone ? SimsTheme.textSecondary : SimsTheme.textPrimary)
                    .strikethrough(task.isDone, color: SimsTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if task.isOverdue && !task.isDone {
                    Text("atrasada")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(SimsTheme.boostNegative)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 144, height: 148, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(cardBG)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(SimsTheme.frame, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(task.title))
        .accessibilityValue(Text(taskAccessibilityValue))
        .accessibilityHint(Text(task.isDone
                                ? "Toca dos veces para marcar como pendiente"
                                : "Toca dos veces para completar"))
        .accessibilityAddTraits(task.isDone ? [.isButton, .isSelected] : .isButton)
    }

    private var taskAccessibilityValue: String {
        var parts: [String] = []
        if task.isDone {
            parts.append(String(localized: "completada"))
        } else if task.isOverdue {
            parts.append(String(localized: "atrasada"))
        } else {
            parts.append(String(localized: "pendiente"))
        }
        if let due = task.dueDate {
            parts.append(due.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    ZStack {
        SimsTheme.background.ignoresSafeArea()
        TasksRow(tasks: []) { _ in }
            .padding()
    }
}
