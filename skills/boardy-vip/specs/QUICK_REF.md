<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# QUICK_REF — Boardy+VIP Master Reference

> Read this file **first** for every task using the Read tool. Then use the Read tool to load exactly the one task-specific spec from the routing table below. Do not pre-load other specs speculatively.

---

## 1. Task → Spec Routing

| Task | Load next |
|------|-----------|
| Architecture overview / runtime composition | `ARCHITECTURE.md` |
| SDK-first / dependency choice | `SDK_FIRST.md` |
| 3-layer dependency rule / cross-layer boundary | `LAYERING.md` |
| Project-specific values (scheme, simulator, paths) | `{ProjectConfigPath}` |
| New module | `MODULE_CREATION.md` |
| IO / BoardID / InOut / ServiceMap | `IO_INTERFACE.md` |
| Microboard with UI (VIP) | `MICROBOARD_UI.md` + `VIP_COMPONENTS.md` |
| Microboard without UI | `MICROBOARD_NONUI.md` (read Decision Tree first!) |
| Cross-module service sharing | `CROSS_MODULE_DI.md` |
| Service / UseCase / Repository / Infra | `SERVICE_LAYER.md` |
| Board communication / Bus / flows | `COMMUNICATION.md` |
| Context navigation / backToPrevious / returnHere / alerts | `CONTEXT_NAVIGATION.md` |
| Plugin / LauncherPlugin | `PLUGINS_INTEGRATION.md` |
| ComposableBoard / TabBar | `COMPOSABLE_BOARD.md` |
| Per-activation services / concurrency guard / routing config in Controller | `PER_ACTIVATION_RESOURCES.md` |
| Multiple interchangeable providers / OCP extensible backend selection | `EXTENSIBLE_PROVIDER.md` |
| Gate board activation behind another board (ad before session, permission check, login wall) | `ACTIVATION_BARRIER.md` |
| Testing | `TESTING.md` |
| Code review | `REVIEWER_CHECKLIST.md` only |
| Code example | `EXAMPLES.md` (index) → load matching `EXAMPLES_*.md` |

> **Non-UI Board type — decide before writing any code:**
> 0. Does a VIP UI board already serve as the entry point to this flow? → **Let that VIP board be the coordinator** via `registerFlows()`. Do NOT wrap it with a Non-UI FlowBoard. A VIP board with UI can own and coordinate its child boards — the entry-screen board acts as coordinator itself. Proceed to 1–3 only when no UI board can serve as anchor.
> 1. Single async task then done? → **BlockTask Board**
> 2. Coordinator that must remember a child board's output for a later step? → **Viewless Board**
> 3. Pure pass-through routing with NO UI anchor, OR reused from multiple entry points, OR conditional gate logic? → **Flow Board** (`finishBus` is the only stored property allowed)

---

## 2. Naming — Module Level

| Concept | No Prefix | With Prefix `DAD` |
|---------|-----------|-------------------|
| Module name | `Profile` | `DADProfile` |
| IO podspec | `Profile` | `DADProfile` |
| Plugins podspec | `ProfilePlugins` | `DADProfilePlugins` |
| No-prefix name (VIP classes) | `Profile` | `Profile` |
| IO ServiceMap class | `ProfileServiceMap` | `DADProfileServiceMap` |
| IO ServiceMap var | `modProfile` | `modDADProfile` |
| Plugins ServiceMap class | `ProfilePluginsServiceMap` | `DADProfilePluginsServiceMap` |
| Plugins ServiceMap var | `modProfilePlugins` | `modDADProfilePlugins` |

---

## 3. Naming — BoardID

| Type | Pattern | Example |
|------|---------|------|
| Public (IO/) | `pub.mod.{ModuleName}IO.{BoardName}` | `pub.mod.ProfileIO.ProfileDetail` |
| Internal (Sources/) | `mod.{ModuleName}.{BoardName}` | `mod.Profile.ProfileDetail` |
| Internal aliases public | `static let modXxx: BoardID = .pubXxx` | direct alias |

Swift declaration:
- Public: `public extension BoardID { static let pub{Name}: BoardID = "..." }`
- Internal: `extension BoardID { static let mod{Name}: BoardID = "..." }`

---

## 4. Naming — VIP Classes

