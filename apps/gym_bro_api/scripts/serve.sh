#!/usr/bin/env bash
# serve.sh — Start edge functions locally against local Docker Supabase.
#
# Usage:
#   ./scripts/serve.sh              # all functions
#   ./scripts/serve.sh users        # specific function

set -euo pipefail

FUNCTION="${1:-}"

supabase functions serve ${FUNCTION:+$FUNCTION} --env-file .env.local
