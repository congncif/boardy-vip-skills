<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Microboard without UI (Non-UI Boards)

> **Load this spec** when creating Microboards that have no UIViewController.
> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `@.claude/rules/MICROBOARD_UI.md` (UI board variant), `@.claude/rules/COMMUNICATION.md` (flow + bus patterns), `@.claude/rules/EXAMPLES_NONUI_BOARDS.md` / `@.claude/rules/EXAMPLES_VIEWLESS_BOARD.md` (concrete skeletons).

## Decision Tree

```
Does the board show UI?
    YES → Use MICROBOARD_UI.md
    NO  → Continue below ↓

Is it a coordinator/flow orchestrator (activates child boards in sequence)?
    ┌── STOP: Does an existing VIP board ALREADY serve as the entry point to this flow?
    │       (i.e. the first screen the user sees is a VIP board with UI)
    │   YES → Let that VIP board be the coordinator via registerFlows().
    │          DO NOT add a Non-UI FlowBoard on top of it.
    │          Non-UI coordinators only make sense when there is NO UI entry point.
    └── Continue only when no VIP board can own the coordination ↓

    Does the flow need conditional entry logic (gate/permission check) before the first UI screen?
        YES → FlowBoard as CHILD of the UI entry board, not as parent/wrapper
        NO  → Continue ↓

    Does the flow need to be reused from multiple distinct entry points?
        YES → FlowBoard (encapsulation for reuse)
        NO  → Continue ↓

    Does it need to STORE anything between child board interactions?
    (save a child's output to pass into / configure a later child)
        YES → Viewless Board  (pattern 4 below)
        NO  → FlowBoard ← @.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Flow

Is it a single async operation where the CALLER needs to handle its result per-activation?
    YES → BlockTaskBoard ← @.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Block Task
        └─ Caller activates with BlockTaskParameter (bundles onSuccess/onProgress/onError per call)
        └─ Multiple concurrent activations handled independently

Is it a single async operation where result goes to the motherboard output stream?
    Multiple activations in flight?    → BlockTaskBoard (concurrent mode)
    One at a time (sequential)?        → TaskBoard  ← @.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Single Task
    Single activation, no side effects → ResultTaskBoard ← Single Result Task

Need to block an action until a prerequisite completes (e.g. login before cart)?
    YES → BarrierBoard ← @.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Barrier

Fully custom logic that doesn't fit above?
    YES → Empty Board ← @.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Empty
```

> **The VIP-board-as-coordinator rule:**
> A VIP board with UI can own `registerFlows()` and coordinate all child boards — the entry-screen board acts as the coordinator itself. Adding a Non-UI FlowBoard on top of a UI board purely to "wrap" a linear flow creates unnecessary files and indirection. Only introduce a Non-UI coordinator when none of the screens can serve as the anchor.

> **Flow vs Viewless — the key question (when a Non-UI coordinator IS needed):**
> After child board A finishes, must its output be *remembered* to activate/configure child board B?
> **YES → Viewless Board.  NO → Flow Board.**
> Flow Boards are STATELESS. The only stored property allowed is `finishBus`.

### Quick comparison

| | VIP board as coordinator | Flow Board | Viewless Board |
|---|---|---|---|
| Has UI | Yes | No | No |
| Business logic | In Interactor | None | In Controller |
| State between children | In Interactor if needed | None — stateless | In Controller |
| Entry point | Yes (preferred) | Only when no UI anchor | Only when no UI anchor |
| Stored properties on Board | `builder`, `completeBus` | `finishBus` only | `builder: Buildable` only |
| Typical use | Most module flows | Pure routing, multi-entry reuse | A output → B input |

---

## 1. Flow Board — Coordinator Pattern

Use when: the board's job is to orchestrate child boards in sequence or parallel.
No Builder, no VIP. Pure board-to-board wiring.

**Typical shape:** an entry-coordinator board that delegates to one or more child boards, listens for their outputs, then calls the input's `completion` closure.

