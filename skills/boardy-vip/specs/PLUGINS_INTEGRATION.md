<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Plugins & Global Integration

> **Load this spec** when implementing ModuleBuilderPlugin, URLOpenerPlugin, LauncherPlugin, or registering a module.
> Reference: *Modern large-scale iOS app development* — Plugin Architecture pillar.
> Companion specs: `.claude/rules/ARCHITECTURE.md` §4 (runtime composition), `.claude/rules/EXAMPLES_PLUGIN.md` (concrete skeleton).

---

## Plugin Architecture Overview

```
App Core (ServiceRegistry)
    │
    └── registers ──► {Module}LauncherPlugin  (public)
                            │
                    ┌───────┴───────┐
                    ▼               ▼
        {Module}ModulePlugin    {Module}URLOpenerPlugin
            │    (one per service/entry point)
            │
        ServiceType enum
        (CaseIterable — one case per public board)
```

---

## 1. ModuleBuilderPlugin — ServiceType Pattern

The real codebase uses a `ServiceType` enum inside `ModuleBuilderPlugin` — one case per public entry board.

**File:** `Sources/Plugins/{ModuleName}ModulePlugin.swift`

```swift
import Boardy
import Foundation
import {ModuleName}IO

struct {ModuleName}ModulePlugin: ModuleBuilderPlugin {

    // MARK: - One case per public entry board
    enum ServiceType: CaseIterable {
        case `default`           // maps to the primary public board
        // case secondaryBoard   // add more if module has multiple entry points

        var identifier: BoardID {
            switch self {
            case .default: .pub{PublicBoardName}
            }
        }
    }

    // MARK: - Shared dependencies (created once, injected into all boards)
    let sharedRepository = {SomeRepository}()
    let sharedTracker = {TrackerService}()

    // MARK: - Required: current service context
    let service: {ModuleName}ModulePlugin.ServiceType

    var identifier: BoardID {
        service.identifier
    }

    // MARK: - Build the entry board for this service
    func build(
        with identifier: BoardID,
        sharedComponent: any SharedValueComponent,
        internalContinuousProducer: any ActivatableBoardProducer
    ) -> any ActivatableBoard {
        switch service {
        case .default:
            // The entry board is the coordinator (delegates internally)
            {EntryCoordinator}Board(identifier: identifier, producer: internalContinuousProducer)
        }
    }

    // MARK: - Register all internal child boards
    func internalContinuousRegistrations(
        sharedComponent: any SharedValueComponent,
        producer: any ActivatableBoardProducer
    ) -> [BoardRegistration] {
        // Use result builder syntax (no 'return' keyword, no array literal)
        BoardRegistration(.mod{InternalBoardA}) { identifier in
            {InternalBoardA}Board(
                identifier: identifier,
                builder: {InternalBoardA}Builder(
                    repository: sharedRepository,
                    tracker: sharedTracker
                ),
                producer: producer
            )
        }

        BoardRegistration(.mod{InternalBoardB}) { identifier in
            {InternalBoardB}Board(
                identifier: identifier,
                builder: {InternalBoardB}Builder(tracker: sharedTracker),
                producer: producer
            )
        }

        BoardRegistration(.mod{InternalBoardC}) { identifier in
            {InternalBoardC}Board(
                identifier: identifier,
                builder: {InternalBoardC}Builder(
                    repository: sharedRepository,
                    tracker: sharedTracker
                ),
                producer: producer
            )
        }
    }
}
```

### Result Builder Syntax in `internalContinuousRegistrations`

```swift
// ✅ Correct — result builder, no return, no array brackets
func internalContinuousRegistrations(...) -> [BoardRegistration] {
    BoardRegistration(.modBoardA) { id in BoardA(identifier: id, ...) }
    BoardRegistration(.modBoardB) { id in BoardB(identifier: id, ...) }
}

// ❌ Wrong — explicit return and array literal NOT needed
func internalContinuousRegistrations(...) -> [BoardRegistration] {
    return [
        BoardRegistration(...),
        BoardRegistration(...)
    ]
}
```

### Shared dependencies pattern

```swift
// ✅ Shared repo/tracker created as stored properties on the plugin struct
// This ensures same instance is used across all board registrations
struct {ModuleName}ModulePlugin: ModuleBuilderPlugin {
    let sharedRepository = SomeMemoryStorageRepository()
    let sharedTracker = {TrackerService}()
    // ...
}
```

---

