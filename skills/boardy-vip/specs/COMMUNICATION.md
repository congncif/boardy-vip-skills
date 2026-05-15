# SPEC: Board Communication Patterns

> **Load this spec** when connecting boards, handling outputs, sending commands, or setting up buses.
> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `.claude/rules/ARCHITECTURE.md` §4 (runtime composition), `.claude/rules/MICROBOARD_UI.md`, `.claude/rules/MICROBOARD_NONUI.md`.

---

## The 3 Pillars — Real API

All board communication goes through `MainboardGenericDestination` (the `io{BoardName}` property on ServiceMap):

```swift
// io{BoardName} returns a MainboardGenericDestination, which has:
.activation    // activate the board with input
.flow          // receive output from the board
.interaction   // send command to the active board
```

### Pillar 1: Activation

```swift
motherboard.serviceMap.mod{ModuleName}Plugins
    .io{BoardName}.activation.activate(with: input)

// Void input:
motherboard.serviceMap.mod{ModuleName}Plugins
    .io{BoardName}.activation.activate()
```

### Pillar 2: Flow (output listener)

```swift
motherboard.serviceMap.mod{ModuleName}Plugins
    .io{BoardName}.flow.addTarget(self) { target, output in
        switch output {
        case .done:
            target.handleDone()
        case .exit:
            target.closeBus.transport()
        }
    }
```

Register flows in `registerFlows()` called from `init` — before any `activate()` call.

### Pillar 3: Interaction (command)

```swift
motherboard.serviceMap.mod{ModuleName}Plugins
    .io{BoardName}.interaction.send(command: .refresh)

// Void command — send without argument:
motherboard.serviceMap.mod{ModuleName}Plugins
    .io{BoardName}.interaction.send()
```

---

## Output / Action / Command — Decision Rule

Three distinct mechanisms for board-to-board communication. Choose by **direction and target**:

| Mechanism | Direction | Target | When to use |
|-----------|-----------|--------|-------------|
| `sendOutput()` → `.flow` | Board → its own Motherboard | Direct parent only | Board signals result or mid-session event to the Motherboard that activated it |
| `broadcastAction()` → `FlowActionType` | Board → upstream chain | One or more upstream boards | Board signals a concern that one or more ancestors need to hear; listeners opt in via flow handlers |
| Command (`.interaction.send(command:)`) | Motherboard → child | An already-activated child board, or any board within the same Motherboard | Motherboard pushes a command into an active child; or two sibling boards within the same Motherboard communicate |

### Decision tree

```
Who do you want to communicate with?
│
├── The Motherboard that activated this board (direct parent)?
│   → sendOutput()
│
├── One or more boards higher up the chain (upstream ancestors)?
│   → broadcastAction()   — upstream listeners opt in; not necessarily all receive it
│
├── A child board that is already activated?
│   → Command: motherboard.serviceMap.io{Board}.interaction.send(command:)
│
└── A sibling board within the same Motherboard?
    → Command: motherboard.serviceMap.io{SiblingBoard}.interaction.send(command:)
```

### Example: child board notifying its direct parent

```swift
// ✅ CORRECT — {ChildBoard} notifies its direct parent ({ParentBoard})
sendOutput(.eventOccurred(data: ...))

// ❌ WRONG — broadcastAction propagates upstream; Home, App root etc. would receive it
broadcastAction(.eventOccurred(data: ...))
```

**Rule of thumb:** `sendOutput()` is the default for child→parent communication. Use `broadcastAction()` only when the signal genuinely belongs to one or more upstream ancestors (e.g. a global analytics event, a session-wide side effect). Use Command when the direction is reversed — a Motherboard pushing into an active child, or two siblings coordinating.

---

## Bus<T> — Board ↔ Controller Bridge

`Bus<T>` bridges events between the Board (coordination layer) and the managed object (ViewController/Interactor).

### Bus types used in real code

```swift
// Standard buses
private let completeBus = Bus<Bool>()     // isDone: Bool
private let finishBus = Bus<Void>()       // simple completion / input callback
```

