<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Module Creation

> **Load this spec** when creating a new module, scaffolding a feature module, or setting up a new submodule.
> Reference: *Modern large-scale iOS app development* — Modular + Interface Module pillar.
> Companion specs: `.claude/rules/IO_INTERFACE.md` (IO layer details), `.claude/rules/PLUGINS_INTEGRATION.md` (LauncherPlugin wiring), `.claude/rules/PROJECT_CONFIG.md` (project-specific values).

## Overview

A Module is the top-level container for a feature domain. Every module splits into two podspecs/targets:
- `{ModuleName}` → IO target (public interface, imported by other modules)
- `{ModuleNamePlugins}` → Sources target (implementation, never imported externally)

## Step-by-Step: Creating a New Module

### Step 1 — Determine Module Name

- Prefix is **optional** — only use it when explicitly specified by the user.

| Scenario | Module name | No-prefix name |
|----------|-------------|----------------|
| No prefix | `Profile` | `Profile` |
| With prefix `DAD` | `DADProfile` | `Profile` |
| With prefix `MOD` | `MODPayment` | `Payment` |

The **no-prefix name** is used for all Swift VIP class names (Interactor, Presenter, etc.).

### Step 2 — Create Module Directory

```bash
mkdir -p {ModuleRoot}/{ModuleName}
cd {ModuleRoot}/{ModuleName}
```

> ⚠️ **Module placement rule:** Every module lives directly under `{ModuleRoot}/{ModuleName}/` — at the same level as other modules. **Never nest a module inside another module's folder.**
> - ✅ `{ModuleRoot}/{ModuleA}/` and `{ModuleRoot}/{ModuleB}/` (siblings)
> - ❌ `{ModuleRoot}/{ModuleA}/{ModuleB}/`  (wrong — nested inside another module)

### Step 3 — Run Init Script

```bash
# No prefix:
sh ../../scripts/init-module.sh Profile

# With explicit prefix:
sh ../../scripts/init-module.sh DADProfile DAD
```

> ⚠️ The script defaults internally to `DAD` if PREFIX is omitted, which would misname files. Always pass PREFIX explicitly when there is one, or use the no-prefix form.

### Step 4 — Verify Generated Structure

```
{ModuleName}/
├── {ModuleName}.podspec                        ← IO target podspec
├── {ModuleNamePlugins}.podspec                 ← Plugins target podspec
├── IO/
│   ├── {ModuleName}ServiceMap.swift            ← public IO ServiceMap class
│   └── {NoPrefixName}/                         ← one subfolder per public board
│       ├── {NoPrefixName}IOInterface.swift
│       ├── {NoPrefixName}InOut.swift
│       └── ServiceMap+{NoPrefixName}.swift
└── Sources/
    ├── Plugins/
    │   ├── {ModuleName}PluginsServiceMap.swift ← internal Plugins ServiceMap
    │   └── {NoPrefixName}ModulePlugin.swift    ← ModuleBuilderPlugin + LauncherPlugin
    ├── Shared/
    │   ├── Extensions/                         ← UIViewController++, UIView++, etc.
    │   └── UIComponents/                       ← Shared views/cells within module
    ├── Microboards/                            ← Empty, ready for boards
    └── Services/
        ├── Domain/
        │   ├── Models/
        │   ├── Repositories/
        │   └── Services/
        ├── Application/                        ← UseCases
        ├── Infra/                              ← Network, Storage
        └── Tracking/                           ← Analytics
```

> **Note:** The template from `init-module.sh` uses `Sources/Components/` and `Sources/Integration/` folder names. After running the script, rename them to match this standard layout:
> - `Sources/Components/` → `Sources/Plugins/`
> - `Sources/Integration/` → merge into `Sources/Plugins/`

### Step 5 — Add Podfile Entries

```ruby
# Podfile — always use :path => (hash-rocket), NOT path: (keyword syntax)
pod '{ModuleName}',        :path => '{ModuleRoot}/{ModuleName}'
pod '{ModuleNamePlugins}', :path => '{ModuleRoot}/{ModuleName}'
```

> ⚠️ **CocoaPods Podfile syntax:** Local pod paths must use `:path =>` (Ruby hash-rocket), not `path:` (keyword syntax). The keyword form is not valid in CocoaPods Podfile DSL.

### Step 5a — Run pod install

After editing the Podfile or any podspec (new module, new dependency, changed source_files/resources), always run:

```bash
pod install
```

This regenerates the Xcode project so new Swift files and dependencies are recognised by the build system. **Never skip this step.**

> Trigger `pod install` whenever:
> - A new module is created (Podfile entries added)
> - A new pod dependency is added/removed in a `.podspec`
> - `source_files` or `resources` globs change in a `.podspec`
> - New Swift source files are added outside Xcode (e.g. created by the AI agent directly)

### xcodebuild — Standard Build Workflow

Always follow this 2-step workflow when running `xcodebuild`:

**Step 1: List available destinations**

```bash
xcodebuild -workspace {Workspace} -list
xcodebuild build -workspace {Workspace} -scheme {MainScheme} -showdestinations
```

Pick an available scheme and device from the output (or use `{Destination}` from `.claude/rules/PROJECT_CONFIG.md` when present).

**Step 2: Build & filter output to essentials**

Use `grep -E` to extract only what matters: errors, warnings, and final status. Never use `-quiet` (it suppresses errors too).

```bash
# Build — filtered output (errors + status only)
xcodebuild build -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# Test — filtered output
xcodebuild test -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' 2>&1 \
  | grep -E "(error:|warning:|FAILED|PASSED|TEST SUCCEEDED|TEST FAILED|BUILD SUCCEEDED|BUILD FAILED)"
```

