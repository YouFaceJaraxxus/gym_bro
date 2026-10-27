#!/usr/bin/env bash
# setup_db.sh — Fill a database in one go: apply every schema file, then seed
# the demo data (users, gyms, shops, workouts, nutrition, classes, orders, …).
#
# Usage:
#   ./scripts/setup_db.sh                 # local stack: migrate + seed
#   ./scripts/setup_db.sh --reset         # local stack: wipe it first (db reset), then migrate + seed
#   ./scripts/setup_db.sh --migrate-only  # schema only
#   ./scripts/setup_db.sh --seed-only     # seed only (schema must be current)
#   ./scripts/setup_db.sh --baseline      # database was migrated by hand before
#                                         # migrate.sh existed: record every schema
#                                         # file as applied, then seed
#
# Any other database (e.g. a hosted Supabase project):
#   ./scripts/setup_db.sh \
#     --db-url "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres" \
#     --supabase-url "https://<ref>.supabase.co" \
#     --service-role-key "<service role key>"
#   (or set DB_URL, SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY)
#   Remote targets ask for confirmation; pass --yes to skip it (CI).
#
# With no target given, the local stack's URLs and keys are read from
# `supabase status`. Both steps are idempotent, so re-running is safe:
# migrations skip what's applied, the seed adds only what's missing.
# Seeded users all sign in with the password GymBroSeed123!.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$(dirname "$SCRIPT_DIR")"
cd "$API_DIR"

usage() { sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

RESET=false
DO_MIGRATE=true
DO_SEED=true
BASELINE=false
ASSUME_YES=false
DB_URL="${DB_URL:-}"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset) RESET=true ;;
    --migrate-only) DO_SEED=false ;;
    --seed-only) DO_MIGRATE=false ;;
    --baseline) BASELINE=true ;;
    --yes|-y) ASSUME_YES=true ;;
    --db-url) DB_URL="$2"; shift ;;
    --supabase-url) SUPABASE_URL="$2"; shift ;;
    --service-role-key) SUPABASE_SERVICE_ROLE_KEY="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if ! $DO_MIGRATE && ! $DO_SEED; then
  echo "Error: --migrate-only and --seed-only together leave nothing to do." >&2
  exit 2
fi

step() { printf '\n\033[1m▸ %s\033[0m\n' "$*"; }
mask() { echo "$1" | sed -E 's#://([^:@/]+):[^@]*@#://\1:***@#'; }

# ── Resolve the target ────────────────────────────────────────────────────────

is_local_url() { [[ "$1" =~ (127\.0\.0\.1|localhost|host\.docker\.internal) ]]; }

if [[ -z "$DB_URL" && -z "$SUPABASE_URL" ]]; then
  # Nothing given: use the local stack.
  if ! command -v supabase >/dev/null 2>&1; then
    echo "Error: no target given and the supabase CLI isn't installed." >&2
    exit 1
  fi
  if ! STATUS_ENV="$(supabase status -o env 2>/dev/null)"; then
    echo "Error: the local stack isn't running. Start it with 'supabase start'." >&2
    exit 1
  fi
  read_status() { echo "$STATUS_ENV" | grep "^$1=" | head -1 | cut -d= -f2- | tr -d '"'; }
  DB_URL="$(read_status DB_URL)"
  SUPABASE_URL="$(read_status API_URL)"
  SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-$(read_status SERVICE_ROLE_KEY)}"
fi

if [[ -z "$DB_URL" ]]; then
  echo "Error: --db-url (or DB_URL) is required for a non-local target." >&2
  exit 1
fi
if $DO_SEED && { [[ -z "$SUPABASE_URL" ]] || [[ -z "$SUPABASE_SERVICE_ROLE_KEY" ]]; }; then
  echo "Error: seeding needs --supabase-url and --service-role-key (it creates auth users)." >&2
  exit 1
fi

LOCAL=false
is_local_url "$DB_URL" && LOCAL=true

echo "Database:  $(mask "$DB_URL")"
$DO_SEED && echo "Supabase:  $SUPABASE_URL"
echo "Steps:     $($RESET && echo 'reset → ')$($DO_MIGRATE && echo 'migrate')$($DO_MIGRATE && $DO_SEED && echo ' → ')$($DO_SEED && echo 'seed')"

if $RESET && ! $LOCAL; then
  echo "Error: --reset only works on the local stack; it never wipes a remote database." >&2
  exit 1
fi

if ! $LOCAL && ! $ASSUME_YES; then
  read -r -p "This writes to a REMOTE database. Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

# One-off SQL against the target, with the same psql/docker fallback as migrate.sh.
run_sql() {
  if command -v psql >/dev/null 2>&1; then
    psql "$DB_URL" -X -q -t -A -v ON_ERROR_STOP=1 -c "$1"
    return
  fi
  local container="${DB_CONTAINER:-supabase_db_gym_bro_api}" port
  port="$(echo "$DB_URL" | sed -nE 's#.*@(127\.0\.0\.1|localhost):([0-9]+)/.*#\2#p')"
  if [[ -n "$port" ]]; then
    container="$(docker ps --filter "publish=$port" --format '{{.Names}}' | head -1)"
    [[ -n "$container" ]] || { echo "Error: no running container publishes port $port." >&2; exit 1; }
  fi
  # Inside the DB container the database listens on 5432.
  docker exec -i "$container" \
    psql "$(echo "$DB_URL" | sed -E 's#@(127\.0\.0\.1|localhost):[0-9]+/#@127.0.0.1:5432/#')" \
    -X -q -t -A -v ON_ERROR_STOP=1 -c "$1"
}

# ── 1. Reset (local only) ─────────────────────────────────────────────────────

if $RESET; then
  if ! $ASSUME_YES; then
    read -r -p "Reset wipes ALL local data, including auth users. Continue? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  fi
  step "Resetting the local database"
  supabase db reset --local --no-seed
fi

# ── 2. Migrate ────────────────────────────────────────────────────────────────

if $DO_MIGRATE; then
  export DATABASE_URL="$DB_URL"

  # A database migrated by hand (before migrate.sh existed) has tables but no
  # tracking table; applying from scratch would fail on the first CREATE TYPE.
  tracked="$(run_sql "SELECT to_regclass('public._schema_migrations') IS NOT NULL")"
  has_tables="$(run_sql "SELECT to_regclass('public.users') IS NOT NULL")"
  if $BASELINE; then
    step "Recording existing schema as applied (baseline)"
    "$SCRIPT_DIR/migrate.sh" --baseline
  elif [[ "$tracked" != "t" && "$has_tables" == "t" ]]; then
    echo "Error: this database already has the app's tables but no migration history" >&2
    echo "(it was migrated by hand). If its schema is complete, re-run with --baseline;" >&2
    echo "on the local stack you can also start over with --reset." >&2
    exit 1
  fi

  step "Applying schema"
  "$SCRIPT_DIR/migrate.sh"
fi

# ── 3. Seed ───────────────────────────────────────────────────────────────────

if $DO_SEED; then
  if ! command -v deno >/dev/null 2>&1; then
    echo "Error: deno is required for seeding (https://deno.land)." >&2
    exit 1
  fi
  step "Seeding demo data"
  DB_URL="$DB_URL" SUPABASE_URL="$SUPABASE_URL" SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
    deno run --allow-net --allow-env --allow-read --allow-sys "$SCRIPT_DIR/seed.ts"
fi

step "Done"
$DO_SEED && echo "Sign in with any seeded user, password GymBroSeed123! (e.g. marcus.bennett@example.com, owner)."
exit 0
