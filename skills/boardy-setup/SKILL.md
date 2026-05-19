---
name: boardy-setup
description: Interactive bootstrap for a brand-new Boardy+VIP iOS project — AI collects required values via AskUserQuestion, auto-discovers simulators, writes CLAUDE.md and project bindings, generates Podfile, runs pod install, scaffolds the first module via boardy-module, and verifies the build.
version: 1.2.0
---

# Boardy+VIP New Project Bootstrap (Interactive)

This skill turns project setup into a guided workflow. The AI drives it, asking the user only for values that cannot be discovered automatically, generating files, and verifying the result.

## Invocation Mode

When invoked, the AI **must** run the phases below in order. Skip a phase only if its outputs already exist and are valid; in that case report "already done" and continue.

Use `AskUserQuestion` for every decision listed under "Ask user". Use `Bash`/`Read` for discovery. Use `Write` to materialize files. Never paste template content into chat — write it to disk.

---

## Phase 0 — Prerequisites

Run these checks via `Bash` (parallel where possible):

- `xcodebuild -version` → must succeed
- `pod --version` → must succeed
- `which claude` → recommend installing if missing (warn only)
- `git -C <project-root> rev-parse --is-inside-work-tree` → must be `true`

If any required check fails, stop and ask the user to install the missing tool. Do not proceed.

Detect project root: the working directory at invocation time. Confirm with the user if ambiguous.

---

## Phase 1 — Locate the plugin pack (for templates)

Templates live in the plugin repo (`boardy-vip-skills/templates/`), not in `~/.claude/skills/`. The skill needs that path to read template files.

1. Try common locations: `~/boardy-vip-skills`, `~/projects/boardy-vip-skills`, `$WORKSPACE/boardy-vip-skills` — `Bash` `ls` each.
2. If found, confirm with user via `AskUserQuestion` ("Use detected pack at X? Yes / Choose other").
3. If not found, ask user via `AskUserQuestion` with an "Other" option to enter the absolute path.

Store the resolved path as `PACK_PATH`. All template reads use `${PACK_PATH}/templates/...`.

---

## Phase 2 — Discover the workspace

Run `Bash`:
```bash
ls -1 *.xcworkspace 2>/dev/null
ls -1 *.xcodeproj 2>/dev/null
```

- If exactly one `.xcworkspace` is found → use it.
- If multiple → `AskUserQuestion` to pick one.
- If only `.xcodeproj` exists and the user plans CocoaPods, warn that `pod install` will create the workspace.

Store as `WORKSPACE`.

---

## Phase 3 — Gather project values (AskUserQuestion)

Fields are split into **Required** (cannot proceed without — bootstrap blocks until set) and **Optional** (can be deferred — pre-filled with sensible defaults or left as a `{Placeholder}` and tracked in `SETUP_TODO.md`).

Each `AskUserQuestion` for an optional field MUST include a "Skip — set later" choice. When skipped, write the value as the original `{Placeholder}` token in `PROJECT_CONFIG.md` and add an entry to `SETUP_TODO.md` (Phase 5b).

### Required (must be set now)

| Key | Source / default |
|---|---|
| `ProjectName` | derived from workspace filename; confirm |
| `MainScheme` | ask, default = `ProjectName` |
| `DependencyManager` | ask: `CocoaPods` / `SwiftPM` / `Both` — drives Phase 6 |

### Optional (skippable)

| Key | Default if skipped | Why optional |
|---|---|---|
| `ModulePrefix` | empty | Many projects don't use a prefix; safe default |
| `BaseBranch` | `main` | Almost always `main`; rare override |
| `GitRemote` | `origin` | Conventional |
| `GitRemoteURL` | `git remote get-url origin` if set, else `{GitRemoteURL}` placeholder | Can be added later via `git remote add` |
| `ModuleRoot` | `submodules/` (CocoaPods) or `Modules/` (SwiftPM) | Convention by dependency manager |
| `BindingsRoot` | `.claude/project/` | Plugin default |

Group related fields into 2–3 `AskUserQuestion` calls; do not ask one-by-one if the user is likely to answer in a batch.

---

## Phase 4 — Discover simulator

Run:
```bash
xcodebuild -workspace "${WORKSPACE}" -scheme "${MainScheme}" -showdestinations 2>&1 | grep "platform:iOS Simulator"
```

If the scheme does not exist yet (fresh project), fall back to:
```bash
xcrun simctl list devices available | grep "iPhone"
```

Present the user with the top 3–4 newest iPhone options via `AskUserQuestion` (single-select with previews). Store `Simulator` and derive `Destination = platform=iOS Simulator,name=${Simulator}`.

---

## Phase 5 — Scaffold project files

