# TODO — Migrar de Cloudflare Workers a iCloud / CloudKit

Cuando pagues el Apple Developer Program ($99/año), conviene mover el sync de
backend propio a iCloud nativo. Es **gratis**, no necesita auth (lo gestiona
iOS con el Apple ID del dispositivo), y elimina toda la capa de
`BackendSync` + `RealtimeSync` + Workers + D1.

Trade-off: solo sincroniza entre dispositivos del **mismo Apple ID**. Si un
día abres la app a otra gente con sus propias cuentas, vuelves a necesitar
backend o pasas a CloudKit Public Database.

---

## 0. Pre-requisitos

- Apple Developer Program activo (membership pagada).
- En `Signing & Capabilities` del target `MySimsLife`, añadir capabilities:
  - **iCloud** → habilitar **CloudKit**.
  - **Push Notifications** (CloudKit los usa para subscriptions).
  - **Background Modes** → *Remote notifications* (para recibir cambios en background).
- En el portal de developer, añadir un container CloudKit:
  `iCloud.com.mysims.life` (mismo bundle id que la app).
- En `MySimsLife.entitlements`, dejar que XcodeGen lo genere con la entry de
  `com.apple.developer.icloud-services` = `["CloudKit"]` y
  `com.apple.developer.icloud-container-identifiers` con el container.

## 1. Decidir: SwiftData + CloudKit (más simple) vs CloudKit puro

Recomendación: **SwiftData + CloudKit**. Es lo que ya usas para el modelo,
solo hace falta enchufarle el contenedor en CloudKit. Apple lo soporta nativo
desde iOS 17.

Limitaciones a tener en cuenta:

- SwiftData + CloudKit **no soporta** propiedades `@Attribute(.unique)`. Si
  alguna de tus `@Model` clases las tiene, hay que quitarlas y dedupear en
  código (ya lo hacemos: `dedupeKeepingFirst` en `BackendSync`).
- Todas las propiedades deben tener un valor por defecto (ya lo cumples).
- Los modelos no pueden tener relaciones a la inversa sin definir las dos
  caras (`@Relationship(inverse:)`). En tu modelo no hay relaciones, OK.

Si quisieras CloudKit puro (sin SwiftData), tendrías que crear `CKRecord` por
cada cambio. Más control, más código. **No es lo que toca**.

## 2. Cambio mínimo en `MySimsLifeApp` (el ModelContainer)

Hoy:

```swift
.modelContainer(for: [ActivityLog.self, Aspiration.self, LifeTask.self])
```

Pasa a:

```swift
let schema = Schema([ActivityLog.self, Aspiration.self, LifeTask.self])
let config = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .private("iCloud.com.mysims.life")
)
let container = try ModelContainer(for: schema, configurations: [config])
```

Con eso, **SwiftData ya sincroniza por iCloud automáticamente**. No hay que
tocar el código que escribe en SwiftData (insert, save, fetch).

## 3. Qué pasa con los `needs_state` (no viven en SwiftData)

Hoy las barras viven en `NeedStore.needs` en memoria + `UserDefaults`. Para
que sincronicen entre dispositivos hay dos opciones:

**A. Convertir `needs_state` en un `@Model`** (recomendado).

```swift
@Model final class NeedSnapshot {
    var needTypeRaw: String = ""
    var value: Double = 0.5
    var lastUpdated: Date = Date()
    var enabled: Bool = true
}
```

Tendrías una fila por need. SwiftData + CloudKit las sincroniza igual que las
demás. La lógica de LWW (`applyRemoteNeeds`) se reemplaza por simple
`fetch + sort`: el valor con `lastUpdated` más reciente es el bueno. CloudKit
hace el merge a nivel record y eso es todo.

**B. Usar `NSUbiquitousKeyValueStore`** (key-value sync por iCloud, sin
SwiftData). Más simple si solo te interesan estas 10 needs y no quieres
añadir un nuevo `@Model`. Tope: 1MB total, 1024 keys. Sobrado.

Coste de A: ~30 minutos de migración + recompilar. Coste de B: ~10 minutos
pero menos consistente con el resto.

## 4. Borrar la capa de backend

Lo que se puede eliminar **del cliente**:

