#!/usr/bin/env bash
# pull_secrets.sh — Fetches secrets from Doppler and writes .env
#
# Usage:
#   ./scripts/pull_secrets.sh
#
# Requires:
#   - Doppler CLI installed: brew install dopplerhq/cli/doppler
#   - Logged in: doppler login
#   - Project linked: doppler setup (run once in apps/gym_bro_api/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$ROOT_DIR/.env"

if ! command -v doppler &>/dev/null; then
  echo "Error: Doppler CLI not installed. Run: brew install dopplerhq/cli/doppler" >&2
  exit 1
fi

echo "Fetching secrets from Doppler ($(doppler configure get project --plain)/$(doppler configure get config --plain))..."

doppler secrets download --no-file --format env > "$ENV_FILE"

echo "Done. $ENV_FILE updated."
