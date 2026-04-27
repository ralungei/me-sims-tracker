import SwiftUI

struct DashboardView: View {
    @Environment(NeedStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("userName") private var userName: String = ""

    @State private var selectedNeed: NeedType?
    @State private var editingAspiration: Aspiration?
    @State private var showAspirationEditor: Bool = false
    @State private var editingTask: LifeTask?
    @State private var showTaskEditor: Bool = false

    private var isCompact: Bool { sizeClass == .compact }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 14 : 22) {
                        headerSection
                        needsPanel
                        aspirationsSection
                        tasksSection
                        AlertsStack(alerts: store.activeAlerts)
                    }
                    .padding(.horizontal, isCompact ? 16 : 32)
                    .padding(.top, isCompact ? 6 : 10)
                    .padding(.bottom, 10)
                }

                suggestionsBar
                    .padding(.bottom, 8)
                    .padding(.top, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.clear, SimsTheme.background.opacity(0.55)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea(.container, edges: .bottom)
                    )
            }

            if let need = selectedNeed {
                QuickActionsOverlay(
                    need: need,
                    onDismiss: { withAnimation(.spring(response: 0.3)) { selectedNeed = nil } }
                )
                .transition(.identity)
            }
        }
        .sheet(isPresented: $showAspirationEditor, onDismiss: { editingAspiration = nil }) {
            AspirationEditor(existing: editingAspiration)
                .environment(store)
        }
        .sheet(isPresented: $showTaskEditor, onDismiss: { editingTask = nil }) {
            TaskEditor(existing: editingTask)
                .environment(store)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        SimsTheme.mainBackground.ignoresSafeArea()
    }

    // MARK: - Header (Mood Gem + greeting + VITAL bar)

    private var headerSection: some View {
        HStack(alignment: .center, spacing: isCompact ? 8 : 12) {
            PlumbobView(
                mood: store.overallMood,
                compact: isCompact,
                size: isCompact ? 56 : 78
            )

            greetingBlock

            Spacer(minLength: 4)

            vitalNumber
        }
    }

    // MARK: - Greeting block (saludo · hora · fecha · estado)

    private var greetingBlock: some View {
        TimeAwareGreeting(
            userName: userName,
            isCompact: isCompact,
            moodCopy: moodCopy,
            moodColor: SimsTheme.plumbobColor(for: store.overallMood)
        )
    }

    private var moodCopy: String {
        switch store.overallMood {
        case 0.75...:     return "te ves genial"
        case 0.55..<0.75: return "estás bien"
        case 0.35..<0.55: return "vas tirando"
        case 0.20..<0.35: return "ojo, andas bajo"
        default:          return "necesitas cuidarte"
        }
    }

    // MARK: - VITAL — segmented pips that fill outward from center (red ← · → green)

    private var vitalNumber: some View {
        let v = store.vitalScore
        let labelColor = SimsTheme.vitalColor(for: v)
        let segments = 12
        let half = segments / 2
        let signedAmount = (Double(v) - 50) / 50.0          // -1 … 0 … +1
        let isPositive = signedAmount > 0
        let fillCount = Int((Double(half) * abs(signedAmount)).rounded())
        let fillColor = isPositive
            ? SimsTheme.valueColor(for: 0.85)
            : SimsTheme.valueColor(for: 0.10)
        let track = Color.white.opacity(0.06)
        let pipWidth: CGFloat = isCompact ? 7 : 9

        func isFilled(_ index: Int) -> Bool {
            if abs(signedAmount) < 0.005 { return false }
            return isPositive
                ? index >= half && index < half + fillCount
                : index >= (half - fillCount) && index < half
        }

        return VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isFilled(i) ? fillColor : track)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    colors: isFilled(i)
                                        ? [Color.white.opacity(0.30), .clear]
                                        : [.clear, .clear],
                                    startPoint: .top, endPoint: .center
                                ))
                        )
                        .frame(width: pipWidth, height: 10)
                        .overlay(alignment: .leading) {
                            // Center divider between pips 5 and 6
                            if i == half {
                                Rectangle()
                                    .fill(Color.white.opacity(0.45))
                                    .frame(width: 1.5, height: 14)
                                    .offset(x: -3)
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.75)
                                    .delay(Double(abs(i - half)) * 0.02), value: signedAmount)
                }
            }

            HStack(spacing: 4) {
                Text("VITAL")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(SimsTheme.textDim)
                Text("·")
                    .foregroundStyle(SimsTheme.textDim)
                Text("\(v)")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(labelColor)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(v)))
                Text("·")
                    .foregroundStyle(SimsTheme.textDim)
                Text(SimsTheme.vitalLabel(for: v))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(labelColor.opacity(0.9))
            }
        }
    }

    // MARK: - Needs Panel (2-col grid on regular, single column on compact)

    private var needsPanel: some View {
        let columns: [GridItem] = isCompact
            ? [GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: SimsTheme.barSpacing(compact: isCompact)) {
            ForEach(NeedType.sorted) { need in
                NeedBarView(
                    need: need,
                    value: store.needs[need] ?? 0,
                    recentActions: store.recentActions(for: need),
                    compact: isCompact,
                    onTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedNeed = need
                        }
                    },
                    onRemoveAction: { index in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.removeRecentAction(for: need, at: index)
                        }
                    }
                )
            }
        }
        .padding(.horizontal, SimsTheme.panelPadding)
        .padding(.vertical, isCompact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: SimsTheme.cornerRadius)
                .fill(SimsTheme.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: SimsTheme.cornerRadius)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 6)
        )
    }

    // MARK: - Aspirations

    private var aspirationsSection: some View {
        AspirationsRow(
            aspirations: store.aspirations,
            horizontalInset: isCompact ? 16 : 32,
            onTap: { asp in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.toggleAspiration(asp)
                }
            },
            onAdd: {
                editingAspiration = nil
                showAspirationEditor = true
            },
            onEdit: { asp in
                editingAspiration = asp
                showAspirationEditor = true
            },
            onDelete: { asp in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.deleteAspiration(asp)
                }
            }
        )
    }

    private var tasksSection: some View {
        TasksRow(
            tasks: store.visibleTasks,
            horizontalInset: isCompact ? 16 : 32,
            onToggle: { task in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.toggleTask(task)
                }
            },
            onAdd: {
                editingTask = nil
                showTaskEditor = true
            },
            onEdit: { task in
                editingTask = task
                showTaskEditor = true
            },
            onDelete: { task in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.deleteTask(task)
                }
            }
        )
    }

    // MARK: - Smart Suggestions

    private var suggestionsBar: some View {
        let inset: CGFloat = isCompact ? 16 : 32
        return Group {
            if !store.smartSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Text("⚡ RÁPIDO")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(SimsTheme.textDim)
                            .tracking(1.4)
                        Spacer()
                        if !store.criticalNeeds.isEmpty {
                            HStack(spacing: 4) {
                                Circle().fill(SimsTheme.negativeTint).frame(width: 5, height: 5)
                                Text("\(store.criticalNeeds.count) en rojo")
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(SimsTheme.negativeTint.opacity(0.85))
                            }
                        }
                    }
                    .padding(.horizontal, inset)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.smartSuggestions) { action in
                                SuggestionChip(action: action) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        store.logAction(action, for: action.needType)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, inset)
                    }
                }
            }
        }
    }
}

