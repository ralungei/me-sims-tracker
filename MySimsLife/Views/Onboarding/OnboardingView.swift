import SwiftUI

struct OnboardingView: View {
    @AppStorage("userName") private var savedName: String = ""

    @State private var name: String = ""
    @State private var step: Step = .welcome
    @FocusState private var nameFocused: Bool

    enum Step: Int, CaseIterable { case welcome, intro, categories, name }

    let onFinish: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            SimsTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                Spacer(minLength: 12)

                // Plumbob is outside the .id(step) block so SceneKit doesn't
                // tear down + rebuild the SCNView on every transition.
                PlumbobView(mood: 0.85, size: 130)
                    .padding(.bottom, 22)

                stepBadge
                    .padding(.bottom, 14)

                Group {
                    switch step {
                    case .welcome:    welcome
                    case .intro:      intro
                    case .categories: categoriesStep
                    case .name:       nameStep
                    }
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .id(step)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 14)),
                    removal:   .opacity.combined(with: .offset(y: -14))
                ))

                Spacer()

                progressDots
                    .padding(.bottom, 16)

                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Top bar (back chevron, hidden on first step)

    private var topBar: some View {
        HStack {
            if step != .welcome {
                Button {
                    goBack()
                } label: {
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

    // MARK: - Step badge ("Paso 1 de 4")

    private var stepBadge: some View {
        Text("Paso \(step.rawValue + 1) de \(Step.allCases.count)")
            .font(.system(.caption, design: .rounded, weight: .heavy))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(SimsTheme.textDim)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 18) {
            Text("Hola.")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
                .tracking(-1.2)
            Text("Lleva tu día como en Los Sims.\nNecesidades, aspiraciones, botiquín y agenda en un sitio.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            // Privacy footer pinned inside its own pill so it reads as a
            // standalone trust badge rather than just smaller body copy.
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(.footnote, weight: .heavy))
                Text("Privado. iCloud. Sin servidor ni analítica.")
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
            .padding(.top, 4)
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Qué vas a ver")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(SimsTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            row("suit.diamond.fill",
                "El rombo",
                "Tu estado general. Verde si vas bien, rojo si vas mal.")

            row("chart.bar.fill",
                "Necesidades",
                "Barras que bajan con el tiempo. Toca una y registra lo que hiciste.")

            row("flag.fill",
                "Aspiraciones",
                "Retos diarios, semanales o de una vez. Suman XP al completarlos.")

            row("pills.fill",
                "Botiquín",
                "Tratamientos, suplementos y vitaminas con recordatorios.")

            row("checklist",
                "Agenda",
                "Tareas puntuales de hoy. Con o sin hora.")
        }
    }

    /// Row promoted to a panel-styled card so it reads as a discrete item
    /// instead of a flat list. Bigger icon tile + heavier title weight than
    /// the previous version.
    private func row(_ icon: String, _ title: LocalizedStringKey, _ desc: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(SimsTheme.frame)
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text(desc)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simsPanelStyle(cornerRadius: 14)
    }

    // MARK: - Categories

    private var categoriesStep: some View {
        VStack(spacing: 12) {
            Text("¿Qué quieres seguir?")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Elige un plan o ajústalo categoría a categoría. Puedes cambiarlo cuando quieras.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            CategoriesEditor(embedded: true)
                .frame(maxHeight: 320)
        }
    }

    // MARK: - Name

    private var nameStep: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("¿Cómo te llamas?")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(SimsTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Aparece en el saludo cuando abres la app.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("", text: $name,
                      prompt: Text("Tu nombre").foregroundStyle(SimsTheme.textSecondary))
                .textFieldStyle(.plain)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
                .padding(.vertical, 18)
                .padding(.horizontal, 18)
                .foregroundStyle(SimsTheme.textPrimary)
                .simsFieldStyle(cornerRadius: 16, selected: nameFocused)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { commit() }
                .padding(.top, 4)
        }
        .onAppear { nameFocused = true }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s == step ? SimsTheme.accentPrimary : SimsTheme.textDim.opacity(0.4))
                    .frame(width: s == step ? 26 : 7, height: 7)
                    .simsAnimation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
            }
        }
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        let label: LocalizedStringKey = step == .name ? "Listo" : "Siguiente"
        let disabled = step == .name && name.trimmingCharacters(in: .whitespaces).isEmpty
        return Button { advance() } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Image(systemName: step == .name ? "checkmark" : "arrow.right")
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
        .opacity(disabled ? 0.4 : 1)
        .simsAnimation(.easeInOut(duration: 0.2), value: disabled)
    }

    private func advance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            switch step {
            case .welcome:    step = .intro
            case .intro:      step = .categories
            case .categories: step = .name
            case .name:       commit()
            }
        }
    }

    private func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = prev
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        savedName = trimmed
        onFinish()
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
