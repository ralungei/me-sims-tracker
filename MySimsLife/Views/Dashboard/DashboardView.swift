import SwiftUI

struct DashboardView: View {
    @Environment(NeedStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedNeed: NeedType?
    @State private var editingAspiration: Aspiration?
    @State private var showAspirationEditor: Bool = false
    @State private var now = Date()

    private var isCompact: Bool { sizeClass == .compact }
    private var alwaysOn: Bool { store.isAlwaysOnMode }

    private let clockTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 14 : 20) {
                        headerSection
                        needsPanel
                        aspirationsSection
                        AlertsStack(alerts: store.activeAlerts)
                    }
                    .padding(.horizontal, isCompact ? 16 : 32)
                    .padding(.top, isCompact ? 8 : 14)
                    .padding(.bottom, 12)
                }

                if !alwaysOn {
                    suggestionsBar
                        .padding(.horizontal, isCompact ? 16 : 32)
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
            }

            if let need = selectedNeed {
                QuickActionsOverlay(
                    need: need,
                    onDismiss: { withAnimation(.spring(response: 0.3)) { selectedNeed = nil } }
                )
                .transition(.identity)
            }
        }
        .onReceive(clockTimer) { _ in now = Date() }
        .sheet(isPresented: $showAspirationEditor, onDismiss: { editingAspiration = nil }) {
            AspirationEditor(existing: editingAspiration)
                .environment(store)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        SimsTheme.mainBackground.ignoresSafeArea()
    }

    // MARK: - Header (Mood Gem + VITAL + Always-On)

    private var headerSection: some View {
        HStack(alignment: .center, spacing: isCompact ? 14 : 22) {
            PlumbobView(
                mood: store.overallMood,
                compact: isCompact,
                size: isCompact ? 76 : (alwaysOn ? 130 : 110)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: isCompact ? 36 : (alwaysOn ? 60 : 48), weight: .heavy, design: .rounded))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .monospacedDigit()
                    .tracking(-1)

                HStack(spacing: 8) {
                    Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(SimsTheme.textSecondary)
                        .textCase(.lowercase)
                    Text("·")
                        .foregroundStyle(SimsTheme.textDim)
                    Text(moodCopy)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.plumbobColor(for: store.overallMood))
                }
            }

            Spacer(minLength: 6)

            vitalCard

            if !alwaysOn {
                alwaysOnButton
            }
        }
    }

    private var moodCopy: String {
        switch store.overallMood {
        case 0.75...:    return "te ves genial"
        case 0.55..<0.75: return "estás bien"
        case 0.35..<0.55: return "vas tirando"
        case 0.20..<0.35: return "ojo, andas bajo"
        default:          return "necesitás cuidarte"
        }
    }

    private var vitalCard: some View {
        let v = store.vitalScore
        let color = SimsTheme.vitalColor(for: v)
        return VStack(alignment: .center, spacing: 0) {
            Text("VITAL")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(SimsTheme.textDim)
            Text("\(v)")
                .font(.system(size: isCompact ? 30 : 40, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(v)))
            Text(SimsTheme.vitalLabel(for: v))
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(color.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.25), radius: 12, y: 3)
        )
    }

    private var alwaysOnButton: some View {
        Button { store.toggleAlwaysOn() } label: {
            VStack(spacing: 2) {
                Image(systemName: store.isAlwaysOnMode ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: isCompact ? 14 : 16))
                Text(store.isAlwaysOnMode ? "ON" : "Always")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
            }
            .foregroundStyle(store.isAlwaysOnMode ? SimsTheme.accentWarm : SimsTheme.textDim)
            .frame(width: isCompact ? 50 : 60)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(store.isAlwaysOnMode ? SimsTheme.accentWarm.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
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
                    alwaysOn: alwaysOn,
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
        .padding(.vertical, isCompact ? 14 : 22)
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
            alwaysOn: alwaysOn,
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
            }
        )
    }

    // MARK: - Smart Suggestions

    private var suggestionsBar: some View {
        Group {
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
                    }
                }
            }
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
