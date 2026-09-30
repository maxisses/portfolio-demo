#!/usr/bin/env bash
# Meldet oc als cluster-admin am ROSA-Hub an. Zugangsdaten kommen aus AWS Secrets Manager.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
creds="$(aws secretsmanager get-secret-value --secret-id portfolio-demo/rosa/users --query SecretString --output text)"
api="$(jq -r .api_url <<<"$creds")"
oc login "$api" -u "$(jq -r .cluster_admin_username <<<"$creds")" -p "$(jq -r .cluster_admin_password <<<"$creds")" \
  --insecure-skip-tls-verify=false >/dev/null
oc config rename-context "$(oc config current-context)" portfolio-hub >/dev/null 2>&1 || true
echo "angemeldet am Hub: $(oc whoami --show-server)"
