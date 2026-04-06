#!/usr/bin/env bash
# dev.sh — Sources .env.local into the shell then starts Supabase.
#
# The edge runtime reads custom secrets via env() in config.toml, so the host
# shell must have those vars exported before `supabase start` runs.
#
# Usage:
#   ./scripts/dev.sh [supabase args...]
#   ./scripts/dev.sh start
#   ./scripts/dev.sh stop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$ROOT_DIR/.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found." >&2
  exit 1
fi

# Export every non-comment, non-empty line from .env.local into the shell.
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

echo "Loaded $ENV_FILE"

exec supabase "$@"
