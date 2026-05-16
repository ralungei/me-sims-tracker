import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 6-step onboarding designed around goal-setting, IKEA effect, and the
/// peak-end rule. Plumbob stays on camera the whole time so the user
/// builds visual attachment before the dashboard appears.
struct OnboardingView: View {
    @Environment(NeedStore.self) private var store
    @AppStorage("userName") private var savedName: String = ""

    @State private var step: Step = {
        // -OnboardingStep=N (0–5) jumps straight to a step for screenshots.
        let args = ProcessInfo.processInfo.arguments
        for arg in args where arg.hasPrefix("-OnboardingStep=") {
            let raw = arg.replacingOccurrences(of: "-OnboardingStep=", with: "")
            if let n = Int(raw), let s = Step(rawValue: n) { return s }
        }
        return .hook
    }()
    @State private var plan: PlanChoice = .light
    @State private var name: String = {
        ProcessInfo.processInfo.arguments.contains("-OnboardingStep=6") ? "Alex" : ""
    }()
    /// Drives the live demo on the model step — plumbob and bar both
    /// reflect this value, bouncing from full → empty → full to show the
    /// "decays automatically, you refill it" loop.
    @State private var demoValue: Double = 0.85
    @State private var sleepChoice: SleepHours? = {
        // -OnboardingSleep=N (0–3) preselects a sleep band — only used
        // by the screenshot harness so you can review the insight card.
        let args = ProcessInfo.processInfo.arguments
        for arg in args where arg.hasPrefix("-OnboardingSleep=") {
            let raw = arg.replacingOccurrences(of: "-OnboardingSleep=", with: "")
            if let n = Int(raw), n >= 0 && n < SleepHours.allCases.count {
                return SleepHours.allCases[n]
            }
        }
        return nil
    }()
    @State private var confettiBurst: Int = 0
    @FocusState private var nameFocused: Bool

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            SimsTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Larger fixed spacer drops the hero block to roughly the
                // upper third of the screen — high enough to feel
                // "anchored at the top" without crashing into the topbar.
                Spacer().frame(height: 70)

                // Plumbob + text travel together as one block — the gem
                // sits directly above the headline, no Spacer between
                // them, so they read as a single hero unit. When a step
                // hides the plumbob (size 0, e.g. customize), it
                // animates out upward with a scale-down + fade; when it
                // returns, it floats in from below with a scale-up.
                let isHidden = plumbobSize == 0
                let renderSize: CGFloat = isHidden ? 120 : plumbobSize
                PlumbobView(mood: plumbobMood, size: renderSize, aspectRatio: 0.85)
                    .scaleEffect(isHidden ? 0.25 : 1)
                    .opacity(isHidden ? 0 : 1)
                    .offset(x: plumbobOffsetX,
                            y: plumbobOffsetY + (isHidden ? -220 : 0))
                    .frame(height: isHidden ? 0 : renderSize * 0.85)
                    .simsAnimation(.spring(response: 0.65, dampingFraction: 0.72), value: step)

                Group {
                    switch step {
                    case .hook:      hookStep
                    case .welcome:   welcomeStep
                    case .model:     modelStep
                    case .customize: customizeStep
                    case .name:      nameStep
                    case .sleep:     sleepStep
                    }
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .id(step)
                .transition(.asymmetric(
                    insertion: .opacity
                        .combined(with: .offset(y: 28))
                        .combined(with: .scale(scale: 0.94, anchor: .top)),
                    removal: .opacity
                        .combined(with: .offset(y: -22))
                        .combined(with: .scale(scale: 1.05, anchor: .bottom))
                ))

                Spacer()

                progressDots
                    .padding(.bottom, 14)

                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }

            confettiOverlay
                .allowsHitTesting(false)
        }
    }

    // MARK: - Step model

    enum Step: Int, CaseIterable {
        case hook, welcome, model, customize, name, sleep
    }

    /// Mirrors the four "Dormí …h" rows in NeedType.energy's QuickAction
    /// catalog (NeedType.swift). Same name, same icon, same boost — so
    /// the sleep entry logged in onboarding is indistinguishable from
    /// one the user could log later from the dashboard.
    enum SleepHours: String, CaseIterable, Identifiable {
        case under5, six, seven, eight
        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .under5: return "Menos de 5h"
            case .six:    return "6h"
            case .seven:  return "7h"
            case .eight:  return "8h o más"
            }
        }

        var actionName: String {
            switch self {
            case .under5: return "Dormí <5h"
            case .six:    return "Dormí 6h"
            case .seven:  return "Dormí 7h"
            case .eight:  return "Dormí 8h"
            }
        }

        var icon: String { "bed.double.fill" }

        /// Boost values lifted straight from the energy catalog.
        var boost: Double {
            switch self {
            case .under5: return 40
            case .six:    return 70
            case .seven:  return 85
            case .eight:  return 100
            }
        }
    }

    enum PlanChoice: String, CaseIterable, Identifiable {
        case light, balanced, intense
        var id: String { rawValue }
        var needPlan: NeedPlan {
            switch self {
            case .light:    return .essential
            case .balanced: return .balanced
            case .intense:  return .complete
            }
        }
        var emoji: String {
            switch self {
            case .light:    return "🌱"
            case .balanced: return "⚖️"
            case .intense:  return "🔥"
            }
        }
        var title: LocalizedStringKey {
            switch self {
            case .light:    return "Ligero"
            case .balanced: return "Equilibrado"
            case .intense:  return "Intenso"
            }
        }
        var subtitle: LocalizedStringKey {
            switch self {
            case .light:    return "Lo que la mayoría elige"
            case .balanced: return "Un punto medio"
            case .intense:  return "Si vienes con todo"
            }
        }
        var count: Int { needPlan.count }
    }

    // MARK: - Plumbob sizing per step

    /// Sizing has intent: bookends (hook + sleep) and the demo step are
    /// where the gem deserves the spotlight, so they go big. Middle steps
    /// keep it large enough to stay anchored to the eye without crowding
    /// the headline beside it.
    /// Sizes follow one rule: medium in content steps, big on the emotional
    /// bookends (hook + sleep). The gem never jumps unpredictably — only
    /// the steps that NEED the headroom (hook intro, final reveal) grow it.
    private var plumbobSize: CGFloat {
        switch step {
        case .hook:      return 230
        case .welcome:   return 150
        case .model:     return 175
        case .customize: return 0     // hidden — list needs the height
        case .name:      return 130
        case .sleep:     return 200
        }
    }
    private var plumbobOffsetX: CGFloat {
        // Centred on every step — the lateral drift was making the
        // overall flow feel scattered. Sizing alone carries the
        // hierarchy now.
        0
    }
    private var plumbobOffsetY: CGFloat {
        switch step {
        case .hook:  return -10
        case .sleep: return -6
        default:     return 0
        }
    }
    /// On the model step the plumbob mirrors the demo bar so users see the
    /// gem changing colour as a need rises and falls. On the rest of the
    /// steps it sits at calm levels that don't compete with the text.
    private var plumbobMood: Double {
        switch step {
        case .hook, .sleep: return 0.92
        case .model:        return demoValue
        default:            return 0.7
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            if step != .hook {
                Button { goBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(.subheadline, weight: .heavy))
                        Text("Atrás")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                    .foregroundStyle(SimsTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityLabel(Text("Paso anterior"))
            }
            Spacer()
        }
        .frame(height: 44)
        .simsAnimation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Step 0 — Hook

    private var hookStep: some View {
        VStack(spacing: 12) {
            Text("Una app para todo.")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
                .tracking(-0.9)
                .fixedSize(horizontal: false, vertical: true)

            Text("Lo que sueles olvidar.\nLo que sueles dejar a medias.")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(SimsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Step 1 — Welcome (what the app actually does)

    private var welcomeStep: some View {
        // 2×2 grid of pillar tiles with the headline centred above.
        // Reads as four pillars rather than a checklist.
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("Todo lo que necesites,")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                Text("en un sitio.")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(SimsTheme.accentPrimary)
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
            }
            .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10),
                          GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                welcomeTile(DashboardTab.needs.icon,
                            "Necesidades", "Tu día a día, medido")
                welcomeTile(DashboardTab.aspirations.icon,
                            "Aspiraciones", "Objetivos a la vista")
                welcomeTile(DashboardTab.botiquin.icon,
                            "Botiquín", "Suplementos sin olvidos")
                welcomeTile(DashboardTab.agenda.icon,
                            "Agenda", "Tareas y cosas del día")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    /// Big square tile — icon at the top, section name bold, hook line
    /// beneath. Visually echoes the dashboard tabs so the user already
    /// recognises the icons once they land on Estado.
    private func welcomeTile(_ icon: String,
                             _ title: LocalizedStringKey,
                             _ hook: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SimsTheme.frame, lineWidth: 1.5)
                    )
                    .frame(width: 46, height: 46)
                // Outline + fill stack so the symbol reads as the same
                // navy-bordered white glyph the NeedBarView uses.
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(SimsTheme.frame)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text(hook)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(SimsTheme.frame.opacity(0.30), lineWidth: 1)
                )
        )
    }

    // MARK: - Step 2 — Model (live demo: bar + plumbob react together)

    private var modelStep: some View {
        VStack(spacing: 16) {
            // Extra breathing room from the plumbob above — the demo
            // bar reads better when it's not pressed against the gem.
            Spacer().frame(height: 32)

            Text("Bajan solas. Tú las subes.")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
                .tracking(-0.5)

            // Real NeedBarView with a value bound to demoValue — the
            // exact same widget the user will see on the dashboard, so
            // the demo isn't a fake mock.
            NeedBarView(need: .energy, value: demoValue, recentActions: [], compact: false, onTap: {})
                .padding(.horizontal, 6)
                .allowsHitTesting(false)

            Text("Verde si vas bien. Rojo si te toca cuidarte.")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .onAppear { runDemoLoop() }
        .onDisappear { demoValue = 0.85 }
    }

    /// Drains pip by pip and refills pip by pip — same stepped approach
    /// in both directions so the bar never snaps. NeedBarView animates
    /// on `filled: Int` (0.25 s ease internal), so we space each
    /// threshold-crossing by ~340 ms to be sure SwiftUI doesn't batch
    /// them. The plumbob colour follows because plumbobMood reads
    /// `demoValue` on the model step.
    private func runDemoLoop() {
        guard step == .model else { return }
        demoValue = 0.85
        Task { @MainActor in
            let segments = 12
            let pipStep = 1.0 / Double(segments)
            while !Task.isCancelled && step == .model {
                // Hold full — green=good registers.
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard step == .model else { return }
                // Stepped decay.
                var v = demoValue
                while v > 0.18 && step == .model {
                    v = max(v - pipStep, 0.18)
                    withAnimation(.easeInOut(duration: 0.30)) { demoValue = v }
                    try? await Task.sleep(nanoseconds: 340_000_000)
                }
                guard step == .model else { return }
                // Linger on red.
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard step == .model else { return }
                // Stepped refill.
                v = demoValue
                while v < 0.85 && step == .model {
                    v = min(v + pipStep, 0.85)
                    withAnimation(.easeOut(duration: 0.22)) { demoValue = v }
                    try? await Task.sleep(nanoseconds: 280_000_000)
                }
                guard step == .model else { return }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    // MARK: - Step 3 — Customize categories

    private var customizeStep: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("¿Qué quieres seguir?")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                Text("Marca lo que importa. Puedes ajustarlo cuando quieras.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CategoriesEditor(embedded: true)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 6 — Name

    private var nameStep: some View {
        // Centered layout — the input field reads best when it sits
        // squarely in the middle of the screen instead of pushed to one
        // side. Plumbob is also centered for this step (offset=0).
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("¿Cómo te llamo?")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                Text("Aparece cuando abres la app. Solo lo verás tú.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("", text: $name,
                      prompt: Text("Tu nombre").foregroundStyle(SimsTheme.textSecondary))
                .textFieldStyle(.plain)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .foregroundStyle(SimsTheme.textPrimary)
                .simsFieldStyle(cornerRadius: 16, selected: nameFocused)
                .focused($nameFocused)
                .submitLabel(.continue)
                .onSubmit { advance() }

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(.footnote, weight: .heavy))
                Text("Privado en tu iCloud.")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .tracking(0.2)
            }
            .foregroundStyle(SimsTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.45), lineWidth: 1))
            )
        }
        .onAppear { nameFocused = true }
    }

    // MARK: - Step 5 — Sleep

    private var sleepStep: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Hola, \(displayName).")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                Text("Empieza por lo primero.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }

            Text("¿Cuántas horas dormiste anoche?")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            VStack(spacing: 8) {
                ForEach(SleepHours.allCases) { h in
                    Button { selectSleep(h) } label: {
                        sleepChip(h.label)
                    }
                    .buttonStyle(.plain)
                    .disabled(sleepChoice != nil)
                }
            }
        }
    }

    private func sleepChip(_ label: LocalizedStringKey) -> some View {
        Text(label)
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(SimsTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(SimsTheme.frame.opacity(0.45), lineWidth: 1)
                    )
            )
            // Make the whole pill rectangle tappable, not just the text glyphs.
            .contentShape(Rectangle())
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s == step ? SimsTheme.accentPrimary : SimsTheme.textDim.opacity(0.4))
                    .frame(width: s == step ? 22 : 6, height: 6)
                    .simsAnimation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
            }
        }
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        let label: LocalizedStringKey = primaryLabel
        let disabled = isPrimaryDisabled
        // Sleep step doesn't need a primary button — tapping an hour
        // option auto-closes the onboarding via `selectSleep` →
        // onFinish.
        let hidden = step == .sleep
        return Button { advance() } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Image(systemName: primaryIcon)
                    .font(.system(.subheadline, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(SimsTheme.accentPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(SimsTheme.frame, lineWidth: 1.2)
                    )
            )
            .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(hidden ? 0 : (disabled ? 0.4 : 1))
        .allowsHitTesting(!hidden)
        .simsAnimation(.easeInOut(duration: 0.2), value: hidden)
        .simsAnimation(.easeInOut(duration: 0.2), value: disabled)
    }

    private var primaryLabel: LocalizedStringKey {
        // Same word everywhere except the very first tap, so users
        // never have to wonder if "Listo" vs "Casi listo" means
        // anything different — it's just one button repeated.
        switch step {
        case .hook:    return "Empezar"
        case .sleep:   return "Entrar"   // hidden until they pick an hour
        default:       return "Continuar"
        }
    }
    private var primaryIcon: String {
        step == .sleep ? "checkmark" : "arrow.right"
    }
    private var isPrimaryDisabled: Bool {
        switch step {
        case .name:
            return name.trimmingCharacters(in: .whitespaces).isEmpty
        default:
            return false
        }
    }

    // MARK: - Confetti

    private var confettiOverlay: some View {
        ZStack {
            if confettiBurst > 0 {
                ConfettiBurst(trigger: confettiBurst)
            }
        }
    }

    // MARK: - Navigation

    private func advance() {
        haptic(.light)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            switch step {
            case .hook:    step = .welcome
            case .welcome: step = .model
            case .model:
                // Seed customize with the essential plan applied so the
                // user lands on a sensible baseline they can extend.
                store.applyPlan(plan.needPlan)
                step = .customize
            case .customize: step = .name
            case .name:      commitName()
            case .sleep:     onFinish()
            }
        }
    }

    private func goBack() {
        haptic(.light)
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = prev
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        savedName = trimmed
        // Plan + individual customisations were already applied via
        // applyPlan and CategoriesEditor in the previous steps, so the
        // dashboard is ready as soon as the user lands on it.
        step = .sleep
    }

    private func selectSleep(_ h: SleepHours) {
        haptic(.success)
        sleepChoice = h
        // Start Energía at 0 so the boost from the catalog lands at the
        // intended absolute value (40/70/85/100 %) — matches what
        // logging the same action manually after a real night's sleep
        // would do.
        store.setValue(0.0, for: .energy)
        let action = QuickAction(
            name: h.actionName,
            icon: h.icon,
            boost: h.boost,
            needType: .energy
        )
        if h == .seven || h == .eight {
            confettiBurst &+= 1
        }
        // Hand off to the dashboard quickly…
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            onFinish()
            // …then trigger the log slightly after the crossfade so the
            // user lands, sees the bar at zero for a beat, and then
            // watches it animate up to the right value while the
            // "Dormí Xh" chip slides in below.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                store.logAction(action, for: .energy)
            }
        }
    }

    // MARK: - Helpers

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "hola") : trimmed
    }

    private enum HapticKind { case light, success }
    private func haptic(_ kind: HapticKind) {
        #if os(iOS)
        switch kind {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }
}