| Component | Pattern | Example |
|-----------|---------|--|
| Board | `{Name}Board` | `ProfileDetailBoard` |
| Builder | `{Name}Builder` | `ProfileDetailBuilder` |
| Interactor | `{Name}Interactor` | `ProfileDetailInteractor` |
| Presenter | `{Name}Presenter` | `ProfileDetailPresenter` |
| ViewController | `{Name}ViewController` | `ProfileDetailViewController` |
| UseCase protocol | `{Action}UseCase` | `LoadProfileUseCase` |
| UseCase impl | `{Action}UseCaseInteractor` | `LoadProfileUseCaseInteractor` |

---

## 5. Protocol Location Rules

| Protocol | Lives in | Conformed by |
|----------|---------|-------------|
| `{Name}Interactable` | `{Name}ViewController.swift` | Interactor |
| `{Name}Presentable` | `{Name}Interactor.swift` | Presenter |
| `{Name}Viewable` | `{Name}Presenter.swift` | ViewController |
| `{Name}Controllable` | `{Name}Protocols.swift` | Interactor (UI) or Controller (Viewless) |
| `{Name}ActionDelegate` | `{Name}Protocols.swift` | Board |
| `{Name}ControlDelegate` | `{Name}Protocols.swift` | Board |
| `{Name}Delegate` | `{Name}Protocols.swift` | Board |
| `{Name}UserInterface` | `{Name}Protocols.swift` | ViewController |
| `{Name}Buildable` | `{Name}Protocols.swift` | Builder struct |

---

## 6. Key Code Patterns

### Weak references — always
```swift
weak var delegate: {Name}ControlDelegate!   // Interactor → Board
weak var actionDelegate: {Name}ActionDelegate!  // ViewController → Board
weak var view: {Name}Viewable!              // Presenter → ViewController
// Interactor MUST NOT declare actionDelegate
```

### Async/await — mandatory pattern
```swift
Task { [weak self] in
    guard let self else { return }
    do {
        let result = try await useCase.execute()
        await MainActor.run { [weak self] in
            guard let self else { return }
            presenter.presentResult(result)
        }
    } catch {
        await MainActor.run { [weak self] in
            guard let self else { return }
            presenter.presentError(error)
        }
    }
}
```

### registerFlows — always in init, never activate
```swift
init(identifier: BoardID, ...) {
    // ...
    super.init(identifier: identifier, boardProducer: producer)
    registerFlows()  // LAST line of init
}
```

### Board communication — Output / Action / Command

```
Who do you want to communicate with?
├── Direct parent Motherboard (the one that activated this board)?
│   → sendOutput()
├── One or more upstream ancestors?
│   → broadcastAction()   (listeners opt in; not a broadcast to all)
├── An already-activated child board?
│   → Command: motherboard.serviceMap.io{Board}.interaction.send(command:)
└── A sibling board within the same Motherboard?
    → Command: motherboard.serviceMap.io{Sibling}.interaction.send(command:)
```

### Board → Controller communication — event bus only
```swift
// ✅ Board sends lifecycle/flow events inward through buses connected per activation.
childOutputBus.connect(target: component.controller) { controller, output in
    controller.didReceiveChildOutput(output)
}

// ✅ Flow registrations transport into buses, never call controller directly.
childOutputBus.transport(input: output)

// ❌ Forbidden: storing controller/ViewController references on Board or manually retrieving controllers to communicate.
```

### Double-activation guard — board-type matrix
| Board type | Guard? | Pattern |
|------------|--------|---------|
| UI VIP board | Optional | Use only when the UI board must be explicitly single-session |
| Composable parent | ❌ Usually no | Permanent container entry point; activates child boards synchronously |
| Composable child | ❌ Usually no | Registers `UIElement` into composer; parent owns lifetime |
| Viewless board | ❌ No | Each activation creates a new controller session; use buses |
| Flow board | Context-dependent | No stored state; guard only when explicitly single-session |
| BlockTask / Task board | ❌ No manual guard | Framework handles task execution semantics |
```swift
func activate(withGuaranteedInput input: InputType) {
    // Add duplicate-activation guard only when this Board is designed as single-session.
}
```

### Access modifiers
```swift
// IO/  → everything public
public final class ProfileServiceMap: ServiceMap {}
public extension BoardID { static let pubProfile: BoardID = "..." }
public struct ProfileInput { ... }

// Sources/  → everything internal (default, no keyword)
final class ProfilePluginsServiceMap: ServiceMap {}
final class ProfileDetailBoard: ModernContinuableBoard, ... {}

// LauncherPlugin — explicitly public
public struct ProfileLauncherPlugin: LauncherPlugin {
    public init() { /**/ }
}
```

