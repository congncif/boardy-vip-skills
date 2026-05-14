# Boardy+VIP Skills Pack

Claude Code skill pack for iOS projects built with [Boardy](https://github.com/congncif/boardy) microservices and VIP (View–Interactor–Presenter) architecture.

---

## What's Included

| Component | Purpose |
|-----------|---------|
| **5 Skills** | Quick-reference guides invokable via Claude Code `Skill` tool |
| **3 Templates** | Drop-in starting files for a new project's `.claude/rules/` |
| **install.sh** | One-command skill installation to `~/.claude/skills/` |
| **sync.sh** | Sync architecture specs from a project's `.claude/rules/` into the skill pack |

### Skills

| Skill | Invoke as | When to use |
|-------|-----------|-------------|
| `boardy-vip` | Any architecture task | Master routing table, 10 rules, naming conventions, key patterns |
| `boardy-module` | Creating a new module | Module scaffold steps, podspec templates, LauncherPlugin wiring |
| `boardy-board` | Implementing any board | Board type decision tree, UI/Flow/Viewless/BlockTask patterns |
| `boardy-review` | Code review / PR verification | Loads full compliance checklist from bundled spec |
| `boardy-setup` | Brand-new project | Bootstrap CLAUDE.md, PROJECT_CONFIG.md, first module, validation |

### Templates

| File | Copy to |
|------|---------|
| `templates/CLAUDE.md` | `{ProjectRoot}/CLAUDE.md` |
| `templates/PROJECT_CONFIG.md` | `{ProjectRoot}/.claude/rules/PROJECT_CONFIG.md` |
| `templates/PROJECT_STRUCTURE.md` | `{ProjectRoot}/.claude/rules/PROJECT_STRUCTURE.md` |

> **Why only 3 files?** Architecture specs (30 `.md` files) are bundled inside the `boardy-vip` skill at `~/.claude/skills/boardy-vip/specs/`. Skills read them directly via the `Read` tool — no per-project copy needed. This means upgrading skills (`git pull && ./install.sh`) automatically updates all specs everywhere, without touching project files.

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
git clone https://github.com/your-org/boardy-skills.git
cd boardy-skills
```

### Step 2 — Run install.sh

```bash
./install.sh
```

This copies skill files to `~/.claude/skills/`:

```
~/.claude/skills/
├── boardy-vip/SKILL.md + specs/
├── boardy-module/SKILL.md
├── boardy-board/SKILL.md
├── boardy-review/SKILL.md
└── boardy-setup/SKILL.md
```

> **Upgrading from v1.0.0?** The script automatically removes the old `boardy-start` directory. Update any CLAUDE.md references from `boardy-start` → `boardy-vip`.

### Step 3 — Verify installation

```bash
ls ~/.claude/skills | grep boardy-
```

Expected output:
```
boardy-board
boardy-module
boardy-review
boardy-setup
boardy-vip
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

# Project config files (the only files needed per-project)
cp /path/to/boardy-skills/templates/CLAUDE.md .
cp /path/to/boardy-skills/templates/PROJECT_CONFIG.md .claude/rules/
cp /path/to/boardy-skills/templates/PROJECT_STRUCTURE.md .claude/rules/
```

Architecture specs are bundled inside `~/.claude/skills/boardy-vip/specs/` (installed in Step 2).
No spec files need to be copied — skills read them directly from the skill directory.

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
Skill({ skill: "boardy-module" })
```

Build to validate:

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

Skills are invoked via the `Skill` tool inside Claude Code sessions.

### Common invocations

```
# At session start or before any architecture task
Skill({ skill: "boardy-vip" })

# Before creating a new module
Skill({ skill: "boardy-module" })

# Before implementing a board
Skill({ skill: "boardy-board" })

# Before reviewing a PR
Skill({ skill: "boardy-review" })

# For a brand-new project
Skill({ skill: "boardy-setup" })
```

---

## Syncing Specs from a Project

When architecture rules evolve in a project's `.claude/rules/`, use `sync.sh` to pull them into this skill pack:

```bash
# Sync specs only (review diff before committing)
./sync.sh /path/to/project/.claude/rules/

# Sync + bump patch version (1.1.0 → 1.1.1) in all SKILL.md files and CHANGELOG.md
./sync.sh /path/to/project/.claude/rules/ --bump-version
```

After syncing:

```bash
# 1. Review what changed
git diff skills/boardy-vip/specs/

# 2. If the rule change affects Claude's BEHAVIOR (not just spec wording),
#    also update the relevant SKILL.md (boardy-board, boardy-module, etc.)

# 3. Commit and push
git add -p
git commit -m "sync: update specs from project rules v1.1.1"
git push

# 4. Re-install on all machines
git pull && ./install.sh
```

### What sync.sh copies

- All `.md` files from the project's `.claude/rules/` directory
- **Skips** project-specific binding files: `PROJECT_CONFIG.md`, `PROJECT_STRUCTURE.md`, `ADOPTION.md`

### What sync.sh does NOT do

- Does not modify SKILL.md content beyond the version field
- Does not push to git — you review and commit manually
- Does not copy templates — templates are maintained separately

---

## Upgrade Path

### Updating skills (receiving updates)

```bash
cd /path/to/boardy-skills
git pull
./install.sh
```

Skills and bundled specs are overwritten in place. Claude Code picks up changes in the next session.

### Project-specific files

`PROJECT_CONFIG.md` and `PROJECT_STRUCTURE.md` are yours — never overwritten by install.

`CLAUDE.md`: if you've customized it, compare with the template (`diff templates/CLAUDE.md your-project/CLAUDE.md`) and merge improvements manually.

---

## Architecture Rules Reference

Full specs are bundled at `~/.claude/skills/boardy-vip/specs/` after installation:

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

## Contributing

1. Fork this repo
2. Update the relevant `skills/{name}/SKILL.md` or `templates/*.md`
3. Run `./sync.sh` to pull latest specs if needed
4. Open a PR describing what changed and why

**Key rule**: Skills are architecture-neutral. Project-specific values belong in templates, not skills.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for full version history.

**Latest**: v1.1.0 — renamed `boardy-start` → `boardy-vip`, added `sync.sh`, refactored `boardy-review` to read from spec.

---

## License

MIT
