#!/usr/bin/env bash
# check-frontmatter.sh — Validate YAML frontmatter in docs
# Exit 1 if any rule is violated. Designed for CI and pre-commit.
set -eu

EXIT=0
err() { echo "❌ $1"; EXIT=1; }
# Extract a frontmatter field value from a header string
get_field() { echo "$1" | grep "^$2:" | sed "s/^$2: *//" | head -1; }

# --- Rule 1: docs/current/ must have status: active + source_of_truth ---
for f in docs/current/*.md; do
  [ -f "$f" ] || continue
  header=$(head -20 "$f")
  echo "$header" | grep -q "^status: active" || err "$f: missing 'status: active'"
  echo "$header" | grep -q "^source_of_truth:" || err "$f: missing 'source_of_truth'"
  echo "$header" | grep -q "^owner:" || err "$f: missing 'owner'"
  echo "$header" | grep -q "^last_verified:" || err "$f: missing 'last_verified'"

  # If source_of_truth is code, code_ref must exist
  sot=$(get_field "$header" "source_of_truth")
  if [ "$sot" = "code" ]; then
    cr=$(get_field "$header" "code_ref")
    if [ -z "$cr" ]; then
      err "$f: source_of_truth=code but missing 'code_ref'"
    else
      # Extract file path (before #symbol if present)
      cr_file="${cr%%#*}"
      if [ ! -e "$cr_file" ]; then
        err "$f: code_ref '$cr_file' does not exist"
      fi
    fi
  fi
done

# --- Rule 2: docs/adr/ must have status: active ---
for f in docs/adr/*.md; do
  [ -f "$f" ] || continue
  header=$(head -20 "$f")
  echo "$header" | grep -q "^status: active" || err "$f: missing 'status: active'"
done

# --- Rule 3: docs/archive/ must NOT have status: active ---
while IFS= read -r -d '' f; do
  if head -20 "$f" | grep -q "^status: active"; then
    err "$f: archive file cannot be 'status: active'"
  fi
done < <(find docs/archive -name "*.md" -print0 2>/dev/null)

# --- Rule 4: CONTEXT*.md must not be in docs/ root or docs/current/ ---
for f in docs/CONTEXT*.md docs/current/CONTEXT*.md; do
  [ -f "$f" ] && err "$f: CONTEXT files belong in docs/archive/context/"
done

# --- Rule 5: deprecated files must have superseded_by ---
for f in docs/current/*.md docs/adr/*.md; do
  [ -f "$f" ] || continue
  header=$(head -20 "$f")
  status=$(get_field "$header" "status")
  if [ "$status" = "deprecated" ]; then
    echo "$header" | grep -q "^superseded_by:" || err "$f: status=deprecated but missing 'superseded_by'"
  fi
done

# --- Rule 6: work/ files must have status; done files must have completed date ---
while IFS= read -r -d '' f; do
  header=$(head -10 "$f")
  # Must have frontmatter delimiter
  if ! head -1 "$f" | grep -q "^---"; then
    err "$f: missing YAML frontmatter"
    continue
  fi
  echo "$header" | grep -q "^status:" || err "$f: missing 'status'"
  echo "$header" | grep -q "^created:" || err "$f: missing 'created' date"
  status=$(get_field "$header" "status")
  if [ "$status" = "done" ]; then
    completed=$(get_field "$header" "completed")
    if [ -z "$completed" ]; then
      err "$f: status=done but missing 'completed' date (staleness bot needs it)"
    fi
  fi
done < <(find work/ -name "*.md" -print0 2>/dev/null)

if [ $EXIT -eq 0 ]; then
  echo "✅ All frontmatter checks passed"
fi
exit $EXIT
