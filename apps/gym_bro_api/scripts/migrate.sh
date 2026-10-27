#!/usr/bin/env bash
# migrate.sh — Apply sql/schemas/*.sql to a Postgres database, tracking what
# has been applied in public._schema_migrations.
#
# Order: users.sql first, then the numbered files (000001_…, 000002_…) in
# numeric order. Each file runs with ON_ERROR_STOP; a file is recorded only
# after it applied cleanly, and a failure stops the run.
#
# Usage:
#   ./scripts/migrate.sh             # apply pending files
#   ./scripts/migrate.sh --status    # list applied / pending files, change nothing
#   ./scripts/migrate.sh --baseline  # record every file as applied WITHOUT running
#                                    # it (for databases migrated by hand)
#
# Target: $DATABASE_URL, default the local Supabase stack
#   postgresql://postgres:postgres@127.0.0.1:54322/postgres
#
# Uses `psql` when installed; otherwise runs psql inside the local Supabase DB
# container (supabase_db_gym_bro_api, override with $DB_CONTAINER) via
# `docker exec` (the container publishing the URL's port, for local URLs),
# rewriting that port to the container's 5432.
#
# The tracking table has RLS enabled and no grants to anon/authenticated, so it
# is invisible through the REST API.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMAS_DIR="$(dirname "$SCRIPT_DIR")/sql/schemas"
DEFAULT_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
DATABASE_URL="${DATABASE_URL:-$DEFAULT_URL}"
DB_CONTAINER="${DB_CONTAINER:-supabase_db_gym_bro_api}"

MODE="apply"
case "${1:-}" in
  "") ;;
  --status) MODE="status" ;;
  --baseline) MODE="baseline" ;;
  -h|--help)
    sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "Unknown option: $1 (use --status, --baseline or no argument)" >&2
    exit 2
    ;;
esac

# ── psql runner ───────────────────────────────────────────────────────────────

