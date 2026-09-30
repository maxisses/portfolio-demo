#!/usr/bin/env bash
# Zeigt URLs und Zugangsdaten der Demo-Umgebung im eigenen Terminal an.
# Quelle ist AWS Secrets Manager; nichts davon liegt im Repo.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
get() { aws secretsmanager get-secret-value --secret-id "$1" --query SecretString --output text; }
rosa="$(get portfolio-demo/rosa/users)"
aap="$(get portfolio-demo/aap/installer)"
users="$(get portfolio-demo/aap/users)"
cat <<OUT
ROSA Console : $(jq -r .console_url <<<"$rosa")
  cluster-admin / $(jq -r .cluster_admin_password <<<"$rosa")
  engineer      / $(jq -r .engineer_password <<<"$rosa")
Argo CD      : https://openshift-gitops-server-openshift-gitops.apps.rosa.portfolio-hub.vnid.p3.openshiftapps.com (Login über OpenShift)
AAP          : https://aap.sandbox3481.opentlc.com
  admin / $(jq -r .admin_password <<<"$aap")
  max          / $(jq -r .max <<<"$users")   (bestellt im Portal)
  agent-claude / $(jq -r '."agent-claude"' <<<"$users")   (Demo-Agent, Token in Secrets Manager)
AAP MCP      : https://aap.sandbox3481.opentlc.com:8448/mcp/job_management
Portal       : https://portal.apps.rosa.portfolio-hub.vnid.p3.openshiftapps.com (Anmeldung über AAP, z. B. als max)
MaaS         : https://maas.apps.rosa.portfolio-hub.vnid.p3.openshiftapps.com
OUT