- `MySimsLife/Store/BackendSync.swift`
- `MySimsLife/Store/RealtimeSync.swift`
- `MySimsLife/Store/BackendCredentials.swift` (gitignored)
- `MySimsLife/Store/HTTPHeader.swift`, `SyncEventType.swift` si solo los usa el sync
- En `NeedStore`: las llamadas a `BackendSync.shared.push*`, el `pullAndApply`,
  el `RealtimeSync.start/stop`, `applyRemoteNeeds`. Mantener `lastUpdated`
  pero solo como timestamp local para ordenar; CloudKit ya hace LWW.

Lo que se puede eliminar **del repo**:

- `backend/` entera (Workers, migrations, wrangler).
- `mcp-server/` — el MCP que talkea al backend. Si quieres seguir teniendo
  acceso desde Claude, ahora tendría que hablar con CloudKit Web Services
  (más enredado), o se queda sin acceso. **Decisión a tomar al migrar.**

## 5. Realtime "free"

Con SwiftData + CloudKit los cambios entre dispositivos llegan en segundos
(CloudKit usa silent push en background). No tienes que escribir nada de
`RealtimeSync`. La parte de WebSockets desaparece.

## 6. Subscriptions push (opcional, para foreground)

Si quieres que la app reciba un evento inmediato cuando otro dispositivo
escribe, registra una `CKQuerySubscription`. SwiftData lo hace automático
si tienes capability de Push Notifications + Background Modes. Probable que
no haga falta tocar nada.

## 7. Notificaciones locales (lo que metimos hoy)

`NotificationManager` no se ve afectado. Sigue siendo todo local, no usa
nada del backend. **Se queda igual.**

## 8. Aspectos a NO perder en la migración

- **Onboarding de username** (`@AppStorage("userName")`): es local. OK.
- **Calibration engine** (decay rates personalizadas): se calcula desde
  `ActivityLog`, que ahora viaja por CloudKit. OK, sigue funcionando.
- **Reset a 50% / Estable** (`resetAllToBaseline`): manipula `needs[need]`
  + `lastUpdated`. Si needs pasa a `@Model` (opción 3.A), reemplazar por
  `update each NeedSnapshot.value = 0.5`. Trivial.
- **Aspiraciones de tratamiento con schedule_raw JSON**: el campo es un
  String en SwiftData, ya viaja por CloudKit. OK.
- **Activity log soft-delete** (`deletedAt`): SwiftData no necesita soft-
  delete porque CloudKit propaga `delete()` correctamente. Se podría
  simplificar a hard-delete. Opcional.

## 9. Plan de orden recomendado

1. Verificar que pagas Apple Developer Program y bajas los certificados.
2. Añadir capability iCloud + container en proyecto.
3. Cambiar `ModelContainer` (paso 2) — recompilar y verificar que datos
   actuales aún se ven (SwiftData migra solo si schema no cambió).
4. Convertir `needs_state` → `NeedSnapshot @Model` (paso 3.A) y migrar valores
   actuales una vez al primer arranque.
5. Probar entre dos dispositivos del mismo Apple ID que los cambios cruzan
   en <30s.
6. Borrar `BackendSync`, `RealtimeSync`, `BackendCredentials` y el resto del
   stack de Workers.
7. Borrar la carpeta `backend/`.
8. Decidir qué hacer con `mcp-server/` (mantener apuntando a backend, o
   reescribir contra CloudKit Web Services, o jubilar).

## 10. Tiempo estimado total

- Setup capabilities + container: 30 min.
- Cambio de ModelContainer: 10 min.
- Migración `needs_state` a `@Model`: 1-2 h.
- Limpieza de `BackendSync`/`RealtimeSync` y código que las llama: 1-2 h.
- Pruebas en dos dispositivos: 1 h.
- **Total: medio día / un día completo** según se complique.

## 11. Punto de no retorno

Una vez activado CloudKit en el container productivo, **no se puede
renombrar ni borrar**. Si en algún momento quieres cambiar el schema (añadir
un campo a `Aspiration`), CloudKit acepta lightweight migrations
(añadir campos opcionales con defaults), pero NO acepta cambios destructivos
sin un nuevo container. Tenlo en cuenta.

---

## Bonus: si en el futuro quieres compartir con otra gente

Migrar a **CloudKit Public Database** (mismo container, otra DB) o a un
backend con auth real (Apple Sign In + JWT verification). Lo segundo es lo
que valoramos en el chat anterior. CloudKit Public DB es más limitado en
lógica pero gratis hasta cuotas amplias.
