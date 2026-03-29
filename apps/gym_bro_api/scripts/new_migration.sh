#!/usr/bin/env bash
# new_migration.sh — Generate a new empty migration file in sql/schemas/
#
# Usage:
#   ./scripts/new_migration.sh <title>
#
# Example:
#   ./scripts/new_migration.sh add_workouts_table
#   → creates sql/schemas/000002_add_workouts_table.sql

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: ./scripts/new_migration.sh <title>" >&2
  exit 1
fi

TITLE="${1// /_}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMAS_DIR="$(dirname "$SCRIPT_DIR")/sql/schemas"

# Find the highest existing migration number
LAST=$(ls "$SCHEMAS_DIR"/[0-9]*.sql 2>/dev/null \
  | grep -oE '^.*/[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -1)

NEXT=$(printf "%06d" $(( ${LAST:-0} + 1 )))
FILE="$SCHEMAS_DIR/${NEXT}_${TITLE}.sql"

touch "$FILE"
echo "Created: $FILE"