// MARK: - Time-aware greeting (isolated so the 30s tick doesn't invalidate the whole dashboard)

private struct TimeAwareGreeting: View {
    let userName: String
    let isCompact: Bool
    let moodCopy: String
    let moodColor: Color

    @State private var now = Date()
    private let clockTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(greeting)
                    .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tracking(-0.5)
                if !userName.isEmpty {
                    Text(userName)
                        .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(SimsTheme.accentWarm)
                        .tracking(-0.5)
                }
            }

            HStack(spacing: 8) {
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .monospacedDigit()
                Circle().fill(SimsTheme.textDim).frame(width: 3, height: 3)
                Text(now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.system(size: isCompact ? 13 : 14, weight: .medium, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .textCase(.lowercase)
                Circle().fill(SimsTheme.textDim).frame(width: 3, height: 3)
                Text(moodCopy)
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(moodColor)
            }
        }
        .onReceive(clockTimer) { _ in now = Date() }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: now) {
        case 6..<13:  return "Buenos días,"
        case 13..<20: return "Buenas tardes,"
        default:      return "Buenas noches,"
        }
    }
}

// MARK: - Suggestion Chip (per-need hue)

struct SuggestionChip: View {
    let action: QuickAction
    let onTap: () -> Void

    private var hue: Double { action.needType.hue }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hue: hue/360, saturation: 0.5, brightness: 0.95))
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.name)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(SimsTheme.textPrimary)
                    Text("\(action.needType.displayName) · +\(Int(action.boost))%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(SimsTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(LinearGradient(
                        colors: [
                            Color(hue: hue/360, saturation: 0.65, brightness: 0.30),
                            Color(hue: hue/360, saturation: 0.55, brightness: 0.20)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        Capsule()
                            .stroke(Color(hue: hue/360, saturation: 0.65, brightness: 0.55).opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Bounce Style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    DashboardView()
        .environment(NeedStore())
}
