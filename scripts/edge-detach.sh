#!/usr/bin/env bash
# Löst einen Edge-Cluster von seinem bisherigen ACM-Hub (Klusterlet entfernen).
#   scripts/edge-detach.sh <kube-context>     (Kubeconfig: local/kubeconfig-edge)
set -euo pipefail
ctx="$1"; root="$(cd "$(dirname "$0")/.." && pwd)"
export KUBECONFIG="${EDGE_KUBECONFIG:-$root/local/kubeconfig-edge}"
oc="oc --context $ctx"
echo "[$ctx] Klusterlet entfernen ..."
$oc delete klusterlet klusterlet --ignore-not-found --wait=true --timeout=300s || true
for ns in open-cluster-management-agent-addon open-cluster-management-agent; do
  $oc delete ns "$ns" --ignore-not-found --wait=true --timeout=300s || true
done
echo "[$ctx] alte Registrierung entfernt"