```swift
// Sources/Microboards/{FeatureName}/{FeatureName}Board.swift
import Boardy
import Foundation
import {ModuleName}IO   // import IO if aliasing public types
import UIKit

final class {FeatureName}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {FeatureName}Input
    typealias OutputType = {FeatureName}Output
    typealias FlowActionType = {FeatureName}Action
    typealias CommandType = {FeatureName}Command

    // MARK: - Buses
    private let finishBus = Bus<Void>()   // for input.completion() callback

    // MARK: - Init
    init(identifier: BoardID, producer: ActivatableBoardProducer) {
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    // MARK: - GuaranteedBoard
    func activate(withGuaranteedInput input: InputType) {
        // 1. Activate the first child board
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoard.activation.activate(with: ChildBoardInput(context: input.context))

        // 2. Wire input's completion callback via bus (called when flow finishes)
        finishBus.deliver {
            input.completion?()
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

// MARK: - Flow registrations
private extension {FeatureName}Board {
    func registerFlows() {
        // Child board output → coordinator reacts
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoard.flow.addTarget(self) { target, output in
                switch output {
                case .done:
                    target.finishBus.transport()
                    target.complete()   // sendOutput to parent
                }
            }
    }
}
```

### `finishBus.deliver {}` vs `finishBus.connect(target:) {}`

```swift
// deliver {} — one-shot block, no target needed, called when bus fires
finishBus.deliver {
    input.completion?()   // closure captured from input
}

// connect(target:) — weakly retains target object, called when bus fires
finishBus.connect(target: nav) { vc in
    vc.dismiss(animated: true)
}
```

Use `deliver {}` when you only need to call a closure (e.g. `input.completion`).
Use `connect(target:)` when you need a weak reference to an object.

---

## 2. BlockTaskBoard — Per-Activation Result Handling

Use when: the caller needs to handle the result **per activation** (not via the motherboard output stream).
Each activation is identified by its `BlockTaskParameter` which carries individual `onSuccess`/`onProgress`/`onError`/`onCompletion` handlers. Results are routed back to the originating `BlockTaskParameter` — each caller gets its own result.
Multiple concurrent activations are handled independently (`executingType: .concurrent`).

> **Why BlockTaskBoard is different from a regular Board:**
> Regular Boards are event-driven services — all activations share one communication channel; callers cannot distinguish which output belongs to which input. `BlockTaskBoard` solves this by bundling per-call handlers directly in `BlockTaskParameter`. The framework routes each task's result to its own parameter's handlers automatically. The Board self-completes after all tasks finish (no manual `complete()` needed).

**Template:** `@.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Block Task`

**⚠️ CRITICAL: Always call completion on MainActor**

Task concurrency may execute on background threads, but Motherboard works on the main thread. Always wrap completion calls in `await MainActor.run`:

```swift
// Factory pattern — NOT a class with init
enum {FeatureName}BoardFactory {
    static func make(identifier: BoardID, executingType: ExecutingType = .concurrent) -> ActivatableBoard {
        BlockTaskBoard<{FeatureName}Input, {FeatureName}Output>(
            identifier: identifier,
            executingType: executingType,
            executor: { _, input, completion in
                Task {
                    // perform work with input
                    let result = await someAsyncWork(input)
                    
                    // ✅ ALWAYS call completion on MainActor
                    await MainActor.run {
                        completion(.success(result))
                    }
                }
                return .none
            }
        )
    }
}
```

**Common mistake:**
```swift
// ❌ WRONG - completion called on background thread
Task {
    let result = await someAsyncWork(input)
    completion(.success(result))  // May crash or cause race conditions
}
```

InOut (caller activates with `{FeatureName}Parameter`, not plain `{FeatureName}Input`):

```swift
struct {FeatureName}Input { ... }
typealias {FeatureName}Parameter = BlockTaskParameter<{FeatureName}Input, {FeatureName}Output>
// IOInterface MainDestination uses Parameter as InputType:
typealias {FeatureName}MainDestination = MainboardGenericDestination<
    {FeatureName}Parameter, {FeatureName}Output, {FeatureName}Command, {FeatureName}Action>
```

Caller activation:

```swift
let param = {FeatureName}Parameter(input: {FeatureName}Input(...))
    .onSuccess(target: self) { target, result in ... }  // optional per-call handler
motherboard.io{FeatureName}().activation.activate(with: param)
```

