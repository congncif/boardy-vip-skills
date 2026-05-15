<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Context Navigation & Presentation Safety

> **Load this spec** when handling navigation dismissal, presenting alerts/modals, or managing view controller context flow.
> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `.claude/rules/COMMUNICATION.md` (Bus patterns), `.claude/rules/MICROBOARD_UI.md` (Board lifecycle).

---

## Core Principles

1. **Simple back navigation** — `backToPrevious()` called on the **current ViewController** via bus
2. **Targeted return navigation** — `returnHere()` called on the **destination ViewController** via bus when flow completes
3. **Local presentation is allowed in the current ViewController** — alerts/sheets that purely render the current screen's state may be presented by that ViewController
4. **Out-of-scope presentation goes through Board-safe context** — alerts/modals managed by another board, cross-flow confirmation, or presentation whose correct context is not the current ViewController must use `rootViewController.topPresentedViewController`

---

## Navigation Decision Tree

```
Need to dismiss/navigate back?
│
├─ Simple back to previous screen (one step)?
│   YES → Connect bus to current ViewController
│         Call viewController.backToPrevious() when bus fires
│
└─ Need to return to a specific destination after multi-step flow?
    YES → Follow Targeted Return Pattern:
          1. Destination Board (coordinator) declares returnBus
          2. Connect returnBus to destination's ViewController.returnHere()
          3. Child boards send output when done
          4. Coordinator's registerFlows() transports returnBus on specific output
          
          ⚠️ NEVER call rootViewController.returnHere() blindly
             rootViewController is root context, not the destination ViewController
```

---

## Pattern 1: Simple Back Navigation (backToPrevious)

Use when: the screen just needs to go back one step in the navigation stack.

### Diagram

```
┌─────────────────────────────────────────────────────────┐
│ {FeatureName}Board                                      │
│                                                         │
│ activate():                                             │
│   cancelBus.connect(target: {FeatureName}ViewController)│
│     → viewController.backToPrevious()                   │
│                                                         │
│ delegate method:                                        │
│   cancel() → cancelBus.transport()                      │
│                    ↓                                    │
│           triggers backToPrevious()                     │
│           on {FeatureName}ViewController                │
│                    ↓                                    │
│           navigates back one step                       │
└─────────────────────────────────────────────────────────┘
```

### Implementation

```swift
// {FeatureName}Board.swift
final class {FeatureName}Board: ModernContinuableBoard, ... {
    private let cancelBus = Bus<Void>()
    
    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        
        // Connect bus to current ViewController
        cancelBus.connect(target: component.userInterface) { viewController in
            viewController.backToPrevious()  // ✅ Called on current VC
        }
        
        watch(content: component.controller)
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
    }
}

extension {FeatureName}Board: {FeatureName}Delegate {
    func cancel() {
        cancelBus.transport()  // Trigger backToPrevious on current VC
        sendOutput(.cancelled)
    }
}
```

**Key insight:** `backToPrevious()` is called on the **current screen's ViewController**, not on rootViewController or any parent.

---

## Pattern 2: Targeted Return Navigation (returnHere)

Use when: a multi-step flow must return to a **specific destination screen** after completion.

### Step 1: Destination Board declares returnBus and connects to its ViewController

```swift
// {CoordinatorName}Board.swift (destination/coordinator)
final class {CoordinatorName}Board: ModernContinuableBoard, ... {
    private let returnBus = Bus<Void>()
    
    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        
        // Connect returnBus to destination's ViewController
        returnBus.connect(target: component.userInterface) { viewController in
            viewController.returnHere()  // ✅ Called on {CoordinatorName}ViewController (destination)
        }
        
        watch(content: component.controller)
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
    }
}
```

### Step 2: Coordinator's registerFlows() transports returnBus on child completion