---

## 7. The 10 Rules (never break)

1. View has ZERO logic — renders ViewModels, forwards events only
2. Unidirectional flow: `ViewController → Interactor → UseCase → Presenter → ViewController`
   - Exception for direct UI navigation intents: `ViewController → ActionDelegate(Board)` when Interactor would only forward without business logic
3. IO modules are `public`; Sources are `internal`
4. Never import `{ModuleNamePlugins}` from another module — only import IO
5. Async UI updates always in `await MainActor.run { [weak self] in ... }`
6. `weak var view` in Presenter; `weak var delegate` in Interactor
7. `registerFlows()` called in Board's `init`, never in `activate()`
8. Double-activation guard only when the Board is explicitly single-session; all Board→Controller communication uses event buses, not retrieved controller references
9. Domain layer is pure Swift — no UIKit, no Boardy, no network frameworks
10. `sharedRepository` as stored property on ModulePlugin — never created inside closures
11. Classify string literals by meaning before localization decisions: user-facing text content must come from Localizable strings (SwiftGen/module strings); non-linguistic constants such as URLs, identifiers, keys, file names, analytics event names, and config values do not belong in Localizable unless product explicitly needs locale-specific variants
12. `complete()` called at most once, only when Board has released all streams/observers; stateless boards rarely need it; `BlockTaskBoard` never needs it (auto-completes); double-`complete()` raises assertion
13. Viewless boards using `attachObject(controller)` manage their own lifecycle — release via `complete()` (ends session) or `detachObject(_:)` (releases specific controller, Board stays alive); without explicit release, re-activation stacks controllers on buses → duplicate handler execution per event
14. `BlockTaskBoard` with `executingType: .concurrent` — use parameter callbacks (`onSuccess`, `onError`) for per-activation result routing; `.flow.addTarget` is unreliable because `.flow` is shared across all concurrent activations; for sequential (single-at-a-time) BlockTaskBoard, `.flow` is acceptable but parameter callbacks are preferred

---

## 8. Module Folder Skeleton

```
{ModuleRoot}/{ModuleName}/
├── {ModuleName}.podspec             ← IO target: source_files = 'IO/**/*.swift'
├── {ModuleNamePlugins}.podspec      ← Plugins target: source_files = 'Sources/**/*.swift'
├── IO/
│   ├── {ModuleName}ServiceMap.swift
│   └── {BoardName}/
│       ├── {BoardName}IOInterface.swift
│       ├── {BoardName}InOut.swift
│       └── ServiceMap+{BoardName}.swift
└── Sources/
    ├── Plugins/
    │   ├── {ModuleName}PluginsServiceMap.swift
    │   └── {NoPrefixName}ModulePlugin.swift
    ├── Microboards/{BoardName}/
    │   ├── {BoardName}Protocols.swift
    │   ├── {BoardName}Board.swift
    │   ├── {BoardName}Builder.swift
    │   ├── {BoardName}Interactor.swift  ← also defines Presentable
    │   ├── {BoardName}Presenter.swift   ← also defines Viewable + ViewModels
    │   ├── {BoardName}ViewController.swift ← also defines Interactable
    │   └── ServiceMap+{BoardName}.swift
    └── Services/
        ├── Domain/{Models, Repositories, Services}
        ├── Application/{Action}UseCase.swift
        └── Infra/
```

### Podfile entry (always hash-rocket syntax)
```ruby
pod '{ModuleName}',        :path => '{ModuleRoot}/{ModuleName}'
pod '{ModuleNamePlugins}', :path => '{ModuleRoot}/{ModuleName}'
```

### s.dependency — name only, never :path
```ruby
s.dependency 'Boardy'          # correct
# s.dependency 'Boardy', :path => '.'  # WRONG — breaks lint
```

---

## 9. Example Dictionary

Load `EXAMPLES.md` (index, ~20 lines) to find which example file to load.
Each example file is a self-contained work unit -- load exactly one.

| Work Unit | Example File |
|-----------|--------------|
| IO layer | `EXAMPLES_IO.md` |
| Plugin layer | `EXAMPLES_PLUGIN.md` |
| Full VIP UI Board (6 files) | `EXAMPLES_VIP_BOARD.md` |
| Viewless Board (4 files) | `EXAMPLES_VIEWLESS_BOARD.md` |
| Flow Board / BlockTask Board | `EXAMPLES_NONUI_BOARDS.md` |
| Service layer | `EXAMPLES_SERVICE.md` |
