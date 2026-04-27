import SwiftUI

// MARK: - Tasks Row (today's agenda — horizontally scrollable)

struct TasksRow: View {
    let tasks: [LifeTask]
    var horizontalInset: CGFloat = 32
    var onToggle: (LifeTask) -> Void
    var onAdd: () -> Void = {}
    var onEdit: (LifeTask) -> Void = { _ in }
    var onDelete: (LifeTask) -> Void = { _ in }
    var onMove: (UUID, UUID) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(SimsTheme.accentWarm)
                Text("AGENDA")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(SimsTheme.textDim)
                Spacer()
                if !tasks.isEmpty {
                    let done = tasks.filter { $0.isDone }.count
                    Text("\(done)/\(tasks.count) hechas")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(done == tasks.count ? SimsTheme.accentGreen : SimsTheme.accentWarm)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    AddTaskCard(onTap: onAdd)
                    ForEach(tasks) { task in
                        TaskCard(task: task) { onToggle(task) }
                            .contextMenu {
                                Button { onEdit(task) } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                Button(role: .destructive) { onDelete(task) } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            } preview: {
                                TaskCard(task: task) {}
                                    .allowsHitTesting(false)
                            }
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
        }
    }
}

// MARK: - Add card

struct AddTaskCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(SimsTheme.textDim, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SimsTheme.textSecondary)
                }
                Text("Nueva")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textSecondary)
                Text("tarea")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(SimsTheme.textDim)
            }
            .padding(10)
            .frame(width: 96, height: 86)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(SimsTheme.textDim.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Card

struct TaskCard: View {
    let task: LifeTask
    let onToggle: () -> Void

    private var statusColor: Color {
        if task.isDone { return SimsTheme.valueColor(for: 1.0) }     // sage green
        if task.isOverdue { return SimsTheme.negativeTint }
        return SimsTheme.accentWarm
    }

    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: task.isDone
                ? [statusColor.opacity(0.30), statusColor.opacity(0.18)]
                : [Color.white.opacity(0.07), Color.white.opacity(0.03)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .strokeBorder(statusColor.opacity(0.6), lineWidth: 1.4)
                            .frame(width: 18, height: 18)
                        if task.isDone {
                            Circle().fill(statusColor.opacity(0.85)).frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                    if let due = task.dueDate {
                        Text(due, format: .dateTime.hour().minute())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(statusColor)
                            .monospacedDigit()
                    }
                }

                Text(task.title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(task.isDone ? SimsTheme.textSecondary : SimsTheme.textPrimary)
                    .strikethrough(task.isDone, color: SimsTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if task.isOverdue && !task.isDone {
                    Text("atrasada")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(SimsTheme.negativeTint)
                }
            }
            .padding(10)
            .frame(width: 132, height: 86, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(bgGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(task.isDone ? statusColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        SimsTheme.mainBackground.ignoresSafeArea()
        TasksRow(tasks: []) { _ in }
            .padding()
    }
}
