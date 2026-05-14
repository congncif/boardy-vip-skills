# SYNC_GUIDE — AI Sync Instructions for boardy-vip-skills

This file is written **for an AI agent** performing a spec sync. Follow it precisely.  
It is not a narrative document — every section is an executable decision rule.

---

## 1. What sync.sh does vs what you must do

`sync.sh` does mechanical work only:

```
copy .md files → skills/boardy-vip/specs/
optionally bump patch version in SKILL.md frontmatters
```

**sync.sh cannot do:**
- Determine if a spec change affects a SKILL.md *behaviorally*
- Update SKILL.md content to reflect new or changed rules
- Detect when a new spec was added and needs a routing entry

That is your job. After `./sync.sh` completes, follow this guide.

---

## 2. Run sync — then diff

```bash
./sync.sh /path/to/project/.claude/rules/
git diff skills/boardy-vip/specs/
```

Collect the list of changed specs. For each changed spec, consult the mapping tables below.

---

## 3. Spec → Skill mapping

The table below shows: which spec → which SKILL.md → which **named section** is affected.

| Changed spec | Affected skill | Affected section in SKILL.md |
|---|---|---|
| `QUICK_REF.md` | `boardy-vip` | Task → Spec Routing, Non-UI Board Decision Tree, Naming Conventions, 10 Non-Negotiable Rules, Key Code Patterns |
| `ARCHITECTURE.md` | `boardy-vip` | Module Folder Skeleton, Task → Spec Routing |
| `MICROBOARD_NONUI.md` | `boardy-vip` | Non-UI Board Decision Tree |
| `MICROBOARD_NONUI.md` | `boardy-board` | Board Type Decision, Flow Board, Viewless Board, complete() Semantics |
| `MICROBOARD_UI.md` | `boardy-board` | UI VIP Board, Presentation Rules |
| `COMMUNICATION.md` | `boardy-board` | complete() Semantics, Navigation Patterns |
| `COMMUNICATION.md` | `boardy-vip` | Key Code Patterns → Board Communication |
| `CONTEXT_NAVIGATION.md` | `boardy-board` | Navigation Patterns |
| `VIP_COMPONENTS.md` | `boardy-board` | UI VIP Board (Controller section) |
| `MODULE_CREATION.md` | `boardy-module` | Step-by-Step, podspec Templates, Validation Checklist |
| `IO_INTERFACE.md` | `boardy-module` | Step-by-Step (IO layer), Validation Checklist |
| `PLUGINS_INTEGRATION.md` | `boardy-module` | LauncherPlugin Template, ModulePlugin Template, Validation Checklist |
| `PLUGINS_INTEGRATION.md` | `boardy-vip` | Module Folder Skeleton |
| `SERVICE_LAYER.md` | *(no SKILL.md)* | Spec is read live. No update needed. |
| `LAYERING.md` | *(no SKILL.md)* | Spec is read live. No update needed. |
| `CROSS_MODULE_DI.md` | *(no SKILL.md)* | Spec is read live. No update needed. |
| `PER_ACTIVATION_RESOURCES.md` | `boardy-vip` | 10 Non-Negotiable Rules (Rule 8 area), Key Code Patterns |
| `EXTENSIBLE_PROVIDER.md` | `boardy-vip` | 10 Non-Negotiable Rules, Task → Spec Routing |
| `ACTIVATION_BARRIER.md` | `boardy-vip` | Task → Spec Routing |
| `ACTIVATION_BARRIER.md` | `boardy-board` | Activation Barrier section, complete() Semantics |
| `REVIEWER_CHECKLIST.md` | `boardy-review` | **Reads live — no update needed unless section order changes** |
| `REVIEWER_CHECKLIST.md` | `boardy-vip` | Quick Fails list in boardy-review Quick Fails section |
| `COMPOSABLE_BOARD.md` | `boardy-board` | Board Type Decision (composable row) |
| `COMPOSABLE_BOARD.md` | `boardy-vip` | Task → Spec Routing |
| `SDK_FIRST.md` | *(no SKILL.md)* | Spec is read live. No update needed. |
| `TESTING.md` | *(no SKILL.md)* | Spec is read live. No update needed. |
| `CONVENTIONS.md` | `boardy-vip` | Naming Conventions (if naming patterns change) |
| `EXAMPLES*.md` | *(no SKILL.md)* | Examples are read live via boardy-vip routing. No update needed. |

**Specs not listed above** (e.g. `COMMIT_WORKFLOW.md`, `ADOPTION.md`, `README.md`):  
→ These are project-operational docs. SKILL.md is not derived from them. Skip.

---

## 4. Change type → update decision

For each spec listed as affecting a SKILL.md, classify the change:

### 4.1 Change types that require SKILL.md update

