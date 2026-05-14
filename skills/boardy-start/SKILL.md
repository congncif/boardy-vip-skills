---
name: boardy-start
description: Use when starting any iOS development task on a Boardy+VIP project — routes to correct spec, provides naming conventions, board communication patterns, and the 10 non-negotiable architecture rules
---

# Boardy+VIP Quick Reference

## Task → Spec Routing

| Task | Spec |
|------|------|
| Architecture overview | `ARCHITECTURE.md` |
| SDK / dependency choice | `SDK_FIRST.md` |
| New module scaffold | `MODULE_CREATION.md` |
| IO / BoardID / InOut / ServiceMap | `IO_INTERFACE.md` |
| UI Board (VIP) | `MICROBOARD_UI.md` + `VIP_COMPONENTS.md` |
| Non-UI Board | `MICROBOARD_NONUI.md` (Decision Tree first) |
| Board communication / Bus / flows | `COMMUNICATION.md` |
| Context navigation (back/return/alerts) | `CONTEXT_NAVIGATION.md` |
| Plugin / LauncherPlugin | `PLUGINS_INTEGRATION.md` |
| ComposableBoard / TabBar | `COMPOSABLE_BOARD.md` |
| Per-activation services / concurrency guard | `PER_ACTIVATION_RESOURCES.md` |
| Multiple providers (OCP) | `EXTENSIBLE_PROVIDER.md` |
| Service / UseCase / Repository | `SERVICE_LAYER.md` |
| Cross-module service sharing | `CROSS_MODULE_DI.md` |
| Code review | `REVIEWER_CHECKLIST.md` |
| Code examples / skeletons | `EXAMPLES.md` → matching `EXAMPLES_*.md` |

## Non-UI Board Decision Tree

```
0. VIP UI board already serves as entry point?
   YES → Use that VIP board as coordinator via registerFlows(). No FlowBoard needed.

1. Single async task, caller needs per-activation result?
   → BlockTask Board

2. Coordinator that remembers child output between steps?
   → Viewless Board

3. Pure routing, no state, OR reused from multiple entry points?
   → Flow Board (finishBus is only stored property allowed)
```

## Naming Conventions

### Module Level

| Concept | No Prefix | With Prefix `DAD` |
|---------|-----------|-------------------|
| IO ServiceMap class | `ProfileServiceMap` | `DADProfileServiceMap` |
| IO ServiceMap var | `modProfile` | `modDADProfile` |
| Plugins ServiceMap class | `ProfilePluginsServiceMap` | `DADProfilePluginsServiceMap` |
| Plugins ServiceMap var | `modProfilePlugins` | `modDADProfilePlugins` |

### BoardID Patterns

```swift
// Public (IO/)
"pub.mod.{ModuleName}IO.{BoardName}"

// Internal (Sources/)
"mod.{ModuleName}.{BoardName}"
```

### VIP Classes

`{Name}Board` · `{Name}Builder` · `{Name}Interactor` · `{Name}Presenter` · `{Name}ViewController`

### Protocol Location

| Protocol | Lives in |
|----------|---------|
| `{Name}Interactable` | ViewController file |
| `{Name}Presentable` | Interactor file |
| `{Name}Viewable` | Presenter file |
| `{Name}Controllable`, `ActionDelegate`, `ControlDelegate`, `Delegate`, `UserInterface`, `Buildable` | Protocols.swift |

## 10 Non-Negotiable Rules

1. **View has ZERO logic** — renders ViewModels, forwards events only
2. **Unidirectional flow** — ViewController → Interactor → UseCase → Presenter → ViewController
3. **IO = public, Sources = internal** — no exceptions
4. **Never import `{Module}Plugins`** from another module; import IO only
5. **Async UI** — `await MainActor.run { [weak self] in ... }`
6. **Weak references** — `weak var view` in Presenter; `weak var delegate` in Interactor
7. **`registerFlows()` in `init`** — never in `activate()`
8. **Board→Controller via event buses** — never store/retrieve controller reference
9. **Domain is pure Swift** — no UIKit, no Boardy, no networking frameworks
10. **`sharedRepository` on ModulePlugin** — never inside closures or BoardRegistration

## Key Code Patterns

### Board Communication

```swift
// Child → direct parent
sendOutput(.result)

// Child → upstream ancestors
broadcastAction(.globalEvent)

// Push into active child / sibling
motherboard.serviceMap.modXPlugins.ioY.interaction.send(command: .refresh)

// Board → Controller (always via bus)
private let dataBus = Bus<SomeType>()
// in activate(): dataBus.connect(target: controller) { c, v in c.handleData(v) }
// in registerFlows(): dataBus.transport(input: output)
```

### Async/Await

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

### registerFlows Always in init

```swift
init(identifier: BoardID, builder: Buildable, producer: ActivatableBoardProducer) {
    self.builder = builder
    super.init(identifier: identifier, boardProducer: producer)
    registerFlows() // LAST line
}
```

## Module Folder Skeleton

```
{ModuleRoot}/{ModuleName}/
├── {ModuleName}.podspec             ← IO: source_files = 'IO/**/*.swift'
├── {ModuleNamePlugins}.podspec      ← Plugins: source_files = 'Sources/**/*.swift'
├── IO/
│   ├── {ModuleName}ServiceMap.swift
│   └── {BoardName}/
│       ├── {BoardName}IOInterface.swift
│       ├── {BoardName}InOut.swift
│       └── ServiceMap+{BoardName}.swift
└── Sources/
    ├── Plugins/
    │   ├── {ModuleName}PluginsServiceMap.swift
    │   └── {Name}ModulePlugin.swift
    ├── Microboards/{BoardName}/     ← VIP files here
    └── Services/
        ├── Domain/
        ├── Application/
        └── Infra/
```