Registration in ModulePlugin:

```swift
case .{featureName}:
    return {FeatureName}BoardFactory.make(identifier: identifier, ...dependencies...)
```

---

## 3. TaskBoard — Sequential Single-Task

Use when: the board performs one async operation at a time; result goes to the **motherboard output stream** (not per-activation).
From Boardy 1.36, only one task executes at a time — use `BlockTaskBoard` for concurrent activations.

**Template:** `@.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Single Task`

**⚠️ CRITICAL: Always call completion on MainActor**

```swift
enum {FeatureName}BoardFactory {
    static func make(identifier: BoardID) -> ActivatableBoard {
        TaskBoard<{FeatureName}Input, {FeatureName}Output>(identifier: identifier) { board, input, completion in
            Task {
                // perform async work
                let result = await someAsyncWork(input)
                
                // ✅ ALWAYS call completion on MainActor
                await MainActor.run {
                    completion(.success(result))
                }
            }
        }
        processingHandler: { $0.showDefaultLoading($0.isProcessing) }
        errorHandler: { $0.showErrorAlert($1) }
    }
}
```

Key differences from `BlockTaskBoard`:
- Activated with plain `Input` (no Parameter wrapper)
- Output goes to motherboard output stream; all listeners receive it
- `processingHandler`/`errorHandler` are board-level (apply to all activations)
- **Still requires MainActor for completion calls**

---

## 4. ResultTaskBoard — Single Activation, No Side Effects

Use when: exactly one activation needed; result wrapped in `BoardResult`; no progress or error side effects.

**Template:** `@.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Single Result Task`

```swift
enum {FeatureName}BoardFactory {
    static func make(identifier: BoardID) -> ActivatableBoard {
        ResultTaskBoard<{FeatureName}Input, {FeatureName}Success, {FeatureName}Failure>(
            identifier: identifier
        ) { input, callback in
            // perform work
            callback(.success(result))
        }
    }
}
```

---

## 5. BarrierBoard — Prerequisite Gate

Use when: an action must be blocked until a prerequisite completes (e.g. user must log in before adding to cart).

**Template:** `@.claude/rules/templates/module-template/Templates/Non-UI Board.xctemplate/Barrier`

```swift
// InOut.swift
typealias {FeatureName}BarrierBoard = BarrierBoard<{FeatureName}Input>
```

Usage pattern:

```swift
// Register callback that fires when prerequisite is met
motherboard.io{Prerequisite}().activation.activate(with: .wait { [weak self] result in
    self?.performActionWith(result)
})

// Activate the prerequisite flow
motherboard.ioAuth().activation.activate()

// In registerFlows() — overcome or cancel barrier when prerequisite resolves
motherboard.ioAuth().flow.addTarget(self) { target, output in
    switch output {
    case .authenticated(let user):
        target.motherboard.io{Prerequisite}().activation.activate(with: .overcome(user))
    case .cancelled:
        target.motherboard.io{Prerequisite}().activation.activate(with: .cancel)
    }
}
```

---

## 7. Empty Board — Full Custom## 3. Empty Board — Full Custom

Starting template for boards that don't fit the above patterns:

```swift
final class {FeatureName}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {FeatureName}Input
    typealias OutputType = {FeatureName}Output
    typealias FlowActionType = {FeatureName}Action
    typealias CommandType = {FeatureName}Command

    init(identifier: BoardID, producer: ActivatableBoardProducer) {
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        // Implement custom logic
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

---

## 8. Viewless Board — Controller-Driven Coordination

Use when: the board orchestrates child boards **and** has stateful business logic (UseCase calls, async operations, state machine). Like a Full UI Board but without Presenter and View.

**Typical shape:** a coordinator board that activates two or more child boards in sequence, invokes one or more UseCases between steps, and tracks transient flow state (e.g. "did the user complete step N?") inside its Controller.

### File set (5 files)

```
Sources/Microboards/{BoardName}/
├── {BoardName}Protocols.swift     ← Controllable + ControlDelegate + Delegate + Interface + Buildable
├── {BoardName}Controller.swift    ← NSObject subclass; holds input + UseCases + state
├── {BoardName}Builder.swift       ← creates Controller, injects deps
├── {BoardName}Board.swift         ← thin shell; registers flows; delegates to Controller
└── ServiceMap+{BoardName}.swift   ← (internal) serviceMap accessor (optional)
```

### Protocols.swift

```swift
// Sources/Microboards/{BoardName}/{BoardName}Protocols.swift
import UIKit