| Change type | Example | Action |
|---|---|---|
| **New rule added** | "Board must never call `complete()` before `sendOutput()`" | Add to relevant Rules/Quick Fails section |
| **Existing rule modified** | Decision tree branch renamed or re-ordered | Update the Decision Tree section |
| **New board type introduced** | New non-UI board variant (e.g. new concurrency pattern) | Update Board Type Decision section |
| **Code pattern changed** | Bus connection order changed, new async pattern | Update relevant code snippet in Key Code Patterns |
| **New spec file added** | `NEW_SPEC.md` added to specs/ | Add a row to Task → Spec Routing in boardy-vip |
| **Spec file removed** | `OLD_SPEC.md` deleted | Remove row from Task → Spec Routing; check if any SKILL.md referenced it directly |
| **Naming convention changed** | New ServiceMap property naming pattern | Update Naming Conventions in boardy-vip |
| **New Quick Fail condition** | New immediately-rejectable code smell | Add to boardy-review Quick Fails section |
| **Module structure changed** | New required file in module scaffold | Update Module Folder Skeleton in boardy-vip, Step-by-Step in boardy-module |
| **podspec syntax changed** | New required dependency pattern | Update podspec Templates in boardy-module |
| **LauncherPlugin/ModulePlugin pattern changed** | New required method or field | Update relevant template in boardy-module |

### 4.2 Change types that do NOT require SKILL.md update

| Change type | Example | Why skip |
|---|---|---|
| **Wording/prose change** | Explanation rewritten for clarity | SKILL.md surfaces rules, not explanations |
| **Example code reformatted** | Variable renamed in example | Examples are read live via routing |
| **New section in spec** | New deep-dive subsection added | SKILL.md is a summary; specs are the source |
| **Comment added to spec** | Context note added | Comments are narrative, not rules |
| **Spec reorganized but rule unchanged** | Sections reordered | Rule is the same; no behavior change |
| **REVIEWER_CHECKLIST.md updated** | New checklist item in existing section | boardy-review reads live — auto-updated |
| **SERVICE_LAYER / LAYERING / TESTING changed** | Any change | These specs are read live, no SKILL.md derives from them |

---

## 5. Section-level update rules

### boardy-vip: Task → Spec Routing (lines ~12–33)

**Update when:**
- A new spec file is added to `specs/` → add a row with the task description and `Read ~/.claude/skills/boardy-vip/specs/NEW_SPEC.md`
- An existing spec is renamed → update the spec filename in the row
- A routing change is made in `QUICK_REF.md` § Task → Spec Routing

**Do not add** rows for specs already routed through a sub-skill (`boardy-board`, `boardy-module`). Those delegate.

---

### boardy-vip: Non-UI Board Decision Tree (lines ~35–49)

**Source of truth:** `MICROBOARD_NONUI.md` → Decision Tree section.

**Update when:**
- A new non-UI board type is added
- The criteria for choosing between Flow/Viewless/BlockTask change
- The "VIP board as coordinator" rule is strengthened or clarified

**Format rule:** keep it as a plain-text decision tree. No prose. Each branch is one line ending with `→ BoardType`.

---

### boardy-vip: 10 Non-Negotiable Rules (lines ~85–96)

**Source of truth:** `QUICK_REF.md` § The 10 Rules.

**Update when:**
- A new never-break rule is added
- An existing rule's wording changes its meaning
- A rule is removed (rare)

**Format rule:** numbered list, one sentence max per rule, bolded concept at start. Do not exceed 10–12 rules total. If a rule requires more than one sentence, it belongs in a spec, not here.

---

### boardy-vip: Key Code Patterns (lines ~98–146)

Three sub-sections:
1. **Board Communication** — sourced from `COMMUNICATION.md`
2. **Async/Await** — sourced from `VIP_COMPONENTS.md` / `QUICK_REF.md`
3. **registerFlows Always in init** — sourced from `MICROBOARD_UI.md`

**Update when:** the actual Swift code pattern changes (new API, new required wrapping, new bus usage).  
**Do not update** when only the prose explanation around the pattern changes.

---

### boardy-board: Board Type Decision (lines ~9–28)

**Source of truth:** `MICROBOARD_NONUI.md` → Decision Tree.

**Update when:** a new board type is introduced, or criteria for choosing change.  
**Format:** plain-text decision tree, same structure as current.

---

### boardy-board: complete() Semantics (lines ~223–235)

**Source of truth:** `COMMUNICATION.md` → Board Lifecycle → When to call complete().

**Update when:**
- A board type is added/removed from the table
- The `sendOutput()`-before-`complete()` ordering rule changes
- The "double-complete raises assertion" behavior changes

---

### boardy-board: Navigation Patterns (lines ~239–254)

**Source of truth:** `CONTEXT_NAVIGATION.md`.

**Update when:** the `backToPrevious` / `returnHere` / `topPresentedViewController` patterns change at the code level.  
**Do not update** for prose clarifications.

---

### boardy-module: Step-by-Step (lines ~13–92)

**Source of truth:** `MODULE_CREATION.md` → Steps 1–7.

