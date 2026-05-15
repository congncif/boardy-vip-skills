<!-- Created by claude-opus-4-7 on 2026-05-09 -->

# LAYERING — Domain-Driven Layered Architecture

> **Purpose**: Define the three-layer cake every feature must follow, what belongs in each layer, and how dependencies must point. Use alongside `.claude/rules/SERVICE_LAYER.md` (concrete code) and `.claude/rules/VIP_COMPONENTS.md` (Business Application detail).
> Reference: *Modern large-scale iOS app development* — Domain-driven Layered pillar.

---

## 1. The Three Layers

```
┌────────────────────────────────────────────────────────────┐
│ Infrastructure & UI  (composition root lives here)         │
│   • UIKit ViewControllers, Storyboards, custom views       │
│   • REST clients, Codable DTOs, persistence stores         │
│   • Third-party SDK adapters (analytics, push, etc.)       │
│   • Microboard **Builder structs** (concrete) — wire       │
│     concrete Infra types into UseCases + VIP components    │
└──────────────────────────┬─────────────────────────────────┘
                           │ depends on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ Business Application (VIP + Boards)                        │
│   • Microboards: Board / Interactor / Presenter / View     │
│   • Buildable **protocol** (Board depends on this, NOT     │
│     on the concrete Builder struct)                        │
│   • UseCase protocols + UseCaseInteractor implementations  │
│   • Coordination (Flow boards, Viewless boards)            │
└──────────────────────────┬─────────────────────────────────┘
                           │ depends on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ Domain                                                     │
│   • Pure-Swift models, value objects, domain errors        │
│   • Repository protocols, domain service protocols         │
│   • No UIKit, no Boardy, no networking, no Codable         │
└────────────────────────────────────────────────────────────┘
```

**Dependency rule**: arrows point inward only. Domain never imports anything above it; Business Application imports Domain; Infrastructure & UI imports both.

---

## 2. Layer Responsibilities

### Domain Layer  *(`Sources/Services/Domain/`)*

| Folder | Contains |
|--------|----------|
| `Models/` | Value types: structs, enums, domain errors |
| `Repositories/` | Repository **protocols** (read/write contracts) |
| `Services/` | Domain service **protocols** (e.g. `*QueryService`, `*SubmitService`) |

Hard rules:
- Pure Swift only (`Foundation` for `URL`/`Date` is fine)
- No `UIKit`, `Boardy`, `Alamofire`, `Codable`, analytics SDKs
- Errors are `enum {Feature}Error: Error`
- Models are `struct`/`enum` — never classes (unless identity matters)

### Business Application Layer  *(`Sources/Microboards/` + `Sources/Services/Application/`)*

| Concern | Files |
|---------|-------|
| Per-screen flow (VIP) | `Microboards/{Board}/{Board}Board.swift` + `Interactor` + `Presenter` + `ViewController` + `Protocols` (defines `Buildable` protocol) |
| Use cases | `Services/Application/{Action}UseCase.swift` (protocol + `{Action}UseCaseInteractor` implementation) |
| Cross-board coordination | Flow / Viewless boards (see `.claude/rules/MICROBOARD_NONUI.md`) |

> **Builder split (important):** the `Buildable` **protocol** lives in this layer (declared in `{Board}Protocols.swift`) — that is what Board holds (`private let builder: {Board}Buildable`). The concrete `{Board}Builder` **struct** that imports REST services, repositories, etc. is the **composition root** and belongs to the Infrastructure & UI layer below. Board never depends on the concrete struct.

Hard rules:
- Interactor depends on UseCase protocols, never on REST/storage directly
- UseCases depend on Repository / Domain Service **protocols** — never on infrastructure types
- Presenter is the only place that maps Domain → ViewModel
- Board is stateless (no stored input/state/flags)
- Board depends on `Buildable` (protocol), not on `Builder` (concrete struct)

### Infrastructure & UI Layer  *(`Sources/Services/Infra/`, `Sources/Services/Tracking/`, plus the UI files in each Microboard)*

| Folder | Contains |
|--------|----------|
| `Infra/` | REST services, Codable DTOs, in-memory / persistent storage, SDK adapters |
| `Tracking/` | Analytics adapters and parameter types |
| Microboard UI files | `*ViewController.swift`, `Views/`, XIBs, Storyboards |
| Microboard `*Builder.swift` (concrete) | **Composition root per screen** — references concrete REST services, repositories, UseCaseInteractors; conforms to the `Buildable` protocol declared in BA layer |