## 2. URLOpenerPlugin — Deep Link Handler

```swift
struct {ModuleName}URLOpenerPlugin: URLOpenerPathMatchingPlugin {
    var matchingPath: String {
        "/{module-path}"   // e.g. "/onboarding"
    }

    func mainboard(_ mainboard: any FlowMotherboard, openURLWithParameters parameters: [String: String]) {
        // Build input from URL parameters
        let input = {PublicBoardName}Input(completion: nil)

        // Activate via the Plugins ServiceMap (internal side)
        mainboard.serviceMap.mod{ModuleName}Plugins
            .io{EntryCoordinator}.activation.activate(with: input)
    }
}
```

**Important:** URLOpener activates via `mod{ModuleName}Plugins` (the **Plugins** ServiceMap), not via `mod{ModuleName}`. This is because the deep link handler is inside `Sources/` (internal context).

---

## 3. LauncherPlugin — Public Export

```swift
public struct {ModuleName}LauncherPlugin: LauncherPlugin {
    public init() { /**/ }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        ModuleComponent(
            // Map all ServiceType cases to plugin instances
            modulePlugins: {ModuleName}ModulePlugin.ServiceType.allCases.map {
                {ModuleName}ModulePlugin(service: $0)
            },
            urlOpenerPlugins: [
                {ModuleName}URLOpenerPlugin()
            ]
        )
    }
}
```

**Key pattern:** `ServiceType.allCases.map { {ModuleName}ModulePlugin(service: $0) }` — each service type becomes its own plugin instance, each registering as a separate entry board.

---

## 4. Board Registration in ModulePlugin — Common Patterns

```swift
// Pattern A: Coordinator/Flow board (no builder, just producer)
BoardRegistration(.modCoordinator) { identifier in
    CoordinatorBoard(identifier: identifier, producer: producer)
}

// Pattern B: UI board (with builder, repository, tracker)
BoardRegistration(.modSomeScreen) { identifier in
    SomeScreenBoard(
        identifier: identifier,
        builder: SomeScreenBuilder(
            someRepository: sharedRepository,
            tracker: sharedTracker
        ),
        producer: producer
    )
}

// Pattern C: Entry board in build() — same as Pattern B but is the public entry
func build(with identifier: BoardID, ...) -> any ActivatableBoard {
    EntryBoard(identifier: identifier, producer: internalContinuousProducer)
}
```

---

## 5. Internal BoardID Declarations

Internal BoardIDs are declared inside `Sources/Microboards/{BoardName}/{BoardName}IOInterface.swift`:

```swift
// Sources/Microboards/SomeBoard/SomeBoardIOInterface.swift
extension BoardID {
    static let modSomeBoard: BoardID = "mod.{ModuleName}.SomeBoard"
}
```

They are **never** in `IO/` and **never** `public`.

---

## 6. Access Modifier Rules

| Element | Access | Reason |
|---------|--------|--------|
| `{Module}LauncherPlugin` struct | `public` | Called from App Core |
| `LauncherPlugin.init()` | `public` | Instantiated externally |
| `{Module}ModulePlugin` struct | `internal` | Only used by LauncherPlugin |
| `ServiceType` enum | `internal` | Inside ModulePlugin |
| `{Module}URLOpenerPlugin` struct | `internal` | Only used by LauncherPlugin |
| `sharedRepository`, `sharedTracker` | `internal` | Plugin-level shared deps |

---

## 7. Global ServiceRegistry Registration (App Core)

```swift
// App/ServiceRegistry+Modules.swift
extension ServiceRegistry {
    static func registerAllModules() -> ServiceRegistry {
        ServiceRegistry {
            {ModuleName}LauncherPlugin()
            OtherModuleLauncherPlugin()
        }
    }
}
```

---

## Checklist for Plugin Integration
- [ ] `ServiceType: CaseIterable` enum with one case per public board
- [ ] `ServiceType.identifier` maps to `BoardID` (public ID from IO)
- [ ] `sharedRepository` / `sharedTracker` declared as stored properties (not locals)
- [ ] `internalContinuousRegistrations` uses result builder syntax (no return, no `[]`)
- [ ] `build()` returns the coordinator/entry board for the active `service`
- [ ] `URLOpenerPlugin` activates via Plugins ServiceMap (not IO ServiceMap)
- [ ] `LauncherPlugin` is `public` with `public init() { /**/ }`
- [ ] `prepareForLaunching` maps `ServiceType.allCases` to plugin instances
