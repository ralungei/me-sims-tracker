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
    // Legacy fields kept so existing `.treatment` aspirations preserve their
    // totalDays / startedAt / unit / dose / schedule when re-saved. The editor
    // no longer offers UI to *create* a treatment aspiration (use the Botiquín
    // tab's TreatmentEditor instead).
    @State private var totalDays: Int = 30
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var dosingMoment: DosingMoment? = nil
    @State private var reminderTime: Date? = nil
    @State private var unit: String = ""
    @State private var defaultDose: Int = 1
    @State private var schedule: [DoseStep] = []

    private let suggestedEmojis = ["🧘","🌱","🎬","📚","💪","🏃","🥗","💧","🛏","☀️","🧠","✍️","🎨","🎵","🙏","🦷","🧴","📞"]
    private let huePresets: [Double] = [22, 38, 158, 195, 220, 258, 295, 335]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        SimsEditorScaffold(
            title: existing == nil ? "Nueva aspiración" : "Editar",
            isValid: isValid,
            onSave: save
        ) {
            previewCard
            SimsSection("Nombre") { nameField }
            SimsSection("Emoji") { emojiField }
            SimsSection("Tipo") { kindField }
            SimsSection("Color") { hueField }
            SimsSection("¿Qué tan grande es?") { xpField }
            if kind == .dailyTimed {
                SimsSection("Duración") { durationField }
            }
            SimsSection("Cuándo (opcional)") { dosingField }
            SimsSection("Hora exacta (opcional)") { reminderField }
            SimsSection("Notas (opcional)") { notesField }
            if existing != nil {
                SimsDeleteButton(label: "Eliminar aspiración") {
                    if let existing { store.deleteAspiration(existing) }
                    dismiss()
                }
                .padding(.top, 12)
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
            startedAt: kind == .treatment ? Date() : nil,
            unit: unit.isEmpty ? nil : unit,
            defaultDose: defaultDose,
            schedule: schedule
        )
        return HStack {
            Spacer()
            AspirationCard(aspiration: preview) {}
                .allowsHitTesting(false)
            Spacer()
        }
        .padding(.vertical, 12)
        .simsFieldStyle(cornerRadius: 24)
    }

    // MARK: - Fields

    private var nameField: some View {
        TextField("",
                  text: $name,
                  prompt: Text("Ej: Meditar 25 min")
                            .foregroundStyle(SimsTheme.textSecondary))
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    private var emojiField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("",
                      text: $emoji,
                      prompt: Text("✨").foregroundStyle(SimsTheme.textSecondary))
                .textFieldStyle(.plain)
                .font(.system(size: 28))
                .frame(width: 70, height: 56)
                .multilineTextAlignment(.center)
                .simsFieldStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestedEmojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e)
                                .font(.system(size: 22))
                                .frame(width: 40, height: 40)
                                .simsFieldStyle(cornerRadius: 10, selected: emoji == e)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -20)
        }
    }

    private var kindField: some View {
        VStack(spacing: 8) {
            ForEach(AspirationKind.pickable, id: \.self) { k in
                Button { kind = k } label: {
                    HStack {
                        Image(systemName: k.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.title)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(SimsTheme.textPrimary)
                            Text(k.hint)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(SimsTheme.textSecondary)
                        }
                        Spacer()
                        if kind == k {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(SimsTheme.frame)
                        }
                    }
                    .padding(12)
                    .simsFieldStyle(selected: kind == k)
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
                        .fill(SimsTheme.hueSwatch(h))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(SimsTheme.frame, lineWidth: abs(hue - h) < 1 ? 2.5 : 1)
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
                                .foregroundStyle(SimsTheme.textPrimary)
                            Text("+\(lvl.value)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(SimsTheme.textSecondary)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .simsFieldStyle(selected: xp == lvl.value)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(XPLevel.from(xp).hint)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
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
        .simsFieldStyle()
    }

    private var dosingField: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SimsSelectableChip(label: String(localized: "ninguno"),
                                   icon: "minus",
                                   isSelected: dosingMoment == nil) {
                    dosingMoment = nil
                }
                ForEach(DosingMoment.allCases, id: \.self) { m in
                    SimsSelectableChip(label: m.label,
                                       icon: m.icon,
                                       isSelected: dosingMoment == m) {
                        dosingMoment = m
                        if reminderTime == nil {
                            reminderTime = Calendar.current.date(bySettingHour: m.defaultHour, minute: 0, second: 0, of: Date())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -20)
    }

    private var reminderField: some View {
        HStack {
            if let time = reminderTime {
                DatePicker("",
                           selection: Binding(
                               get: { time },
                               set: { reminderTime = $0 }),
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Spacer()
                Button { reminderTime = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SimsTheme.textPrimary.opacity(0.6))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text("Añadir hora").font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(SimsTheme.textPrimary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(12)
        .simsFieldStyle()
    }

    private var notesField: some View {
        TextField("", text: $notes, prompt: Text("Por qué te importa, recordatorios...").foregroundStyle(SimsTheme.textSecondary), axis: .vertical)
            .lineLimit(3...8)
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    // MARK: - Helpers

    private func loadIfExisting() {
        guard let asp = existing else { return }
        name = asp.name
        emoji = asp.emoji
        kind = asp.kind
        hue = asp.hue
        xp = asp.xp
        durationMinutes = asp.durationMinutes ?? 25
        totalDays = asp.totalDays ?? 30
        notes = asp.notes ?? ""
        startDate = asp.startedAt ?? Date()
        dosingMoment = asp.dosingMoment
        reminderTime = asp.reminderTime
        unit = asp.unit ?? ""
        defaultDose = asp.defaultDose
        schedule = asp.schedule
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
            case .mini:   return String(localized: "Mini")
            case .small:  return String(localized: "Pequeña")
            case .medium: return String(localized: "Normal")
            case .big:    return String(localized: "Grande")
            case .epic:   return String(localized: "Épica")
            }
        }

        var hint: String {
            switch self {
            case .mini:   return String(localized: "Gesto de segundos — tomar una pastilla, lavarse las manos")
            case .small:  return String(localized: "Algo rápido de 2–5 min — un vaso de agua, escribir tres líneas")
            case .medium: return String(localized: "Sesión real de 15–30 min — meditar, leer un capítulo")
            case .big:    return String(localized: "Esfuerzo notable de 30+ min — entrenar, cocinar bien")
            case .epic:   return String(localized: "Logro semanal — postear, terminar un proyecto, salir con gente")
            }
        }

        static func from(_ value: Int) -> XPLevel {
            allCases.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? .small
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let safeEmoji = emoji.isEmpty ? "✨" : emoji
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        let resolvedUnit: String? = trimmedUnit.isEmpty ? nil : trimmedUnit
        let resolvedSchedule = (resolvedUnit == nil || kind != .treatment) ? [] : schedule
        if let asp = existing {
            asp.name = trimmedName
            asp.emoji = safeEmoji
            asp.kind = kind
            asp.hue = hue
            asp.xp = xp
            asp.notes = resolvedNotes
            asp.dosingMoment = dosingMoment
            asp.reminderTime = reminderTime
            asp.durationMinutes = kind == .dailyTimed ? durationMinutes : nil
            asp.totalDays = kind == .treatment ? totalDays : nil
            asp.startedAt = kind == .treatment ? startDate : nil
            asp.unit = resolvedUnit
            asp.defaultDose = defaultDose
            asp.schedule = resolvedSchedule
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
                startedAt: kind == .treatment ? startDate : nil,
                notes: resolvedNotes,
                dosingMoment: dosingMoment,
                reminderTime: reminderTime,
                unit: resolvedUnit,
                defaultDose: defaultDose,
                schedule: resolvedSchedule
            )
            store.addAspiration(asp)
        }
        dismiss()
    }
}
