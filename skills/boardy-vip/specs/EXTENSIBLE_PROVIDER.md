<!-- Created by combo-huy-diet on 2026-05-14 -->
# SPEC: Extensible Provider Architecture (OCP Pattern)

> **Load this spec** when a module needs to support multiple interchangeable external providers or frameworks (ad SDKs, payment gateways, analytics backends, map SDKs, auth frameworks, etc.) such that adding a new provider requires only new files — no edits to existing code.
> Reference: Open/Closed Principle applied to Boardy+VIP plugin composition.
> Companion specs: `PER_ACTIVATION_RESOURCES.md` (per-activation lifecycle), `PLUGINS_INTEGRATION.md` (plugin wiring).

---

## Problem

When a module integrates multiple concrete external providers or frameworks (AdMob, Unity Ads, Stripe, Firebase, Mapbox, Braintree...), the naive approach stores provider selection as an enum:

```swift
// ❌ WRONG — every new provider requires editing this enum and every switch
public enum ProviderConfiguration {
    case providerA(id: String)
    case providerB(gameID: String, placementID: String)
}
```

Every `switch providerConfiguration { }` across the codebase must be updated when a new provider is added. This violates OCP and makes providers tightly coupled to coordination logic.

---

## Solution: Two-Layer Protocol Pattern

Split the configuration type into two layers:

| Layer | Access | Purpose |
|-------|--------|---------|
| Public marker protocol | `public` | App client passes it in; lives in **IO or Sources/Plugins** (NOT as enum) |
| Internal factory protocol | `internal` | Provides board factory methods; lives in **Sources/Plugins** |

```
App Client (LauncherPlugin.init)
  passes → public ProviderConfiguration (marker protocol)
              │
              ▼
  AdvertisingModulePlugin casts → InternalProviderConfiguration
              │
              ▼
  factory.makeProviderBoard(identifier:hostProvider:producer:)
              │
              ▼
  ConcreteProviderBoard (baked with IDs from init)
```

### Layer 1 — Public Marker Protocol (Sources/Plugins/)

```swift
// Sources/Plugins/ProviderConfiguration.swift
public protocol {Feature}ProviderConfiguration {}
```

This is the **only type the app client imports**. It carries no behavior — it is a type-safe token the client passes in, and the internal layer resolves to the factory.

### Layer 2 — Internal Factory Protocol (Sources/Plugins/)

```swift
// Sources/Plugins/ProviderConfiguration.swift (same file)
protocol Internal{Feature}ProviderConfiguration: {Feature}ProviderConfiguration {
    /// Called once at app launch (via launchSettings) to initialize the SDK.
    func setup()

    func make{TypeA}Board(
        identifier: BoardID,
        hostProvider: {Feature}HostProvider,
        producer: ActivatableBoardProducer
    ) -> any ActivatableBoard

    func make{TypeB}Board(
        identifier: BoardID,
        hostProvider: {Feature}HostProvider,
        producer: ActivatableBoardProducer
    ) -> any ActivatableBoard
}
```

**Rules:**
- The public marker protocol lives in `Sources/Plugins/` (not IO/) because it is never depended on cross-module — it is only passed in by the app client at plugin installation time
- The internal factory protocol is `internal` and only used by `ModulePlugin`
- `setup()` is SDK-specific — each concrete config implements it to initialize its SDK once at launch
- Factory methods produce concrete boards with IDs already baked in

---

## Concrete Provider Configuration

Each provider is a `struct` that conforms to `Internal{Feature}ProviderConfiguration`:

```swift
// Sources/Plugins/{ProviderName}ProviderConfiguration.swift
import {ProviderSDK}   // ← SDK-specific import lives here, isolated from the rest of the module

public struct {ProviderName}ProviderConfiguration: Internal{Feature}ProviderConfiguration {
    public let adUnitID: String          // provider-specific ID fields
    public let rewardUnitID: String

    public init(adUnitID: String, rewardUnitID: String) {
        self.adUnitID = adUnitID
        self.rewardUnitID = rewardUnitID
    }

    func setup() {
        // SDK-specific one-time initialization
        {ProviderSDK}.initialize(...)
    }

    func make{TypeA}Board(identifier: BoardID, hostProvider: {Feature}HostProvider, producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderName}{TypeA}Board(
            identifier: identifier,
            unitID: adUnitID,        // ID baked in at creation time
            hostProvider: hostProvider,
            producer: producer
        )
    }

    func make{TypeB}Board(identifier: BoardID, hostProvider: {Feature}HostProvider, producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderName}{TypeB}Board(
            identifier: identifier,
            unitID: rewardUnitID,
            hostProvider: hostProvider,
            producer: producer
        )
    }
}
```