Create directories:
```bash
mkdir -p "${BindingsRoot}" "${BindingsRoot}/decisions" .superpowers/{plans,specs,reports,brainstorms,reviews,scratch} "${ModuleRoot}"
```

For each template file below: `Read` from pack → substitute placeholders → `Write` to destination.

| Source (pack) | Destination | Placeholders to substitute |
|---|---|---|
| `templates/CLAUDE.md` | `<project>/CLAUDE.md` | (none — uses default placeholders) |
| `templates/PROJECT_CONFIG.md` | `<project>/${BindingsRoot}/PROJECT_CONFIG.md` | `{ProjectName}`, `{Workspace}`, `{MainScheme}`, `{ModulePrefix}`, `{BaseBranch}`, `{GitRemote}`, `{GitRemoteURL}`, `{Simulator}`, `{Destination}`, `{ModuleRoot}` |
| `templates/PROJECT_STRUCTURE.md` | `<project>/${BindingsRoot}/PROJECT_STRUCTURE.md` | leave as template — user will fill module inventory after Phase 7 |
| `templates/decisions/README.md` | `<project>/${BindingsRoot}/decisions/README.md` | (none) |

If `BindingsRoot` is not the default `.claude/project/`, also patch the bound `CLAUDE.md` paths (lines that mention `.claude/project/PROJECT_*`) to point at `${BindingsRoot}`.

Append `.superpowers/` to `.gitignore` (or create if absent).

---

## Phase 5b — Write SETUP_TODO.md (deferred-items tracker)

`Write` `${BindingsRoot}/SETUP_TODO.md` listing every optional field that was skipped or left as a `{Placeholder}`. Use this exact shape:

```markdown
# SETUP_TODO — deferred bootstrap items

Items below were skipped during `boardy-setup`. Fill them when ready and update `PROJECT_CONFIG.md` accordingly.

## Unfilled placeholders

- [ ] `{GitRemoteURL}` — run `git remote add origin <url>` then update `PROJECT_CONFIG.md`
- [ ] `{ModulePrefix}` — currently empty; set if you adopt a prefix convention (e.g. `DAD`)

## Optional steps not run

- [ ] First module — invoke `Skill({ skill: "boardy-module" })`
- [ ] LauncherPlugin wiring in app entry — pending first module

## How to detect remaining placeholders

```bash
grep -r '{' ${BindingsRoot}/PROJECT_CONFIG.md
```
```

Rules:
- Only include rows for items actually skipped — keep the file scoped to real pending work.
- If nothing was skipped, still `Write` the file with: `_All required and optional fields set during bootstrap. Nothing pending._`
- Re-running `boardy-setup` (or future `boardy-setup --resume`) should reconcile `SETUP_TODO.md` against `PROJECT_CONFIG.md` and remove resolved rows.

---

## Phase 6 — Dependency manager wiring

Branch on `${DependencyManager}` from Phase 3.

### 6a. CocoaPods path

If `Podfile` exists, `Read` it, confirm overwrite via `AskUserQuestion`. Otherwise `Write`:

```ruby
platform :ios, '13.0'
use_frameworks!

target '${ProjectName}' do
  pod 'Boardy'
  pod 'SiFUtilities'
end
```

Run:
```bash
pod install
```

Verify `Pods/` created and `${WORKSPACE}` exists. Add Pods to `.gitignore` if not present.

### 6b. SwiftPM path

No `Podfile`. Instead, declare dependencies through the Xcode project (`.xcodeproj` Package Dependencies) **or** via a workspace-level `Package.swift` if the user prefers a single source.

Steps:
1. Detect SPM dependencies already added: `grep -l "Boardy" *.xcodeproj/project.pbxproj 2>/dev/null` and `find . -name 'Package.resolved' -not -path './DerivedData/*'`.
2. If missing, instruct the user (via `AskUserQuestion`) to add packages in Xcode manually OR generate a starter `Package.swift` at `${ModuleRoot}/Package.swift` declaring:
   - `https://github.com/congncif/boardy` (or pinned fork)
   - `https://github.com/congncif/SiFUtilities` (if applicable)
3. Modules in SPM mode are **local Swift packages** under `${ModuleRoot}/<ModuleName>/` with `Package.swift`. The `boardy-module` skill must be told this — pass `DependencyManager=SwiftPM` when delegating in Phase 7 so it scaffolds packages instead of podspecs.
4. There is no `pod install` step. Build verification (Phase 9) uses `-project` or `-scheme` directly without `-workspace` unless a workspace exists.

### 6c. Both (CocoaPods workspace + SPM packages)

Rare. Treat as 6a for app target wiring, plus 6b for module dependency surface. Note this in `SETUP_TODO.md` with a row warning that mixed managers require manual reconciliation per module.

### Workspace/destination implications