if command -v psql >/dev/null 2>&1; then
  run_psql() { psql "$DATABASE_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }
  TARGET_DESC="$(echo "$DATABASE_URL" | sed -E 's#://([^:@/]+):[^@]*@#://\1:***@#')"
else
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: neither psql nor docker is available." >&2
    exit 1
  fi
  # For a local URL, use the container that actually publishes that port, so a
  # second local stack never gets its SQL run against the first one.
  LOCAL_PORT="$(echo "$DATABASE_URL" | sed -nE 's#.*@(127\.0\.0\.1|localhost):([0-9]+)/.*#\2#p')"
  if [[ -n "$LOCAL_PORT" ]]; then
    PUBLISHER="$(docker ps --filter "publish=$LOCAL_PORT" --format '{{.Names}}' | head -1)"
    if [[ -z "$PUBLISHER" ]]; then
      echo "Error: psql isn't installed and no running container publishes port $LOCAL_PORT." >&2
      echo "Install psql or start the local stack (supabase start)." >&2
      exit 1
    fi
    DB_CONTAINER="$PUBLISHER"
  elif ! docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER"; then
    echo "Error: psql isn't installed and container '$DB_CONTAINER' isn't running." >&2
    echo "Install psql, or start the local stack so its psql can reach the remote database." >&2
    exit 1
  fi
  # Inside the container the database listens on 5432, not the published port.
  CONTAINER_URL="$(echo "$DATABASE_URL" | sed -E 's#@(127\.0\.0\.1|localhost):[0-9]+/#@127.0.0.1:5432/#')"
  run_psql() { docker exec -i "$DB_CONTAINER" psql "$CONTAINER_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }
  TARGET_DESC="$(echo "$CONTAINER_URL" | sed -E 's#://([^:@/]+):[^@]*@#://\1:***@#') (via docker exec $DB_CONTAINER)"
fi

checksum() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# ── Files, in order ───────────────────────────────────────────────────────────

FILES=()
[[ -f "$SCHEMAS_DIR/users.sql" ]] && FILES+=("users.sql")
while IFS= read -r f; do
  FILES+=("$f")
done < <(cd "$SCHEMAS_DIR" && ls | grep -E '^[0-9]+_.*\.sql$' | sort -n)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No migration files in $SCHEMAS_DIR" >&2
  exit 1
fi

# ── Tracking table ────────────────────────────────────────────────────────────

ensure_table() {
  run_psql <<'SQL'
SET client_min_messages = warning;
CREATE TABLE IF NOT EXISTS public._schema_migrations (
  filename   TEXT        PRIMARY KEY,
  checksum   TEXT        NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  baseline   BOOLEAN     NOT NULL DEFAULT FALSE
);
ALTER TABLE public._schema_migrations ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON public._schema_migrations FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON public._schema_migrations FROM authenticated;
  END IF;
END $$;
SQL
}

applied_list() {
  # Prints "filename|checksum" per applied file; empty if the table is missing.
  run_psql -t -A -F '|' -c "
    SELECT filename, checksum FROM public._schema_migrations
    WHERE to_regclass('public._schema_migrations') IS NOT NULL
    ORDER BY filename" 2>/dev/null || true
}

sql_quote() { printf "%s" "$1" | sed "s/'/''/g"; }

record() { # filename checksum baseline(true|false)
  run_psql -c "INSERT INTO public._schema_migrations (filename, checksum, baseline)
               VALUES ('$(sql_quote "$1")', '$2', $3)
               ON CONFLICT (filename) DO UPDATE SET checksum = EXCLUDED.checksum"
}

# ── Status ────────────────────────────────────────────────────────────────────

if [[ "$MODE" == "status" ]]; then
  EXISTS="$(run_psql -t -A -c "SELECT to_regclass('public._schema_migrations') IS NOT NULL")"
  APPLIED="$( [[ "$EXISTS" == "t" ]] && applied_list || true )"
  echo "Target: $TARGET_DESC"
  [[ "$EXISTS" == "t" ]] || echo "(public._schema_migrations doesn't exist yet — nothing recorded)"
  pending=0
  for f in "${FILES[@]}"; do
    line="$(awk -F'|' -v f="$f" '$1 == f' <<<"$APPLIED")"
    if [[ -z "$line" ]]; then
      echo "  pending   $f"
      pending=$((pending + 1))
    elif [[ "${line#*|}" != "$(checksum "$SCHEMAS_DIR/$f")" ]]; then
      echo "  applied   $f   (file changed since it was applied)"
    else
      echo "  applied   $f"
    fi
  done
  echo "$pending pending"
  exit 0
fi

ensure_table
APPLIED="$(applied_list)"

is_applied() {
  [[ -n "$(awk -F'|' -v f="$1" '$1 == f' <<<"$APPLIED")" ]]
}

echo "Target: $TARGET_DESC"

# ── Baseline ──────────────────────────────────────────────────────────────────

if [[ "$MODE" == "baseline" ]]; then
  n=0
  for f in "${FILES[@]}"; do
    if ! is_applied "$f"; then
      record "$f" "$(checksum "$SCHEMAS_DIR/$f")" true
      echo "  baselined $f"
      n=$((n + 1))
    fi
  done
  echo "Marked $n file(s) as applied (not run)."
  exit 0
fi

# ── Apply ─────────────────────────────────────────────────────────────────────

n=0
for f in "${FILES[@]}"; do
  is_applied "$f" && continue
  echo "  applying  $f"
  # No --single-transaction: some files add enum values (ALTER TYPE … ADD
  # VALUE) and later use them, which Postgres forbids inside one transaction.
  if ! run_psql -f - < "$SCHEMAS_DIR/$f"; then
    echo "Error: $f failed — stopping. Fix it and re-run (files are written to be idempotent)." >&2
    exit 1
  fi
  record "$f" "$(checksum "$SCHEMAS_DIR/$f")" false
  n=$((n + 1))
done

if [[ $n -eq 0 ]]; then
  echo "Up to date."
else
  echo "Applied $n file(s)."
fi
