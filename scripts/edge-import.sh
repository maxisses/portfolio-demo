#!/usr/bin/env bash
# Importiert einen Edge-Cluster in den ROSA-Hub (Pull: der Edge meldet sich selbst an).
# Der ManagedCluster selbst kommt aus Git (gitops/components/fleet), hier wenden wir nur
# die vom Hub erzeugten Import-Manifeste auf dem Edge an.
#   scripts/edge-import.sh <name>   (Hub: local/kubeconfig, Edge: local/kubeconfig-edge)
set -euo pipefail
name="$1"; root="$(cd "$(dirname "$0")/.." && pwd)"
hub="oc --kubeconfig ${HUB_KUBECONFIG:-$root/local/kubeconfig}"
edge="oc --kubeconfig ${EDGE_KUBECONFIG:-$root/local/kubeconfig-edge} --context $name"
echo "[$name] warte auf Import-Secret am Hub ..."
until $hub get secret "$name-import" -n "$name" >/dev/null 2>&1; do sleep 10; done
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
$hub get secret "$name-import" -n "$name" -o jsonpath='{.data.crds\.yaml}' | base64 -d > "$tmp/crds.yaml"
$hub get secret "$name-import" -n "$name" -o jsonpath='{.data.import\.yaml}' | base64 -d > "$tmp/import.yaml"
$edge apply -f "$tmp/crds.yaml" >/dev/null
sleep 5
$edge apply -f "$tmp/import.yaml" >/dev/null
# Apps-Domain als Label am ManagedCluster (für Routen von Localnews), nicht im Repo
domain="$($edge get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
$hub label managedcluster "$name" "apps-domain=$domain" --overwrite >/dev/null
echo "[$name] warte auf Registrierung ..."
until [ "$($hub get managedcluster "$name" -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}')" = "True" ]; do sleep 10; done
echo "[$name] importiert und verfügbar"
