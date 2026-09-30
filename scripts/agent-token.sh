#!/usr/bin/env bash
# Stellt ein AAP-API-Token für den Agent-Nutzer aus (Scope write = Jobs starten) und legt es
# in AWS Secrets Manager ab (portfolio-demo/aap/agent-token). Gibt den Wert nie aus.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
pw="$(aws secretsmanager get-secret-value --secret-id portfolio-demo/aap/users --query SecretString --output text | jq -r '."agent-claude"')"
token="$(curl -sf -u "agent-claude:$pw" -H 'Content-Type: application/json' \
  -d '{"description":"Claude Code (MCP), Portfolio-Demo","scope":"write"}' \
  https://aap.sandbox3481.opentlc.com/api/gateway/v1/tokens/ | jq -r .token)"
[ -n "$token" ] && [ "$token" != null ] || { echo "Token konnte nicht erzeugt werden" >&2; exit 1; }
if aws secretsmanager describe-secret --secret-id portfolio-demo/aap/agent-token >/dev/null 2>&1; then
  aws secretsmanager put-secret-value --secret-id portfolio-demo/aap/agent-token --secret-string "$token" >/dev/null
else
  aws secretsmanager create-secret --name portfolio-demo/aap/agent-token --secret-string "$token" >/dev/null
fi
echo "Token für agent-claude in Secrets Manager: portfolio-demo/aap/agent-token"
