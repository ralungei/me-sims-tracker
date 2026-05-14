import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(NeedStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName: String = ""

    @Query(sort: \Treatment.createdAt, order: .reverse)
    private var treatments: [Treatment]

    @State private var selectedNeed: NeedType?
    @State private var editingAspiration: Aspiration?
    @State private var showNewAspiration: Bool = false
    @State private var editingTask: LifeTask?
    @State private var showNewTask: Bool = false
    @State private var editingTreatment: Treatment?
    @State private var showNewTreatment: Bool = false
    @State private var showAlerts: Bool = false
    /// Per-session dismissed alerts. Re-show on next launch / next hour
    /// rollover (the store regenerates the alert list on those triggers).
    @State private var dismissedAlertMessages: Set<String> = []
    @State private var showCategoriesEditor: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var selectedTab: DashboardTab = {
        // Screenshot harness — `Tools/screenshots.sh` launches the app with
        // `-StartTab <raw>` to start each capture on a specific tab.
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-StartTab"),
           idx + 1 < args.count,
           let tab = DashboardTab(rawValue: args[idx + 1]) {
            return tab
        }
        return .needs
    }()

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

        }
        // System bottom sheet — covers the system tab bar, slides up from
        // the bottom edge, drag-to-dismiss, supports detents.
        .sheet(item: $selectedNeed) { need in
            QuickActionsOverlay(need: need, onDismiss: { selectedNeed = nil })
                .environment(store)
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
        .sheet(item: $editingTreatment) { t in
            TreatmentEditor(existing: t)
        }
        .sheet(isPresented: $showNewTreatment) {
            TreatmentEditor(existing: nil)
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
                // Semantic `.title` (≈ 28pt) scales with Dynamic Type. The
                // old fixed 26/32 pt looked nicer but stayed put at AX
                // sizes; this lets low-vision users see the header grow.
                .font(.system(isCompact ? .title : .largeTitle,
                              design: .rounded,
                              weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(SimsTheme.textPrimary)
            tabTitleCounter
            Spacer()
            tabTitleAddButton
        }
        .id(selectedTab)
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .simsAnimation(.spring(response: 0.4, dampingFraction: 0.78),
                       value: selectedTab)
    }

    /// Right-aligned action buttons in the title row. Each tab has its own
    /// affordances — for `.needs` it's the "A neutro" reset + the categories
    /// configurator (both need-specific actions). For content tabs, it's the
    /// "+" to create a new item once the list is non-empty (when empty, the
    /// big dashed "Nueva X" card in the row IS the CTA, so a header button
    /// would be redundant). Mirrors the iOS Reminders / Notes pattern.
    @ViewBuilder
    private var tabTitleAddButton: some View {
        switch selectedTab {
        case .needs:
            HStack(spacing: 8) {
                resetToNeutralButton
                iconButton("slider.horizontal.3", "Configurar necesidades") {
                    showCategoriesEditor = true
                }
            }
        case .aspirations:
            if !store.aspirations.isEmpty {
                iconButton("plus", "Nueva aspiración") { showNewAspiration = true }
            }
        case .agenda:
            if !store.tasks.isEmpty {
                iconButton("plus", "Nueva tarea") { showNewTask = true }
            }
        case .botiquin:
            let hasAny = treatments.contains(where: \.isActive)
            if hasAny {
                iconButton("plus", "Nuevo tratamiento") { showNewTreatment = true }
            }
        }
    }

    /// Generic Sims-style icon-only button in the title row. The "+" used to
    /// live here as a hand-rolled view; now it shares geometry with the
    /// needs-tab configurator so both buttons sit at the same 30×30 size.
    private func iconButton(_ systemName: String,
                            _ accessibility: LocalizedStringKey,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(SimsTheme.frame)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibility))
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
                                     ? SimsTheme.boostPositive
                                     : SimsTheme.frame)
                    .monospacedDigit()
                    .accessibilityLabel(Text("\(donesToday) de \(total) completadas hoy"))
            }
        case .agenda:
            let done = store.tasks.filter { $0.isDone }.count
            let total = store.tasks.count
            if total > 0 {
                Text("\(done)/\(total) hechas")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(done == total
                                     ? SimsTheme.boostPositive
                                     : SimsTheme.frame)
                    .monospacedDigit()
                    .accessibilityLabel(Text("\(done) de \(total) tareas completadas"))
            }
        case .botiquin:
            let active = treatments.filter { $0.isActive }
            let taken = active.filter { $0.isTakenToday() }.count
            let total = active.count
            if total > 0 {
                Text("\(taken)/\(total) hoy")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(taken == total
                                     ? SimsTheme.boostPositive
                                     : SimsTheme.frame)
                    .monospacedDigit()
                    .accessibilityLabel(Text("\(taken) de \(total) tomados hoy"))
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

            // Tabs leading + notifications bell trailing. The bell is a
            // global control (alerts apply across every tab) and lives in
            // this row instead of the plumbob arc cluster — easier to reach,
            // more obvious as an affordance.
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(DashboardTab.allCases) { tab in
                    sims2Tab(tab,
                             active: tab == selectedTab,
                             width: tabWidth,
                             height: tabHeight,
                             radius: tabRadius)
                }
                Spacer(minLength: 8)
                tabsBarBellButton
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, isCompact ? 16 : 32)
        }
        .frame(height: tabHeight)
        .simsAnimation(.spring(response: 0.4, dampingFraction: 0.78), value: selectedTab)
    }

    /// Notifications bell anchored at the trailing edge of the tabs row.
    /// Used to live in the plumbob arc — moved here so it stays at thumb
    /// distance and reads as part of the tab chrome instead of decoration.
    private var tabsBarBellButton: some View {
        let alertCount = visibleAlerts.count
        let icon: String = alertCount > 0 ? "bell.badge.fill" : "bell"
        return Button {
            showAlerts = true
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(SimsTheme.frame)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                )
                .overlay(alignment: .topTrailing) {
                    if alertCount > 0 {
                        Circle()
                            .fill(SimsTheme.simsRed)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.4))
                            .offset(x: -30 * 0.18, y: 30 * 0.18)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(alertCount > 0
                                 ? "Ver \(alertCount) notificaciones"
                                 : "Notificaciones"))
    }

    /// Pill that parks every enabled need at 50 %. Lives on the right edge
    /// of the tabs row so the action label is fully readable (used to be a
    /// gauge icon in the plumbob arc cluster, where it wasn't discoverable).
    private var resetToNeutralButton: some View {
        Button {
            showResetConfirm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 11, weight: .heavy))
                Text("A neutro")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(0.2)
            }
            .foregroundStyle(SimsTheme.frame)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Marcar todo a neutro"))
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
        case .botiquin:
            treatmentsSection
        }
    }

    // MARK: - Header (Mood Gem + greeting + VITAL bar)

    @ViewBuilder
    private var headerSection: some View {
        if isCompact { compactHeader } else { regularHeader }
    }

    /// Plumbob with three completion dots running along its UPPER-LEFT
    /// edge — the diamond's "face 1" diagonal (top vertex → left vertex).
    /// Dots descend in the same slope as the edge, offset slightly outside
    /// so they don't overlap the gem. Each reads as "today's box":
    /// - filled green w/ ✓ = everything done for today
    /// - hollow navy = pending items remaining
    /// - gray = nothing scheduled today for that tab
    private var plumbobWithActions: some View {
        let mood = store.overallMood
        let plumbobSize: CGFloat = isCompact ? 74 : 100
        let plumbobAspect: CGFloat = 1.15  // matches PlumbobView's frame()
        let plumbobHeight = plumbobSize * plumbobAspect
        let dotSize: CGFloat = isCompact ? 18 : 22
        // Perpendicular offset (in pt) from the diamond's upper-left edge
        // to the line the dots ride on. Negative = outside the gem.
        let outwardOffset: CGFloat = isCompact ? 8 : 10

        let specs: [(tab: DashboardTab, icon: String,
                     done: Int, total: Int,
                     accessibility: LocalizedStringKey)] = [
            (.aspirations, "flag.fill",    aspirationDoneCount, aspirationTotal, "Aspiraciones"),
            (.botiquin,    "pills.fill",   treatmentDoneCount,  treatmentTotal,  "Botiquín"),
            (.agenda,      "checklist",    taskDoneCount,       taskTotal,       "Agenda")
        ]

        // Face-1 endpoints in the plumbob's local frame (origin = top-left
        // of the plumbob's bounding box).
        let topVertex  = CGPoint(x: plumbobSize / 2, y: 0)
        let leftVertex = CGPoint(x: 0,               y: plumbobHeight / 2)
        // Outward perpendicular unit vector for face 1. Edge direction is
        // (left-top, +bottom); the outward (up-left) normal flips and
        // rotates -90°: (-Δy, -Δx)/|edge|.
        let dx = leftVertex.x - topVertex.x          // -plumbobSize/2
        let dy = leftVertex.y - topVertex.y          // +plumbobHeight/2
        let edgeLen = (dx * dx + dy * dy).squareRoot()
        let normal = CGPoint(x: -dy / edgeLen, y: -dx / edgeLen)  // points outside-up-left

        // Shifted line endpoints (the actual centre line the dots ride on).
        let lineStart = CGPoint(x: topVertex.x  + normal.x * outwardOffset,
                                y: topVertex.y  + normal.y * outwardOffset)
        let lineEnd   = CGPoint(x: leftVertex.x + normal.x * outwardOffset,
                                y: leftVertex.y + normal.y * outwardOffset)

        // 3 dots at t = 0.18, 0.5, 0.82 along the line. The end-padding
        // keeps the outermost dots from sitting at the very tips of the
        // edge where they'd visually drop off the diamond.
        let tValues: [CGFloat] = [0.18, 0.50, 0.82]
        let centres = tValues.map { t in
            CGPoint(x: lineStart.x + (lineEnd.x - lineStart.x) * t,
                    y: lineStart.y + (lineEnd.y - lineStart.y) * t)
        }
        let topLefts = centres.map { CGPoint(x: $0.x - dotSize / 2, y: $0.y - dotSize / 2) }
        let minX = topLefts.map(\.x).min() ?? 0
        let minY = topLefts.map(\.y).min() ?? 0
        // Negative minX means dots extend leftward of the plumbob; shift the
        // plumbob right by abs(minX) so the whole composition has a clean
        // (0, 0) origin in its bounding box.
        let shiftX: CGFloat = max(0, -minX)
        let shiftY: CGFloat = max(0, -minY)
        let plumbobOrigin = CGPoint(x: shiftX, y: shiftY)
        let dotOrigins = topLefts.map { CGPoint(x: $0.x + shiftX, y: $0.y + shiftY) }
        let frameW = max(plumbobOrigin.x + plumbobSize,
                         dotOrigins.map { $0.x + dotSize }.max() ?? 0)
        let frameH = max(plumbobOrigin.y + plumbobHeight,
                         dotOrigins.map { $0.y + dotSize }.max() ?? 0)

        return ZStack(alignment: .topLeading) {
            ForEach(specs.indices, id: \.self) { i in
                let spec = specs[i]
                completionDot(for: spec.tab,
                              icon: spec.icon,
                              done: spec.done,
                              total: spec.total,
                              diameter: dotSize,
                              accessibility: spec.accessibility)
                    .offset(x: dotOrigins[i].x, y: dotOrigins[i].y)
            }
            PlumbobView(mood: mood, compact: isCompact, size: plumbobSize)
                .frame(width: plumbobSize, height: plumbobSize)
                .offset(x: plumbobOrigin.x, y: plumbobOrigin.y)
        }
        .frame(width: frameW, height: frameH, alignment: .topLeading)
        .simsAnimation(.spring(response: 0.4, dampingFraction: 0.78),
                       value: aspirationDoneCount + treatmentDoneCount + taskDoneCount)
    }

    /// One completion dot. Falls back to a disabled grey state when there's
    /// nothing on the user's plate for the day — no false-positive "you've
    /// finished!" if you have zero tasks.
    private func completionDot(for tab: DashboardTab,
                               icon: String,
                               done: Int,
                               total: Int,
                               diameter: CGFloat,
                               accessibility: LocalizedStringKey) -> some View {
        let disabled = total == 0
        let complete = !disabled && done == total
        let iconSize: CGFloat = diameter * 0.42
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                Circle()
                    .fill(complete ? SimsTheme.simsGreen : Color.white.opacity(0.20))
                    .frame(width: diameter, height: diameter)
                Circle()
                    .stroke(disabled ? SimsTheme.textDim
                                     : SimsTheme.frame,
                            lineWidth: 1.2)
                    .frame(width: diameter, height: diameter)
                Image(systemName: complete ? "checkmark" : icon)
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(complete ? Color.white
                                              : (disabled ? SimsTheme.textDim
                                                          : SimsTheme.frame))
            }
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(Text(accessibility))
        .accessibilityValue(Text(disabled
                                 ? "nada hoy"
                                 : (complete ? "completado"
                                             : "\(done) de \(total)")))
        .accessibilityHint(Text(disabled ? "" : "Toca dos veces para abrir"))
    }

    // MARK: - Completion counts (match `tabTitleCounter` semantics)

    private var aspirationDoneCount: Int {
        store.aspirations.filter { $0.isDoneNow() }.count
    }
    private var aspirationTotal: Int { store.aspirations.count }

    private var taskDoneCount: Int {
        store.tasks.filter { $0.isDone }.count
    }
    private var taskTotal: Int { store.tasks.count }

    private var treatmentDoneCount: Int {
        treatments.filter { $0.isActive && $0.isTakenToday() }.count
    }
    private var treatmentTotal: Int {
        treatments.filter { $0.isActive }.count
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
        .simsAnimation(.easeInOut(duration: 0.3), value: signedAmount)
        // VITAL bar: the 12 pips and the centre tick are decoration. Fold the
        // whole row into a single element with a meaningful spoken value.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("VITAL"))
        .accessibilityValue(Text(vitalAccessibilityValue(score: v, signed: signedAmount)))
    }

    /// Builds the spoken description for VITAL — e.g. "60 puntos, ligeramente
    /// por encima del centro" — without leaking colour-only info.
    private func vitalAccessibilityValue(score: Int, signed: Double) -> String {
        if abs(signed) < 0.005 { return String(localized: "\(score) puntos, en el centro") }
        if signed > 0 {
            return String(localized: "\(score) puntos, por encima del centro")
        }
        return String(localized: "\(score) puntos, por debajo del centro")
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
            upcoming: store.upcomingTasks,
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

    // MARK: - Treatments (Botiquín)

    private var treatmentsSection: some View {
        let active = treatments.filter { $0.isActive && !$0.isScheduledForFuture() }
        let upcoming = treatments.filter { $0.isActive && $0.isScheduledForFuture() }
            .sorted { ($0.startedAt ?? Date.distantFuture) < ($1.startedAt ?? Date.distantFuture) }
        return TreatmentsRow(
            treatments: active,
            upcoming: upcoming,
            outerEscape: isCompact ? 16 : 32,
            cardInset: isCompact ? 16 : 32,
            onTap: { t in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if t.isTakenToday() {
                        t.lastTakenAt = nil
                    } else {
                        t.lastTakenAt = Date()
                    }
                    try? modelContext.save()
                }
            },
            onAdd: { showNewTreatment = true },
            onEdit: { t in editingTreatment = t },
            onDelete: { t in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    NotificationManager.shared.cancelTaskReminder(taskID: t.id)
                    modelContext.delete(t)
                    try? modelContext.save()
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
        // `.title2` ≈ 22pt at default, scales with Dynamic Type up to
        // ~37pt at AX1 (the global cap). Wrapping on the same line is
        // intentional via HStack with `.lineLimit(1)` to keep one row.
        let style: Font = .system(isCompact ? .title2 : .title,
                                  design: .rounded,
                                  weight: .bold)
        return HStack(spacing: 6) {
            Text(greeting)
                .font(style)
                .foregroundStyle(SimsTheme.textPrimary)
                .tracking(-0.5)
            if !userName.isEmpty {
                Text(userName)
                    .font(style)
                    .foregroundStyle(SimsTheme.accentPrimary)
                    .tracking(-0.5)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// Sims-style weekday strip with today's letter highlighted (filled
    /// navy circle, white letter). Letters are pulled from
    /// `veryShortStandaloneWeekdaySymbols` so they localize automatically:
    /// es → "L M X J V S D", en → "M T W T F S S".
    private var dateLine: some View {
        // Calendar gives Sunday-first symbols ["D","L","M","X","J","V","S"]
        // (es) or ["S","M","T","W","T","F","S"] (en). Shift to Monday-first
        // so it matches Spain's week start and our highlight math below.
        let sundayFirst = Calendar.current.veryShortStandaloneWeekdaySymbols
        let letters = Array(sundayFirst.dropFirst()) + [sundayFirst[0]]
        // Calendar gives weekday with Sunday = 1 ... Saturday = 7. Shift to
        // ISO (Monday = 0 ... Sunday = 6) so it matches the letter array.
        let raw = Calendar.current.component(.weekday, from: now)
        let todayIndex = (raw + 5) % 7
        let cellSize: CGFloat = isCompact ? 20 : 22
        return HStack(spacing: isCompact ? 3 : 4) {
            ForEach(letters.indices, id: \.self) { i in
                let isToday = i == todayIndex
                Text(letters[i])
                    .font(.system(size: isCompact ? 11 : 12,
                                  weight: .heavy,
                                  design: .rounded))
                    .foregroundStyle(isToday ? Color.white : SimsTheme.textSecondary)
                    .frame(width: cellSize, height: cellSize)
                    .background(
                        Circle()
                            .fill(isToday ? SimsTheme.frame : Color.clear)
                    )
            }
        }
        // VoiceOver: read the full weekday name + date instead of the seven
        // single-letter pips one by one. The colour pip is decoration.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(now.formatted(date: .complete, time: .omitted)))
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
