#!/usr/bin/env bash
# Terraform-Wrapper: lädt .env, prüft den Account, setzt das Backend und die Admin-IP.
#   scripts/tf.sh <verzeichnis unter terraform/> <terraform-args...>
#   z. B. scripts/tf.sh foundation plan
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
dir="$1"; shift
account="$(aws sts get-caller-identity --query Account --output text)"
export TF_VAR_admin_cidr="${TF_VAR_admin_cidr:-$(curl -s https://checkip.amazonaws.com)/32}"
cd "$root/terraform/$dir"
if [ ! -d .terraform ] || [ "${1:-}" = "init" ]; then
  terraform init -input=false -reconfigure -backend-config="bucket=portfolio-demo-tfstate-$account" >/dev/null
  [ "${1:-}" = "init" ] && exit 0
fi
terraform "$@"
