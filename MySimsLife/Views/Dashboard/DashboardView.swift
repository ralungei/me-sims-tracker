import SwiftUI

struct DashboardView: View {
    @Environment(NeedStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("userName") private var userName: String = ""

    @State private var selectedNeed: NeedType?
    @State private var editingAspiration: Aspiration?
    @State private var showNewAspiration: Bool = false
    @State private var editingTask: LifeTask?
    @State private var showNewTask: Bool = false
    @State private var showAlerts: Bool = false
    /// Per-session dismissed alerts. Re-show on next launch / next hour
    /// rollover (the store regenerates the alert list on those triggers).
    @State private var dismissedAlertMessages: Set<String> = []
    @State private var showCategoriesEditor: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var selectedTab: DashboardTab = .needs

    private var isCompact: Bool { sizeClass == .compact }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, isCompact ? 16 : 32)
                    .padding(.top, isCompact ? 6 : 10)
                    .padding(.bottom, isCompact ? 14 : 22)

                // ZStack so tabsBar is rendered AFTER (on top of) the bridge
                // and contentArea — that way the active tab body's negative
                // bottom padding overlaps the bridge in front, killing the
                // hairline at the seam.
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: isCompact ? 38 : 44)
                        Rectangle()
                            .fill(SimsTheme.panelPeriwinkle)
                            .frame(height: 2)
                        contentArea
                    }
                    tabsBar
                }
                // Flatten ALL the sibling views (bridge + contentArea + tabs)
                // into a single composited layer before rasterising — that's
                // the only way SwiftUI guarantees no sub-pixel seams between
                // them, regardless of where the boundary falls on the
                // hardware pixel grid.
                .compositingGroup()
            }

            if let need = selectedNeed {
                QuickActionsOverlay(
                    need: need,
                    onDismiss: { withAnimation(.spring(response: 0.3)) { selectedNeed = nil } }
                )
                .transition(.identity)
            }

        }
        // Edit existing — `.sheet(item:)` guarantees the asp is set BEFORE the
        // sheet evaluates its content (avoids the `.sheet(isPresented:)` race
        // where existing arrives nil on the first render).
        .sheet(item: $editingAspiration) { asp in
            AspirationEditor(existing: asp)
                .environment(store)
        }
        .sheet(isPresented: $showNewAspiration) {
            AspirationEditor(existing: nil)
                .environment(store)
        }
        .sheet(item: $editingTask) { task in
            TaskEditor(existing: task)
                .environment(store)
        }
        .sheet(isPresented: $showNewTask) {
            TaskEditor(existing: nil)
                .environment(store)
        }
        .sheet(isPresented: $showCategoriesEditor) {
            CategoriesEditor()
                .environment(store)
        }
        .sheet(isPresented: $showAlerts) {
            NotificationsSheet(
                alerts: visibleAlerts,
                onDismissAlert: { alert in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        _ = dismissedAlertMessages.insert(alert.message)
                    }
                },
                onClose: { showAlerts = false }
            )
        }
        .alert("¿Marcar todo como estable?",
               isPresented: $showResetConfirm) {
            Button("Cancelar", role: .cancel) {}
            // .destructive paints the action button red so it's clearly the
            // "this changes things" option vs the bold-but-neutral Cancel.
            Button("Sí, al 50%", role: .destructive) {
                store.resetAllToBaseline()
            }
        } message: {
            Text("Pone todas las barras al 50%. No borra el historial.")
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        SimsTheme.backgroundGradient.ignoresSafeArea()
    }

    // MARK: - Centered greeting

    private var centeredGreeting: some View {
        let mood = store.overallMood
        return TimeAwareGreeting(
            userName: userName,
            isCompact: isCompact,
            moodCopy: moodCopy(for: mood),
            moodColor: SimsTheme.plumbobColor(for: mood),
            horizontalAlignment: .center
        )
    }

    // MARK: - Tab title (large heading above the tab content)

    private var tabTitle: some View {
        HStack(spacing: 10) {
            Text(selectedTab.label)
                .font(.system(size: isCompact ? 26 : 32, weight: .heavy, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(SimsTheme.textPrimary)
            tabTitleCounter
            Spacer()
        }
        .id(selectedTab)
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .animation(.spring(response: 0.4, dampingFraction: 0.78),
                   value: selectedTab)
    }

    /// Per-tab counter chip (e.g. "1/4 hoy", "3/5 hechas") rendered next to the
    /// tab title. Hidden on the needs tab since the bars themselves convey
    /// progress.
    @ViewBuilder
    private var tabTitleCounter: some View {
        switch selectedTab {
        case .needs:
            EmptyView()
        case .aspirations:
            let donesToday = store.aspirations.filter { $0.isDoneNow() }.count
            let total = store.aspirations.count
            if total > 0 {
                Text("\(donesToday)/\(total) hoy")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(donesToday == total
                                     ? SimsTheme.accentGreen
                                     : SimsTheme.accentPrimary)
                    .monospacedDigit()
            }
        case .agenda:
            let done = store.tasks.filter { $0.isDone }.count
            let total = store.tasks.count
            if total > 0 {
                Text("\(done)/\(total) hechas")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(done == total
                                     ? SimsTheme.accentGreen
                                     : SimsTheme.accentPrimary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Sims 2 style tabs + merged content panel

    /// Sims-2 style: rounded-square tabs along the top, anchored to the left
    /// edge of the panel. The active tab is rendered IN FRONT of the panel
    /// (3-sided stroke + same fill, so its bottom dissolves into the panel).
    /// Inactive tabs are rendered BEHIND the panel — their lower portion is
    /// covered by the panel, so they look like folder tabs tucked behind.
    // MARK: - Tabs bar (Sims-2 style: tabs sit on an edge-to-edge navy line)

    /// Tabs row anchored on a horizontal navy line that spans screen-edge to
    /// screen-edge. Active tab body fills with periwinkle (matching content
    /// below), so the line is hidden under the active tab and visible to
    /// either side of it.
    private var tabsBar: some View {
        let tabHeight: CGFloat = isCompact ? 38 : 44
        let tabWidth:  CGFloat = isCompact ? 56 : 66
        let tabRadius: CGFloat = 10
        return ZStack(alignment: .bottom) {
            // Navy line edge-to-edge at the very bottom of the tabs row.
            Rectangle()
                .fill(SimsTheme.frame)
                .frame(height: 1.5)

            // Tabs row, leading-aligned. Bodies cover the line in their x
            // range; line is naked in the Spacer area to the right.
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(DashboardTab.allCases) { tab in
                    sims2Tab(tab,
                             active: tab == selectedTab,
                             width: tabWidth,
                             height: tabHeight,
                             radius: tabRadius)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, isCompact ? 16 : 32)
        }
        .frame(height: tabHeight)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: selectedTab)
    }

    private func sims2Tab(_ tab: DashboardTab,
                          active: Bool,
                          width: CGFloat,
                          height: CGFloat,
                          radius: CGFloat) -> some View {
        let iconSize: CGFloat = isCompact ? 16 : 18
        let topShape = UnevenRoundedRectangle(
            topLeadingRadius:     radius,
            bottomLeadingRadius:  0,
            bottomTrailingRadius: 0,
            topTrailingRadius:    radius
        )
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                // Active body extends 3pt below its layout frame so it
                // fully covers the 2pt bridge AND bleeds 1pt into the
                // content area — every potential antialiasing seam at the
                // active tab's bottom (tab/bridge AND bridge/content) is
                // subsumed under the body fill.
                topShape
                    .fill(active ? SimsTheme.panelPeriwinkle
                                 : SimsTheme.panelPeriwinkle.opacity(0.55))
                    .padding(.bottom, active ? -3 : 0)

                if active {
                    TabTopBorderShape(radius: radius)
                        .stroke(SimsTheme.frame, lineWidth: 1.5)
                } else {
                    // strokeBorder: stroke INSET (entirely inside the shape)
                    // so the tab's bottom edge aligns flush with the navy
                    // line below, instead of overshooting it by 0.75pt.
                    topShape.strokeBorder(SimsTheme.frame, lineWidth: 1.5)
                }

                Image(systemName: tab.icon)
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(active
                                     ? SimsTheme.textPrimary
                                     : SimsTheme.textPrimary.opacity(0.45))
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tab.label))
    }

    // MARK: - Content area (periwinkle bg + sticky title + uncliped scroll)

    /// Uses `safeAreaInset(.top)` to pin the title above the ScrollView with
    /// an opaque periwinkle background. The ScrollView itself runs without
    /// clipping (`scrollClipDisabled`) so card shadows / scale animations
    /// can render past the viewport edges; the sticky title's opaque bg
    /// covers any content scrolled behind it.
    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title block — fixed at top of contentArea, not a safeAreaInset
            // so there's no gap-introducing inset boundary.
            tabTitle
                .padding(.horizontal, isCompact ? 16 : 32)
                .padding(.top, isCompact ? 14 : 18)
                .padding(.bottom, isCompact ? 10 : 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle()
                .fill(SimsTheme.frame)
                .frame(height: 1.5)

            // Scrollable content. ScrollView's default clipping keeps
            // scrolled content inside its frame — can't render above into
            // the title block.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                    tabContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, isCompact ? 16 : 32)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            SimsTheme.panelPeriwinkle
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }

    // MARK: - Plumbob-side actions (arc cluster around the rombo's bottom-left)

    /// One slot in the action arc — declarative spec for `plumbobWithActions`
    /// to render via `sideActionButton`.
    private struct ArcAction {
        let systemName: String
        let accessibility: LocalizedStringKey
        let badge: Bool
        let action: () -> Void
    }

    /// Global controls — always visible regardless of tab.
    private var arcActions: [ArcAction] {
        let alertCount = visibleAlerts.count
        return [
            // chip 0: closest to plumbob (bottom of arc)
            ArcAction(systemName: "gauge.with.dots.needle.50percent",
                      accessibility: "Marcar todo al 50%",
                      badge: false,
                      action: { showResetConfirm = true }),
            ArcAction(systemName: "slider.horizontal.3",
                      accessibility: "Configurar necesidades",
                      badge: false,
                      action: { showCategoriesEditor = true }),
            ArcAction(systemName: alertCount > 0 ? "bell.badge.fill" : "bell",
                      accessibility: alertCount > 0
                          ? "Ver \(alertCount) notificaciones"
                          : "Notificaciones",
                      badge: alertCount > 0,
                      action: { showAlerts = true })
        ]
    }

    /// One Sims-style icon button: circle, navy frame, semitransparent
    /// white fill. `badge: true` adds a red dot in the top-trailing corner.
    private func sideActionButton(_ slot: ArcAction, size: CGFloat) -> some View {
        Button(action: slot.action) {
            Image(systemName: slot.systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(SimsTheme.textSecondary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                )
                .overlay(alignment: .topTrailing) {
                    if slot.badge {
                        Circle()
                            .fill(SimsTheme.simsRed)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.2))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(slot.accessibility))
    }

    /// Active alerts excluding ones the user dismissed this session.
    private var visibleAlerts: [NeedStore.SimAlert] {
        store.activeAlerts.filter { !dismissedAlertMessages.contains($0.message) }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .needs:
            // Alerts moved to a floating overlay at the top of the screen
            // (see body's ZStack), dismissible per-session.
            needsPanel
        case .aspirations:
            aspirationsSection
        case .agenda:
            tasksSection
        }
    }

    // MARK: - Header (Mood Gem + greeting + VITAL bar)

    @ViewBuilder
    private var headerSection: some View {
        if isCompact { compactHeader } else { regularHeader }
    }

    /// Plumbob with global action buttons fanning out in an arc from its
    /// bottom-LEFT corner — same Sims-2 cluster geometry as the old tab arc,
    /// just with action icons (Estable, categorías, notificaciones).
    private var plumbobWithActions: some View {
        let mood = store.overallMood
        let plumbobSize: CGFloat = isCompact ? 56 : 78
        let chipSize: CGFloat = isCompact ? 33 : 39
        let radius: CGFloat = isCompact ? 50 : 56
        let stepDeg: Double = 48
        let startDeg: Double = 95
        let dropY: CGFloat = 8
        let shiftX: CGFloat = 6
        let slots = arcActions

        // Centres of each chip on the arc, relative to (0,0).
        let centres = slots.indices.map { i -> CGPoint in
            let θ = (startDeg + stepDeg * Double(i)) * .pi / 180
            return CGPoint(x: CGFloat(cos(θ)) * radius,
                           y: CGFloat(sin(θ)) * radius)
        }
        // Top-lefts then normalize so the bounding box starts at (0, 0).
        let topLefts = centres.map { CGPoint(x: $0.x - chipSize / 2, y: $0.y - chipSize / 2) }
        let minX = topLefts.map(\.x).min() ?? 0
        let minY = topLefts.map(\.y).min() ?? 0
        let normalized = topLefts.map { CGPoint(x: $0.x - minX, y: $0.y - minY) }
        // chip 1 (middle) anchors to the plumbob's bottom-LEFT corner.
        let chip1 = CGPoint(x: normalized[1].x + chipSize / 2,
                            y: normalized[1].y + chipSize / 2)
        let chipsMaxX = normalized.map(\.x).max()! + chipSize
        let chipsMaxY = normalized.map(\.y).max()! + chipSize

        return ZStack(alignment: .topLeading) {
            // Action chips
            ForEach(slots.indices, id: \.self) { i in
                sideActionButton(slots[i], size: chipSize)
                    .offset(x: normalized[i].x,
                            y: normalized[i].y + plumbobSize - chip1.y + dropY)
            }
            // Plumbob — chip1 centre lines up with its bottom-LEFT corner.
            PlumbobView(mood: mood, compact: isCompact, size: plumbobSize)
                .frame(width: plumbobSize, height: plumbobSize)
                .offset(x: chip1.x + shiftX, y: 0)
        }
        .frame(width: max(chipsMaxX, chip1.x + shiftX + plumbobSize),
               height: plumbobSize + chipsMaxY - chip1.y + dropY,
               alignment: .topLeading)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: visibleAlerts.count)
    }

    /// iPad/Mac layout: VITAL pip bar on the left, greeting absolutely
    /// centred on top, rombo+actions on the right.
    private var regularHeader: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 8) {
                vitalNumber
                Spacer()
                plumbobWithActions
            }
            centeredGreeting
        }
    }

    /// iPhone layout: date · hour on top, greeting below, VITAL pip bar
    /// underneath; rombo+actions on the right.
    private var compactHeader: some View {
        let mood = store.overallMood
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                TimeAwareGreeting(
                    userName: userName,
                    isCompact: true,
                    moodCopy: moodCopy(for: mood),
                    moodColor: SimsTheme.plumbobColor(for: mood),
                    horizontalAlignment: .leading
                )
                vitalNumber
            }
            Spacer()
            plumbobWithActions
        }
    }

    private func moodCopy(for mood: Double) -> String {
        switch mood {
        case 0.75...:     return String(localized: "te ves genial")
        case 0.55..<0.75: return String(localized: "estás bien")
        case 0.35..<0.55: return String(localized: "vas tirando")
        case 0.20..<0.35: return String(localized: "ojo, andas bajo")
        default:          return String(localized: "necesitas cuidarte")
        }
    }

    // MARK: - VITAL — segmented pips that fill outward from center (red ← · → green)

    private var vitalNumber: some View {
        let v = store.vitalScore
        let segments = 12
        let half = segments / 2
        let signedAmount = (Double(v) - 50) / 50.0          // -1 … 0 … +1
        let isPositive = signedAmount > 0
        let fillCount = Int((Double(half) * abs(signedAmount)).rounded())
        let posColor = SimsTheme.valueColor(for: 0.85)
        let negColor = SimsTheme.valueColor(for: 0.10)
        let track = Color.white.opacity(0.10)
        // Fixed pip dimensions — bar width stays constant regardless of the
        // available space so it doesn't stretch on wider devices.
        let pipWidth:  CGFloat = isCompact ? 12 : 14
        let pipHeight: CGFloat = isCompact ? 12 : 10

        func isFilled(_ index: Int) -> Bool {
            if abs(signedAmount) < 0.005 { return false }
            return isPositive
                ? index >= half && index < half + fillCount
                : index >= (half - fillCount) && index < half
        }

        func fillStyle(_ index: Int) -> AnyShapeStyle {
            guard isFilled(index) else { return AnyShapeStyle(track) }
            let color = isPositive ? posColor : negColor
            return AnyShapeStyle(LinearGradient(
                colors: [color.opacity(0.85), color],
                startPoint: .top, endPoint: .bottom
            ))
        }

        return HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                let isFirst = i == 0
                let isLast  = i == segments - 1
                let shape = UnevenRoundedRectangle(
                    topLeadingRadius:     isFirst ? 6 : 1,
                    bottomLeadingRadius:  isFirst ? 6 : 1,
                    bottomTrailingRadius: isLast  ? 6 : 1,
                    topTrailingRadius:    isLast  ? 6 : 1
                )
                shape
                    .fill(fillStyle(i))
                    .frame(width: pipWidth, height: pipHeight)
                    .overlay(alignment: .trailing) {
                        // Center divider: white tick between pip 5 and 6.
                        if i == half - 1 {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2, height: pipHeight + 4)
                                .offset(x: 1)
                        }
                    }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SimsTheme.frame)
        )
        .fixedSize()
        .animation(.easeInOut(duration: 0.3), value: signedAmount)
    }

    // MARK: - Needs Panel (2-col grid on regular, single column on compact)

    private var needsPanel: some View {
        // Single periwinkle panel — the bg lives directly on the grid (see
        // `needsGrid`'s `.background(...)` at the bottom). No outer wrapper.
        needsGrid
    }

    private var needsGrid: some View {
        let columns: [GridItem] = isCompact
            ? [GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)]
        let loading = !store.hasInitialSyncCompleted
        return LazyVGrid(columns: columns, alignment: .leading, spacing: SimsTheme.barSpacing(compact: isCompact)) {
            ForEach(store.sortedEnabledNeeds) { need in
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
        // Skeleton state until the first remote pull lands. The bars are
        // already mounted (so layout doesn't jump) but dimmed and untouchable.
        .opacity(loading ? 0.35 : 1.0)
        .saturation(loading ? 0 : 1)
        .allowsHitTesting(!loading)
        .overlay(alignment: .center) {
            if loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(SimsTheme.accentPrimary)
            }
        }
    }

    // MARK: - Aspirations

    private var aspirationsSection: some View {
        // Parent is the contentArea's scroll content with horizontal body
        // padding (16 / 32). outerEscape = that padding so the row's scroll
        // viewport bleeds to the screen edge. cardInset = visible margin
        // between card and screen edge.
        AspirationsRow(
            aspirations: store.activeAspirations,
            upcoming: store.upcomingAspirations,
            outerEscape: isCompact ? 16 : 32,
            cardInset: isCompact ? 16 : 32,
            onTap: { asp in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.toggleAspiration(asp)
                }
            },
            onAdd: {
                showNewAspiration = true
            },
            onEdit: { asp in
                editingAspiration = asp
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
                showNewTask = true
            },
            onEdit: { task in
                editingTask = task
            },
            onDelete: { task in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.deleteTask(task)
                }
            },
            onMove: { dragged, target in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    store.moveTask(withID: dragged, toBefore: target)
                }
            }
        )
    }

    // MARK: - Smart Suggestions

    private var suggestionsBar: some View {
        let inset: CGFloat = isCompact ? 16 : 32
        // Compute once — both the empty-check and the ForEach used to access this twice.
        let suggestions = store.smartSuggestions
        return Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("⚡ RÁPIDO")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(SimsTheme.textDim)
                        .tracking(1.4)
                        .padding(.horizontal, inset)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestions) { action in
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
    var horizontalAlignment: HorizontalAlignment = .leading

    @State private var now = Date()
    private let clockTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 4) {
            if isCompact {
                dateLine
                greetingLine
            } else {
                greetingLine
                HStack(spacing: 8) {
                    dateLine
                    Circle().fill(SimsTheme.textDim).frame(width: 3, height: 3)
                    Text(moodCopy)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(moodColor)
                }
            }
        }
        .onReceive(clockTimer) { _ in now = Date() }
    }

    private var greetingLine: some View {
        HStack(spacing: 6) {
            Text(greeting)
                .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                .foregroundStyle(SimsTheme.textPrimary)
                .tracking(-0.5)
            if !userName.isEmpty {
                Text(userName)
                    .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SimsTheme.accentPrimary)
                    .tracking(-0.5)
            }
        }
    }

    private var dateLine: some View {
        HStack(spacing: 8) {
            Text(now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.system(size: isCompact ? 14 : 15, weight: .medium, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .textCase(.lowercase)
            Circle().fill(SimsTheme.textDim).frame(width: 3, height: 3)
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: isCompact ? 14 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .monospacedDigit()
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: now) {
        case 6..<13:  return String(localized: "Buenos días,")
        case 13..<20: return String(localized: "Buenas tardes,")
        default:      return String(localized: "Buenas noches,")
        }
    }
}

// MARK: - Suggestion Chip (per-need hue)

struct SuggestionChip: View {
    let action: QuickAction
    let onTap: () -> Void

    private var hueDeg: Double { action.needType.hue }
    private var iconColor:   Color { SimsTheme.hueIconColor(hueDeg) }
    private var bgTop:       Color { SimsTheme.hueGradientTop(hueDeg) }
    private var bgBottom:    Color { SimsTheme.hueGradientBottom(hueDeg) }
    private var strokeColor: Color { SimsTheme.hueStroke(hueDeg) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.localizedName)
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
                    .fill(LinearGradient(colors: [bgTop, bgBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().stroke(strokeColor, lineWidth: 1))
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

// MARK: - Sims-2 tab top border (3-sided: top + sides, no bottom)

/// Open shape that traces only the top and side edges of a tab. Used as a
/// stroke under the active tab so its bottom edge dissolves into the panel.
private struct TabTopBorderShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))                       // bottom-left (open)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))           // up the left side
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                 radius: radius,
                 startAngle: .degrees(180),
                 endAngle: .degrees(270),
                 clockwise: false)                                            // top-left curve
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))           // top edge
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                 radius: radius,
                 startAngle: .degrees(270),
                 endAngle: .degrees(0),
                 clockwise: false)                                            // top-right curve
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))                    // down the right side (open)
        return p
    }
}

#Preview {
    DashboardView()
        .environment(NeedStore())
}
