#!/usr/bin/env bash
# check-docs-impact.sh — Ensure code changes are reflected in docs
# Parameterized version for composite action use.
#
# Required env vars:
#   CODE_IMPACT_PATTERNS — pipe-separated glob patterns (e.g. "src/*|include/*|CMakeLists.txt")
#   BYPASS_LABEL         — label name to skip check (e.g. "docs-not-needed")
set -eu

BASE_BRANCH="${1:-origin/main}"

if [ -z "${CODE_IMPACT_PATTERNS:-}" ]; then
  echo "❌ CODE_IMPACT_PATTERNS not set" >&2
  exit 1
fi

BYPASS_LABEL="${BYPASS_LABEL:-docs-not-needed}"

# Get changed files in this PR/branch
CHANGED=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --name-only HEAD~1)

# Helper: check if a file matches any code impact pattern
matches_code_path() {
  local file="$1"
  local IFS='|'
  for pat in $CODE_IMPACT_PATTERNS; do
    case "$file" in
      $pat) return 0 ;;
    esac
  done
  return 1
}

# Check if code files changed
CODE_CHANGED=false
for f in $CHANGED; do
  if matches_code_path "$f"; then
    CODE_CHANGED=true
    break
  fi
done

if ! $CODE_CHANGED; then
  echo "✅ No code changes — docs-impact check skipped"
  exit 0
fi

# Check if any docs/current/ file was also changed
DOCS_CHANGED=false
for f in $CHANGED; do
  case "$f" in
    docs/current/*)
      DOCS_CHANGED=true
      break
      ;;
  esac
done

if $DOCS_CHANGED; then
  echo "✅ Code and docs both changed — docs-impact check passed"
  exit 0
fi

# Check for label (GitHub Actions only)
if [ -n "${GITHUB_EVENT_PATH:-}" ]; then
  if command -v jq &>/dev/null; then
    LABELS=$(jq -r '.pull_request.labels[].name // empty' "$GITHUB_EVENT_PATH" 2>/dev/null)
    if echo "$LABELS" | grep -q "$BYPASS_LABEL"; then
      echo "✅ '$BYPASS_LABEL' label found — docs-impact check skipped"
      exit 0
    fi
  fi
fi

echo "❌ Code changed but no docs/current/ file was updated."
echo "   Either update the relevant doc, or add the '$BYPASS_LABEL' label."
echo ""
echo "   Changed code files:"
for f in $CHANGED; do
  if matches_code_path "$f"; then
    echo "     $f"
  fi
done
exit 1
