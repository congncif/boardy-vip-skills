# Changelog

All notable changes to the Boardy+VIP Skills Pack are documented here.

Format: `version — date — summary`

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