```swift
// {CoordinatorName}Board.swift
private extension {CoordinatorName}Board {
    func registerFlows() {
        // Listen to child completion
        motherboard.serviceMap.mod{ModuleName}Plugins
            .io{ChildName}.flow.addTarget(self) { target, output in
                switch output {
                case .retry(let data):
                    // Restart child with new data
                    target.motherboard.serviceMap.mod{ModuleName}Plugins
                        .io{OtherChild}.activation.activate(with: data)
                case .backToCoordinator:
                    // Return to coordinator (this board's ViewController)
                    target.returnBus.transport()  // ✅ Triggers returnHere on {CoordinatorName}ViewController
                }
            }
    }
}
```

### Step 3: Child Board sends output (no direct navigation)

```swift
// {ChildName}Board.swift
extension {ChildName}Board: {ChildName}Delegate {
    func backToCoordinator() {
        sendOutput(.backToCoordinator)  // Parent coordinator handles navigation
        complete()
    }
}
```

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ {CoordinatorName}Board (coordinator/destination)               │
│                                                                 │
│ activate():                                                     │
│   returnBus.connect(target: {CoordinatorName}ViewController)   │
│     → viewController.returnHere()                               │
│                                                                 │
│ registerFlows():                                                │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ {ChildA}.flow → .next:                                  │  │
│   │   └─ activate {ChildB}                                  │  │
│   │                                                         │  │
│   │ {ChildB}.flow → .completed:                            │  │
│   │   └─ transport dataBus (to controller)                 │  │
│   │                                                         │  │
│   │ {ChildC}.flow:                                         │  │
│   │   ├─ .retry → activate {ChildB} (replace)             │  │
│   │   └─ .backToCoordinator → returnBus.transport()       │  │
│   │                             ↓                           │  │
│   │                    triggers returnHere()                │  │
│   │                    on {CoordinatorName}ViewController   │  │
│   └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐        ┌──────────┐        ┌──────────┐
   │ {ChildA} │  next  │ {ChildB} │  done  │ {ChildC} │
   │  Board   │───────>│  Board   │───────>│  Board   │
   └──────────┘        └──────────┘        └──────────┘
        │                                        │
        │ .cancelled                             │ .backToCoordinator
        │                                        │
        └────────────────────┬───────────────────┘
                             ▼
                    returnBus.transport()
                             ↓
              {CoordinatorName}ViewController.returnHere()
```

**Key insight:** The **destination Board** (coordinator) owns the `returnHere()` call via bus connected to its own ViewController. Child boards only send output; the coordinator decides when and where to return.

---

## Pattern 3: Local vs Out-of-Scope Alert/Modal Presentation

Use local ViewController presentation when the alert/sheet is a pure rendering concern for the current screen, such as validation feedback, purchase result messages, or a confirmation whose data and lifecycle belong entirely to that ViewController.

Use Board-safe topmost presentation when the alert/modal is out of scope of the current ViewController: another Board owns it, the current context lacks enough information to choose the presenter, the presentation crosses flow boundaries, or the current context may already be stale/dismissed.

### Diagram

```
Presentation Chain:
┌──────────────────────────────────────────────────────────┐
│ Window                                                   │
│   └─ RootViewController (rootViewController)            │
│       └─ NavigationController                            │
│           └─ {FeatureA}ViewController                    │
│               └─ {FeatureB}ViewController (presented)    │
│                   └─ {FeatureC}ViewController (presented)│ ← topPresentedViewController
│                       ↑                                  │
│                       │                                  │
│                  Present alert HERE                      │
│                  (always on topmost)                     │
└──────────────────────────────────────────────────────────┘

❌ WRONG: rootViewController.present(alert, ...)
   → Presents from Window root, may be behind other VCs

✅ CORRECT: rootViewController.topPresentedViewController.present(alert, ...)
   → Presents from topmost VC in chain
