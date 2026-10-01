#!/usr/bin/env bash
# Startet ein Job- oder Workflow-Template als Demo-Agent (agent-claude) und wartet aufs Ende.
#   scripts/aap-launch.sh job|workflow <template-id> '<extra_vars als JSON>'
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
kind="$1"; id="$2"; vars="${3:-{\}}"
T="$(aws secretsmanager get-secret-value --secret-id portfolio-demo/aap/agent-token --query SecretString --output text)"
A=https://aap.sandbox3481.opentlc.com/api/controller/v2
path=$([ "$kind" = workflow ] && echo workflow_job_templates || echo job_templates)
jobs=$([ "$kind" = workflow ] && echo workflow_jobs || echo jobs)
job=$(curl -sf -H "Authorization: Bearer $T" -H 'Content-Type: application/json' -X POST -d "{\"extra_vars\":$vars}" "$A/$path/$id/launch/" | jq -r '.id')
echo "gestartet: $jobs/$job"
while :; do s=$(curl -s -H "Authorization: Bearer $T" "$A/$jobs/$job/" | jq -r .status); case $s in successful|failed|error|canceled) break;; esac; [ "${WAIT_QUIET:-}" ] || printf "."; sleep 10; done; echo
echo "Status: $s"
[ "$kind" = job ] && curl -s -H "Authorization: Bearer $T" "$A/jobs/$job/" | jq -c '.artifacts | if .api_key then .api_key = (.api_key[0:10] + "...") else . end'
exit 0
