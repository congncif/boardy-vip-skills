# Boardy+VIP Skills Pack

Claude Code skill pack for iOS projects built with [Boardy](https://github.com/congncif/boardy) microservices and VIP (View–Interactor–Presenter) architecture.

---

## What's Included

| Component | Purpose |
|-----------|---------|
| **5 Skills** | Quick-reference guides invokable via Claude Code `Skill` tool |
| **3 Templates** | Drop-in starting files for a new project's `.claude/rules/` |
| **install.sh** | One-command skill installation to `~/.claude/skills/` |

### Skills

| Skill | Invoke as | When to use |
|-------|-----------|-------------|
| `boardy-vip-quick-ref` | Any architecture task | Master routing table, 10 rules, naming conventions, key patterns |
| `boardy-vip-module` | Creating a new module | Module scaffold steps, podspec templates, LauncherPlugin wiring |
| `boardy-vip-board` | Implementing any board | Board type decision tree, UI/Flow/Viewless/BlockTask patterns |
| `boardy-vip-review` | Code review / PR verification | Complete architecture compliance checklist |
| `boardy-vip-setup` | Brand-new project | Bootstrap CLAUDE.md, PROJECT_CONFIG.md, first module, validation |

### Templates

| File | Copy to |
|------|---------|
| `templates/CLAUDE.md` | `{ProjectRoot}/CLAUDE.md` |
| `templates/PROJECT_CONFIG.md` | `{ProjectRoot}/.claude/rules/PROJECT_CONFIG.md` |
| `templates/PROJECT_STRUCTURE.md` | `{ProjectRoot}/.claude/rules/PROJECT_STRUCTURE.md` |

---

## Architecture in 2 Minutes

**Boardy+VIP** is a modular iOS architecture with five pillars:

1. **SDK-first** — platform frameworks before third-party
2. **Modular + Interface Module** — each feature splits into `{Module}` (IO/public) and `{Module}Plugins` (Sources/internal)
3. **Plugin Architecture** — runtime assembly via `PluginLauncher` + `LauncherPlugin` + `ModulePlugin`
4. **Micro-services Composable** — screens are activatable `Board` services on a `Motherboard`
5. **Domain-Driven Layering** — pure domain core, VIP business application layer, infrastructure at edges

```
App Entry File
    ↓ PluginLauncher
Motherboard (gateway)
    ↓ serviceMap.mod{Module}.io{Board}.activation.activate(with: input)
Board (stateless service shell)
    ↓ builder.build(withDelegate: self, input: input)
VIP: Interactor → UseCase → Presenter → ViewController
```

---

## Prerequisites

- **Xcode** 15+
- **CocoaPods** (`gem install cocoapods`)
- **Boardy** pod (from your Podfile)
- **SiFUtilities** pod
- **Claude Code** CLI (`claude` command available)

---

## Installation

### Step 1 — Clone or download this repo

```bash
git clone https://github.com/your-org/boardy-vip-skills.git
cd boardy-vip-skills
```

### Step 2 — Run install.sh

```bash
./install.sh
```

This copies skill files to `~/.claude/skills/`:

```
~/.claude/skills/
├── boardy-vip-quick-ref/SKILL.md
├── boardy-vip-module/SKILL.md
├── boardy-vip-board/SKILL.md
├── boardy-vip-review/SKILL.md
└── boardy-vip-setup/SKILL.md
```

### Step 3 — Verify installation

```bash
ls ~/.claude/skills | grep boardy-vip
```

Expected output:
```
boardy-vip-board
boardy-vip-module
boardy-vip-quick-ref
boardy-vip-review
boardy-vip-setup
```

### Uninstall

```bash
./install.sh --uninstall
```

---

## Setting Up a New Project

### 1. Create the Xcode project

Standard iOS app creation in Xcode. Close Xcode after creation.

### 2. Copy templates

```bash
cd /path/to/your-new-project
mkdir -p .claude/rules

cp /path/to/boardy-vip-skills/templates/CLAUDE.md .
cp /path/to/boardy-vip-skills/templates/PROJECT_CONFIG.md .claude/rules/
cp /path/to/boardy-vip-skills/templates/PROJECT_STRUCTURE.md .claude/rules/
```

### 3. Fill PROJECT_CONFIG.md

Open `.claude/rules/PROJECT_CONFIG.md` and replace ALL `{Placeholder}` values:

```markdown
| `{ProjectName}` | YourApp |
| `{Workspace}` | YourApp.xcworkspace |
| `{MainScheme}` | YourApp |
| `{Simulator}` | iPhone 17 |
| `{Destination}` | platform=iOS Simulator,name=iPhone 17 |
| `{BaseBranch}` | main |
| `{GitRemote}` | origin |
| `{ModuleRoot}` | submodules/ |
```

Verify no unfilled placeholders remain:
```bash
grep -r '{' .claude/rules/PROJECT_CONFIG.md
```

### 4. Discover available simulators (if needed)

```bash
xcodebuild build -workspace YourApp.xcworkspace -scheme YourApp -showdestinations
```

Pick the right device name and update `{Destination}` in PROJECT_CONFIG.md.

### 5. Set up Podfile

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'Boardy'
  pod 'SiFUtilities'
end
```

```bash
pod install
```

### 6. Create first module

```bash
mkdir -p submodules/Core
```

Then open Claude Code and invoke:
```
Skill({ skill: "boardy-vip-module" })
```

Follow the module creation steps. Build to validate:

```bash
xcodebuild build \
  -workspace YourApp.xcworkspace \
  -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

### 7. Update PROJECT_STRUCTURE.md

After creating the first module, update `.claude/rules/PROJECT_STRUCTURE.md` with the scheme and module inventory.

### 8. Create .superpowers/ directory

```bash
mkdir -p .superpowers/{plans,specs,reports,brainstorms,reviews,scratch}
echo ".superpowers/" >> .gitignore   # optional: keep AI artifacts local
```

---

## Using Skills in Claude Code

Skills are invoked via the `Skill` tool inside Claude Code sessions. Claude Code auto-discovers skills from `~/.claude/skills/`.

### Common invocations

```
# At session start or before any architecture task
Skill({ skill: "boardy-vip-quick-ref" })

# Before creating a new module
Skill({ skill: "boardy-vip-module" })

# Before implementing a board
Skill({ skill: "boardy-vip-board" })

# Before reviewing a PR
Skill({ skill: "boardy-vip-review" })

# For a brand-new project
Skill({ skill: "boardy-vip-setup" })
```

### How Claude uses skills

When Claude Code loads a skill, it reads the `SKILL.md` content and uses it as a reference guide. Skills with clear `description` fields are also auto-matched by Claude when a relevant task is detected.

---

## Project Templates Guide

### CLAUDE.md

The constitution file that Claude loads at session start. It:
- Defines load order for rules files
- Establishes the rule hierarchy
- Sets operating discipline (commit workflow, staging policy)

After copying, no modifications needed — it references other files via `@.claude/rules/`.

### PROJECT_CONFIG.md

**Project-specific values only.** Fill all `{Placeholder}` entries. This file is the single source of truth for:
- Build commands (workspace, scheme, destination)
- Git configuration (remote, branch)
- Module root path
- AI workflow artifact locations

**Do not** put architecture rules here — those live in the skill files.

### PROJECT_STRUCTURE.md

**Keep synchronized with code.** Update in the same commit whenever:
- A module is added or removed
- A scheme is renamed
- Module responsibilities change

---

## Architecture Rules Reference

The full architecture rules (specs) are embedded in the skill files and available on demand. For deep dives, the originating project's `.claude/rules/` contains the complete spec set:

| Spec | Topic |
|------|-------|
| `ARCHITECTURE.md` | Five pillars overview |
| `MICROBOARD_UI.md` | Full VIP UI board |
| `MICROBOARD_NONUI.md` | Non-UI boards (Flow/BlockTask/Viewless) |
| `VIP_COMPONENTS.md` | Interactor/Presenter/ViewController/Builder rules |
| `COMMUNICATION.md` | Board communication, Bus patterns |
| `CONTEXT_NAVIGATION.md` | back/return/alert patterns |
| `PLUGINS_INTEGRATION.md` | ModulePlugin/LauncherPlugin |
| `PER_ACTIVATION_RESOURCES.md` | Stateful service lifecycle |
| `EXTENSIBLE_PROVIDER.md` | OCP multi-provider pattern |
| `SERVICE_LAYER.md` | UseCase/Repository/Domain |
| `LAYERING.md` | 3-layer dependency rules |
| `CROSS_MODULE_DI.md` | Cross-module service sharing |

---

## Upgrade Path

### Updating skills

```bash
cd /path/to/boardy-vip-skills
git pull
./install.sh
```

Skills are overwritten in place. Claude Code picks up changes immediately in the next session.

### Propagating rule updates to existing projects

Rule templates in `templates/` are starting points. For existing projects:

1. Review `git diff` between new template and your current rules file
2. Merge improvements manually — never blindly overwrite (your PROJECT_CONFIG.md and PROJECT_STRUCTURE.md have project-specific content)
3. Re-run `pod install` if podspec conventions change

---

## Contributing

This pack is extracted from a production project and kept in sync as the architecture evolves. To contribute improvements:

1. Fork this repo
2. Update the relevant `skills/{name}/SKILL.md` or `templates/*.md`
3. Open a PR with a description of what changed and why

**Key rule**: Skills should be architecture-neutral where possible. Project-specific values belong in templates, not skills.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-14 | Initial release — 5 skills, 3 templates, install.sh |

---

## License

MIT
