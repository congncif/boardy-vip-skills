<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Cross-Module Service Sharing

> Load when a service (UseCase, Repository, domain operation) must be **consumed by more than one module**.
> This replaces any pattern that passes implementations directly through `ServiceMap`, `sharedComponent`, or stored struct properties.
> Companion specs: `.claude/rules/LAYERING.md` (3-layer rule), `.claude/rules/PLUGINS_INTEGRATION.md` (plugin registration).

---

## Two Patterns

| | Pattern A — Boardy Board Interface | Pattern B — Resolver DI |
|---|---|---|
| **Preferred** | **Yes (default)** | Secondary |
| Extra module | None | `{Feature}Core` interface pod |
| Architecture fit | Fully Boardy-native | Pure DI, outside Boardy |
| Calling convention | Activate board, handle output | `@LazyInjected` local var |
| Best for | Any cross-module service | Stateless utilities, team prefers DI |

---

## 1. Core Rule

**Never inject an implementation module (e.g. `{Owner}Plugins`) as a dependency of another implementation module (e.g. `{Client}Plugins`).** Implementation modules are internal leaf nodes — they register boards, they do not expose services.

> Library-type modules (pure utilities with no business logic) are exempt from this rule.

---

## 2. Decision Tree

```
Does a service need to be consumed by more than one module?
│
├── NO  → Keep it internal. Inject as stored property on ModulePlugin.
│
└── YES → Pattern A: Boardy Board Interface (preferred)
          │
          └── Is it a pure stateless utility AND team explicitly chooses DI?
              │
              └── YES → Pattern B: Resolver DI (see section 5)
```

---

## 3. Pattern A — Boardy Board Interface (Preferred)

### How It Works

1. Owner module wraps the service in a **`BlockTaskBoard`** inside `Sources/Microboards/`
2. Owner registers the board in `ModulePlugin.internalContinuousRegistrations`
3. Owner's IO module exposes `BoardID`, `Input`, `Output`, `ServiceMap` extension — public
4. Client's **FlowBoard or FlowController** activates the service board via `motherboard.serviceMap`
5. Client's Interactor stays clean: it signals intent via `FlowAction` or `Controllable` delegate

### File Templates

#### Owner: `Sources/Microboards/{Service}/{Service}Board.swift`

```swift
import Boardy
import Foundation

final class {Service}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Service}Input
    typealias OutputType = {Service}Output
    typealias FlowActionType = {Service}Action
    typealias CommandType = {Service}Command

    private let useCase: {Service}UseCaseType   // internal protocol

    init(identifier: BoardID, useCase: {Service}UseCaseType, producer: ActivatableBoardProducer) {
        self.useCase = useCase
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        Task { [weak self] in
            guard let self else { return }
            let result = await useCase.execute(input)
            await MainActor.run { [weak self] in
                self?.sendOutput(result)
                self?.complete()
            }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

#### Owner: `Sources/Plugins/{Feature}ModulePlugin.swift` — registration

```swift
func internalContinuousRegistrations(
    sharedComponent: any SharedValueComponent,
    producer: any ActivatableBoardProducer
) -> [BoardRegistration] {
    BoardRegistration(.mod{Service}) { [self] identifier in
        {Service}Board(
            identifier: identifier,
            useCase: {Service}UseCaseInteractor(repository: sharedRepository),
            producer: producer
        )
    }
}
```

#### Owner: `IO/{Service}/{Service}IOInterface.swift` (public)

```swift
import Boardy
import Foundation

public extension BoardID {
    static let pub{Service}: BoardID = "pub.mod.{Feature}IO.{Service}"
}

public typealias {Service}MainDestination = MainboardGenericDestination<
    {Service}Input,
    {Service}Output,
    {Service}Command,
    {Service}Action
>

public extension MotherboardType where Self: FlowManageable {
    func io{Service}(_ identifier: BoardID = .pub{Service}) -> {Service}MainDestination {
        {Service}MainDestination(destinationID: identifier, mainboard: self)
    }
}
```

#### Owner: `IO/{Service}/{Service}InOut.swift` (public)

```swift
import Boardy
import Foundation

public struct {Service}Input {
    public let value: SomeType
    public init(value: SomeType) { self.value = value }
}

public enum {Service}Output {
    case success
    case failure(Error)
}

public typealias {Service}Command = Void
public enum {Service}Action: BoardFlowAction {}
```

#### Owner: `IO/{Service}/ServiceMap+{Service}.swift` (public)

```swift
import Boardy
import Foundation

public extension {Feature}ServiceMap {
    var io{Service}: {Service}MainDestination {
        mainboard.io{Service}()
    }
}
```

#### Client: FlowBoard (or FlowController delegate) — activation

**Option A — FlowBoard activates directly** (use when the FlowBoard owns the decision)

```swift
// {Client}FlowBoard.swift — registerFlows() or delegate method

