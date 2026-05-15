# SPEC: Activation Barrier

> **Load this spec** when a board's activation must be gated behind another board completing first — e.g. show an ad before a game session, enforce a permission check before a feature, gate a flow behind a login wall.
> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `.claude/rules/MICROBOARD_NONUI.md` (non-UI board types), `.claude/rules/PER_ACTIVATION_RESOURCES.md` (per-activation lifecycle), `.claude/rules/COMMUNICATION.md` (`complete()` semantics).

---

## What is an Activation Barrier?

An **Activation Barrier** is a mechanism that intercepts a board's `activate()` call, runs a gating board first, and then allows the original activation to proceed.

| Role | Responsibility |
|------|---------------|
| **Gated Board** | The board whose activation is intercepted. Declares `activationBarrier` returning a non-nil value. |
| **Barrier Board** | The board that runs first. Must call `complete()` when done — this is the signal to release the gate. |
| **`ActivationBarrier`** | Value returned by `activationBarrier(withGuaranteedInput:)` — describes which board to run and its scope. |

`complete()` defaults to `isDone: true`, meaning **every board that calls `complete()` implicitly passes the barrier**. There is no separate "block" vs "allow" signal — calling `complete()` always lets the gated board through.

---

## Decision Tree

```
Need to run Board A before Board B activates?
│
├── Does Board A call complete() at the end of its work?
│   YES → Board A qualifies as a barrier board.
│         Set Board B's activationBarrier to return Board A's barrier.
│   NO  → Board A cannot be a barrier. Refactor Board A to call complete(),
│         or use a Flow Board coordinator instead.
│
└── Should the barrier be shared app-wide (one instance, reused)?
    YES → scope: .application
    NO  → scope: .mainboard  (new instance per activation — default choice)
```

---

## Qualifying a Board as a Barrier

Any board that calls `complete()` at the end of its lifecycle qualifies. No structural changes are needed — `complete()` is the barrier signal.

```swift
// Board A qualifies if it has this exit pattern:
func finish(_ result: SomeResult) {
    sendOutput(result)
    complete()   // ← this is the barrier signal; always passes through
}
```

Common boards that naturally qualify: ad show boards, permission request boards, onboarding splash boards, paywall boards.

---

## Declaring the Barrier on the Gated Board

Override `activationBarrier(withGuaranteedInput:)` on the gated board:

```swift
// {GatedName}Board.swift
func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? {
    motherboard.serviceMap.mod{BarrierModule}
        .io{BarrierName}
        .activation
        .barrier(scope: .mainboard, with: {BarrierName}Input())
}
```

**Scope:**

| Scope | Behavior | When to use |
|-------|----------|-------------|
| `.mainboard` | New `ActivatableBarrierBoard` per activation — self-destructs after use | Default. Per-session gates (ads, per-flow checks) |
| `.application` | One shared instance app-wide — created once, reused forever | Login wall, subscription gate |

---

## Input: `.barrier(with:)` vs `.barrier()`

**Always use `.barrier(with: {BarrierName}Input(...))` when `InputType` is not `Void`.**

`.barrier()` uses the `.void` option which passes `()` internally. When the framework tries to cast `()` to a non-Void `InputType`, the cast fails silently and the barrier board never activates.

```swift
// ✅ CORRECT — typed input, barrier activates properly
.barrier(scope: .mainboard, with: {BarrierName}Input())

// ❌ WRONG — .barrier() passes Void; cast to {BarrierName}Input fails silently
.barrier(scope: .mainboard)

// ✅ Safe only when typealias {BarrierName}Input = Void
.barrier(scope: .mainboard)
```

---

## "Close → Play" Pattern (Always-Passthrough Barrier)

The most common use case: run Board A first, and **always** proceed to Board B regardless of Board A's outcome. No extra code needed — `complete()` == `complete(isDone: true)` always passes through.

```swift
// {BarrierName}Board.swift — all exit paths call complete()
func finish(_ result: {BarrierName}Result) {
    sendOutput(result)   // e.g. .shown / .skipped / .notEligible / .failed
    complete()           // ← barrier always passes through regardless of result
}
```

The gated board activates after *any* barrier outcome. If the parent coordinator also needs the barrier result, it registers a flow handler in `registerFlows()`.