**Update when:** any step changes (new required command, new file to create, pod install trigger condition).  
Each step in SKILL.md must match the corresponding step in spec exactly.

---

### boardy-module: Validation Checklist (lines ~182–193)

**Source of truth:** `MODULE_CREATION.md` checklist + `PLUGINS_INTEGRATION.md` checklist.

**Update when:** a new required item is added to either spec's checklist.  
Every item here must be independently verifiable by an AI without reading the spec.

---

### boardy-review: Quick Fails (lines ~29–37)

**Update when:** `REVIEWER_CHECKLIST.md` adds a new "stop review immediately" condition.

**Criteria for Quick Fail status:** a violation that is always wrong with no valid exception, visible in the file without reading surrounding context, and should stop review before wasting time on the rest.

Current Quick Fails (verify these still match `REVIEWER_CHECKLIST.md`):
- `public` inside `Sources/` files
- Import of `{Module}Plugins` from another module
- `registerFlows()` called inside `activate()`
- ViewModel constructed in Interactor
- Business logic inside ViewController
- Board stores per-activation service as property
- `public enum {Feature}ProviderConfiguration` (enum form of provider config)

---

### boardy-review: How to Apply section (lines ~17–27)

**Update when:** `REVIEWER_CHECKLIST.md` adds a new top-level section or changes the review order.  
The numbered list here must mirror the section order in `REVIEWER_CHECKLIST.md`.

Current section order:
1. Architecture Rules
2. Per-Activation Resources
3. Activation Barrier
4. Extensible Provider
5. Module Structure
6. IO Layer
7. VIP Components
8. Service Layer
9. Context Navigation

---

## 6. New spec added — full checklist

When a **new** `.md` file appears in `specs/` after sync:

- [ ] Is it a project-binding file (`PROJECT_CONFIG.md`, `PROJECT_STRUCTURE.md`, `ADOPTION.md`)? → **skip everything below**
- [ ] Read the new spec. What task does it address?
- [ ] Add a row to **boardy-vip Task → Spec Routing** with the task description
- [ ] Does it introduce new rules?  
  - If always-reject → add to **boardy-review Quick Fails**  
  - If never-break → add to **boardy-vip 10 Non-Negotiable Rules**  
  - If code-pattern change → add to **boardy-board** or **boardy-vip Key Code Patterns**
- [ ] Does it change module scaffold / podspec / LauncherPlugin? → update **boardy-module**
- [ ] Does it change board type decision criteria? → update **boardy-board Board Type Decision**
- [ ] Bump version with `--bump-version` flag if any SKILL.md changed

---

## 7. After all SKILL.md updates — verification

Before committing:

1. **Routing completeness** — every spec in `specs/` has a corresponding row in boardy-vip Task → Spec Routing (or is covered by a sub-skill delegation row)
2. **Quick Fails parity** — every item in boardy-review Quick Fails exists as a rule in `REVIEWER_CHECKLIST.md`
3. **Decision Tree parity** — boardy-vip Non-UI Board Decision Tree branches match `MICROBOARD_NONUI.md` top-level branches exactly
4. **Rules count** — boardy-vip has ≤12 numbered rules; each maps to a rule in `QUICK_REF.md`
5. **No stale spec paths** — no SKILL.md references a spec filename that no longer exists in `specs/`

Run a quick grep to catch stale references:
```bash
grep -r "specs/" skills/*/SKILL.md | grep -v "boardy-vip/specs"
# Should return nothing — all spec paths must be under boardy-vip/specs/
```

---

## 8. Version bumping policy

| What changed | Bump? |
|---|---|
| Spec files updated (content only, no SKILL.md changes) | Optional — use judgment |
| Any SKILL.md content changed | **Yes — always bump** |
| New spec file added and routing updated | **Yes — always bump** |
| Spec file removed and routing updated | **Yes — always bump** |

Run: `./sync.sh /path/to/rules/ --bump-version`

---

## 9. Commit message convention

```
sync: update specs from project rules v{new_version}

- {spec name}: {one-line summary of what changed}
- {spec name}: {one-line summary of what changed}
- boardy-{skill}: updated {section name} — {reason}
```

Example:
```
sync: update specs from project rules v1.1.2

- EXTENSIBLE_PROVIDER.md: added InputType alias rule for provider boards
- REVIEWER_CHECKLIST.md: added new Quick Fail for typealias InputType = Void
- boardy-vip: updated 10 Non-Negotiable Rules — new rule for InputType alias
- boardy-review: updated Quick Fails — added typealias InputType = Void condition
```

---

## 10. What this guide does NOT cover

- Changes to `install.sh` or `sync.sh` scripts themselves
- Changes to `templates/` directory
- Adding or removing skills entirely
- Changes to `CHANGELOG.md` format (maintained by `sync.sh --bump-version`)

For structural changes to the skill pack itself, edit this guide first, then implement.
