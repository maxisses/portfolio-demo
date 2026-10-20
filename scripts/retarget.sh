#!/usr/bin/env bash
# Stellt Repo und Präsentation auf eine neue Sandbox um, wenn die alte weg ist.
# Ersetzt die festen Werte der bisherigen Umgebung durch die neuen. Zwei Phasen:
#   Phase 1, vor dem Aufbau:   scripts/retarget.sh --domain sandbox1234.opentlc.com --account 123456789012
#   Phase 2, nach ROSA:        scripts/retarget.sh --cluster portfolio-hub2 --rosa-base abcd.p3 --infra-id <infra-id>
#   Eigener Fork:              scripts/retarget.sh --repo kollege/portfolio-demo   (GitHub owner/name)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# Die aktuellen Werte liest das Skript aus dem Repo selbst (keine Statusdatei nötig, auch nicht
# in einem frischen Fork):
cur() { grep -ho "$2" $1 | head -1 | sed -E "$3"; }
CUR_DOMAIN=$(cur terraform/foundation/variables.tf 'sandbox[0-9]*\.opentlc\.com' 's/x/x/')
CUR_ACCOUNT=$(cur gitops/components/external-secrets/secretstore.yaml 'arn:aws:iam::[0-9]*' 's/arn:aws:iam:://')
CUR_INFRA_ID=$(grep -A3 'variable "rosa_infra_id"' terraform/foundation/variables.tf | grep -o 'default *= *"[^"]*"' | sed -E 's/.*"(.*)"/\1/')
hub=$(cur ansible/orchestrator-config/objects.yml 'maas\.apps\.rosa\.[a-z0-9-]*\.[a-z0-9]*\.[a-z0-9]*' 's/maas\.apps\.rosa\.//')
CUR_CLUSTER=${hub%%.*}; CUR_ROSA_BASE=${hub#*.}
CUR_REPO=$(cur gitops/bootstrap/root-app.yaml 'github.com/[^ ]*\.git' 's#github.com/##; s#\.git$##')
for v in CUR_DOMAIN CUR_ACCOUNT CUR_INFRA_ID CUR_CLUSTER CUR_ROSA_BASE CUR_REPO; do
  [ -n "${!v}" ] || { echo "aktuellen Wert $v nicht gefunden" >&2; exit 1; }
done

new_domain="$CUR_DOMAIN"; new_account="$CUR_ACCOUNT"; new_rosa="$CUR_ROSA_BASE"; new_infra="$CUR_INFRA_ID"; new_cluster="$CUR_CLUSTER"; new_repo="$CUR_REPO"
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) new_domain="$2"; shift 2 ;;
    --account) new_account="$2"; shift 2 ;;
    --rosa-base) new_rosa="$2"; shift 2 ;;
    --cluster) new_cluster="$2"; shift 2 ;;
    --infra-id) new_infra="$2"; shift 2 ;;
    --repo) new_repo="$2"; shift 2 ;;
    *) echo "unbekannt: $1" >&2; exit 1 ;;
  esac
done

files=$( { git grep -l -e "$CUR_DOMAIN" -e "$CUR_ACCOUNT" -e "$CUR_CLUSTER.$CUR_ROSA_BASE" -e "$CUR_INFRA_ID" -e "github.com[:/]$CUR_REPO" -- . \
           ':!docs/build-journal.md' ':!docs/compliance' ':!CLAUDE.md' 2>/dev/null || true;
           ls presentation/index.html 2>/dev/null || true; } | sort -u)

for f in $files; do
  sed -i '' \
    -e "s/${CUR_DOMAIN//./\\.}/$new_domain/g" \
    -e "s/$CUR_ACCOUNT/$new_account/g" \
    -e "s/${CUR_CLUSTER}\.${CUR_ROSA_BASE//./\\.}/$new_cluster.$new_rosa/g" \
    -e "s/$CUR_INFRA_ID/$new_infra/g" \
    -e "s#github.com\([:/]\)$CUR_REPO\([./\"]\)#github.com\1$new_repo\2#g" \
    -e "s#github.com\([:/]\)$CUR_REPO\$#github.com\1$new_repo#g" \
    "$f"
done

echo "Umgestellt in $(echo "$files" | wc -w | tr -d ' ') Dateien:"
echo "  Domain   $new_domain"
echo "  Account  $new_account"
echo "  ROSA     apps.rosa.$new_cluster.$new_rosa.openshiftapps.com"
echo "  Infra-ID $new_infra"
echo "  Repo     github.com/$new_repo"
