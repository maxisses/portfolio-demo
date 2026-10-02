#!/usr/bin/env bash
# Stellt Repo und Präsentation auf eine neue Sandbox um, wenn die alte weg ist.
# Ersetzt die festen Werte der bisherigen Umgebung durch die neuen. Zwei Phasen:
#   Phase 1, vor dem Aufbau:   scripts/retarget.sh --domain sandbox1234.opentlc.com --account 123456789012
#   Phase 2, nach ROSA:        scripts/retarget.sh --cluster portfolio-hub2 --rosa-base abcd.p3 --infra-id <infra-id>
# Die aktuellen Werte stehen in scripts/retarget.env und werden nach jedem Lauf fortgeschrieben.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
state="scripts/retarget.env"
# shellcheck disable=SC1090
source "$state"

new_domain="$CUR_DOMAIN"; new_account="$CUR_ACCOUNT"; new_rosa="$CUR_ROSA_BASE"; new_infra="$CUR_INFRA_ID"; new_cluster="$CUR_CLUSTER"
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) new_domain="$2"; shift 2 ;;
    --account) new_account="$2"; shift 2 ;;
    --rosa-base) new_rosa="$2"; shift 2 ;;
    --cluster) new_cluster="$2"; shift 2 ;;
    --infra-id) new_infra="$2"; shift 2 ;;
    *) echo "unbekannt: $1" >&2; exit 1 ;;
  esac
done

files=$( { git grep -l -e "$CUR_DOMAIN" -e "$CUR_ACCOUNT" -e "$CUR_CLUSTER.$CUR_ROSA_BASE" -e "$CUR_INFRA_ID" -- . \
           ':!docs/build-journal.md' ':!docs/compliance' ':!CLAUDE.md' ':!scripts/retarget.env' 2>/dev/null || true;
           ls presentation/index.html 2>/dev/null || true; } | sort -u)

for f in $files; do
  sed -i '' \
    -e "s/${CUR_DOMAIN//./\\.}/$new_domain/g" \
    -e "s/$CUR_ACCOUNT/$new_account/g" \
    -e "s/${CUR_CLUSTER}\.${CUR_ROSA_BASE//./\\.}/$new_cluster.$new_rosa/g" \
    -e "s/$CUR_INFRA_ID/$new_infra/g" \
    "$f"
done

cat > "$state" <<EOF
# Aktuelle umgebungsspezifische Werte (von scripts/retarget.sh gepflegt)
CUR_DOMAIN=$new_domain
CUR_ACCOUNT=$new_account
CUR_ROSA_BASE=$new_rosa
CUR_INFRA_ID=$new_infra
CUR_CLUSTER=$new_cluster
EOF
echo "Umgestellt in $(echo "$files" | wc -w | tr -d ' ') Dateien:"
echo "  Domain   $new_domain"
echo "  Account  $new_account"
echo "  ROSA     apps.rosa.$new_cluster.$new_rosa.openshiftapps.com"
echo "  Infra-ID $new_infra"