extension {Client}FlowBoard: {Client}FlowDelegate {
    func perform{Service}(value: SomeType) {
        motherboard.serviceMap.mod{Feature}   // owner module's IO ServiceMap
            .io{Service}.activation
            .activate(with: {Service}Input(value: value))
    }
}

private extension {Client}FlowBoard {
    func registerFlows() {
        // Handle result from service board
        motherboard.serviceMap.mod{Feature}
            .io{Service}.flow
            .addTarget(self) { target, output in
                switch output {
                case .success:
                    target.serviceDidCompleteBus.transport()
                case .failure:
                    break   // handle or ignore
                }
            }
    }
}
```

**Option B — VIP Interactor signals via FlowAction** (use when Interactor triggers the service call)

```swift
// {Client}ResultInOut.swift — add action case
public enum {Client}ResultAction: BoardFlowAction {
    case perform{Service}(value: SomeType)
}

// {Client}ResultInteractor.swift — signal intent, no cross-module import
func userDidLoadResult(input: {Client}ResultInput) {
    delegate?.perform{Service}(value: input.value)  // via Controllable
    // OR send via FlowAction:
    // sendAction(.perform{Service}(value: input.value))
    presenter.presentResult(input: input)
}

// {Client}FlowBoard.swift — registerFlows() catches the action
motherboard.serviceMap.mod{Client}Plugins
    .io{Client}Result.flow
    .addTarget(self) { target, action in
        switch action {
        case .perform{Service}(let value):
            target.motherboard.serviceMap.mod{Feature}
                .io{Service}.activation
                .activate(with: {Service}Input(value: value))
        }
    }
```

### Dependency Graph

```
App motherboard (app entry file)
  ├── pub{Service}   ← {Owner}Plugins registered this board
  └── pub{ClientEntry}
        └── {Client}FlowBoard (internal motherboard)
              ├── mod{ClientChildA}
              └── mod{ClientChildB}

{Client}FlowBoard.registerFlows():
  catches .perform{Service}(value) FlowAction from mod{ClientChildB}
  → activates motherboard.serviceMap.mod{Owner}.io{Service}
  → result handled by mod{Owner}.io{Service}.flow handler

Dependencies:
  {Client}Plugins.podspec:
    s.dependency '{Owner}'   ← IO types only (BoardID, Input, Output)
    NO dependency on {Owner}Plugins

  {Owner}Plugins (owner):
    registers {Service}Board internally
    {Owner}LauncherPlugin installs it into the shared motherboard
```

### Checklist — Pattern A

- [ ] `BlockTaskBoard` created in `{Feature}Plugins/Sources/Microboards/{Service}/`
- [ ] Board registered in owner's `ModulePlugin.internalContinuousRegistrations`
- [ ] `{Service}IOInterface.swift`, `{Service}InOut.swift`, `ServiceMap+{Service}.swift` added to owner's IO module
- [ ] IO types are `public`; board implementation is `internal`
- [ ] Client podspec depends on `{Feature}` IO module, **not** on `{Feature}Plugins`
- [ ] Client FlowBoard/FlowController activates via `motherboard.serviceMap.mod{Feature}.io{Service}`
- [ ] Output handler registered in client's `registerFlows()` if result is needed
- [ ] Client Interactor has **zero imports** from owner module — signals intent via `FlowAction` or `Controllable` delegate only
- [ ] `pod install` run after podspec changes

---

## 4. Pattern A — Worked Example (placeholders)

```
{Owner}/IO/{Service}/
  {Service}IOInterface.swift     → pub{Service} BoardID, MotherboardType extension
  {Service}InOut.swift           → {Service}Input(value: SomeType), {Service}Output
  ServiceMap+{Service}.swift     → {Owner}ServiceMap.io{Service}

{Owner}/Sources/Microboards/{Service}/
  {Service}Board.swift           → BlockTaskBoard, calls {Service}UseCaseInteractor

{Client}/Sources/Microboards/{Client}Flow/
  {Client}FlowBoard.swift        → registerFlows() catches .perform{Service} action
                                    activates motherboard.serviceMap.mod{Owner}.io{Service}
  {Client}FlowController.swift   → didExitChild() calls delegate?.perform{Service}(value:)

{Client}/Sources/Microboards/{ClientChild}/
  {ClientChild}Action            → case perform{Service}(value: SomeType)
  {ClientChild}Interactor        → sendAction(.perform{Service}(value: input.value))
                                    (no import of {Owner} module)
