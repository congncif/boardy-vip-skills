#!/usr/bin/env bash
# Boardy+VIP Skills Pack — Install Script
# Usage: ./install.sh [--uninstall]
set -e

SKILLS_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SKILLS="$SCRIPT_DIR/skills"

SKILL_NAMES=(
  "boardy-vip"
  "boardy-module"
  "boardy-board"
  "boardy-review"
  "boardy-setup"
)

# Skills renamed in previous versions — remove on install and uninstall
LEGACY_SKILL_NAMES=(
  "boardy-start"
)

# ── Uninstall ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  echo "Uninstalling Boardy+VIP skills..."
  for skill in "${SKILL_NAMES[@]}" "${LEGACY_SKILL_NAMES[@]}"; do
    target="$SKILLS_DIR/$skill"
    if [[ -d "$target" ]]; then
      rm -rf "$target"
      echo "  removed: $target"
    fi
  done
  echo "Done."
  exit 0
fi

# ── Remove legacy installs ─────────────────────────────────────────────────────
for legacy in "${LEGACY_SKILL_NAMES[@]}"; do
  target="$SKILLS_DIR/$legacy"
  if [[ -d "$target" ]]; then
    rm -rf "$target"
    echo "  removed legacy: $target"
  fi
done

# ── Install ────────────────────────────────────────────────────────────────────
echo "Installing Boardy+VIP skills to $SKILLS_DIR"

if [[ ! -d "$SKILLS_DIR" ]]; then
  mkdir -p "$SKILLS_DIR"
  echo "  created: $SKILLS_DIR"
fi

for skill in "${SKILL_NAMES[@]}"; do
  src="$SOURCE_SKILLS/$skill"
  target="$SKILLS_DIR/$skill"

  if [[ ! -d "$src" ]]; then
    echo "  WARNING: skill not found at $src — skipping"
    continue
  fi

  if [[ -d "$target" ]]; then
    rm -rf "$target"
  fi

  cp -r "$src" "$target"
  echo "  installed: $skill"
done

echo ""
echo "Installation complete. Skills available:"
for skill in "${SKILL_NAMES[@]}"; do
  echo "  - $skill"
done
echo ""
echo "Verify with: ls $SKILLS_DIR | grep boardy-"
echo ""
echo "Usage in Claude Code:"
echo "  Skill({ skill: \"boardy-vip\" })"
echo "  Skill({ skill: \"boardy-module\" })"
echo "  Skill({ skill: \"boardy-board\" })"
echo "  Skill({ skill: \"boardy-review\" })"
echo "  Skill({ skill: \"boardy-setup\" })"
