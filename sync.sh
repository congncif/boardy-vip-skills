#!/usr/bin/env bash
# sync.sh — Copy architecture specs from a project's .claude/rules/ into skills/boardy-vip/specs/
#
# Usage:
#   ./sync.sh /path/to/project/.claude/rules/
#   ./sync.sh /path/to/project/.claude/rules/ --bump-version
#
# Options:
#   --bump-version   Increment patch version in all SKILL.md frontmatter and CHANGELOG.md
#
# What it does:
#   1. Copies all .md files from the given rules/ directory to skills/boardy-vip/specs/
#   2. Skips files that are project-specific bindings (PROJECT_CONFIG.md, PROJECT_STRUCTURE.md)
#   3. Optionally bumps the patch version (1.1.0 → 1.1.1) across all SKILL.md files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECS_DEST="$SCRIPT_DIR/skills/boardy-vip/specs"

# ── Arg parsing ───────────────────────────────────────────────────────────────
SOURCE_RULES="${1:-}"
BUMP_VERSION=false

for arg in "$@"; do
  case "$arg" in
    --bump-version) BUMP_VERSION=true ;;
  esac
done

if [[ -z "$SOURCE_RULES" || "$SOURCE_RULES" == --* ]]; then
  echo "Usage: ./sync.sh /path/to/project/.claude/rules/ [--bump-version]"
  echo ""
  echo "Example:"
  echo "  ./sync.sh ~/projects/QuizCombatApp/.claude/rules/"
  echo "  ./sync.sh ~/projects/QuizCombatApp/.claude/rules/ --bump-version"
  exit 1
fi

if [[ ! -d "$SOURCE_RULES" ]]; then
  echo "ERROR: Directory not found: $SOURCE_RULES"
  exit 1
fi

# ── Files to skip (project-specific bindings, not architecture specs) ─────────
SKIP_FILES=(
  "PROJECT_CONFIG.md"
  "PROJECT_STRUCTURE.md"
  "ADOPTION.md"
)

is_skipped() {
  local file="$1"
  for skip in "${SKIP_FILES[@]}"; do
    [[ "$(basename "$file")" == "$skip" ]] && return 0
  done
  return 1
}

# ── Copy specs ────────────────────────────────────────────────────────────────
echo "Syncing specs from: $SOURCE_RULES"
echo "         target:    $SPECS_DEST"
echo ""

mkdir -p "$SPECS_DEST"

copied=0
skipped=0

for src_file in "$SOURCE_RULES"*.md; do
  [[ -f "$src_file" ]] || continue

  filename="$(basename "$src_file")"

  if is_skipped "$src_file"; then
    echo "  skip (project-binding): $filename"
    ((skipped++)) || true
    continue
  fi

  dest_file="$SPECS_DEST/$filename"
  cp "$src_file" "$dest_file"
  echo "  copied: $filename"
  ((copied++)) || true
done

echo ""
echo "Done: $copied files copied, $skipped skipped."

# ── Version bump ──────────────────────────────────────────────────────────────
if [[ "$BUMP_VERSION" == true ]]; then
  echo ""
  echo "Bumping patch version in all SKILL.md files..."

  for skill_file in "$SCRIPT_DIR/skills"/*/SKILL.md; do
    [[ -f "$skill_file" ]] || continue

    # Extract current version (e.g. "1.1.0")
    current=$(grep -E '^version: ' "$skill_file" | head -1 | sed 's/version: //')
    if [[ -z "$current" ]]; then
      echo "  WARNING: no version field in $skill_file — skipping"
      continue
    fi

    # Parse major.minor.patch and increment patch
    IFS='.' read -r major minor patch <<< "$current"
    new_version="$major.$minor.$((patch + 1))"

    # Replace in file (macOS-compatible sed)
    sed -i '' "s/^version: $current$/version: $new_version/" "$skill_file"
    echo "  $(basename "$(dirname "$skill_file")"): $current → $new_version"
  done

  # Update CHANGELOG — prepend new entry
  new_version_str=""
  # Re-read version from boardy-vip skill as canonical
  new_version_str=$(grep -E '^version: ' "$SCRIPT_DIR/skills/boardy-vip/SKILL.md" | head -1 | sed 's/version: //')
  today=$(date +%Y-%m-%d)

  changelog="$SCRIPT_DIR/CHANGELOG.md"
  tmp_changelog=$(mktemp)

  # Inject new entry after the first "---" separator
  awk -v ver="$new_version_str" -v date="$today" '
    /^---$/ && !inserted {
      print
      print ""
      print "## " ver " — " date
      print ""
      print "Spec sync from project rules — run \`./sync.sh ... --bump-version\`."
      print ""
      print "- Updated bundled specs in `skills/boardy-vip/specs/`"
      print ""
      inserted=1
      next
    }
    { print }
  ' "$changelog" > "$tmp_changelog"

  mv "$tmp_changelog" "$changelog"
  echo ""
  echo "CHANGELOG.md updated with version $new_version_str."
fi

echo ""
echo "Next steps:"
echo "  1. Review changes: git diff skills/boardy-vip/specs/"
echo "  2. If behavior changed (not just spec text), update the relevant SKILL.md"
echo "  3. Commit: git add -p && git commit -m 'sync: update specs from project rules'"
echo "  4. Push and re-run install.sh on all machines: git pull && ./install.sh"
