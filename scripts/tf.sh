#!/usr/bin/env bash
# Terraform-Wrapper: lädt .env, prüft den Account, setzt das Backend und die Admin-IP.
#   scripts/tf.sh <verzeichnis unter terraform/> <terraform-args...>
#   z. B. scripts/tf.sh foundation plan
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
dir="$1"; shift
account="$(aws sts get-caller-identity --query Account --output text)"
# Red-Hat-Anmeldung für den rhcs-Provider: standardmäßig die Sitzung von `rosa login`
# (Refresh-Token aus ocm.json; macOS: ~/Library/Application Support/ocm, Linux: ~/.config/ocm). Mit RHCS_AUTH=service-account gelten
# stattdessen RHCS_CLIENT_ID/RHCS_CLIENT_SECRET aus .env.
ocm_cfg="$HOME/Library/Application Support/ocm/ocm.json"
[ -f "$ocm_cfg" ] || ocm_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/ocm/ocm.json"
if [ "${RHCS_AUTH:-rosa}" = "rosa" ] && [ -f "$ocm_cfg" ]; then
  export RHCS_TOKEN="$(jq -r .refresh_token "$ocm_cfg")" RHCS_CLIENT_ID="$(jq -r .client_id "$ocm_cfg")"
  unset RHCS_CLIENT_SECRET
fi
[ -n "${ANTHROPIC_API_KEY:-}" ] && export TF_VAR_anthropic_api_key="$ANTHROPIC_API_KEY"
export TF_VAR_admin_cidr="${TF_VAR_admin_cidr:-$(curl -s https://checkip.amazonaws.com)/32}"
cd "$root/terraform/$dir"
if [ ! -d .terraform ] || [ "${1:-}" = "init" ]; then
  terraform init -input=false -reconfigure -backend-config="bucket=portfolio-demo-tfstate-$account" >/dev/null
  [ "${1:-}" = "init" ] && exit 0
fi
terraform "$@"