```

---

## 5. Pattern B — Resolver DI (Secondary)

Use when the team explicitly chooses Resolver over Boardy for a specific service, or when the service is a pure stateless utility with no async result needed.

### Naming Convention

| Role | Pod name | Source dir | Access |
|------|----------|------------|--------|
| Protocol / interface | `{Feature}Core` | `{Module}/Core/**/*.swift` | `public` |
| Implementation | `{Feature}Plugins` | `{Module}/Sources/**/*.swift` | `internal` |

### File Templates

#### `{Feature}Core.podspec`

```ruby
Pod::Spec.new do |s|
  s.name             = '{Feature}Core'
  s.source_files     = 'Core/**/*.swift'
  s.ios.deployment_target = '16.6'
  s.swift_version    = '5.9'
  # No external dependencies — pure Swift protocols only
end
```

#### `Core/{Action}UseCase.swift`

```swift
import Foundation

public protocol {Action}UseCase {
    func execute(...) async
}
```

#### `Sources/Plugins/Resolver+{Feature}Services.swift`

```swift
import Foundation
import Resolver
import {Feature}Core

public extension Resolver {
    static func register{Feature}Services() {
        register({Action}UseCase.self) {
            {Action}UseCaseInteractor(repository: {Entity}Repository())
        }
        .scope(.application)
    }
}
```

#### `{Feature}LauncherPlugin` — registration via `launchSettings`

```swift
public struct {Feature}LauncherPlugin: LauncherPlugin {
    public init() { /**/ }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        ModuleComponent(
            modulePlugins: {Feature}ModulePlugin.ServiceType.allCases.map {
                {Feature}ModulePlugin(service: $0)
            },
            launchSettings: { _ in
                Resolver.register{Feature}Services()   // ← owner module registers its own services
            }
        )
    }
}
```

#### Client `ModulePlugin` — `@LazyInjected` as local variable

```swift
import Resolver
import {Feature}Core

struct {Client}ModulePlugin: ModuleBuilderPlugin {
    // NOTE: @LazyInjected must be a LOCAL variable inside the func.
    // Stored property causes struct mutation issues.

    func internalContinuousRegistrations(
        sharedComponent: any SharedValueComponent,
        producer: any ActivatableBoardProducer
    ) -> [BoardRegistration] {
        @LazyInjected var {action}UseCase: {Action}UseCase   // ← resolved on first board activation

        BoardRegistration(.mod{Board}) { identifier in
            {Board}Board(
                identifier: identifier,
                builder: {Board}Builder({action}UseCase: {action}UseCase),
                producer: producer
            )
        }
    }
}
```

### Execution Order Guarantee

```
PluginLauncher.initialize()
  └─ generateMainboard()
      ├─ loadPluginsIfNeeded()         (1) internalContinuousRegistrations() runs
      │                                    @LazyInjected closures CAPTURED (not resolved)
      └─ customLaunchSettings run      (2) Resolver.register{Feature}Services() runs

PluginLauncher.launch()
  └─ board activated                (3) BoardRegistration closure executes
                                         @LazyInjected resolves → gets implementation
```

Resolution at step (3) is guaranteed to happen after registration at step (2). This is why `@LazyInjected` (not `@Injected`) is required — it defers resolution to first access.

### Dependency Graph

```
App entry file
  imports: {Feature}Plugins           (for LauncherPlugin)
  no Resolver calls — module handles its own registration

{Client}Plugins
  s.dependency '{Feature}Core'        ← protocol only
  s.dependency 'Resolver'
  uses: @LazyInjected var x: {Action}UseCase

{Feature}Plugins
  s.dependency '{Feature}Core'
  s.dependency 'Resolver'
  provides: Resolver+{Feature}Services.swift
  calls:    Resolver.register{Feature}Services() in launchSettings

{Feature}Core
  no external deps — pure protocols
```

### Scope Guidelines

| Scope | Use when |
|-------|----------|
| `.application` | Stateless use cases, persistent repositories (default) |
| `.unique` | New instance needed on every resolution |
| `.cached` | Shared within a logical named scope |

### Checklist — Pattern B

- [ ] Protocol lives in `{Feature}Core/Core/` and is `public`
- [ ] `{Feature}Core.podspec` created with `source_files = 'Core/**/*.swift'`, no deps
- [ ] `{Feature}Core` added to Podfile with `:path =>`
- [ ] `{Feature}Plugins.podspec` adds `s.dependency '{Feature}Core'` and `s.dependency 'Resolver'`
- [ ] `Resolver+{Feature}Services.swift` in `{Feature}Plugins/Sources/Plugins/`
- [ ] `{Feature}LauncherPlugin` calls `Resolver.register{Feature}Services()` in `launchSettings: { _ in ... }`
- [ ] Client podspecs depend on `{Feature}Core` + `Resolver`, **not** on `{Feature}Plugins`
- [ ] `@LazyInjected var x: Protocol` declared as **local variable** inside `internalContinuousRegistrations`
- [ ] `pod install` run after all podspec changes
