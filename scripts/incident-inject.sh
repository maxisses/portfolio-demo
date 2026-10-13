#!/usr/bin/env bash
# Spielt die Störung für die Orchestrator-Story ein: schaltet die Segmentierungsregel für Werk
# Berlin scharf (ein Commit, wie eine echte Änderung im Wartungsfenster). Den Rest macht die
# Plattform: ACM meldet den Ausfall, AAP startet den Orchestrator, nach der Freigabe nimmt
# Ansible den Commit per git revert zurück.
#   scripts/incident-inject.sh          scharf schalten
#   scripts/incident-inject.sh --reset  von Hand zurücknehmen (nur falls der Workflow nicht lief)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
f=gitops/components/fleet/policy-plant-segmentation.yaml
git pull -q --rebase
if [ "${1:-}" = "--reset" ]; then
  sed -i '' 's/^  disabled: false$/  disabled: true/' "$f"
  msg="Plant Berlin: segmentation rule IEC 62443-3-3 SR 5.1 switched off again (manual reset)"
else
  sed -i '' 's/^  disabled: true$/  disabled: false/' "$f"
  msg="Plant Berlin: enforce network segmentation IEC 62443-3-3 SR 5.1 (maintenance window)"
fi
git diff --quiet -- "$f" && { echo "keine Änderung, Regel steht schon so"; exit 0; }
git add "$f"
git commit -q -m "$msg"
git push -q
echo "$(git log --oneline -1)"
KUBECONFIG="$root/local/kubeconfig" oc annotate applications.argoproj.io fleet -n openshift-gitops \
  argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
