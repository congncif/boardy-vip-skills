# SPEC: Per-Activation Resource Management

> **Load this spec** when a Board wraps a stateful service (SDK delegate, socket, streaming operation) that must be created fresh per activation and kept alive until the operation completes.
> Companion specs: `@.claude/rules/MICROBOARD_NONUI.md` (Viewless Board), `@.claude/rules/COMMUNICATION.md` (Bus patterns, `complete()` semantics).

---

## Problem

A Board is stateless and long-lived (registered once in the Motherboard). If an external service (e.g. an SDK delegate, HTTP stream, ad provider) is stored as a Board property:

| Issue | Effect |
|-------|--------|
| Board stores service | One service shared across ALL activations — callbacks from old activations pollute new ones |
| Service is an NSObject delegate | Must stay alive while the async operation runs; no one holds it after `activate()` returns |
| Shared singleton guard on Board | Board statefulness rule broken; concurrent activations race on the same flag |

---

## Rule 1 — Board MUST NOT store per-activation services

```swift
// ❌ WRONG — service shared across activations
final class SomeBoard: ModernContinuableBoard, ... {
    private let service: SomeService   // ← stored property on Board

    init(identifier: BoardID, service: SomeService, producer: ActivatableBoardProducer) {
        self.service = service
        ...
    }

    func activate(withGuaranteedInput input: InputType) {
        service.run(input.param) { [weak self] result in
            self?.sendOutput(result)
        }
    }
}

// ✅ CORRECT — service created per activation, kept alive with attachObject
final class SomeBoard: ModernContinuableBoard, ... {
    private let factory: SomeServiceFactory   // stateless factory / host provider

    init(identifier: BoardID, factory: SomeServiceFactory, producer: ActivatableBoardProducer) {
        self.factory = factory
        ...
    }

    func activate(withGuaranteedInput input: InputType) {
        let service = factory.makeService()   // new instance per activation
        attachObject(service)                 // keeps it alive until complete()
        service.run(input.param) { [weak self] result in
            self?.sendOutput(result)
            self?.complete()
        }
    }
}
```

**Why:** `attachObject(_:)` ties the object's lifetime to the Board. When `complete()` is called, the Board is released from the Motherboard and all attached objects are released.

**Requirements for `attachObject`:**
- The object must be an `NSObject` subclass (Boardy `Attachable` protocol requirement)
- `complete()` must be called only after ALL attached work is done — see `@.claude/rules/COMMUNICATION.md` for the full `complete()` semantics and when-to-call rules

> **`complete()` timing note:** For a Board that attaches a single service, call `complete()` in that service's completion callback. For a Board that attaches multiple tasks concurrently, call `complete()` only after the last task finishes — premature `complete()` releases all attached objects while others are still running.

---

## Rule 2 — Concurrency guards are dedicated objects, placed at the right scope

When a Board represents a UI-presenting operation that must be single-concurrent, the guard must NOT be a flag on the Board (that would be stored state — violating the statefulness rule). Instead:

1. Create a dedicated guard class (single responsibility)
2. Place the shared instance at the **narrowest scope that covers the required exclusion**
3. Inject it into the Controller (not the Board)

### Guard placement — by required scope

| Exclusion covers | Place guard on | Example |
|-----------------|---------------|---------|
| All flows in the entire module (e.g. "only one ad at a time, any type") | `LauncherPlugin` stored property — passed to every plugin instance | `AdShowingGuard` shared across interstitial and reward |
| One specific `ServiceType` only (e.g. "only one interstitial at a time, reward is independent") | `ModulePlugin` stored property for that case, or local in `build()` for that case | Guard created inside `case .showInterstitialAd:` branch only |
| A single flow, never shared | Local variable inside `internalContinuousRegistrations` or `build()`, passed to Builder | Guard needed only for one background task board |

