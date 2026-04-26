# me-sims-tracker

Mi vida como una partida de Los Sims. App personal multi-device (iPad escritorio · iPhone companion · widgets · Watch face) que trata el día a día como un sistema de necesidades con barras, plumbob/orbe de mood, puntaje VITAL y aspiraciones personales.

## Stack

- SwiftUI + SwiftData (CloudKit-ready)
- iOS 17+ / macOS 14+
- XcodeGen (`project.yml`)

## Conceptos

- **8 Necesidades**: Energía, Nutrición, Hidratación, Ejercicio, Higiene, Entorno, Social, Ocio. Cada una decae con una tasa calibrada a ritmos biológicos reales.
- **Mood Disc**: anillo + disco que cambian de color según el estado general (verde / champagne / caramelo / dusty rose).
- **VITAL 0–100**: mood ponderado + bonus por aspiraciones cumplidas.
- **Aspiraciones**: retos personales con 4 tipos (diaria simple, diaria con sesión, tratamiento de N días, semanal) y 5 niveles de XP (Mini, Pequeña, Normal, Grande, Épica).

## Comandos

```bash
xcodegen generate            # regenerar .xcodeproj
xcodebuild -scheme MySimsLife -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

## CloudKit

Configurado para sincronizar entre devices con la cuenta de iCloud personal. Si no hay cuenta o el container no está aprovisionado (Apple Developer Program), cae a almacenamiento local automáticamente.
