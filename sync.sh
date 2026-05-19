#!/usr/bin/env bash
# sync.sh — Copy architecture + workflow specs from a project into skills/boardy-vip/specs/
#
# Usage:
#   ./sync.sh /path/to/project
#   ./sync.sh /path/to/project --bump-version
#
# Options:
#   --bump-version   Increment patch version in all SKILL.md frontmatter and CHANGELOG.md
#
# What it does:
#   1. Copies architecture specs from <project>/.ai/specs/*.md
#   2. Copies workflow rules from <project>/.claude/rules/*.md (QUICK_REF, COMMIT_WORKFLOW, SPEC_SYNC, PLAN_EXECUTION, …)
#   3. Skips project-specific bindings: PROJECT_CONFIG.md, PROJECT_STRUCTURE.md, ADOPTION.md
#   4. Skips project-specific ADRs under .claude/project/decisions/ (those are decisions, not patterns)
#   5. Optionally bumps the patch version (1.1.0 → 1.1.1) across all SKILL.md files
#
# Backwards-compatible: if the first argument is a directory ending in /.ai/specs or /rules, this
# script also accepts a direct path to a single specs directory (legacy form).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECS_DEST="$SCRIPT_DIR/skills/boardy-vip/specs"

# ── Arg parsing ───────────────────────────────────────────────────────────────
SOURCE_ARG="${1:-}"
BUMP_VERSION=false

for arg in "$@"; do
  case "$arg" in
    --bump-version) BUMP_VERSION=true ;;
  esac
done

if [[ -z "$SOURCE_ARG" || "$SOURCE_ARG" == --* ]]; then
  echo "Usage: ./sync.sh /path/to/project [--bump-version]"
  echo ""
  echo "Example:"
  echo "  ./sync.sh ~/projects/QuizCombatApp"
  echo "  ./sync.sh ~/projects/QuizCombatApp --bump-version"
  exit 1
fi

if [[ ! -d "$SOURCE_ARG" ]]; then
  echo "ERROR: Directory not found: $SOURCE_ARG"
  exit 1
fi

# Detect input form: project root vs direct specs dir (legacy)
SOURCE_DIRS=()
if [[ -d "$SOURCE_ARG/.ai/specs" ]]; then
  SOURCE_DIRS+=("$SOURCE_ARG/.ai/specs")
fi
if [[ -d "$SOURCE_ARG/.claude/rules" ]]; then
  SOURCE_DIRS+=("$SOURCE_ARG/.claude/rules")
fi

# Legacy form: treat the path itself as a specs source
if [[ ${#SOURCE_DIRS[@]} -eq 0 ]]; then
  SOURCE_DIRS+=("$SOURCE_ARG")
fi

# ── Files to skip (project-specific bindings, not architecture/workflow specs) ─
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
echo "Syncing specs into: $SPECS_DEST"
for d in "${SOURCE_DIRS[@]}"; do
  echo "  source: $d"
done
echo ""

mkdir -p "$SPECS_DEST"

copied=0
skipped=0

for src_dir in "${SOURCE_DIRS[@]}"; do
  for src_file in "$src_dir"/*.md; do
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
done

echo ""
echo "Done: $copied files copied, $skipped skipped."

# ── Version bump ──────────────────────────────────────────────────────────────
if [[ "$BUMP_VERSION" == true ]]; then
  echo ""
  echo "Bumping patch version in all SKILL.md files..."

  for skill_file in "$SCRIPT_DIR/skills"/*/SKILL.md; do
    [[ -f "$skill_file" ]] || continue

    current=$(grep -E '^version: ' "$skill_file" | head -1 | sed 's/version: //')
    if [[ -z "$current" ]]; then
      echo "  WARNING: no version field in $skill_file — skipping"
      continue
    fi

    IFS='.' read -r major minor patch <<< "$current"
    new_version="$major.$minor.$((patch + 1))"

    sed -i '' "s/^version: $current$/version: $new_version/" "$skill_file"
    echo "  $(basename "$(dirname "$skill_file")"): $current → $new_version"
  done

  new_version_str=$(grep -E '^version: ' "$SCRIPT_DIR/skills/boardy-vip/SKILL.md" | head -1 | sed 's/version: //')
  today=$(date +%Y-%m-%d)

  changelog="$SCRIPT_DIR/CHANGELOG.md"
  tmp_changelog=$(mktemp)

  awk -v ver="$new_version_str" -v date="$today" '
    /^---$/ && !inserted {
      print
      print ""
      print "## " ver " — " date
      print ""
      print "Spec sync from project rules — run `./sync.sh ... --bump-version`."
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
