#!/usr/bin/env swift
import Foundation

struct NeedSim {
    let name: String
    let decayPerHour: Double
    let boostEvents: [(hour: Int, boost: Double, label: String)]
}

let needs: [NeedSim] = [
    NeedSim(name: "Energía", decayPerHour: 6.25,
            boostEvents: [(7, 85, "Dormí 7h")]),
    NeedSim(name: "Nutricion", decayPerHour: 6.0,
            boostEvents: [(8, 50, "Desayuno"), (13, 55, "Almuerzo"), (20, 50, "Cena"), (16, 20, "Snack")]),
    NeedSim(name: "Hidratac", decayPerHour: 7.0,
            boostEvents: [(8, 30, "Agua"), (10, 18, "Cafe"), (12, 30, "Agua"),
                          (15, 30, "Agua"), (18, 30, "Agua"), (21, 22, "Te")]),
    NeedSim(name: "Ejercicio", decayPerHour: 4.17,
            boostEvents: [(17, 65, "Gym")]),
    NeedSim(name: "Higiene", decayPerHour: 4.17,
            boostEvents: [(7, 20, "Dientes"), (8, 65, "Ducha"), (22, 20, "Dientes")]),
    NeedSim(name: "Social", decayPerHour: 2.08,
            boostEvents: [(13, 15, "Mensajes"), (19, 55, "Amigos")]),
    NeedSim(name: "Diversion", decayPerHour: 4.0,
            boostEvents: [(17, 45, "Juegos"), (21, 40, "Serie")]),
    NeedSim(name: "Mente", decayPerHour: 2.5,
            boostEvents: [(9, 45, "Estudie"), (22, 25, "Lei")])
]

print("SIMULACION 24 HORAS - MY SIMS LIFE")
print("Escenario: dia tipico, todas las barras empiezan en 0%")
print(String(repeating: "=", count: 90))

func pad(_ s: String, _ w: Int) -> String {
    if s.count >= w { return String(s.prefix(w)) }
    return s + String(repeating: " ", count: w - s.count)
}

func fmtPct(_ v: Double) -> String {
    let s = String(format: "%.1f", v)
    return pad(s + "%", 7)
}

func icon(_ v: Double) -> String {
    if v >= 65 { return "G" }
    if v >= 40 { return "Y" }
    if v >= 20 { return "O" }
    return "R"
}

// Header
var hdr = pad("Hora", 8)
for n in needs { hdr += "| " + pad(n.name, 10) }
print(hdr)
print(String(repeating: "-", count: 8 + needs.count * 12))

var values = [Double](repeating: 0.0, count: needs.count)

for hour in 0...23 {
    if hour > 0 {
        for i in 0..<needs.count {
            values[i] = max(0.0, values[i] - needs[i].decayPerHour)
        }
    }

    var events: [String] = []
    for i in 0..<needs.count {
        for event in needs[i].boostEvents where event.hour == hour {
            values[i] = min(100.0, values[i] + event.boost)
            events.append("       ^ \(event.label) -> \(needs[i].name)")
        }
    }

    let hourStr = String(format: "%02d:00", hour)
    var row = pad(hourStr, 8)
    for i in 0..<needs.count {
        row += "| \(icon(values[i])) \(fmtPct(values[i])) "
    }
    print(row)
    for e in events { print(e) }
}

print(String(repeating: "=", count: 90))
print()
print("RESUMEN 23:00:")
print(String(repeating: "-", count: 60))
for i in 0..<needs.count {
    let v = values[i]
    let filled = Int(v / 5)
    let bar = String(repeating: "#", count: filled) + String(repeating: ".", count: 20 - filled)
    let status: String
    if v >= 65 { status = "OK" }
    else if v >= 40 { status = "MEDIO" }
    else if v >= 20 { status = "BAJO" }
    else { status = "CRITICO" }
    print("  \(pad(needs[i].name, 12)) [\(bar)] \(fmtPct(v))  \(status)")
}

print()
print("TASAS DE DECAIMIENTO:")
print(String(repeating: "-", count: 60))
for need in needs {
    let empty = 100.0 / need.decayPerHour
    let perMin = need.decayPerHour / 60.0
    print("  \(pad(need.name, 12)) \(String(format: "%.2f", need.decayPerHour))%/h  vacia en \(String(format: "%.1f", empty))h  (\(String(format: "%.4f", perMin))%/min)")
}

print()
let weights: [Double] = [1.5, 1.3, 1.2, 1.0, 0.8, 1.1, 0.9, 0.8]
var ws = 0.0, tw = 0.0
for i in 0..<needs.count {
    ws += (values[i] / 100.0) * weights[i]
    tw += weights[i]
}
let mood = ws / tw * 100
print("ANIMO GENERAL (Maslow-weighted): \(String(format: "%.1f", mood))%")
