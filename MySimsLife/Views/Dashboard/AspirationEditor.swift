import SwiftUI

// MARK: - Aspiration Editor (create / edit)

struct AspirationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NeedStore.self) private var store

    let existing: Aspiration?

    @State private var name: String = ""
    @State private var emoji: String = "✨"
    @State private var kind: AspirationKind = .dailySimple
    @State private var hue: Double = 220
    @State private var xp: Int = 10
    @State private var durationMinutes: Int = 25
    @State private var totalDays: Int = 30

    private let suggestedEmojis = ["🧘","💊","🌱","🎬","📚","💪","🏃","🥗","💧","🛏","☀️","🧠","✍️","🎨","🎵","🙏","💧","🦷","🧴","📞"]
    private let huePresets: [Double] = [22, 38, 158, 195, 220, 258, 295, 335]

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.mainBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        previewCard
                        section("Nombre") { nameField }
                        section("Emoji") { emojiField }
                        section("Tipo") { kindField }
                        section("Color") { hueField }
                        section("¿Qué tan grande es?") { xpField }
                        if kind == .dailyTimed {
                            section("Duración") { durationField }
                        }
                        if kind == .treatment {
                            section("Días totales") { totalDaysField }
                        }
                        if existing != nil {
                            deleteButton
                                .padding(.top, 12)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existing == nil ? "Nueva aspiración" : "Editar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
        .onAppear { loadIfExisting() }
    }

    // MARK: - Preview

    private var previewCard: some View {
        let preview = Aspiration(
            name: name.isEmpty ? "Tu aspiración" : name,
            emoji: emoji,
            kind: kind,
            hue: hue, xp: xp,
            durationMinutes: durationMinutes,
            totalDays: totalDays,
            startedAt: kind == .treatment ? Date() : nil
        )
        return HStack {
            Spacer()
            AspirationCard(aspiration: preview) {}
                .allowsHitTesting(false)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(SimsTheme.textDim)
            content()
        }
    }

    private var nameField: some View {
        TextField("Ej: Meditar 25 min", text: $name)
            .textFieldStyle(.plain)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            .foregroundStyle(SimsTheme.textPrimary)
    }

    private var emojiField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("✨", text: $emoji)
                .textFieldStyle(.plain)
                .font(.system(size: 28))
                .frame(width: 70, height: 56)
                .multilineTextAlignment(.center)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestedEmojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e)
                                .font(.system(size: 22))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(emoji == e ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var kindField: some View {
        VStack(spacing: 8) {
            ForEach([AspirationKind.dailySimple, .dailyTimed, .treatment, .weekly], id: \.self) { k in
                Button { kind = k } label: {
                    HStack {
                        Image(systemName: kindIcon(k))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(kind == k ? SimsTheme.accentWarm : SimsTheme.textSecondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kindTitle(k))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(SimsTheme.textPrimary)
                            Text(kindHint(k))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(SimsTheme.textDim)
                        }
                        Spacer()
                        if kind == k {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(SimsTheme.accentWarm)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(kind == k ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(kind == k ? SimsTheme.accentWarm.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var hueField: some View {
        HStack(spacing: 10) {
            ForEach(huePresets, id: \.self) { h in
                Button { hue = h } label: {
                    Circle()
                        .fill(Color(hue: h/360, saturation: 0.55, brightness: 0.62))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: abs(hue - h) < 1 ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var xpField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(XPLevel.allCases) { lvl in
                    Button { xp = lvl.value } label: {
                        VStack(spacing: 4) {
                            Text(lvl.emoji)
                                .font(.system(size: 22))
                            Text(lvl.label)
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(xp == lvl.value ? SimsTheme.textPrimary : SimsTheme.textSecondary)
                            Text("+\(lvl.value)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(xp == lvl.value ? SimsTheme.accentWarm : SimsTheme.textDim)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(xp == lvl.value ? Color.white.opacity(0.10) : Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(xp == lvl.value ? SimsTheme.accentWarm.opacity(0.55) : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(XPLevel.from(xp).hint)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(SimsTheme.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var durationField: some View {
        Stepper(value: $durationMinutes, in: 1...180, step: 5) {
            Text("\(durationMinutes) min")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private var totalDaysField: some View {
        Stepper(value: $totalDays, in: 3...365, step: 1) {
            Text("\(totalDays) días")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let existing { store.deleteAspiration(existing) }
            dismiss()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Eliminar aspiración")
            }
            .font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(14)
            .foregroundStyle(SimsTheme.negativeTint)
            .background(RoundedRectangle(cornerRadius: 12).fill(SimsTheme.negativeTint.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func kindIcon(_ k: AspirationKind) -> String {
        switch k {
        case .dailySimple: return "sun.max.fill"
        case .dailyTimed:  return "timer"
        case .treatment:   return "leaf.fill"
        case .weekly:      return "calendar"
        }
    }

    private func kindTitle(_ k: AspirationKind) -> String {
        switch k {
        case .dailySimple: return "Diario"
        case .dailyTimed:  return "Diario con sesión"
        case .treatment:   return "Tratamiento"
        case .weekly:      return "Semanal"
        }
    }

    private func kindHint(_ k: AspirationKind) -> String {
        switch k {
        case .dailySimple: return "Una vez al día (ej: creatina)"
        case .dailyTimed:  return "Diario con duración (ej: meditar 25 min)"
        case .treatment:   return "Curso finito con progreso (ej: prebióticos 30 días)"
        case .weekly:      return "Una vez por semana (ej: postear reel)"
        }
    }

    private func loadIfExisting() {
        guard let asp = existing else { return }
        name = asp.name
        emoji = asp.emoji
        kind = asp.kind
        hue = asp.hue
        xp = asp.xp
        durationMinutes = asp.durationMinutes ?? 25
        totalDays = asp.totalDays ?? 30
    }

    // MARK: - XP Level

    enum XPLevel: CaseIterable, Identifiable {
        case mini, small, medium, big, epic

        var id: Int { value }

        var value: Int {
            switch self {
            case .mini:   return 5
            case .small:  return 10
            case .medium: return 25
            case .big:    return 50
            case .epic:   return 100
            }
        }

        var emoji: String {
            switch self {
            case .mini:   return "🪶"
            case .small:  return "🌱"
            case .medium: return "⭐"
            case .big:    return "💪"
            case .epic:   return "🏆"
            }
        }

        var label: String {
            switch self {
            case .mini:   return "Mini"
            case .small:  return "Pequeña"
            case .medium: return "Normal"
            case .big:    return "Grande"
            case .epic:   return "Épica"
            }
        }

        var hint: String {
            switch self {
            case .mini:   return "Gesto de segundos — tomar una pastilla, lavarse las manos"
            case .small:  return "Algo rápido de 2–5 min — un vaso de agua, escribir tres líneas"
            case .medium: return "Sesión real de 15–30 min — meditar, leer un capítulo"
            case .big:    return "Esfuerzo notable de 30+ min — entrenar, cocinar bien"
            case .epic:   return "Logro semanal — postear, terminar un proyecto, salir con gente"
            }
        }

        static func from(_ value: Int) -> XPLevel {
            allCases.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? .small
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let safeEmoji = emoji.isEmpty ? "✨" : emoji
        if let asp = existing {
            asp.name = trimmedName
            asp.emoji = safeEmoji
            asp.kind = kind
            asp.hue = hue
            asp.xp = xp
            asp.durationMinutes = kind == .dailyTimed ? durationMinutes : nil
            if kind == .treatment {
                asp.totalDays = totalDays
                if asp.startedAt == nil { asp.startedAt = Date() }
            } else {
                asp.totalDays = nil
                asp.startedAt = nil
            }
            store.updateAspiration(asp)
        } else {
            let asp = Aspiration(
                name: trimmedName,
                emoji: safeEmoji,
                kind: kind,
                hue: hue,
                xp: xp,
                durationMinutes: kind == .dailyTimed ? durationMinutes : nil,
                totalDays: kind == .treatment ? totalDays : nil,
                startedAt: kind == .treatment ? Date() : nil
            )
            store.addAspiration(asp)
        }
        dismiss()
    }
}