**Rules:**
- Concrete configs are `public struct` (app client instantiates them)
- They conform to the **internal** factory protocol (`Internal{Feature}ProviderConfiguration`)
- Swift sees this as valid: a `public struct` can conform to an `internal` protocol; the conformance is internal-only
- All provider-specific IDs are stored in the `struct`'s `let` properties
- Factory methods use those stored IDs to init the board — the board receives IDs at `init`, not at `activate()`

---

## Provider Boards: IDs Baked In

Provider boards have no runtime input — all required IDs are `init` parameters. The effective input is `Void`, but **always expressed through a named type alias from `{Type}ProviderInOut.swift`**, never as `Void` directly on the board.

**Why?** `typealias InputType` on the Board must align with the `MainboardGenericDestination` type parameter in the IOInterface. If the Board sets `InputType = Void` directly but the IOInterface uses `InterstitialAdProviderInput` (which is `typealias … = Void`), the type contract breaks silently. Always reference the named alias.

```swift
// {Type}ProviderInOut.swift  ← define the alias HERE, not on the Board
typealias {Type}ProviderInput = Void    // effective Void, but named for contract alignment
typealias {Type}ProviderOutput = Provider{Type}Result
typealias {Type}ProviderCommand = Void
enum {Type}ProviderAction: BoardFlowAction {}
```

```swift
// Sources/Microboards/{Provider}{Type}Provider/{Provider}{Type}ProviderBoard.swift
final class {Provider}{Type}ProviderBoard: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Type}ProviderInput    // ← reference InOut alias, NEVER Void directly
    typealias OutputType = {Type}ProviderOutput
    typealias FlowActionType = {Type}ProviderAction
    typealias CommandType = {Type}ProviderCommand

    private let unitID: String           // ← baked in at init, never changes
    private let hostProvider: {Feature}HostProvider

    init(
        identifier: BoardID,
        unitID: String,
        hostProvider: {Feature}HostProvider,
        producer: ActivatableBoardProducer
    ) {
        self.unitID = unitID
        self.hostProvider = hostProvider
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: {Type}ProviderInput) {
        let service = {Provider}{Type}Service(hostProvider: hostProvider)
        attachObject(service)
        service.run(unitID: unitID) { [weak self] result in
            self?.sendOutput(result)
            self?.complete()
        }
    }

    func activationBarrier(withGuaranteedInput _: {Type}ProviderInput) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: {Type}ProviderCommand) {}
}
```

**Why no runtime input?** The board already knows everything it needs from `init`. Callers just say `.activate()`. The named-alias chain (`InputType → {Type}ProviderInput → Void`) keeps the IOInterface contract intact without leaking `Void` into the Board definition.

---

## Unified Board IDs

Instead of one `BoardID` per provider-type combination, use one `BoardID` per **ad type** (or service type):

```swift
// ✅ CORRECT — unified IDs, provider is an implementation detail
extension BoardID {
    static let mod{TypeA}Provider: BoardID = "mod.{Module}.{TypeA}Provider"
    static let mod{TypeB}Provider: BoardID = "mod.{Module}.{TypeB}Provider"
}

// ❌ WRONG — leaks provider identity into the ID namespace
extension BoardID {
    static let modProviderA{TypeA}: BoardID = "mod.{Module}.ProviderA{TypeA}"
    static let modProviderA{TypeB}: BoardID = "mod.{Module}.ProviderA{TypeB}"
    static let modProviderB{TypeA}: BoardID = "mod.{Module}.ProviderB{TypeA}"
    // ... grows with every new provider
}
```

`ShowInterstitialAdBoard` activates `.mod{TypeA}Provider` — it doesn't know or care which provider is behind that ID. The ModulePlugin registered the right concrete board there.

---

## ModulePlugin: Factory Dispatch (No Switch)

`ModulePlugin.internalContinuousRegistrations` casts to the internal factory and calls factory methods. No `switch` on provider type:

```swift
func internalContinuousRegistrations(
    sharedComponent: any SharedValueComponent,
    producer: any ActivatableBoardProducer
) -> [BoardRegistration] {
    // Force cast is safe: public API only accepts structs that conform to Internal protocol.
    // A crash here is a programming error (wrong type passed to LauncherPlugin.init).
    // swiftlint:disable:next force_cast
    let internalConfig = providerConfiguration as! Internal{Feature}ProviderConfiguration

    BoardRegistration(.mod{TypeA}Provider) { [hostProvider] identifier in
        internalConfig.make{TypeA}Board(identifier: identifier, hostProvider: hostProvider, producer: producer)
    }
    BoardRegistration(.mod{TypeB}Provider) { [hostProvider] identifier in
        internalConfig.make{TypeB}Board(identifier: identifier, hostProvider: hostProvider, producer: producer)
    }
}
```

