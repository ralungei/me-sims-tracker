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
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var dosingMoment: DosingMoment? = nil
    @State private var reminderTime: Date? = nil
    @State private var unit: String = ""
    @State private var defaultDose: Int = 1
    @State private var schedule: [DoseStep] = []

    private let suggestedEmojis = ["🧘","💊","🌱","🎬","📚","💪","🏃","🥗","💧","🛏","☀️","🧠","✍️","🎨","🎵","🙏","💧","🦷","🧴","📞"]
    private let suggestedUnits = ["sobre", "cápsula", "comprimido", "pastilla", "gota", "ml", "g", "scoop"]
    private let huePresets: [Double] = [22, 38, 158, 195, 220, 258, 295, 335]

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.background.ignoresSafeArea()
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
                            section("Empieza el") { startDateField }
                        }
                        section("Unidad (opcional)") { unitField }
                        if !unit.isEmpty {
                            section("Cantidad por toma") { defaultDoseField }
                            if kind == .treatment {
                                section("Variación por semanas (opcional)") { scheduleField }
                            }
                        }
                        section("Cuándo tomarla (opcional)") { dosingField }
                        section("Hora exacta (opcional)") { reminderField }
                        section("Notas (opcional)") { notesField }
                        if existing != nil {
                            deleteButton
                                .padding(.top, 12)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existing == nil
                             ? Text("Nueva aspiración")
                             : Text("Editar"))
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

    // MARK: - Sections

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(SimsTheme.textSecondary)
            content()
        }
    }

    private var nameField: some View {
        TextField("Ej: Meditar 25 min", text: $name)
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    private var emojiField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("✨", text: $emoji)
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
            }
        }
    }

    private var kindField: some View {
        VStack(spacing: 8) {
            ForEach(AspirationKind.allCases, id: \.self) { k in
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

    private var totalDaysField: some View {
        Stepper(value: $totalDays, in: 3...365, step: 1) {
            Text("\(totalDays) días")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)
        }
        .padding(12)
        .simsFieldStyle()
    }

    private var startDateField: some View {
        DatePicker("", selection: $startDate, displayedComponents: .date)
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .simsFieldStyle()
    }

    private var unitField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("sobre, cápsula, ml...", text: $unit)
                .textFieldStyle(.plain)
                .padding(12)
                .simsFieldStyle()
                .foregroundStyle(SimsTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestedUnits, id: \.self) { u in
                        Button { unit = (unit == u ? "" : u) } label: {
                            Text(u)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(SimsTheme.textPrimary)
                                .simsChipStyle(selected: unit == u)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var defaultDoseField: some View {
        Stepper(value: $defaultDose, in: 1...20) {
            Text("\(defaultDose) \(defaultDose == 1 ? unit : Aspiration.pluralize(unit))")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)
        }
        .padding(12)
        .simsFieldStyle()
    }

    private var scheduleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(schedule.indices, id: \.self) { i in
                scheduleRow(index: i)
            }
            Button {
                let last = schedule.last
                let nextFrom = (last?.toWeek ?? 0) + 1
                schedule.append(DoseStep(fromWeek: nextFrom, toWeek: nextFrom + 1, count: defaultDose))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Añadir tramo")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(SimsTheme.accentPrimary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if !schedule.isEmpty {
                Text("Si una semana no está cubierta, se usa la cantidad por defecto.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textDim)
            }
        }
    }

    @ViewBuilder
    private func scheduleRow(index: Int) -> some View {
        let step = schedule[index]
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Sem")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(SimsTheme.textDim)
                    Stepper(value: $schedule[index].fromWeek, in: 1...52) {
                        Text("\(step.fromWeek)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .monospacedDigit()
                    }
                    .labelsHidden()
                    Text("a")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(SimsTheme.textDim)
                    // Custom binding here keeps the invariant `toWeek >= fromWeek`.
                    Stepper(value: Binding(
                        get: { schedule[index].toWeek },
                        set: { schedule[index].toWeek = max(schedule[index].fromWeek, $0) }
                    ), in: 1...52) {
                        Text("\(step.toWeek)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .monospacedDigit()
                    }
                    .labelsHidden()
                }
                Stepper(value: $schedule[index].count, in: 1...20) {
                    Text("\(step.count) \(step.count == 1 ? unit : Aspiration.pluralize(unit))")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                }
            }
            Button { schedule.remove(at: index) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(SimsTheme.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .simsFieldStyle()
    }

    private var dosingField: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: String(localized: "ninguno"), icon: "minus", isSelected: dosingMoment == nil) {
                    dosingMoment = nil
                }
                ForEach(DosingMoment.allCases, id: \.self) { m in
                    chip(label: m.label, icon: m.icon, isSelected: dosingMoment == m) {
                        dosingMoment = m
                        if reminderTime == nil {
                            reminderTime = Calendar.current.date(bySettingHour: m.defaultHour, minute: 0, second: 0, of: Date())
                        }
                    }
                }
            }
        }
    }

    private func chip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(label).font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(SimsTheme.textPrimary)
            .simsChipStyle(selected: isSelected)
        }
        .buttonStyle(.plain)
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
        TextField("", text: $notes, prompt: Text("Posología, marca, instrucciones...").foregroundStyle(SimsTheme.textSecondary), axis: .vertical)
            .lineLimit(3...8)
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
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
            if kind == .treatment {
                asp.totalDays = totalDays
                asp.startedAt = startDate
            } else {
                asp.totalDays = nil
                asp.startedAt = nil
            }
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