| Manager | Build artifact | Build command shape |
|---|---|---|
| CocoaPods | `${WORKSPACE}` (`.xcworkspace`) | `xcodebuild ... -workspace ${WORKSPACE} -scheme ${MainScheme}` |
| SwiftPM only | `.xcodeproj` | `xcodebuild ... -project ${ProjectName}.xcodeproj -scheme ${MainScheme}` |
| Both | `${WORKSPACE}` | same as CocoaPods row |

Record the resolved command in `PROJECT_CONFIG.md` §4 so future runs use it verbatim.

---

## Phase 7 — First module (delegate)

Ask via `AskUserQuestion`: "Create first module now? (Recommended: yes — validates the full pipeline)".

If yes, invoke `Skill({ skill: "boardy-module" })` and pass the collected values as context (ProjectName, ModulePrefix, ModuleRoot, BindingsRoot). The module skill owns scaffolding logic. Wait for it to finish, then return here.

If no, skip to Phase 8 — but warn the user that `Phase 9 build verification` will likely fail without at least one module.

---

## Phase 8 — Update PROJECT_STRUCTURE.md

After the first module exists, fill `${BindingsRoot}/PROJECT_STRUCTURE.md` with:
- The single scheme created
- The single module category (e.g. `Feature` or `Core`) and its module name
- Discovery commands appropriate to `${ModuleRoot}`

Use `Read` on the template, substitute, `Write`.

---

## Phase 9 — Build verification

Use the command shape recorded for `${DependencyManager}` in Phase 6.

CocoaPods (or Both):
```bash
xcodebuild build \
  -workspace "${WORKSPACE}" \
  -scheme "${MainScheme}" \
  -destination 'platform=iOS Simulator,name=${Simulator}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

SwiftPM only:
```bash
xcodebuild build \
  -project "${ProjectName}.xcodeproj" \
  -scheme "${MainScheme}" \
  -destination 'platform=iOS Simulator,name=${Simulator}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

- Empty output → treat as failure. Re-run without grep to inspect.
- `BUILD SUCCEEDED` → mark Phase 9 complete.

---

## Phase 10 — Validation checklist

Report each item as ✅/❌/⏭️ (skipped — tracked in `SETUP_TODO.md`):

- [ ] `CLAUDE.md` present at project root
- [ ] `${BindingsRoot}/PROJECT_CONFIG.md` has no **required** `{Placeholder}` left. Optional placeholders (`{GitRemoteURL}`, `{ModulePrefix}`) may remain — list each one as ⏭️ with a `SETUP_TODO.md` row
- [ ] `${BindingsRoot}/PROJECT_STRUCTURE.md` reflects current schemes/modules
- [ ] `${BindingsRoot}/decisions/README.md` present
- [ ] `${BindingsRoot}/SETUP_TODO.md` written (even if empty)
- [ ] Dependency manager wiring complete:
  - CocoaPods → `Podfile.lock` exists
  - SwiftPM → `Package.resolved` exists OR Xcode Package Dependencies populated
- [ ] First module scaffold present under `${ModuleRoot}` (⏭️ allowed if Phase 7 declined)
- [ ] LauncherPlugin installed in app entry file (`grep -r 'LauncherPlugin\|PluginLauncher' --include='*.swift'`)
- [ ] `BUILD SUCCEEDED` observed

For each ❌, list the remediation step. For each ⏭️, point at the corresponding row in `SETUP_TODO.md`.

---

## Phase 11 — Report

Send a final structured summary to the user covering:
- Files written (with paths)
- Discovered values (workspace, scheme, simulator, dependency manager)
- Deferred items — count + path to `SETUP_TODO.md`
- Build result
- Next steps (typically: implement first board via `boardy-board` skill; resolve `SETUP_TODO.md` rows when ready)

Do **not** commit. The user reviews and commits per their commit workflow.

---

## Common First-Session Mistakes (still surface in Phase 10 if observed)

| Mistake | Fix |
|---|---|
| `{Placeholder}` values not filled in `PROJECT_CONFIG.md` | Re-run Phase 3 + Phase 5 |
| `pod install` skipped after adding module | Always run after Podfile/podspec changes |
| App imports `{Module}` instead of `{Module}Plugins` for LauncherPlugin | LauncherPlugin lives in Plugins target |
| `sharedRepository` created inside `BoardRegistration` closure | Store as `let` on ModulePlugin struct |
| Forgetting `public init() { /**/ }` on LauncherPlugin | LauncherPlugin is called from outside the module |

---

## Upgrade Path

When the pack releases new versions:
```bash
cd ${PACK_PATH} && git pull && ./install.sh
```

Skills and bundled specs are updated in place. Project files (`CLAUDE.md`, bindings, ADRs) are never overwritten by `install.sh`.
