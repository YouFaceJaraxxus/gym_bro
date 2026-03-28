#!/usr/bin/env bash
# pull_secrets.sh — Fetches secrets from Supabase and writes .env
#
# Usage:
#   SUPABASE_ACCESS_TOKEN=<token> SUPABASE_PROJECT_REF=<ref> ./scripts/pull_secrets.sh
#
# Or export both vars in your shell profile so you never need to pass them.
#
# Get your access token: https://supabase.com/dashboard/account/tokens
# Get your project ref:  supabase.com/dashboard/project/<ref>/settings/general

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$ROOT_DIR/.env.template"
ENV_FILE="$ROOT_DIR/.env"

# ── Checks ────────────────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
  echo "Error: curl is required" >&2; exit 1
fi
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq" >&2; exit 1
fi
if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Error: SUPABASE_ACCESS_TOKEN is not set." >&2
  echo "  Get one at: https://supabase.com/dashboard/account/tokens" >&2
  exit 1
fi
if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo "Error: SUPABASE_PROJECT_REF is not set." >&2
  exit 1
fi

# ── Fetch secrets from Supabase Management API ────────────────────────────────
echo "Fetching secrets for project: $SUPABASE_PROJECT_REF"

RESPONSE=$(curl -sf \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/secrets")

if [[ -z "$RESPONSE" ]]; then
  echo "Error: Empty response from Supabase API. Check your token and project ref." >&2
  exit 1
fi

# ── Build .env from template, injecting fetched values ───────────────────────
echo "Writing $ENV_FILE"

while IFS= read -r line; do
  # Pass through comments and blank lines unchanged
  if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
    echo "$line"
    continue
  fi

  # Extract key name (everything before the first =)
  key="${line%%=*}"

  # Look up the value in the API response
  value=$(echo "$RESPONSE" | jq -r --arg k "$key" '.[] | select(.name == $k) | .value // empty')

  if [[ -z "$value" ]]; then
    echo "Warning: no secret found for key '$key' — leaving empty" >&2
    echo "$key="
  else
    echo "$key=$value"
  fi
done < "$TEMPLATE" > "$ENV_FILE"

echo "Done. $ENV_FILE updated."
