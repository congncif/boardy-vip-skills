# PROJECT_CONFIG — Project Configuration Contract

> **How to customize**: Replace ALL `{Placeholder}` values in the tables below.
> Run `grep -r '{' .claude/rules/PROJECT_CONFIG.md` to find unfilled placeholders.

---

## 1. Identity Configuration

| Key | Value |
|-----|-------|
| `{ProjectName}` | **FILL: YourProjectName** |
| `{Workspace}` | **FILL: YourProject.xcworkspace** |
| `{MainScheme}` | **FILL: YourProject** |
| `{ModulePrefix}` | *(none — or fill if modules use a prefix)* |
| `{BaseBranch}` | **FILL: main** |
| `{GitRemote}` | **FILL: origin** |
| `{GitRemoteURL}` | **FILL: https://github.com/your-org/your-repo.git** |
| `{Simulator}` | **FILL: iPhone 17** |
| `{Destination}` | **FILL: platform=iOS Simulator,name=iPhone 17** |

---

## 2. Project-Wide Path Configuration

| Concern | Value |
|---------|-------|
| Module root | **FILL: submodules/** |
| Project structure inventory | `@.claude/rules/PROJECT_STRUCTURE.md` |
| Superpowers workspace root | `.superpowers/` |
| Plans root | `.superpowers/plans/` |
| Specs root | `.superpowers/specs/` |
| Brainstorms root | `.superpowers/brainstorms/` |
| Reports root | `.superpowers/reports/` |
| Reviews root | `.superpowers/reviews/` |
| Scratch root | `.superpowers/scratch/` |

---

## 3. Tooling Configuration

| Concern | Value |
|---------|-------|
| Dependency manager | CocoaPods |
| App dependency file | `Podfile` |
| Module dependency files | `*.podspec` |
| App plugin host | **FILL: SceneDelegate.scene(_:willConnectTo:options:)** |
| Interface source glob | `IO/**/*.swift` |
| Implementation source glob | `Sources/**/*.swift` |
| Interface target pattern | `{ModuleName}` |
| Implementation target pattern | `{ModuleName}Plugins` |

---

## 4. Build/Test Configuration

### Destination Discovery

```bash
xcodebuild build -workspace {Workspace} -scheme {MainScheme} -showdestinations
```

### Canonical Build Command

```bash
xcodebuild build -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

### Canonical Test Command

```bash
xcodebuild test -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|FAILED|PASSED|TEST SUCCEEDED|TEST FAILED|BUILD SUCCEEDED|BUILD FAILED)"
```

### Verification Rules

| Rule | Detail |
|------|--------|
| No `-quiet` | Hides errors; never use |
| Empty grep output | Treat as failure; re-run without grep |
| Build success | Requires `** BUILD SUCCEEDED **` |
| Test success | Requires `** TEST SUCCEEDED **` with no `error:` |

---

## 5. Dependency Generation

| Trigger | Action |
|---------|--------|
| New module | Add Podfile entries + `pod install` |
| New pod dependency | Update podspec/Podfile + `pod install` |
| Removed pod dependency | Update podspec/Podfile + `pod install` |
| Changed `source_files` glob | `pod install` |
| New Swift files added outside Xcode | `pod install` |

Podfile syntax:
```ruby
pod '{ModuleName}',        :path => '{ModuleRoot}/{ModuleName}'
pod '{ModuleNamePlugins}', :path => '{ModuleRoot}/{ModuleName}'
```

---

## 6. AI Workflow Configuration

| Artifact type | Location |
|---------------|----------|
| Plans | `.superpowers/plans/` |
| Specs | `.superpowers/specs/` |
| Brainstorms | `.superpowers/brainstorms/` |
| Reports | `.superpowers/reports/` |
| Reviews | `.superpowers/reviews/` |
| Scratch | `.superpowers/scratch/` |

Report filenames: `YYYY-MM-DD-<topic>.md`

---

## 7. Git Workflow

| Rule | Binding |
|------|---------|
| Phase completion | Commit after each user-approved phase |
| Commit approval | Only after explicit user approval |
| Push approval | Only after explicit user approval |
| Staging | Explicit file paths only; no `git add -A` |
| Target | `{GitRemote}` / `{BaseBranch}` |

---

## 8. Placeholder Resolution Map

| Placeholder | Resolution |
|-------------|------------|
| `{ProjectName}` | **FILL** |
| `{Workspace}` | **FILL** |
| `{MainScheme}` | **FILL** |
| `{Scheme}` | Bound per task; default to `{MainScheme}` |
| `{Simulator}` | **FILL** |
| `{Destination}` | **FILL** |
| `{BaseBranch}` | **FILL** |
| `{GitRemote}` | **FILL** |
| `{ModuleName}` | Bound per task |
| `{ModulePluginsName}` | `{ModuleName}Plugins` |
| `{NoPrefixName}` | Same as `{ModuleName}` if no prefix |
| `{ModuleRoot}` | **FILL** |
| `{SuperpowersRoot}` | `.superpowers/` |