// MARK: - Confetti burst

private struct ConfettiBurst: View {
    let trigger: Int
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var scale: CGFloat
        var color: Color
        var symbol: String
    }

    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.84, blue: 0.27),  // yellow
        Color(red: 0.36, green: 0.76, blue: 0.46),  // green
        Color(red: 0.41, green: 0.51, blue: 0.92),  // periwinkle
        Color(red: 0.94, green: 0.56, blue: 0.62)   // pink
    ]

    private static let symbols: [String] = [
        "sparkle", "star.fill", "circle.fill"
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Image(systemName: p.symbol)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(p.color)
                        .scaleEffect(p.scale)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                }
            }
            .onChange(of: trigger) { _, _ in
                burst(in: geo.size)
            }
        }
    }

    private func burst(in size: CGSize) {
        let centre = CGPoint(x: size.width / 2, y: size.height * 0.55)
        var seeds: [Particle] = []
        for _ in 0..<14 {
            seeds.append(Particle(
                x: centre.x,
                y: centre.y,
                rotation: Double.random(in: 0..<360),
                scale: 0.4,
                color: Self.palette.randomElement()!,
                symbol: Self.symbols.randomElement()!
            ))
        }
        particles = seeds

        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            particles = particles.map { p in
                var n = p
                let angle = Double.random(in: 0..<(2 * .pi))
                let dist  = CGFloat.random(in: 90...170)
                n.x = centre.x + cos(angle) * dist
                n.y = centre.y + sin(angle) * dist - 40
                n.rotation += Double.random(in: 120...300)
                n.scale = CGFloat.random(in: 0.9...1.3)
                return n
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                particles = particles.map {
                    var n = $0
                    n.scale = 0
                    return n
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                particles = []
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environment(NeedStore())
}
