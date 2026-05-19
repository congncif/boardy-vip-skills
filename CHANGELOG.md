# Changelog

All notable changes to the Boardy+VIP Skills Pack are documented here.

Format: `version — date — summary`

---

## 1.2.0 — 2026-05-19

**Portability refactor** — plugin specs are now fully project-agnostic and reusable across any Boardy+VIP project.

- **Placeholder convention**: project paths in specs now use `{ProjectConfigPath}`, `{ProjectStructurePath}`, `{DecisionsPath}`, `{ModuleTemplatesPath}` instead of hardcoded `.claude/rules/...`. Consumers bind paths via CLAUDE.md.
- **New bundled specs**: `SPEC_SYNC.md` (12-row sync detection checklist + anti-drift invariants), `PLAN_EXECUTION.md` (long-plan build verification cadence).
- **New ADR template**: `templates/decisions/README.md` provides a portable Michael Nygard ADR program README for consumers to drop into `.claude/project/decisions/`.
- **Bindings layout**: templates target `.claude/project/` (bindings) rather than `.claude/rules/` (rule pack). Updates `boardy-setup` SKILL.md, README.md, and ADOPTION.md accordingly.
- **`sync.sh` rewritten**: auto-discovers `<project>/.ai/specs/` + `<project>/.claude/rules/` from a project root. Legacy single-dir form still supported.
- **`SYNC_GUIDE.md`**: documents auto-discovery, new mapping rows for `SPEC_SYNC.md` and `PLAN_EXECUTION.md`.
- **Cross-spec refs**: stripped `.claude/rules/` prefix from inter-spec references (filename-only) since plugin specs co-locate under `skills/boardy-vip/specs/`.
- **`boardy-setup` rewritten as interactive bootstrap**: 12-phase workflow that uses `AskUserQuestion` to collect values, auto-discovers workspace + simulator, `Write`s `CLAUDE.md` + bindings + ADR README, branches on **CocoaPods / SwiftPM / Both** dependency manager choice, scaffolds the first module via `boardy-module`, and verifies the build. Required vs optional fields explicit; optional fields skippable. Skipped items written to `${BindingsRoot}/SETUP_TODO.md` so the user stays aware of pending setup. Replaces the prior runbook-style checklist.
- All 5 SKILL.md files bumped to `version: 1.2.0`.

**Migration**: existing consumers with `.claude/rules/PROJECT_CONFIG.md` and `.claude/rules/PROJECT_STRUCTURE.md` can either keep them in place (update CLAUDE.md placeholders to point at `.claude/rules/`) or move bindings to `.claude/project/` to match the new default.

---

## 1.1.4 — 2026-05-17

Spec sync from project rules — run `./sync.sh ... --bump-version`.

- Updated bundled specs in `skills/boardy-vip/specs/`


## 1.1.2 — 2026-05-15

Spec sync from project rules — run `./sync.sh ... --bump-version`.

- Updated bundled specs in `skills/boardy-vip/specs/`


## 1.1.1 — 2026-05-14

Spec sync from project rules — run `./sync.sh ... --bump-version`.

- Updated bundled specs in `skills/boardy-vip/specs/`


## 1.1.0 — 2026-05-14

**Breaking rename**: skill `boardy-start` → `boardy-vip` to align folder name with skill name and purpose.

- Renamed `skills/boardy-vip/` SKILL.md frontmatter from `name: boardy-start` → `name: boardy-vip`
- Updated `install.sh` SKILL_NAMES: `boardy-start` → `boardy-vip`; added auto-cleanup of old `boardy-start` install
- Updated all spec path references from `~/.claude/skills/boardy-start/specs/` → `~/.claude/skills/boardy-vip/specs/`
- Refactored `boardy-review`: removed embedded checklist, now reads live from `REVIEWER_CHECKLIST.md` spec so it stays in sync automatically
- Added `version:` field to frontmatter of all 5 skills
- Added `sync.sh` — copies specs from project `.claude/rules/` into `skills/boardy-vip/specs/` and bumps version
- Added this CHANGELOG

**Migration**: run `./install.sh` to reinstall. The script removes the old `boardy-start` directory automatically. Update any project CLAUDE.md references from `boardy-start` → `boardy-vip`.

---

## 1.0.0 — 2026-05-14

Initial release — 5 skills, 3 templates, install.sh.

Skills: `boardy-start`, `boardy-module`, `boardy-board`, `boardy-review`, `boardy-setup`.
Specs bundled inside `boardy-start/specs/` (30 architecture spec files).
