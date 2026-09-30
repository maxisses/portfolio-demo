#!/usr/bin/env bash
# Lädt .env aus dem Repo-Root in die aktuelle Shell: `source scripts/load-env.sh`
# Versteht KEY=value und das ältere KEY: value. Aus einer `podman login`-Zeile werden
# QUAY_USERNAME und QUAY_PASSWORD, aus einer nackten git@-URL wird GIT_REPO_SSH.
# Gibt nur Variablennamen aus, nie Werte.
_env_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
_env_file="${ENV_FILE:-$_env_root/.env}"
if [ ! -f "$_env_file" ]; then echo "load-env: $_env_file fehlt" >&2; return 1 2>/dev/null || exit 1; fi
_loaded=()
_strip() { local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; v="${v#\'}"; v="${v%\'}"; v="${v#\"}"; v="${v%\"}"; printf '%s' "$v"; }
while IFS= read -r _line || [ -n "$_line" ]; do
  case "$_line" in ''|\#*) continue ;; esac
  if [[ "$_line" =~ ^podman[[:space:]]+login ]]; then
    if [[ "$_line" =~ (-u|--username)[=[:space:]]+\'?([^\'[:space:]]+) ]]; then export QUAY_USERNAME="${BASH_REMATCH[2]}"; _loaded+=(QUAY_USERNAME); fi
    if [[ "$_line" =~ (-p|--password)[=[:space:]]+\'?([^\'[:space:]]+) ]]; then export QUAY_PASSWORD="${BASH_REMATCH[2]}"; _loaded+=(QUAY_PASSWORD); fi
    continue
  fi
  if [[ "$_line" =~ ^git@[^[:space:]]+\.git$ ]]; then export GIT_REPO_SSH="$_line"; _loaded+=(GIT_REPO_SSH); continue; fi
  if [[ "$_line" =~ ^(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[:=][[:space:]]*(.*)$ ]]; then
    _k="${BASH_REMATCH[2]}"; _v="$(_strip "${BASH_REMATCH[3]}")"
    export "$_k=$_v"; _loaded+=("$_k")
  fi
done < "$_env_file"
export AWS_REGION="${AWS_REGION:-eu-central-1}" AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-eu-central-1}"
unset AWS_PROFILE
[ -z "$LOAD_ENV_QUIET" ] && echo "load-env: ${_loaded[*]}" >&2
unset _line _k _v _loaded _env_file _env_root