**Why `as!` (force cast)?**
`Internal{Feature}ProviderConfiguration` is `internal` — the app client cannot construct a value of this protocol type directly. Every concrete config struct provided by the module (`{ProviderA}ProviderConfiguration`, `{ProviderB}ProviderConfiguration`) already conforms to it. The cast will only fail if someone creates a custom `public struct MyConfig: {Feature}ProviderConfiguration {}` outside the module without the internal conformance — which is a programming error that should crash loudly. Do not use `guard ... return []` here; it silently registers no boards and produces a confusing runtime failure.

---

## LauncherPlugin: Public API

```swift
public struct {Feature}LauncherPlugin: LauncherPlugin {
    private let providerConfiguration: {Feature}ProviderConfiguration  // marker protocol type
    private let hostProvider: {Feature}HostProvider                     // created once, shared

    public init(
        providerConfiguration: {Feature}ProviderConfiguration,
        // ... other config
    ) {
        self.providerConfiguration = providerConfiguration
        self.hostProvider = {Feature}DefaultHostProvider()
    }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        let hostProvider = self.hostProvider
        // swiftlint:disable:next force_cast
        let internalConfig = providerConfiguration as! Internal{Feature}ProviderConfiguration
        return ModuleComponent(
            modulePlugins: {Feature}ModulePlugin.ServiceType.allCases.map {
                {Feature}ModulePlugin(
                    service: $0,
                    providerConfiguration: providerConfiguration,
                    hostProvider: hostProvider,
                    // ...
                )
            },
            launchSettings: { _ in
                internalConfig.setup()   // ← SDK initialized once at app launch
            }
        )
    }
}
```

App client usage:
```swift
PluginLauncher.with(options: .default)
    .install(launcherPlugin: {Feature}LauncherPlugin(
        providerConfiguration: {ProviderA}ProviderConfiguration(
            adUnitID: "ca-app-pub-xxx",
            rewardUnitID: "ca-app-pub-yyy"
        )
    ))
    .initialize()
```

Switching providers = change one line at the call site.

---

## Decision Tree

```
Need multiple interchangeable external providers or frameworks for a module?
│
├── Will the active provider be decided at compile-time / app startup?
│   YES → Two-Layer Protocol Pattern (this spec)
│         - public marker protocol for app client
│         - internal factory protocol for ModulePlugin
│         - concrete configs as public structs
│
└── Will the active provider change at runtime (user selection)?
    YES → Command pattern on the provider boards
          - Keep two-layer protocol for initial config
          - Add Command to switch provider mid-session
          - Or: re-activate the module with a new config

Does the provider configuration include SDK-specific identifiers (unit IDs, placement IDs)?
    YES → Bake IDs into board init params
          InOut.swift: typealias {Type}ProviderInput = Void
          Board: typealias InputType = {Type}ProviderInput  (named alias, NOT Void directly)
          IDs flow: config struct init → board init → service.run(unitID:)
    NO  → IDs may still live in config struct (same pattern, fewer fields)

Do provider boards share the same Input/Output contract?
    YES → Use unified BoardIDs (one per service type, not per provider)
    NO  → Split into separate service types, each with their own unified ID
```

---

## Adding a New Provider (Zero-Modification Proof)

To add `ProviderC` to an existing module built with this pattern:

1. **New file:** `Sources/Plugins/ProviderCProviderConfiguration.swift`
   - `public struct ProviderCProviderConfiguration: Internal{Feature}ProviderConfiguration`
   - Add `providerC`-specific `let` fields
   - Implement `setup()` to initialize the SDK
   - Implement factory methods

2. **New file(s):** `Sources/Microboards/ProviderC{TypeA}Provider/ProviderC{TypeA}ProviderBoard.swift`
   - `typealias InputType = {TypeA}ProviderInput` (InOut.swift already defines `typealias {TypeA}ProviderInput = Void`)
   - Store provider-specific IDs in `init`
   - Implement `activate` calling the new SDK service

3. **New file(s):** `Sources/Microboards/ProviderC{TypeB}Provider/ProviderC{TypeB}ProviderBoard.swift`
   - Same pattern

**Zero existing files modified.** `ModulePlugin`, `LauncherPlugin`, show-boards, controllers, builders, IO — all unchanged.