// MARK: - Inward (Board u2192 Controller)
protocol {BoardName}Controllable: AnyObject {
    func start()
    // add lifecycle callbacks the Board needs to forward to the Controller
    func didReceiveChildOutput(/* ... */)
}

// MARK: - Outward (Controller u2192 Board)
protocol {BoardName}ControlDelegate: AnyObject {
    func activateChildBoard(context: UIViewController?)
    func finishFlow(output: {PublicBoardName}Output)
}

// Board adopts this; Controller holds weak reference via ControlDelegate
protocol {BoardName}Delegate: {BoardName}ControlDelegate {}

// MARK: - Interface returned by Builder
struct {BoardName}Interface {
    let controller: {BoardName}Controllable
}

// MARK: - Builder
protocol {BoardName}Buildable {
    func build(withDelegate delegate: {BoardName}Delegate?,
               input: {BoardName}Input) -> {BoardName}Interface
}
```

### Controller.swift

The Controller is a plain `NSObject` (so it is `Attachable`). It owns the input, use cases, and all mutable state.

```swift
// Sources/Microboards/{BoardName}/{BoardName}Controller.swift
import Foundation

final class {BoardName}Controller: NSObject {
    weak var delegate: {BoardName}ControlDelegate?

    private let input: {BoardName}Input
    private let someUseCase: SomeUseCase
    private var state: Bool = false   // all mutable state lives here

    init(input: {BoardName}Input, someUseCase: SomeUseCase) {
        self.input = input
        self.someUseCase = someUseCase
    }
}

extension {BoardName}Controller: {BoardName}Controllable {
    func start() {
        delegate?.activateChildBoard(context: input.context)
    }

    func didReceiveChildOutput(/* ... */) {
        Task { [weak self] in
            guard let self else { return }
            let result = await someUseCase.execute(/* ... */)
            await MainActor.run { [weak self] in
                // compute next step, update state
                self?.state = true
                self?.delegate?.activateChildBoard(context: self?.input.context)
            }
        }
    }
}
```

### Builder.swift

```swift
// Sources/Microboards/{BoardName}/{BoardName}Builder.swift
import Foundation

struct {BoardName}Builder: {BoardName}Buildable {
    let someUseCase: SomeUseCase

    func build(withDelegate delegate: {BoardName}Delegate?,
               input: {BoardName}Input) -> {BoardName}Interface {
        let controller = {BoardName}Controller(input: input, someUseCase: someUseCase)
        controller.delegate = delegate
        return {BoardName}Interface(controller: controller)
    }
}
```

### Board.swift

The Board is a thin shell: it attaches the Controller to an appropriate context, connects event buses to the controller, registers child-board flows, and delegates everything else to the Controller.

**CRITICAL: Board must be STATELESS.** Never store input, context, or any state on the Board. All state lives in Controller.

**CRITICAL: Use Event Buses for Board→Controller communication.** Never store or retrieve controller reference directly. Use event buses to decouple Board from Controller lifecycle.

```swift
// Sources/Microboards/{BoardName}/{BoardName}Board.swift
import Boardy
import Foundation
import UIKit