```

### Problem: Detached View Controller Warning

```
⚠️ WARNING: Presenting view controller <AlertVC> from detached view controller <MyVC> 
is not supported, and may result in incorrect safe area insets and a corrupt root presentation.
```

This happens when:
- The presenting view controller is no longer in the hierarchy
- Another modal is already presented
- The context has been dismissed but still holds a reference

### Solution: choose presenter by ownership

If the current ViewController owns the message and is still the active context, present locally:

```swift
private extension {FeatureName}ViewController {
    func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

If the presentation is out of scope of the current ViewController, present on `topPresentedViewController` from the Board:

```swift
// ✅ CORRECT — present on top of the presentation chain
extension {FeatureName}Board: {FeatureName}Delegate {
    func showConfirmation(message: String) {
        let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.confirmBus.transport(input: ())
        })
        
        // ✅ Present on topmost presented VC
        rootViewController.topPresentedViewController.present(alert, animated: true)
    }
    
    func showModal(with data: SomeData) {
        let modalVC = {Modal}ViewController(data: data)
        let navigationController = UINavigationController(rootViewController: modalVC)
        
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        // ✅ Present on topmost VC
        rootViewController.topPresentedViewController.present(navigationController, animated: true)
    }
}
```

```swift
// ❌ WRONG — may present from detached VC
rootViewController.present(alert, animated: true)  // rootViewController might not be topmost

// ❌ WRONG — context might be stale
input.context?.present(alert, animated: true)  // context might be dismissed
```

### topPresentedViewController Helper

If not available in SiFUtilities, add this extension:

```swift
extension UIViewController {
    var topPresentedViewController: UIViewController {
        var top = self
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
```

**Key insight:** Presentation ownership determines the presenter. Current-screen alerts/sheets can be presented by the current ViewController. Cross-board, cross-flow, or stale-context-risk presentations use `rootViewController.topPresentedViewController` so they appear on the topmost view controller in the presentation chain.

---

## Context Passing Guidelines

### When to pass context

```swift
// ✅ Pass rootViewController as context for child boards
motherboard.serviceMap.mod{ModuleName}Plugins
    .io{ChildName}.activation.activate(
        with: {ChildName}Input(
            data: data, 
            context: rootViewController  // Parent's rootViewController
        )
    )

// ✅ Pass for modals that need to present on top
motherboard.serviceMap.mod{ModuleName}Plugins
    .io{ModalName}.activation.activate(
        with: {ModalName}Input(
            data: data,
            context: rootViewController  // For potential modals
        )
    )
```

### When NOT to pass context

- Don't pass for simple navigation stack pushes where child doesn't need to present anything
- Don't pass stale context from input — always use current `rootViewController`

---

## Anti-Patterns to Avoid

| Anti-Pattern | Why it's wrong | Correct Pattern |
|-------------|----------------|-----------------|
| `rootViewController.backToPrevious()` | `rootViewController` is root context, not current VC | Connect bus to current ViewController: `cancelBus.connect(target: component.userInterface) { $0.backToPrevious() }` |
| `rootViewController.returnHere()` | `rootViewController` is root context, not destination VC | Connect bus to destination ViewController: `returnBus.connect(target: component.userInterface) { $0.returnHere() }` |
| `context?.present(alert, ...)` for out-of-scope presentation | Context may be dismissed/detached | `rootViewController.topPresentedViewController.present(...)` |
| Delegating every local alert to Board | Adds routing ceremony for current-screen rendering | Present local alerts/sheets directly from the current ViewController when it owns the message and context |
| Child Board navigating directly | Breaks coordinator pattern | Child sends output; coordinator handles navigation via registerFlows() |
| Calling navigation methods without bus | Tight coupling, no lifecycle safety | Always use Bus to decouple Board from ViewController lifecycle |

---

## Checklist for Navigation Code Review

### Simple Back Navigation
- [ ] `cancelBus` (or similar) declared in Board
- [ ] Bus connected to **current ViewController** in `activate()`
- [ ] `viewController.backToPrevious()` called when bus fires
- [ ] Bus transported from delegate method
- [ ] `sendOutput()` called after bus transport

### Targeted Return Navigation
- [ ] `returnBus` declared in **destination Board** (coordinator)
- [ ] Bus connected to **destination's ViewController** in `activate()`
- [ ] `viewController.returnHere()` called when bus fires
- [ ] Coordinator's `registerFlows()` transports bus on child completion output
- [ ] Child Board sends output only (no direct navigation)
- [ ] Never `rootViewController.returnHere()` — always via bus to specific ViewController

### Alert/Modal Presentation
- [ ] Current-screen alerts/sheets may be presented directly by the current ViewController when the message is pure rendering for that screen
- [ ] Cross-board, cross-flow, or stale-context-risk alerts/modals present on `rootViewController.topPresentedViewController`
- [ ] Never presents out-of-scope UI on bare `rootViewController` or stale `context`
- [ ] Sheet presentation configured if needed (detents, grabber)
- [ ] No "detached view controller" warnings in console

### Context Passing
- [ ] Context passed as `rootViewController` when child needs it
- [ ] Context used for child board activation, not stored on Board
- [ ] Context not passed for simple navigation stack pushes

### Bus Usage for Navigation
- [ ] No direct navigation method calls without bus
- [ ] All navigation triggered via bus transport
- [ ] Buses connected in `activate()`, transported in delegate methods or `registerFlows()`

---

## Complete Example: Multi-Step Flow

```swift
// CoordinatorBoard.swift (destination)
final class CoordinatorBoard: ModernContinuableBoard, ... {
    private let returnBus = Bus<Void>()
    
    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        
        // Connect returnBus to destination ViewController
        returnBus.connect(target: component.userInterface) { viewController in
            viewController.returnHere()  // ✅ Return to this screen
        }
        
        watch(content: component.controller)
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
    }
}

extension CoordinatorBoard: CoordinatorDelegate {
    func startFlow() {
        motherboard.serviceMap.mod{ModuleName}Plugins
            .io{ChildA}.activation.activate(with: {ChildA}Input(context: rootViewController))
    }
}

private extension CoordinatorBoard {
    func registerFlows() {
        // ChildA → ChildB
        motherboard.serviceMap.mod{ModuleName}Plugins
            .io{ChildA}.flow.addTarget(self) { target, output in
                switch output {
                case .next:
                    target.motherboard.serviceMap.mod{ModuleName}Plugins
                        .io{ChildB}.activation.activate(with: {ChildB}Input(context: target.rootViewController))
                case .cancelled:
                    break
                }
            }
        
        // ChildB → return to Coordinator
        motherboard.serviceMap.mod{ModuleName}Plugins
            .io{ChildB}.flow.addTarget(self) { target, output in
                switch output {
                case .completed:
                    target.returnBus.transport()  // ✅ Triggers returnHere on CoordinatorViewController
                case .cancelled:
                    break
                }
            }
    }
}

// ChildABoard.swift
final class {ChildA}Board: ModernContinuableBoard, ... {
    private let cancelBus = Bus<Void>()
    
    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        
        // Connect to current ViewController
        cancelBus.connect(target: component.userInterface) { viewController in
            viewController.backToPrevious()  // ✅ Back from ChildA
        }
        
        watch(content: component.controller)
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
    }
}

extension {ChildA}Board: {ChildA}Delegate {
    func cancel() {
        cancelBus.transport()
        sendOutput(.cancelled)
    }
    
    func proceed() {
        sendOutput(.next)  // Coordinator handles next step
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // ✅ Present on topmost VC
        rootViewController.topPresentedViewController.present(alert, animated: true)
    }
}
```

---

## Integration with Existing Specs

This spec complements:

- **`.claude/rules/COMMUNICATION.md`** — Bus patterns for Board↔Controller communication
- **`.claude/rules/MICROBOARD_UI.md`** — Board lifecycle and presentation basics
- **`.claude/rules/MICROBOARD_NONUI.md`** — Flow Board coordination patterns

Add to review checklist in `.claude/rules/REVIEWER_CHECKLIST.md`:

```markdown
## Context Navigation (check every PR with navigation)

- [ ] `backToPrevious()` called on current ViewController via bus (not rootViewController)
- [ ] `returnHere()` called on destination ViewController via bus (not rootViewController)
- [ ] Return bus connected at destination Board, transported from coordinator's registerFlows()
- [ ] Child boards send output only; coordinator handles navigation
- [ ] Alerts/modals presented on `rootViewController.topPresentedViewController`
- [ ] No "detached view controller" warnings
- [ ] Context passed as `rootViewController` when needed
- [ ] No direct navigation method calls without bus
```
