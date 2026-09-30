#!/usr/bin/env bash
# Lädt .env aus dem Repo-Root in die aktuelle Shell (bash oder zsh):
#   source scripts/load-env.sh
# Versteht KEY=value und das ältere KEY: value. Aus einer `podman login`-Zeile werden
# QUAY_USERNAME und QUAY_PASSWORD, aus einer nackten git@-URL wird GIT_REPO_SSH.
# Gibt nur Variablennamen aus, nie Werte.
if [ -n "${BASH_SOURCE:-}" ]; then _le_dir="$(dirname "${BASH_SOURCE[0]}")"; else _le_dir="$(dirname "${(%):-%x}")"; fi
_le_root="$(cd "$_le_dir/.." && pwd)"
eval "$(ENV_FILE="${ENV_FILE:-$_le_root/.env}" python3 "$_le_root/scripts/parse-env.py")"
export AWS_REGION="${AWS_REGION:-eu-central-1}" AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-eu-central-1}"
unset AWS_PROFILE _le_dir _le_root
