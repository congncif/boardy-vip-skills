---
name: boardy-module
description: Use when creating a new Boardy+VIP feature module — covers directory setup, podspec templates, LauncherPlugin wiring, and first module validation checklist
version: 1.2.0
---

# Boardy+VIP Module Creation

## Overview

Every module splits into two targets: **IO** (public interface) and **Plugins** (internal implementation). Consumers only ever import the IO target.

## Step-by-Step

### 1. Determine Module Name

| Scenario | Module name |
|----------|------------|
| No prefix | `Profile` |
| With prefix `DAD` | `DADProfile` (VIP classes still use `Profile`) |

### 2. Create Directory

```bash
mkdir -p {ModuleRoot}/{ModuleName}
```

> Module lives at `{ModuleRoot}/{ModuleName}/` — **never nested inside another module**.

### 3. Run Init Script (if available)

```bash
sh ../../scripts/init-module.sh Profile
# or with prefix:
sh ../../scripts/init-module.sh DADProfile DAD
```

### 4. Verify Generated Structure

```
{ModuleName}/
├── {ModuleName}.podspec
├── {ModuleNamePlugins}.podspec
├── IO/
│   ├── {ModuleName}ServiceMap.swift
│   └── {NoPrefixName}/
│       ├── {NoPrefixName}IOInterface.swift
│       ├── {NoPrefixName}InOut.swift
│       └── ServiceMap+{NoPrefixName}.swift
└── Sources/
    ├── Plugins/
    │   ├── {ModuleName}PluginsServiceMap.swift
    │   └── {NoPrefixName}ModulePlugin.swift
    ├── Microboards/
    └── Services/
        ├── Domain/{Models, Repositories, Services}
        ├── Application/
        └── Infra/
```

### 5. Wire the module into the dependency manager

Branch on the project's `Dependency manager` value from `{ProjectConfigPath}` §3.

#### 5a. CocoaPods path

```ruby
# Always hash-rocket syntax, never keyword syntax
pod '{ModuleName}',        :path => '{ModuleRoot}/{ModuleName}'
pod '{ModuleNamePlugins}', :path => '{ModuleRoot}/{ModuleName}'
```

Run:
```bash
pod install
```

> **Always run after**: new module, new pod dependency, changed `source_files` glob, new Swift files added outside Xcode.

#### 5b. SwiftPM path

Create a single `Package.swift` at `{ModuleRoot}/{ModuleName}/Package.swift` exposing both targets:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "{ModuleName}",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "{ModuleName}", targets: ["{ModuleName}"]),
        .library(name: "{ModuleName}Plugins", targets: ["{ModuleName}Plugins"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/congncif/boardy", from: "x.y.z"),
    ],
    targets: [
        .target(name: "{ModuleName}", dependencies: ["Boardy"], path: "IO"),
        .target(name: "{ModuleName}Plugins", dependencies: ["{ModuleName}", "Boardy", "SiFUtilities"], path: "Sources"),
    ]
)
```

Wire it into the app:
- Xcode → app project → Package Dependencies → **Add Local…** → select `{ModuleRoot}/{ModuleName}/`
- Add `{ModuleName}` and `{ModuleName}Plugins` to the app target's frameworks
- No equivalent of `pod install`; SPM resolves on build.

#### 5c. Both

Apply 5a for app/workspace and 5b for module-internal package surface only where required. Avoid mixing for the same module unless there is a documented reason recorded under `{DecisionsPath}`.

### 6. Wire LauncherPlugin

Find the app entry file (SceneDelegate or AppDelegate):

```swift
import {ModuleNamePlugins}   // ← Plugins target, not IO

PluginLauncher.with(options: .default)
    .install(launcherPlugin: ExistingPlugin())
    .install(launcherPlugin: {Name}LauncherPlugin())   // ← add here
    .initialize()
    .launch(in: window) { motherboard in
        motherboard.serviceMap.mod{ModuleName}
            .io{EntryBoard}.activation.activate(with: {EntryBoard}Input())
    }
```

## Dependency manifests

> Use the manifest type that matches the project's `Dependency manager` setting in `{ProjectConfigPath}` §3. CocoaPods projects get podspecs; SwiftPM projects get the single `Package.swift` from step 5b; "Both" projects ship both manifests.

### CocoaPods — IO podspec

```ruby
Pod::Spec.new do |s|
  s.name             = '{ModuleName}'
  s.version          = '0.1.0'
  s.summary          = '{ModuleName} interface module.'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.source_files     = 'IO/**/*.swift'
  s.dependency 'Boardy'
end
```

### CocoaPods — Plugins podspec

```ruby
Pod::Spec.new do |s|
  s.name             = '{ModuleNamePlugins}'
  s.version          = '0.1.0'
  s.summary          = '{ModuleName} implementation module.'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.source_files     = 'Sources/**/*.swift'
  s.dependency '{ModuleName}'
  s.dependency 'Boardy'
  s.dependency 'SiFUtilities'
end
```

> `s.dependency` takes name only — **never** add `:path =>` inside podspec.

## LauncherPlugin Template

```swift
public struct {Name}LauncherPlugin: LauncherPlugin {
    public init() { /**/ }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        ModuleComponent(
            modulePlugins: {Name}ModulePlugin.ServiceType.allCases.map {
                {Name}ModulePlugin(service: $0)
            }
        )
    }
}
```

## ModulePlugin Template

```swift
struct {Name}ModulePlugin: ModuleBuilderPlugin {
    enum ServiceType: CaseIterable {
        case `default`
        var identifier: BoardID {
            switch self { case .default: .pub{EntryBoard} }
        }
    }

    let sharedRepository: {Entity}Repository = {Entity}MemoryStorageRepository()
    let service: ServiceType
    var identifier: BoardID { service.identifier }

    func build(with identifier: BoardID,
               sharedComponent: any SharedValueComponent,
               internalContinuousProducer: any ActivatableBoardProducer) -> any ActivatableBoard {
        {EntryBoard}Board(identifier: identifier, producer: internalContinuousProducer)
    }

    func internalContinuousRegistrations(
        sharedComponent: any SharedValueComponent,
        producer: any ActivatableBoardProducer
    ) -> [BoardRegistration] {
        BoardRegistration(.mod{ChildBoard}) { identifier in
            {ChildBoard}Board(
                identifier: identifier,
                builder: {ChildBoard}Builder(repository: sharedRepository),
                producer: producer
            )
        }
    }
}
```

## Validation Checklist

- [ ] Module at `{ModuleRoot}/{ModuleName}/` (not nested)
- [ ] Dependency manifest matches `{ProjectConfigPath}` §3:
  - CocoaPods → two podspecs (IO + Plugins) with hash-rocket Podfile entries, `s.dependency` name-only, `pod install` run
  - SwiftPM → single `Package.swift` with two products and two `.target(path:)` entries, added to Xcode as a Local Package
  - Both → both manifests present, no contradictions
- [ ] IO scope: `IO/**/*.swift` (podspec `source_files` or SwiftPM `.target(path: "IO")`)
- [ ] Plugins scope: `Sources/**/*.swift` (podspec `source_files` or SwiftPM `.target(path: "Sources")`)
- [ ] LauncherPlugin wired in app entry file
- [ ] App entry imports `{ModuleNamePlugins}`, not `{ModuleName}`
- [ ] Build succeeds