### connect(target:) — object-based subscription

```swift
// Board connects a bus to itself (standard completion pattern)
completeBus.connect(target: self) { target, isDone in
    target.rootViewController.returnHere { [weak target] in
        target?.complete(isDone)
    }
}
```

### deliver {} — closure-based subscription (no target)

```swift
// Used when you only need to call a captured closure
finishBus.deliver {
    input.completion?()   // closure from input, no object needed
}
```

### transport(input:) — fire the bus

```swift
// From delegate methods (Board receives from ViewController/Interactor)
func close(_ isDone: Bool) {
    completeBus.transport(input: isDone)
}

// Void bus:
finishBus.transport()
// Non-void bus:
completeBus.transport(input: true)
```

### Bus connection order

```swift
func activate(withGuaranteedInput input: InputType) {
    let component = builder.build(withDelegate: self, input: input)
    let viewController = component.userInterface

    watch(content: component.controller)          // 1. watch controller
    motherboard.putIntoContext(viewController)     // 2. put into context
    rootViewController.show(viewController)        // 3. show (SiFUtilities)

    // 4. Connect buses after show
    completeBus.connect(target: self) { ... }

    // 5. deliver {} for input callbacks
    finishBus.deliver {
        input.completion?()
    }
}
```

---

## Inter-Board Flow Coordination (registerFlows pattern)

The most common pattern: Board A listens to child board outputs and activates next steps.

```swift
// In ParentBoard.init():
super.init(identifier: identifier, boardProducer: producer)
registerFlows()   // always last in init

private extension ParentBoard {
    func registerFlows() {
        // Child A output → activate Child B
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildA.flow.addTarget(self) { target, output in
                switch output {
                case .next:
                    target.motherboard.serviceMap.mod{ModuleName}Plugins
                        .ioChildB.activation.activate()
                case .exit:
                    target.closeBus.transport()
                }
            }

        // Child B output → complete the flow
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildB.flow.addTarget(self) { target, output in
                switch output {
                case .done:
                    target.closeBus.transport()
                case .exit:
                    target.closeBus.transport()
                }
            }
    }
}
```

---

## Delegate Pattern — Board ↔ VIP

The Board conforms to `{FeatureName}Delegate` (= ActionDelegate + ControlDelegate). This is how the Board receives events from ViewController and Interactor:

```swift
extension {FeatureName}Board: {FeatureName}Delegate {
    // From ViewController (ActionDelegate)
    func close(_ isDone: Bool) {
        completeBus.transport(input: isDone)   // forward to bus
    }
    func exitFlow() {
        closeBus.transport()
    }

    // From Interactor (ControlDelegate)
    func performCompletion(_ isDone: Bool) {
        completeBus.transport(input: isDone)
    }
    func presentChildBoard(with data: SomeData) {
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoard.activation.activate(with: data)   // activate child
    }
    func loadData() {}   // optional hook, usually empty
}
```

---

## Board Lifecycle — `complete()` Semantics

### Board as an Independent Service

A Board is a **long-lived, stateless service** registered in the Motherboard. Once activated, it stays alive until explicitly released. Multiple activations of the same Board (multiple concurrent controllers) are allowed; all share the same event buses and communication channels.

**Event-driven, not input-mapped.** When the same Board is activated multiple times, there is no built-in mechanism to route an output back to a specific input. All events flow through a single channel (the Board). Callers must distinguish events by their **content** (payload inside the event), not by which activation produced them.

```
[Activation 1 → Controller A] ─┐
                                 ├─ same Bus / Flow channel ─► single Board
[Activation 2 → Controller B] ─┘
```

> **Exception:** `BlockTaskBoard` is specifically designed for per-input result routing. Each activation carries its own `BlockTaskParameter` with independent `onSuccess`/`onProgress`/`onError`/`onCompletion` handlers. This is the only Board type where output is mapped back to its originating input.

### When to call `complete()`

`complete()` tells the Motherboard: *"this Board is fully done — release it."* The Motherboard removes the Board from its registry.

