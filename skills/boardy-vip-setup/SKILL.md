---
name: boardy-vip-setup
description: Use when starting a brand-new iOS project with Boardy+VIP architecture — covers CLAUDE.md wiring, PROJECT_CONFIG.md setup, first module creation, and validation that the architecture is correctly bootstrapped
---

# Boardy+VIP New Project Setup

## Overview

Setting up a new project requires wiring three layers:
1. **AI rules** — CLAUDE.md + `.claude/rules/` so every conversation has architecture context
2. **Project config** — PROJECT_CONFIG.md with project-specific values
3. **First module** — one working module to validate the setup end-to-end

## Prerequisites

- Xcode 15+
- CocoaPods (`gem install cocoapods`)
- Boardy pod available (via CocoaPods or local path)
- Claude Code CLI

## Step 1 — Install the Skill Pack Rules

```bash
# Option A: Copy rules from boardy-vip-skills repo
cp -r /path/to/boardy-vip-skills/templates/.claude /path/to/new-project/

# Option B: Install from skill pack (if install.sh run)
# Skills are already at ~/.claude/skills/ — rules templates need manual copy
```

## Step 2 — Configure CLAUDE.md

Create `{ProjectRoot}/CLAUDE.md`:

```markdown
# Project Constitution

@.claude/rules/QUICK_REF.md       ← load FIRST every session
@.claude/rules/PROJECT_CONFIG.md  ← project-specific values
@.claude/rules/PROJECT_STRUCTURE.md ← current module topology

## Rule Hierarchy
1. User's explicit instruction
2. This constitution
3. `.claude/rules/QUICK_REF.md` and task specs
4. `.claude/rules/REVIEWER_CHECKLIST.md` for reviews
5. `.claude/rules/PROJECT_CONFIG.md` for build commands
6. `.claude/rules/PROJECT_STRUCTURE.md` for topology

## Operating Discipline
- Run `pod install` after any structural change
- Stage commits by explicit file paths only
- Commit only after user approval
- Use `.superpowers/` for AI workflow artifacts
```

## Step 3 — Fill PROJECT_CONFIG.md

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

## Step 4 — Create PROJECT_STRUCTURE.md

Copy template and fill scheme/module inventory. Update this file every time a module is added/removed/renamed.

## Step 5 — Set Up Podfile

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'Boardy'
  pod 'SiFUtilities'
  # Add module pods here as you create them
end
```

## Step 6 — Create First Module

Follow `boardy-vip-module` skill. The first module validates the full pipeline:

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

## Step 7 — Wire Superpowers (optional)

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

- [ ] `CLAUDE.md` loads `QUICK_REF.md` first via `@` reference
- [ ] `PROJECT_CONFIG.md` has all `{Placeholder}` values filled
- [ ] `PROJECT_STRUCTURE.md` reflects current schemes/modules
- [ ] `pod install` succeeded with no warnings
- [ ] First module builds: `** BUILD SUCCEEDED **` confirmed
- [ ] LauncherPlugin installed in app entry file
- [ ] Running `Skill({ skill: "boardy-vip-quick-ref" })` returns routing table

## Common First-Session Mistakes

| Mistake | Fix |
|---------|-----|
| `{Placeholder}` values not filled in PROJECT_CONFIG.md | Fill before first coding session |
| `pod install` skipped after adding module | Always run after Podfile/podspec changes |
| App imports `{Module}` instead of `{Module}Plugins` for LauncherPlugin | LauncherPlugin is in Plugins target |
| `sharedRepository` created inside `BoardRegistration` closure | Store as `let` on ModulePlugin struct |
| Forgetting `public init() { /**/ }` on LauncherPlugin | LauncherPlugin is called from outside the module |

## Upgrade Path

When `boardy-vip-skills` releases new rule versions:
```bash
# Re-run install to update skills
cd /path/to/boardy-vip-skills && ./install.sh

# Copy updated rule templates to project
cp templates/.claude/rules/*.md /path/to/project/.claude/rules/
# Then re-fill project-specific values in PROJECT_CONFIG.md and PROJECT_STRUCTURE.md
```
