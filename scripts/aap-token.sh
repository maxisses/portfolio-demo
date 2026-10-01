#!/usr/bin/env bash
# Stellt ein AAP-API-Token (Scope write) für einen AAP-Nutzer aus und legt es in AWS Secrets
# Manager ab. Gibt den Wert nie aus.
#   scripts/aap-token.sh agent-claude portfolio-demo/aap/agent-token         (nur Token)
#   scripts/aap-token.sh acm-automation portfolio-demo/aap/acm-token json    ({"host","token"} für ACM)
set -euo pipefail
user="$1"; secret="$2"; format="${3:-plain}"
root="$(cd "$(dirname "$0")/.." && pwd)"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
host=https://aap.sandbox3481.opentlc.com
pw="$(aws secretsmanager get-secret-value --secret-id portfolio-demo/aap/users --query SecretString --output text | jq -r --arg u "$user" '.[$u]')"
token="$(curl -sf -u "$user:$pw" -H 'Content-Type: application/json' -d "{\"description\":\"$secret\",\"scope\":\"write\"}" "$host/api/gateway/v1/tokens/" | jq -r .token)"
[ -n "$token" ] && [ "$token" != null ] || { echo "Token konnte nicht erzeugt werden" >&2; exit 1; }
value="$token"; [ "$format" = json ] && value="$(jq -nc --arg h "$host" --arg t "$token" '{host:$h, token:$t}')"
if aws secretsmanager describe-secret --secret-id "$secret" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value --secret-id "$secret" --secret-string "$value" >/dev/null
else
  aws secretsmanager create-secret --name "$secret" --secret-string "$value" >/dev/null
fi
echo "Token für $user in Secrets Manager: $secret"