**⚠️ `complete()` cannot be called twice.** Calling it a second time raises an assertion, indicating a design problem: either the flow is terminating incorrectly, an observer/stream is still alive after release, or the Board is being retained as a leaked instance.

| Board type | Call `complete()`? | Reason |
|------------|-------------------|--------|
| Stateless VIP board | ❌ Usually NOT needed | Board has no resources to clean up; Motherboard manages lifecycle |
| Flow Board (coordinator) | ✅ When flow is fully done | After `sendOutput()` to signal parent, `complete()` to release self |
| Viewless Board (with Controller) | ✅ When Controller is done | Controller + UseCase resources must be released; `complete()` detaches them |
| BlockTaskBoard | ✅ Auto-completes | Framework calls `complete()` internally after all tasks finish |

**Before calling `complete()`, ensure:**
1. All event streams (flows, observers, buses) are terminated or disconnected
2. No further events will arrive at this Board after it is released
3. No other object holds a reference that will try to use this Board

```swift
// ✅ Correct: sendOutput THEN complete (output goes out before Board is released)
func finishFlow(output: SomeOutput) {
    sendOutput(output)
    complete()
}

// ❌ Wrong: complete() called twice
func handleDone() {
    sendOutput(.done)
    complete()
}
func handleExit() {
    complete()   // ← assertion: Board already completed above
}
```

### `complete()` Helper (convenience method)

`ModernContinuableBoard` provides a `complete()` convenience method:

```swift
// complete() with no argument — emits Void output then releases
target.complete()

// complete(isDone: Bool) — custom helper you define
private func complete(_ isDone: Bool) {
    if isDone {
        sendOutput(.done)
    } else {
        sendOutput(.exit)
    }
    // NOTE: do not call complete() here unless this Board holds resources.
    // For stateless boards, the parent coordinator handles lifecycle.
}
```

---

## SiFUtilities Helpers

The real codebase uses `SiFUtilities` for navigation:

```swift
import SiFUtilities

// ✅ Standard — show ViewController (push in nav stack or present)
rootViewController.show(viewController)

// ✅ Navigate back to this board's root, then execute callback
rootViewController.returnHere { [weak self] in
    self?.complete(isDone)
}

// ✅ Put into Boardy navigation context (always before show)
motherboard.putIntoContext(viewController)

// ✅ Replace top view controller (in-place transition, no push/pop)
rootViewController.replaceTopViewControllerIfNeeded(with: viewController)
```

> **Do NOT use** `topPresentViewController(nav)`, `presentViewController(nav)`, or nav wrapping.
> Use `rootViewController.show(viewController)` — simpler and consistent.

---

## Anti-Patterns to Avoid

| Anti-Pattern | Correct Pattern |
|-------------|----------------|
| `registerFlows()` in `activate()` | Call in `init` |
| Direct ViewController reference across boards | Use ServiceMap + activation/flow |
| NotificationCenter for board events | Use Bus<T> or Flow pillar |
| `transport()` before `connect()` / `deliver()` | Always connect/deliver first |
| Board holding or retrieving controller references to communicate | Use event buses connected in `activate()`; keep `watch(content:)` for lifecycle tracking only |
| `sendOutput()` before `closeBus.transport()` | Use bus → completion → sendOutput chain |
| Calling `complete()` twice | Terminates flow once; second call raises assertion — fix the double-complete path |
| Calling `complete()` on stateless boards unnecessarily | Most VIP boards need no `complete()`; only call when Board holds attachable resources |
| Distinguishing per-input results on a regular Board | Use `BlockTaskBoard` for per-activation result routing; regular Boards are event-driven |
| `broadcastAction()` used to notify direct parent | Use `sendOutput()` — Output goes to direct parent; `broadcastAction()` propagates upstream and is for signals meant for one or more ancestors |
| Command used to communicate child→parent | Use `sendOutput()` — Command direction is Motherboard→child or sibling→sibling within same Motherboard |
| `sendOutput()` used to push into an already-active child board | Use Command: `motherboard.serviceMap.io{Board}.interaction.send(command:)` |