---

## File Layout

```
Sources/
├── Plugins/
│   ├── {Feature}ProviderConfiguration.swift        ← public marker + internal factory (2 protocols)
│   ├── {ProviderA}ProviderConfiguration.swift       ← public struct, conforms to internal factory
│   ├── {ProviderB}ProviderConfiguration.swift       ← public struct, conforms to internal factory
│   └── {Feature}ModulePlugin.swift                  ← casts to internal factory, factory dispatch
├── Microboards/
│   ├── {TypeA}Provider/
│   │   ├── {TypeA}ProviderIOInterface.swift          ← unified BoardID (.mod{TypeA}Provider)
│   │   ├── {TypeA}ProviderInOut.swift
│   │   └── ServiceMap+{TypeA}Provider.swift
│   ├── {TypeB}Provider/                             ← same structure
│   ├── {ProviderA}{TypeA}Provider/
│   │   └── {ProviderA}{TypeA}ProviderBoard.swift    ← InputType = {TypeA}ProviderInput (→ Void), unitID in init
│   ├── {ProviderA}{TypeB}Provider/                  ← same structure
│   ├── {ProviderB}{TypeA}Provider/                  ← same structure
│   └── {ProviderB}{TypeB}Provider/                  ← same structure
```

IO layer exposes nothing about specific providers — only unified service-type IOInterfaces.

---

## Checklist

### Two-Layer Protocol Setup
- [ ] `public protocol {Feature}ProviderConfiguration {}` — marker only, no methods, no associated types
- [ ] `protocol Internal{Feature}ProviderConfiguration: {Feature}ProviderConfiguration` — factory methods, `internal` access
- [ ] Both live in `Sources/Plugins/`, not `IO/`
- [ ] Public enum variant of `{Feature}ProviderConfiguration` does NOT exist in IO layer

### Concrete Provider Configuration
- [ ] `public struct {ProviderX}ProviderConfiguration: Internal{Feature}ProviderConfiguration`
- [ ] All SDK-specific IDs stored as `public let` fields
- [ ] `func setup()` implemented — initializes the SDK (e.g. `MobileAds.shared.start(...)`, `UnityAds.initialize(...)`)
- [ ] SDK-specific import (`import GoogleMobileAds`, `import UnityAds`, etc.) at top of the config file — isolated here, not leaked elsewhere
- [ ] Factory methods (`make{TypeA}Board`, `make{TypeB}Board`) create the board with IDs baked in
- [ ] No `switch` on provider type inside factory methods — each struct knows its own type

### Provider Boards
- [ ] `{Type}ProviderInOut.swift` defines `typealias {Type}ProviderInput = Void` — alias lives in InOut, not on the Board
- [ ] Board uses `typealias InputType = {Type}ProviderInput` — references the named alias; **never** `typealias InputType = Void` directly (breaks IOInterface contract)
- [ ] SDK unit IDs stored as `private let` init params on the board
- [ ] `activate(withGuaranteedInput:)` creates service, calls `attachObject(service)`, uses stored IDs
- [ ] `complete()` called in service completion callback after `sendOutput()`

### Unified Board IDs
- [ ] One `BoardID` per service type (e.g. `.modInterstitialAdProvider`)
- [ ] No `BoardID` per provider-type combination
- [ ] Show-boards (callers) activate the unified ID, not provider-specific IDs
- [ ] ServiceMap extension exposes `var io{TypeA}Provider` using the unified ID

### ModulePlugin
- [ ] `let providerConfiguration: {Feature}ProviderConfiguration` — stored as marker protocol type
- [ ] `let hostProvider: {Feature}HostProvider` — stored property, NOT created inside `internalContinuousRegistrations`
- [ ] `internalContinuousRegistrations` uses `as!` cast to `Internal{Feature}ProviderConfiguration`
- [ ] No `switch` on provider in `internalContinuousRegistrations` — only factory method calls
- [ ] Exactly N `BoardRegistration` blocks where N = number of service types (not number of providers × types)

### LauncherPlugin
- [ ] `init(providerConfiguration: {Feature}ProviderConfiguration, ...)` — accepts marker protocol type
- [ ] `hostProvider` created once in `prepareForLaunching` and shared across all plugin instances
- [ ] `launchSettings: { _ in internalConfig.setup() }` present — SDK initialized exactly once at launch
- [ ] `as!` cast to `Internal{Feature}ProviderConfiguration` in `prepareForLaunching` for `setup()` call (same pattern as `internalContinuousRegistrations`)
- [ ] App client can switch providers by passing a different concrete config struct