> **Critical rules:**
> - **Never use `-quiet`** — it hides errors and produces misleading silent failures
> - **Empty output = ERROR**, not success. If grep returns nothing, the command failed silently (wrong scheme, wrong destination, xcodebuild crash). Re-run without grep to see full output and report to the user.
> - Always confirm `** BUILD SUCCEEDED **` or `** BUILD FAILED **` is present in the output
> - If the build fails, re-run `2>&1 | grep -B 2 -A 5 "error:"` to get error context
> - Use an actual available scheme/device name from step 1

### Step 6 — Wire LauncherPlugin via PluginLauncher

Find the app entry file that owns `UIWindow` (declared in `.claude/rules/PROJECT_CONFIG.md`; commonly `SceneDelegate` for UIKit scene apps or `AppDelegate` for older UIKit apps).

**If PluginLauncher is not yet set up**, add it:

```swift
// AppEntry.swift (for example: SceneDelegate.swift or AppDelegate.swift)
import Boardy
import {ModuleNamePlugins}
import UIKit

func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    let window = UIWindow(windowScene: windowScene)
    self.window = window

    PluginLauncher.with(options: .default)
        .install(launcherPlugin: {NoPrefixName}LauncherPlugin())
        .initialize()
        .launch(in: window) { motherboard in
            motherboard.serviceMap.mod{ModuleName}
                .io{EntryBoardName}.activation.activate(with: {EntryBoardName}Input())
        }
}
```

**If PluginLauncher already exists**, add `.install(launcherPlugin:)` for the new module before `.initialize()`:

```swift
PluginLauncher.with(options: .default)
    .install(launcherPlugin: ExistingLauncherPlugin())
    .install(launcherPlugin: {NoPrefixName}LauncherPlugin())   // ← add here
    .initialize()
    .launch(in: window) { ... }
```

> **Rules:**
> - Import `{ModuleNamePlugins}` (not `{ModuleName}`) in the app entry file — the LauncherPlugin is in the Plugins target
> - Never import `{ModuleNamePlugins}` from any other module
> - Initial activation uses the IO ServiceMap: `motherboard.serviceMap.mod{ModuleName}`

---

## podspec Templates

### IO podspec — `{ModuleName}.podspec`

```ruby
Pod::Spec.new do |s|
  s.name             = '{ModuleName}'
  s.version          = '0.1.0'
  s.summary          = '{ModuleName} interface module.'
  s.description      = 'Public interface: BoardIDs, InOut models, ServiceMap.'
  s.homepage         = 'https://github.com/your-org/{ModuleName}'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Team' => 'team@example.com' }
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.source_files     = 'IO/**/*.swift'
  s.dependency 'Boardy'
end
```

### Plugins podspec — `{ModuleNamePlugins}.podspec`

```ruby
Pod::Spec.new do |s|
  s.name             = '{ModuleNamePlugins}'
  s.version          = '0.1.0'
  s.summary          = '{ModuleName} implementation module.'
  s.homepage         = 'https://github.com/your-org/{ModuleName}'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Team' => 'team@example.com' }
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.source_files     = 'Sources/**/*.swift'
  s.resources        = 'Sources/Resources/**/*'
  s.dependency '{ModuleName}'
  s.dependency 'Boardy'
  s.dependency 'SiFUtilities'
  # Add other dependencies here (name only — never add :path to s.dependency)
end
```

> ⚠️ **podspec dependency rule:** `s.dependency` only takes a pod name (and optional version constraint). **Never** add `:path` or any local path hint to a `s.dependency` line. Path resolution is the Podfile's job.
> - ✅ `s.dependency '{OtherModule}'`
> - ❌ `s.dependency '{OtherModule}', :path => '.'`  ← wrong, breaks lint

---

## init-module.sh Reference

The script is at `scripts/init-module.sh`. See the actual script file for full content. Key operations:

1. Clones the module template repository configured for the project (for example: `{ModuleTemplateURL}` from `.claude/rules/PROJECT_CONFIG.md`)
2. Replaces `__DAD__` → `{ModuleName}` throughout
3. Replaces `___VARIABLE_moduleName___` → `{NoPrefixName}` throughout
4. Sets ServiceMap property names: `mod{ModuleName}` and `mod{ModuleNamePlugins}`
5. Renames all files accordingly

---

## Module Naming Quick Reference

| Concept | No Prefix | With Prefix `DAD` |
|---------|-----------|-------------------|
| Full module name | `Profile` | `DADProfile` |
| IO podspec | `Profile` | `DADProfile` |
| Plugins podspec | `ProfilePlugins` | `DADProfilePlugins` |
| No-prefix name (VIP classes) | `Profile` | `Profile` |
| IO ServiceMap class | `ProfileServiceMap` | `DADProfileServiceMap` |
| IO ServiceMap property | `modProfile` | `modDADProfile` |
| Plugins ServiceMap class | `ProfilePluginsServiceMap` | `DADProfilePluginsServiceMap` |
| Plugins ServiceMap property | `modProfilePlugins` | `modDADProfilePlugins` |

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Importing `{ModuleNamePlugins}` from another module | Import `{ModuleName}` (IO) only |
| Making internal boards `public` | Remove `public`; internal boards live in Sources |
| Forgetting `public init() { /**/ }` on LauncherPlugin | Always add it |
| `sharedRepository` created inside `build()` or `BoardRegistration` | Declare as stored property on `ModulePlugin` struct |
