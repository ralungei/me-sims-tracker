# Calibration

Sistema reproducible para verificar que las constantes de la app (decay
rates, boosts de quick actions, pesos de mood, fórmula del VITAL) siguen
produciendo una experiencia sana cuando se añaden / cambian cosas.

**Cómo correr:**

```bash
swift Tools/CalibrationCheck.swift
```

Exit 0 = todo verde · Exit 1 = uno o más checks fallaron, hay que mirar
los `[FAIL]` antes de subir cambios.

**Cuándo correr (obligatorio):**

- Tocas `decayRatePerHour` o `moodWeight` en `MySimsLife/Models/NeedType.swift`
- Añades / quitas / cambias el boost de cualquier `QuickAction`
- Cambias la fórmula de `vitalScore` o `overallMood` en `NeedStore`
- Añades una `NeedType` nueva

---

## Filosofía

La app modela 11 necesidades que decaen con el tiempo. El reto de
calibrar es que **ninguna debe sentirse castigadora ni trivial**:

- **Castigadora:** el VITAL baja demasiado rápido aunque hagas todo bien
  → el usuario abandona porque "siempre estoy en rojo".
- **Trivial:** el VITAL se queda alto sin esfuerzo → la app no aporta
  nada porque no refleja realmente cómo estás.

El punto de equilibrio:

- Mañana con rutina sana → pico **VITAL ≥ 70**
- Día normal con altibajos → media en torno a **50-65**
- Día pasivo (sin tocar la app) → cae a **< 20** en 24h
- "Perfecto" + aspiraciones cumplidas → **VITAL = 100** sí alcanzable pero
  requiere mantener varias barras al máximo

---

## Escenarios actuales (8)

### 1. Arranque fresh install

Confirma que un usuario nuevo abre la app y ve:

- Todas las barras decaying al 50%
- Health al 100% (es manual, no decae)
- VITAL = **50** exactos (centro del bar, no negativo)
- Mood global = 50% exacto

**Nota histórica:** la fórmula original era `mood × 90 + bonus(max 10)`,
con la idea de reservar 10 puntos al bonus de aspiraciones. Efecto
colateral: con todas las barras al 50% (mood = 0.5), VITAL salía a 45,
que el centrado-bar renderizaba como "1 pip en rojo a la izquierda
del centro". Eso era el primer estado que veía un usuario nuevo →
mensaje confuso ("¿qué he hecho mal si acabo de abrir la app?").
Cambio a `mood × 100 + bonus(max 10)` clamped en 100. Aspiraciones
ahora pueden empujar partial-mood-states por encima del techo
natural en lugar de competir por un cupo de 10 puntos.

### 2. Decay rates en rangos sensatos

Para cada need decaying, verifica las horas de 100% → 0% sin acciones.
Rangos esperados (subjetivos pero conservadores):

| Need | Horas a 0% | Justificación |
|------|------------|---------------|
| mentalHealth | 50-100 | Resiliencia psicológica — 2-4 días de neglect |
| energy | 14-20 | Un día despierto te deja agotado |
| nutrition | 14-20 | Sin comer 24h tiene sentido al 0% |
| hydration | 12-18 | Beber varias veces al día es realista |
| bladder | 6-12 | Vejiga cíclica, varias veces al día |
| exercise | 20-30 | 1 día sedentario es manejable |
| hygiene | 20-30 | Ducha diaria normal |
| environment | 30-50 | Limpiar 2-3 veces/semana es OK |
| social | 40-60 | No es diario obligatorio |
| leisure | 24-36 | Necesitas ocio cada 1-1.5 días |

Si modificas un `decayRatePerHour` fuera de estos rangos, **justifícalo
en este doc** y ajusta el rango aquí mismo. Si no, FAIL.

### 3. Cada need tiene presupuesto de positivos ≥ 100

Para cada need, suma de todos los boosts positivos disponibles ≥ 100.
Garantiza que con las acciones que ofrecemos, un usuario puede recuperar
una barra de 0% → 100% en un día. Si añades una `NeedType` nueva sin
positivos suficientes, FAIL.

### 4. Comer ≠ hambre 5 min después

Verifica que tras loguear "Almuerzo" (+55 Nutrición), 5 minutos después
la barra apenas ha bajado (drop < 2%). Garantiza que las alertas no se
dispararán justo después de una acción positiva. Si alguna vez la decay
rate sube demasiado, FAIL aquí.

### 5. Día activo logra VITAL alto

Simula una mañana con rutina sana (dormir + desayuno + meditar + almuerzo).

- Pico VITAL en la mañana ≥ 70
- Tras almorzar (mediodía) ≥ 60

Si bajan estos números → o las acciones positivas son débiles o el decay
es agresivo. Hay que rebalancear.

### 6. Día pasivo cae a < 20

24h sin tocar la app → VITAL < 20. El castigo a no usarse debe ser
visible. Si el VITAL se queda alto sin hacer nada, la app no incentiva
uso → FAIL.

### 7. VITAL máximo alcanzable

- Todas las barras a 100% + 0 aspiraciones cumplidas → VITAL = 90
- Todas las barras a 100% + 4 aspiraciones cumplidas → VITAL = 100

Esto valida la fórmula `mood × 90 + min(10, aspsDone × 3)`. Si cambias
la fórmula, ajusta este check.

### 8. Mental health resiste

Mental decae más lento que el resto (es la "ancla"). Tras 24h sin
hacer nada, debe quedar ≥ 10%. Si esto baja, mental se está usando como
otra need más en vez de como ancla emocional.

---

## Añadir un escenario nuevo

Cualquier comportamiento nuevo del modelo merece un check. Patrón:

```swift
section("X. Descripción corta")
do {
    var b = freshBars()
    // ... simular acciones ...
    let result = vital(b, enabled: essentialPlan)
    check("Aserción legible", result >= esperado, "got \(result)")
}
```

Las funciones disponibles para usar:

- `freshBars()` — bars iniciales (50% / 100%)
- `applyDecay(&bars, hours:, enabled:)` — adelantar tiempo
- `boost(&bars, "nutrition", 55)` — loguear acción (boost en puntos %)
- `vital(bars, enabled:, aspirationsDone:)` — VITAL en 0-100
- `overallMood(bars, enabled:)` — mood en 0-1
- `hoursTo(from, to, rate:)` — tiempo en alcanzar un valor

---

## Pitfalls de drift

Este script **duplica las constantes** del código real. Tiene una
ventaja (corre standalone, no requiere Xcode) y una desventaja (puede
desincronizarse). Antidoto:

- Si cambias un valor en `NeedType.swift`, copia el cambio aquí.
- Si añades una `NeedType` nueva, añádela a `decayRates`,
  `moodWeights`, `positiveBoostBudget`.
- Antes de commit: corre el script. Si falla, arregla; si las
  expectativas cambian conscientemente, actualiza este doc.
