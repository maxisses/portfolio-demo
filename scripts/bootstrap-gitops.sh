#!/usr/bin/env bash
# Einziger manueller apply: installiert OpenShift GitOps und hängt die Root-Application ein.
# Voraussetzung: oc ist als cluster-admin am Hub angemeldet (scripts/hub-login.sh).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
oc apply -k "$root/gitops/bootstrap"
echo "warte auf die Argo-CD-Instanz ..."
until oc get argocd openshift-gitops -n openshift-gitops >/dev/null 2>&1; do sleep 10; done
oc apply -f "$root/gitops/bootstrap/argocd-cluster-admin.yaml"
# Mehr Speicher für den Application-Controller: mit ACM und RHOAI gibt es viele CRDs.
oc patch argocd openshift-gitops -n openshift-gitops --type=merge -p \
  '{"spec":{"controller":{"resources":{"limits":{"cpu":"4","memory":"6Gi"},"requests":{"cpu":"500m","memory":"2Gi"}}}}}'
oc apply -f "$root/gitops/bootstrap/root-app.yaml"
echo "Argo CD: https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
