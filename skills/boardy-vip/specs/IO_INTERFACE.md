<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: IO Interface Definition

> **Load this spec** when defining BoardIDs, Input/Output models, Destinations, or ServiceMap for a module or microboard.
> Reference: *Modern large-scale iOS app development* — Interface Module contract from Modular + Interface Module pillar.
> Synonym: in PDF terminology this is the **Interface Module**. Companion: `EXAMPLES_IO.md` (concrete 4-file skeleton).

---

## Module-level IO Structure

Every module has one top-level `ServiceMap` class in the `IO/` folder, plus one subfolder per **public board** it exposes.

```
IO/
├── {ModuleName}ServiceMap.swift            ← Module's IO ServiceMap class
└── {PublicBoardName}/
    ├── {PublicBoardName}IOInterface.swift  ← BoardID + MainDestination typealias
    ├── {PublicBoardName}InOut.swift        ← Input, Output, Command, Action
    └── ServiceMap+{PublicBoardName}.swift  ← Extension on IO ServiceMap
```

---

## 1. Module IO ServiceMap

**File:** `IO/{ModuleName}ServiceMap.swift`

```swift
//  Compatible with Boardy 1.55.1 or later

import Boardy
import Foundation

public final class {ModuleName}ServiceMap: ServiceMap {}

public extension ServiceMap {
    var mod{ModuleName}: {ModuleName}ServiceMap { link() }
}
```

**Rules:**
- `public final class` — always `public` and `final`
- Class name: `{ModuleName}ServiceMap`
- ServiceMap property name: `mod{ModuleName}`
- This is the **only** public entry point clients import

---

## 2. BoardID + MainDestination Interface

**File:** `IO/{PublicBoardName}/{PublicBoardName}IOInterface.swift`

```swift
//  Compatible with Boardy 1.55.1 or later

import Boardy
import Foundation

// MARK: - ID

public extension BoardID {
    static let pub{PublicBoardName}: BoardID = "pub.mod.{ModuleName}IO.{PublicBoardName}"
}

// MARK: - Interface

public typealias {PublicBoardName}MainDestination = MainboardGenericDestination<
    {PublicBoardName}Input,
    {PublicBoardName}Output,
    {PublicBoardName}Command,
    {PublicBoardName}Action
>

extension MotherboardType where Self: FlowManageable {
    func io{PublicBoardName}(_ identifier: BoardID = .pub{PublicBoardName}) -> {PublicBoardName}MainDestination {
        {PublicBoardName}MainDestination(destinationID: identifier, mainboard: self)
    }
}
```

**BoardID naming — public boards (IO/):**
```
"pub.mod.{ModuleName}IO.{PublicBoardName}"
```

**BoardID naming — internal boards (Sources/):**
```
"mod.{ModuleName}.{InternalBoardName}"
```

---

## 3. InOut Models

**File:** `IO/{PublicBoardName}/{PublicBoardName}InOut.swift`

```swift
//  Compatible with Boardy 1.55.1 or later

import Boardy
import Foundation
import UIKit

// MARK: - Input

public struct {PublicBoardName}Input {
    public weak var context: UIViewController?     // presentation context (weak!)
    public let completion: (() -> Void)?

    public init(context: UIViewController? = nil, completion: (() -> Void)? = nil) {
        self.context = context
        self.completion = completion
    }
}

public typealias {PublicBoardName}Parameter = BlockTaskParameter<{PublicBoardName}Input, {PublicBoardName}Output>

// MARK: - Output

public typealias {PublicBoardName}Output = Void   // Void when no data returned
// — OR enum when output carries data —
public enum {PublicBoardName}Output {
    case completed(SomeResult)
    case cancelled
}

// MARK: - Command

public typealias {PublicBoardName}Command = Void  // Void when no commands needed
// — OR enum for reactive commands —
public enum {PublicBoardName}Command {
    case refresh
}

// MARK: - Action

public enum {PublicBoardName}Action: BoardFlowAction {}  // usually empty enum
```

**Patterns from real code:**
- `weak var context: UIViewController?` — presentation context is always `weak`
- Always include `BlockTaskParameter<Input, Output>` typealias
- Prefer `typealias XxxOutput = Void` when no data is returned
- Prefer `typealias XxxCommand = Void` when no commands needed
- `Action` enum always conforms to `BoardFlowAction`, usually left empty

---

## 4. ServiceMap Extension (IO side)

**File:** `IO/{PublicBoardName}/ServiceMap+{PublicBoardName}.swift`

```swift
//  Compatible with Boardy 1.55.1 or later

import Boardy
import Foundation

public extension {ModuleName}ServiceMap {
    var io{PublicBoardName}: {PublicBoardName}MainDestination {
        mainboard.io{PublicBoardName}()
    }
}
```

Extension is on the **module's IO ServiceMap class** (not on the global `ServiceMap`).

---

## Internal Board IO Interface (Sources/)

Internal boards live in `Sources/Microboards/{BoardName}/` with `internal` access.

**File:** `Sources/Microboards/{BoardName}/{BoardName}IOInterface.swift`

```swift
import Boardy
import Foundation
import {ModuleName}IO   // import IO module when aliasing public types

// MARK: - ID

extension BoardID {
    static let mod{BoardName}: BoardID = "mod.{ModuleName}.{BoardName}"
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

**Internal InOut** — when input/output mirrors a public type, alias it:
```swift
// Sources/Microboards/{BoardName}/{BoardName}InOut.swift
import {ModuleName}IO

typealias {BoardName}Input = {PublicBoardName}Input
typealias {BoardName}Output = {PublicBoardName}Output
typealias {BoardName}Command = {PublicBoardName}Command
typealias {BoardName}Action = {PublicBoardName}Action
```

---

## Plugins ServiceMap (Sources/)

**File:** `Sources/Plugins/{ModuleName}PluginsServiceMap.swift`

```swift
import Boardy
import Foundation

final class {ModuleName}PluginsServiceMap: ServiceMap {}   // internal — NOT public

extension ServiceMap {
    var mod{ModuleName}Plugins: {ModuleName}PluginsServiceMap { link() }
}
```

Per-board extensions in `Sources/Microboards/{BoardName}/ServiceMap+{BoardName}.swift`:

```swift
extension {ModuleName}PluginsServiceMap {
    var io{BoardName}: {BoardName}MainDestination {
        mainboard.io{BoardName}()
    }
}
```

---

## Access Modifier Summary

| File | Element | Access |
|------|---------|--------|
| `IO/{ModuleName}ServiceMap.swift` | Class + ServiceMap extension | `public` |
| `IO/{Board}/...IOInterface.swift` | BoardID, typealias, extension | `public` |
| `IO/{Board}/...InOut.swift` | Input/Output/Command/Action | `public` |
| `IO/{Board}/ServiceMap+...swift` | Extension on IO ServiceMap | `public` |
| `Sources/Plugins/...ServiceMap.swift` | ServiceMap class | `internal` (default) |
| `Sources/Microboards/...IOInterface.swift` | All | `internal` (default) |
| `Sources/Microboards/.../ServiceMap+...swift` | Extension property | `internal` (default) |