final class {BoardName}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {BoardName}Input
    typealias OutputType = {BoardName}Output
    typealias FlowActionType = {BoardName}Action
    typealias CommandType = {BoardName}Command

    private let builder: {BoardName}Buildable

    // Event buses for communicating with active controller (one bus per action)
    private let childOutputBus = Bus<ChildOutputType>()
    private let anotherActionBus = Bus<SomeDataType>()

    init(identifier: BoardID, builder: {BoardName}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()   // ALWAYS in init, never in activate
    }

    func activate(withGuaranteedInput input: {BoardName}Input) {
        let component = builder.build(withDelegate: self, input: input)

        // Connect event buses to controller
        childOutputBus.connect(target: component.controller) { controller, output in
            controller.didReceiveChildOutput(output)
        }
        anotherActionBus.connect(target: component.controller) { controller, data in
            controller.handleAnotherAction(data)
        }

        // Attach controller to appropriate context
        // Board context is preferred: controller lifecycle tied to Board's complete()
        attachObject(component.controller)
        component.controller.start()
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

// MARK: - {BoardName}Delegate
extension {BoardName}Board: {BoardName}Delegate {
    func activateChildBoard(context: UIViewController?) {
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoard.activation.activate(with: ChildBoardInput(context: context))
    }

    func finishFlow(output: {PublicBoardName}Output) {
        sendOutput(output)
        complete()
    }
}

// MARK: - Flow registrations
private extension {BoardName}Board {
    func registerFlows() {
        // Transport events via bus instead of calling controller directly
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoard.flow.addTarget(self) { target, output in
                target.childOutputBus.transport(input: output)
            }
    }
}
```

### Event Bus Pattern

**Why use event buses?**
1. Board remains stateless — no stored controller reference
2. Each activation creates a new controller session with fresh bus connections
3. Bus connections are automatically cleaned up when controller is deallocated
4. Decouples Board from Controller lifecycle

**Pattern:**
1. Declare `private let xxxBus = Bus<EventType>()` for each action
2. In `activate()`: `xxxBus.connect(target: controller) { controller, event in controller.handleXxx(event) }`
3. In `registerFlows()`: `xxxBus.transport(input: event)` instead of direct controller call

### Controller Attachment Context

Choose the appropriate context for attaching controller:

| Context | Lifecycle | When to use |
|---------|-----------|-------------|
| Board context (`attachObject()`) | Tied to Board's `complete()` | Preferred: controller released when Board completes |
| Root context (`rootViewController.attachObject()`) | Tied to root VC lifetime | When controller must survive beyond Board lifecycle |
| Input context (`input.context?.attachObject()`) | Tied to caller's context | When caller controls the lifecycle (e.g., presented VC) |

**Principle:** The core principle of `Attachable` is that the object is tied to the context it's attached to. Choose the context that matches the desired lifecycle:
- Board context: controller dies when Board completes
- Root context: controller lives as long as root VC
- Input context: controller lives as long as the caller's provided context (e.g., a presented navigation stack)

### Key conventions

| Rule | Detail |
|------|--------|
| **No direct controller reference** | Never store or retrieve controller reference. Use event buses for all communication. |
| Controller is `NSObject` | Required for `Attachable` conformance. |
| All state in Controller | Board must be stateless. `input`, use cases, flags, completions — all in Controller. |
| `registerFlows()` in `init` | Never in `activate`. Flows transport events via buses. |
| `delegate` is `weak` | `weak var delegate: {BoardName}ControlDelegate?` |
| **Event buses for communication** | One bus per action. Connect in `activate()`, transport in `registerFlows()`. |

---

## IO Interface for Non-UI Boards

Non-UI coordinator boards still need IO definitions — in `Sources/Microboards/{BoardName}/` (internal):

```swift
// Sources/Microboards/{BoardName}/{BoardName}IOInterface.swift
import Boardy
import Foundation
import {ModuleName}IO

// MARK: - ID (aliases the public ID it implements)
extension BoardID {
    static let mod{BoardName}: BoardID = .pub{PublicBoardName}
}

// MARK: - Interface
typealias {BoardName}MainDestination = MainboardGenericDestination<
    {BoardName}Input,
    {BoardName}Output,
    {BoardName}Command,
    {BoardName}Action
>

extension MotherboardType where Self: FlowManageable {
    func io{BoardName}(_ identifier: BoardID = .mod{BoardName}) -> {BoardName}MainDestination {
        {BoardName}MainDestination(destinationID: identifier, mainboard: self)
    }
}
```

```swift
// Sources/Microboards/{BoardName}/{BoardName}InOut.swift
import {ModuleName}IO

// Alias from the public IO types
typealias {BoardName}Input = {PublicBoardName}Input
typealias {BoardName}Parameter = BlockTaskParameter<{BoardName}Input, {BoardName}Output>
typealias {BoardName}Output = {PublicBoardName}Output
typealias {BoardName}Command = {PublicBoardName}Command
typealias {BoardName}Action = {PublicBoardName}Action
```

---

## Registration in ModulePlugin

```swift
// Flow coordinator board — built directly (no builder)
func build(with identifier: BoardID,
           sharedComponent: any SharedValueComponent,
           internalContinuousProducer: any ActivatableBoardProducer) -> any ActivatableBoard {
    {FeatureName}Board(identifier: identifier, producer: internalContinuousProducer)
}

// BlockTask board — inject use case
BoardRegistration(.mod{ModuleName}SomeTask) { identifier in
    let useCase = SomeTaskUseCase(service: sharedService)
    return SomeTaskBoard(identifier: identifier, useCase: useCase, producer: producer)
}

// Viewless board — inject builder (builder injects use cases)
func build(with identifier: BoardID,
           sharedComponent: any SharedValueComponent,
           internalContinuousProducer: any ActivatableBoardProducer) -> any ActivatableBoard {
    let builder = {BoardName}Builder(someUseCase: SomeUseCaseInteractor(repository: sharedRepository))
    return {BoardName}Board(identifier: identifier, builder: builder, producer: internalContinuousProducer)
}
```

---

## Checklist for Non-UI Board
- [ ] Extends `ModernContinuableBoard` (not plain `Board`)
- [ ] All 4 `Guaranteed*` protocol conformances + typealiases
- [ ] `registerFlows()` called in `init` (for Flow + Viewless boards)
- [ ] `activationBarrier` returns `nil` (unless barrier logic needed)
- [ ] `interact(guaranteedCommand:)` implemented (can be empty for `Void` command)
- [ ] `finishBus.deliver {}` used for input completion callbacks (Flow boards)
- [ ] Board registered in `ModulePlugin`

### `complete()` decision — apply to every board type

| Board type | Call `complete()`? |
|------------|-------------------|
| Stateless VIP / Flow board | Usually NOT — parent coordinator handles lifecycle |
| Flow board that IS the coordinator root | ✅ After `sendOutput()` to signal parent |
| Viewless board (Controller attached) | ✅ After `sendOutput()` — releases Controller + resources |
| BlockTaskBoard | ❌ Framework auto-completes after all tasks finish |

**Rules:**
- Never call `complete()` twice — raises assertion (double-complete = flow design bug)
- Always call `sendOutput()` BEFORE `complete()`
- Before calling `complete()`, confirm: all streams terminated, no observer still live, no retained reference will fire into this Board afterward

### Additional checklist for BlockTaskBoard / TaskBoard
- [ ] **Completion called on MainActor** — `await MainActor.run { completion(.success(result)) }`
- [ ] Never call `completion()` directly from background thread
- [ ] All async work wrapped in `Task { ... }`
- [ ] Do NOT call `complete()` manually — BlockTaskBoard self-completes after all tasks finish

### Additional checklist for Viewless Board
- [ ] Controller is `NSObject` subclass (required for `Attachable`)
- [ ] Board holds `private let builder: {BoardName}Buildable` (not use cases directly)
- [ ] Controller attached to appropriate context (consider lifecycle requirements)
- [ ] **No direct controller reference** — never store or retrieve controller reference directly
- [ ] **Event buses declared** — one `private let xxxBus = Bus<Type>()` per action
- [ ] **Buses connected in `activate()`** — `bus.connect(target: controller) { ... }`
- [ ] **Buses transported in `registerFlows()`** — `bus.transport(input: value)`
- [ ] All mutable state (`input`, use cases, flags) lives in Controller, not Board
- [ ] Controller's `delegate` is `weak var`
- [ ] Protocols file defines: `Controllable`, `ControlDelegate`, `Delegate`, `Interface`, `Buildable`
- [ ] `complete()` called exactly once: after `sendOutput()`, after all streams are terminated