---

## Listening to Barrier Board Output (Optional)

If the gated board's parent coordinator needs the barrier board's result, register a flow handler alongside the normal gated board flow:

```swift
private extension {CoordinatorName}Board {
    func registerFlows() {
        // Listen to barrier board output (e.g. to log or react to result)
        motherboard.serviceMap.mod{BarrierModule}Plugins
            .io{BarrierName}.flow.addTarget(self) { target, result in
                switch result {
                case .succeeded:
                    target.recordSuccess()
                default:
                    break
                }
            }

        // Listen to gated board output as usual
        motherboard.serviceMap.mod{Module}Plugins
            .io{GatedName}.flow.addTarget(self) { target, output in
                target.handleGatedOutput(output)
            }
    }
}
```

---

## Barrier Board Output as a Public Contract

When the barrier board's outcome matters to callers, `OutputType` must carry a typed result — not `Void`.

```swift
// {BarrierName}InOut.swift
public typealias {BarrierName}Output = {BarrierName}Result

public enum {BarrierName}Result {
    case succeeded
    case skipped
    case notEligible
    case failed
}
```

All controller exit paths must pass the result to `delegate?.finish(_ result:)`, and the board's `finish` method passes it to `sendOutput` before `complete()`:

```swift
// {BarrierName}Board.swift
extension {BarrierName}Board: {BarrierName}Delegate {
    func finish(_ result: {BarrierName}Result) {
        sendOutput(result)   // result available to .flow listeners
        complete()           // barrier passes through
    }
}
```

---

## Code Skeleton: Gated Board

```swift
// {GatedName}Board.swift
import {BarrierModule}   // ← import barrier board's module

final class {GatedName}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    // ... typealiases, builder, buses, init ...

    func activate(withGuaranteedInput input: InputType) {
        // ... normal activation ...
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? {
        motherboard.serviceMap.mod{BarrierModule}
            .io{BarrierName}
            .activation
            .barrier(scope: .mainboard, with: {BarrierName}Input())
    }

    func interact(guaranteedCommand: CommandType) {}
}
```

**Dependency wiring** (when barrier board lives in a different module):
- Gated board's Plugins podspec: `s.dependency '{BarrierModule}'`
- Gated board file: `import {BarrierModule}`

---

## Anti-Patterns

| Anti-Pattern | Why wrong | Correct pattern |
|---|---|---|
| `.barrier()` with non-Void InputType | Passes `()` — cast fails silently, barrier never runs | `.barrier(with: {BarrierName}Input(...))` |
| `scope: .application` for per-session gates | Shared barrier survives across sessions — wrong lifecycle | Use `scope: .mainboard` |
| Barrier board NOT calling `complete()` in every path | Gated board never activates — hangs forever | Ensure all exit paths call `complete()` after `sendOutput()` |
| Chaining barriers (`activationBarrier` on the barrier board itself) | Chaining barriers is not supported | Use a Flow Board coordinator instead |
| Registering barrier board `.flow` listener inside `activate()` | `registerFlows()` must be in `init` | Register in `registerFlows()` called from `init` |

---

## Checklist

### Gated Board
- [ ] `activationBarrier(withGuaranteedInput:)` returns non-nil barrier
- [ ] Uses `.barrier(with: {BarrierName}Input(...))` — not `.barrier()` — when InputType ≠ Void
- [ ] Correct scope: `.mainboard` for per-session; `.application` for app-wide singleton
- [ ] When barrier board is in a different module: Plugins podspec adds `s.dependency '{BarrierModule}'`
- [ ] When barrier board is in a different module: `import {BarrierModule}` at top of Board file

### Barrier Board
- [ ] Every exit path calls `sendOutput(result)` then `complete()` — no path skips `complete()`
- [ ] `OutputType` carries a typed result enum (not `Void`) when callers need to distinguish outcomes
- [ ] All controller exit paths pass the result to `delegate?.finish(_ result:)`
- [ ] No double-`complete()` — all exit paths lead to exactly one `complete()` call

### Coordination
- [ ] If parent coordinator needs barrier result: flow handler registered in `registerFlows()` on `.io{BarrierName}.flow`
- [ ] Gated board activation flows through normal coordinator `registerFlows()` on `.io{GatedName}.flow`