```swift
// ✅ Guard class — dedicated single-responsibility object with lock
final class SomeOperationGuard {
    private var isRunning = false
    private let lock = NSLock()

    func tryAcquire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    func release() {
        lock.lock()
        defer { lock.unlock() }
        isRunning = false
    }
}

// ✅ Module-wide guard — LauncherPlugin owns it
public struct SomeLauncherPlugin: LauncherPlugin {
    private let operationGuard = SomeOperationGuard()   // shared across ALL ServiceType cases

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        ModuleComponent(
            modulePlugins: SomeModulePlugin.ServiceType.allCases.map {
                SomeModulePlugin(service: $0, operationGuard: operationGuard)
            }
        )
    }
}

// ✅ Single-flow guard — local to the specific build branch
func build(with identifier: BoardID, ...) -> any ActivatableBoard {
    switch service {
    case .specificFlow:
        let guard = SomeOperationGuard()   // only this flow needs it
        return SpecificFlowBoard(
            identifier: identifier,
            builder: SpecificFlowBuilder(operationGuard: guard),
            producer: internalContinuousProducer
        )
    case .otherFlow:
        return OtherFlowBoard(identifier: identifier, producer: internalContinuousProducer)
    }
}

// ✅ Guard injected into Controller via Builder — never stored on Board
struct SomeBuilder: SomeBuildable {
    let operationGuard: SomeOperationGuard

    func build(withDelegate delegate: SomeDelegate?, input: SomeInput) -> SomeInterface {
        let controller = SomeController(input: input, operationGuard: operationGuard)
        controller.delegate = delegate
        return SomeInterface(controller: controller)
    }
}

// ✅ Guard used in Controller
final class SomeController: NSObject {
    private let input: SomeInput
    private let operationGuard: SomeOperationGuard

    func start() {
        guard operationGuard.tryAcquire() else {
            input.completion?(.skipped)
            delegate?.finish()
            return
        }
        // proceed with operation
    }

    func didComplete(result: SomeResult) {
        operationGuard.release()   // always release before finish, in every path
        input.completion?(result)
        delegate?.finish()
    }
}
```

**Key rule:** The guard's placement follows its exclusion scope — not a blanket "always LauncherPlugin". Choose the narrowest owner that is still shared by all flows that must mutually exclude.

---

## Rule 3 — Routing configuration belongs in Controller, not Board

A Board that routes to different child boards based on some configuration (e.g. `providerConfiguration` deciding between AdMob or UnityAds) must NOT store that configuration as a Board property.

```swift
// ❌ WRONG — Board stores config and makes routing decisions
final class SomeBoard: ModernContinuableBoard, ... {
    private let config: SomeConfig   // ← Board is stateful!

    extension SomeBoard: SomeDelegate {
        func activateProvider() {
            switch config {              // Board routing decision
            case .typeA: activateA()
            case .typeB: activateB()
            }
        }
    }
}

// ✅ CORRECT — Controller makes routing decision, Board implements thin delegate methods
// Protocol splits activation into typed methods:
protocol SomeControlDelegate: AnyObject {
    func activateTypeAProvider(param: String)
    func activateTypeBProvider(param1: String, param2: String)
    func finish()
}

// Controller decides which delegate method to call based on injected config
final class SomeController: NSObject {
    private let config: SomeConfig

    func start() {
        switch config {
        case .typeA(let param):
            delegate?.activateTypeAProvider(param: param)
        case .typeB(let p1, let p2):
            delegate?.activateTypeBProvider(param1: p1, param2: p2)
        }
    }
}

// Board is thin — each delegate method is a pure ServiceMap call
extension SomeBoard: SomeDelegate {
    func activateTypeAProvider(param: String) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioTypeAProvider.activation.activate(with: TypeAInput(param: param))
    }

    func activateTypeBProvider(param1: String, param2: String) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioTypeBProvider.activation.activate(with: TypeBInput(p1: param1, p2: param2))
    }

    func finish() {
        sendOutput(())
        complete()
    }
}
```

**Why:** Board delegates know nothing about config — each method is a single ServiceMap call. Routing logic lives in the Controller where all per-activation state resides.

---

## Decision Tree

```
Board wraps an external service (SDK, HTTP, socket)?
│
├── Service has state (delegate, completion closure)?
│   YES → Create per activation inside activate()
│          attachObject(service)
│          call complete() after ALL attached work finishes
│          (see COMMUNICATION.md for complete() semantics)
│
└── Service is purely stateless (just a function call)?
    YES → Inject as factory/hostProvider (stateless dep on Board)
           Still: do NOT store service instance on Board

Board routes to different providers based on config?
    YES → Config → Controller (via Builder injection)
           Protocol → split per provider (one method each)
           Board implements thin ServiceMap calls only

Board needs a concurrency guard?
    YES → Dedicated guard class (single responsibility)
           Placement by scope:
             All flows in module → LauncherPlugin stored property
             One specific flow  → local in build() for that case
           Injected into Controller via Builder
           Board remains stateless
```

---

## Checklist for Per-Activation Resource Boards

- [ ] No per-activation service stored as Board property
- [ ] Service created inside `activate()` and immediately `attachObject(service)` called
- [ ] `complete()` called only after ALL attached work is done (not per-task if multiple tasks run concurrently)
- [ ] Routing config (provider selection, SDK configuration) injected into Controller via Builder, not stored on Board
- [ ] Concurrency guard is a dedicated class; placement matches the required exclusion scope (not blindly at LauncherPlugin level)
- [ ] Guard `.tryAcquire()` called at start of Controller's first method; `.release()` called in every completion path before `delegate?.finish()`
- [ ] Protocol delegate split per concrete provider when routing varies; each Board delegate method is a pure ServiceMap call
- [ ] NSObject conformance on any object passed to `attachObject`
