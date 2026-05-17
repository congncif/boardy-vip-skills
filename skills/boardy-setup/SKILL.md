---
name: boardy-setup
description: Use when starting a brand-new iOS project with Boardy+VIP architecture — covers CLAUDE.md wiring, PROJECT_CONFIG.md setup, first module creation, and validation that the architecture is correctly bootstrapped
version: 1.1.3
---

# Boardy+VIP New Project Setup

## Overview

Setting up a new project requires wiring three layers:
1. **AI rules** — CLAUDE.md + `.claude/rules/` so every conversation has architecture context
2. **Project config** — PROJECT_CONFIG.md with project-specific values
3. **First module** — one working module to validate the setup end-to-end

Architecture specs are bundled inside the installed skills at `~/.claude/skills/boardy-vip/specs/` — no per-project copy needed.

## Prerequisites

- Xcode 15+
- CocoaPods (`gem install cocoapods`)
- Boardy pod available (via CocoaPods or local path)
- Claude Code CLI
- Boardy skills installed: `cd /path/to/boardy-skills && ./install.sh`

## Step 1 — Copy Project Templates

```bash
cd /path/to/new-project
mkdir -p .claude/rules

# Project config and constitution
cp /path/to/boardy-skills/templates/CLAUDE.md .
cp /path/to/boardy-skills/templates/PROJECT_CONFIG.md .claude/rules/
cp /path/to/boardy-skills/templates/PROJECT_STRUCTURE.md .claude/rules/
```

Architecture specs are in `~/.claude/skills/boardy-vip/specs/` (installed by `install.sh`).
No spec files need to be copied to the project — skills read them directly from the skill directory.

## Step 2 — Fill PROJECT_CONFIG.md

Copy template and fill these required values:

```markdown
| `{ProjectName}` | YourProjectName |
| `{Workspace}` | YourProject.xcworkspace |
| `{MainScheme}` | YourProject |
| `{Simulator}` | iPhone 17 |
| `{Destination}` | platform=iOS Simulator,name=iPhone 17 |
| `{BaseBranch}` | main |
| `{GitRemote}` | origin |
| `{ModuleRoot}` | submodules/ |
```

Run destination discovery if simulator is unknown:
```bash
xcodebuild build -workspace {Workspace} -scheme {Scheme} -showdestinations
```

## Step 3 — Create PROJECT_STRUCTURE.md

Copy template and fill scheme/module inventory. Update this file every time a module is added/removed/renamed.

## Step 4 — Set Up Podfile

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'Boardy'
  pod 'SiFUtilities'
  # Add module pods here as you create them
end
```

## Step 5 — Create First Module

Follow `boardy-module` skill. The first module validates the full pipeline:

```bash
mkdir -p submodules/Core
# scaffold IO + Sources manually or via init-module.sh
```

Validate with filtered build:
```bash
xcodebuild build \
  -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

> Empty grep output = failure. Always verify `** BUILD SUCCEEDED **` is present.

## Step 6 — Wire Superpowers (optional)

Create `.superpowers/` directory for AI workflow artifacts:
```
.superpowers/
├── plans/
├── specs/
├── reports/
└── brainstorms/
```

Add to `.gitignore` if artifacts should stay local.

## Validation Checklist

- [ ] `CLAUDE.md` present at project root
- [ ] `PROJECT_CONFIG.md` has all `{Placeholder}` values filled
- [ ] `PROJECT_STRUCTURE.md` reflects current schemes/modules
- [ ] `pod install` succeeded with no warnings
- [ ] First module builds: `** BUILD SUCCEEDED **` confirmed
- [ ] LauncherPlugin installed in app entry file
- [ ] Running `Skill({ skill: "boardy-vip" })` returns routing table

## Common First-Session Mistakes

| Mistake | Fix |
|---------|-----|
| `{Placeholder}` values not filled in PROJECT_CONFIG.md | Fill before first coding session |
| `pod install` skipped after adding module | Always run after Podfile/podspec changes |
| App imports `{Module}` instead of `{Module}Plugins` for LauncherPlugin | LauncherPlugin is in Plugins target |
| `sharedRepository` created inside `BoardRegistration` closure | Store as `let` on ModulePlugin struct |
| Forgetting `public init() { /**/ }` on LauncherPlugin | LauncherPlugin is called from outside the module |

## Upgrade Path

When `boardy-skills` releases new versions:
```bash
# Re-run install — skills and bundled specs are updated in place
cd /path/to/boardy-skills && git pull && ./install.sh
```

Architecture specs automatically update in `~/.claude/skills/boardy-vip/specs/`.
No project files need to be touched — only `PROJECT_CONFIG.md` and `PROJECT_STRUCTURE.md` are project-specific.
