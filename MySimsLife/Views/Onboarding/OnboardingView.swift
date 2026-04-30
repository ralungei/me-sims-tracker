import SwiftUI

struct OnboardingView: View {
    @AppStorage("userName") private var savedName: String = ""

    @State private var name: String = ""
    @State private var step: Step = .welcome
    @FocusState private var nameFocused: Bool

    enum Step: Int, CaseIterable { case welcome, intro, categories, name }

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            SimsTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Outside the .id(step) block so the SCNView isn't recreated on every step change
                PlumbobView(mood: 0.85, size: 110)
                    .padding(.bottom, 32)

                Group {
                    switch step {
                    case .welcome:    welcome
                    case .intro:      intro
                    case .categories: categoriesStep
                    case .name:       nameStep
                    }
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 32)
                .id(step)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 14)),
                    removal:   .opacity.combined(with: .offset(y: -14))
                ))

                Spacer()

                progressDots
                    .padding(.bottom, 18)

                primaryButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 14) {
            Text("Hola.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
                .tracking(-0.6)
            Text("Lleva el tracking de tu día como en Los Sims.\nNecesidades, retos y agenda en un sitio.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Qué vas a ver")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(SimsTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            row("circle.hexagongrid.fill",
                "El rombo",
                "Tu estado general. Cambia de color: verde si vas bien, rojo si vas mal.")

            row("drop.fill",
                "Necesidades",
                "10 barras que bajan con el tiempo. Toca una y registra lo que hiciste.")

            row("sparkles",
                "Aspiraciones",
                "Retos que querés mantener. Diarios, semanales o tratamientos.")

            row("checklist",
                "Agenda",
                "Tareas puntuales de hoy. Con o sin hora.")
        }
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ desc: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(SimsTheme.accentPrimary.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SimsTheme.accentPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text(desc)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Name

    private var categoriesStep: some View {
        VStack(spacing: 12) {
            Text("¿Qué quieres seguir?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(SimsTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Activa solo las que te interesen. Puedes cambiarlo después en Categorías.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(SimsTheme.textDim)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            CategoriesEditor(embedded: true)
                .frame(maxHeight: 320)
        }
    }

    private var nameStep: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("¿Cómo te llamas?")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Aparece en el saludo cuando abres la app.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SimsTheme.textDim)
                    .multilineTextAlignment(.center)
            }

            TextField("", text: $name, prompt: Text("Tu nombre").foregroundStyle(SimsTheme.textDim))
                .textFieldStyle(.plain)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(nameFocused ? SimsTheme.accentPrimary.opacity(0.5) : Color.white.opacity(0.05),
                                        lineWidth: 1)
                        )
                )
                .foregroundStyle(SimsTheme.textPrimary)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { commit() }
                .padding(.top, 4)
        }
        .onAppear { nameFocused = true }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s == step ? SimsTheme.accentPrimary : SimsTheme.textDim.opacity(0.5))
                    .frame(width: s == step ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
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
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SimsTheme.accentPrimary)
            )
            .foregroundStyle(Color.black.opacity(0.85))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: disabled)
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