Hard rules:
- DTOs (`Codable`) live here — never in Domain
- Each REST/storage type implements one or more **Domain protocols** via `extension`
- DTOs map to Domain models with a `.toDomain()` method on the DTO side
- `UIViewController` subclasses are humble: render ViewModels, forward events. No business decisions.

---

## 3. Allowed Dependencies (compile-time)

| From → To | Allowed |
|-----------|---------|
| Domain → Foundation | ✅ |
| Domain → anything else | ❌ |
| Business Application → Domain | ✅ |
| Business Application → Boardy / SiFUtilities | ✅ |
| Business Application → Infrastructure types | ❌ — depend on Domain protocols only |
| Infrastructure → Domain (protocols + models) | ✅ |
| Infrastructure → Business Application | ❌ |
| UI (ViewController) → Presenter / Interactor protocols | ✅ |
| UI → Domain models | ❌ — Presenter maps to ViewModels first |

> A grep for `import Alamofire` (or any networking framework) inside `Sources/Services/Domain/` indicates a layer violation.

---

## 4. Wiring (composition root)

The concrete `{Board}Builder` struct of each Microboard is the **composition root** for that screen — it lives at the Infrastructure & UI layer, instantiates concrete Infra types, and injects them into UseCases. Board only knows the `Buildable` protocol:

```swift
struct {Board}Builder: {Board}Buildable {
    let repository: {Entity}Repository           // shared, injected from ModulePlugin

    func build(...) -> {Board}Interface {
        let restService  = REST{Entity}Service(httpClient: HTTPClient.default)
        let useCase      = {Action}UseCaseInteractor(repository: repository,
                                                     queryService: restService)
        let presenter    = {Board}Presenter()
        let interactor   = {Board}Interactor(presenter: presenter,
                                             input: input,
                                             useCase: useCase)
        // … wire delegates and return Interface
    }
}
```

The ModulePlugin owns process-wide singletons (e.g. `sharedRepository`, `sharedTracker`) and hands them to each Builder via stored properties — never via closures captured inside `BoardRegistration`.

---

## 5. Cross-Module Layering

When a UseCase or Repository must be reused across modules:

1. The owner module exposes the capability through its **Interface Module** (`{Module}` / IO).
2. Consumers depend on the Interface Module, never on `{Module}Plugins`.
3. Cross-module activation goes through `motherboard.serviceMap.mod{Module}.io{Service}` (Pattern A in `.claude/rules/CROSS_MODULE_DI.md`).
4. Pure protocol-only sharing may use a third pod `{Module}Core` (Pattern B).

Layering and modularity reinforce each other: the Interface Module *is* the Domain protocol surface that consumers compile against.

---

## 6. Verification Checklist

- [ ] No file under `Services/Domain/` imports `UIKit`, `Boardy`, or networking frameworks
- [ ] Repository protocols return Domain models, not DTOs
- [ ] DTOs are `Codable` and live in `Services/Infra/`
- [ ] DTOs expose `func toDomain() -> {Model}` (or initializer on the model)
- [ ] UseCase protocols live in `Services/Application/`; implementations end with `UseCaseInteractor`
- [ ] Presenter is the only place constructing `{Board}ViewModel`
- [ ] Interactor protocol surface (`Presentable`) accepts domain model types only
- [ ] Concrete `{Board}Builder` struct (composition root) composes Infra → UseCase → Presenter → Interactor and wires delegates; Board references only the `Buildable` protocol
- [ ] Shared dependencies (`sharedRepository`, `sharedTracker`) are stored properties on the ModulePlugin
- [ ] Consumer modules import `{Module}` (Interface), never `{Module}Plugins` (Implementation)

---

## 7. Anti-Patterns

| Smell | Why it breaks layering | Fix |
|-------|----------------------|-----|
| `Codable` on a Domain model | Couples Domain to a serialization concern | Add a DTO in Infra; map via `.toDomain()` |
| `UIColor` in a Domain model | Domain leaks into UI framework | Keep colors in Presenter / DesignSystem |
| Interactor receives a `URLSession` | Skips UseCase + Repository abstraction | Inject a UseCase that hides the transport |
| Presenter calls `URLSession` | UI layer reaches into Infra directly | Route through Interactor + UseCase |
| ViewController constructs `ViewModel` | View has logic | Presenter builds VM; View renders only |
| Importing `{Module}Plugins` from another module | Implementation leak | Depend on `{Module}` Interface; activate via Motherboard |
| `sharedRepository` created inside `BoardRegistration` closure | New instance per build = lost state | Store on ModulePlugin as `let sharedRepository = …` |
