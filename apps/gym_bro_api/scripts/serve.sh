#!/usr/bin/env bash
# serve.sh — Start edge functions locally, targeting prod DB by default.
#
# Usage:
#   ./scripts/serve.sh              # targets prod Supabase (via Doppler)
#   ./scripts/serve.sh --local      # targets local Docker Supabase
#   ./scripts/serve.sh --local users # specific function, local
#   ./scripts/serve.sh users         # specific function, prod

set -euo pipefail

PROD=false
FUNCTION=""

for arg in "$@"; do
  case "$arg" in
    --prod) PROD=true ;;
    *) FUNCTION="$arg" ;;
  esac
done

SERVE_CMD="supabase functions serve${FUNCTION:+ $FUNCTION}"

if $PROD; then
  echo "▶ Starting functions locally → PROD Supabase (via Doppler)"
  TMPENV=$(mktemp /tmp/gym_bro_env.XXXXXX)
  trap "rm -f $TMPENV" EXIT
  doppler secrets download --no-file --format env > "$TMPENV"
  eval "$SERVE_CMD --env-file $TMPENV"
else
  echo "▶ Starting functions locally → LOCAL Docker Supabase"
  eval "$SERVE_CMD"
fi
