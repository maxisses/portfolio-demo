#!/usr/bin/env bash
# Entfernt ein lokal installiertes ACM/MCE von einem Edge-Cluster, damit er von einem
# anderen Hub verwaltet werden kann. Einmaliger Aufräumschritt, nicht umkehrbar.
# Kommt auch mit toten Operatoren klar: verwaiste Webhooks und Finalizer werden entfernt.
#   scripts/edge-remove-acm.sh <kube-context>
set -uo pipefail
ctx="$1"; root="$(cd "$(dirname "$0")/.." && pwd)"
export KUBECONFIG="${EDGE_KUBECONFIG:-$root/local/kubeconfig-edge}"
oc="oc --context $ctx --request-timeout=120s"
nofin='{"metadata":{"finalizers":[]}}'

echo "[$ctx] tote Pods löschen (Phase Failed) ..."
$oc delete pods -A --field-selector=status.phase==Failed --wait=false >/dev/null 2>&1

echo "[$ctx] Operatoren (Subscriptions, CSVs) entfernen ..."
for ns in open-cluster-management multicluster-engine; do
  $oc delete subscriptions.operators.coreos.com --all -n "$ns" --ignore-not-found
  $oc delete csv --all -n "$ns" --ignore-not-found
done

echo "[$ctx] verwaiste ACM/MCE-Webhooks entfernen ..."
for kind in validatingwebhookconfiguration mutatingwebhookconfiguration; do
  $oc get "$kind" -o name | grep -E 'multiclusterhub|multicluster-engine|multiclusterengine|ocm-|open-cluster-management|klusterlet' \
    | xargs -r $oc delete --ignore-not-found
done

echo "[$ctx] MultiClusterHub, MultiClusterEngine, Klusterlet löschen (Finalizer entfernen) ..."
for r in "multiclusterhub -n open-cluster-management" "multiclusterengine" "klusterlet" "managedcluster"; do
  for obj in $($oc get $r -o name 2>/dev/null); do
    ns_flag=""; [[ "$r" == *" -n "* ]] && ns_flag="-n ${r##* }"
    $oc patch $obj $ns_flag --type=merge -p "$nofin" >/dev/null 2>&1
    $oc delete $obj $ns_flag --ignore-not-found --wait=false >/dev/null 2>&1
  done
done

echo "[$ctx] ACM/MCE-CRDs entfernen (Conversion-Webhook und Finalizer zuerst) ..."
for crd in $($oc get crd -o name | grep -E 'open-cluster-management\.io|multicluster\.openshift\.io'); do
  $oc patch "$crd" --type=json -p '[{"op":"replace","path":"/spec/conversion","value":{"strategy":"None"}}]' >/dev/null 2>&1
  plural="${crd#*/}"
  for obj in $($oc get "$plural" -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    ns="${obj%%/*}"; name="${obj##*/}"
    if [ -n "$ns" ]; then $oc patch "$plural" "$name" -n "$ns" --type=merge -p "$nofin" >/dev/null 2>&1
    else $oc patch "$plural" "$name" --type=merge -p "$nofin" >/dev/null 2>&1; fi
  done
  $oc delete "$crd" --wait=false >/dev/null 2>&1
done

echo "[$ctx] Namespaces entfernen ..."
for ns in $($oc get ns -o name | grep -E 'open-cluster-management|multicluster-engine|local-cluster$|hive$'); do
  $oc delete "$ns" --wait=false >/dev/null 2>&1
done
# Auch RoleBindings tragen ACM-Finalizer (manifest-work-cleanup), die sonst niemand abräumt.
for ns in $($oc get ns -o name | grep -E 'open-cluster-management|multicluster-engine|local-cluster$' | cut -d/ -f2); do
  for rb in $($oc get rolebinding -n "$ns" -o name 2>/dev/null); do
    $oc patch "$rb" -n "$ns" --type=merge -p "$nofin" >/dev/null 2>&1
  done
done
echo "[$ctx] fertig; Namespaces werden im Hintergrund entfernt"
