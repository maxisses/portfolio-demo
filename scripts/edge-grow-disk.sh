#!/usr/bin/env bash
# Vergrößert die Root-Partition eines (Single-Node-)OpenShift-Knotens nach einer
# Disk-Vergrößerung, ohne SSH: über den privilegierten machine-config-daemon.
# CoreOS wächst nur beim ersten Boot automatisch; /sysroot ist read-only, daher über /var.
#   scripts/edge-grow-disk.sh <kube-context> [disk=vda] [partition=4]
set -euo pipefail
ctx="$1"; disk="${2:-vda}"; part="${3:-4}"; root="$(cd "$(dirname "$0")/.." && pwd)"
export KUBECONFIG="${EDGE_KUBECONFIG:-$root/local/kubeconfig-edge}"
pod="$(oc --context "$ctx" get pods -n openshift-machine-config-operator -l k8s-app=machine-config-daemon -o name | head -1)"
oc --context "$ctx" exec -n openshift-machine-config-operator "$pod" -c machine-config-daemon -- chroot /rootfs bash -c "
  growpart /dev/$disk $part || true
  partx -u /dev/$disk
  nsenter -t 1 -m -- xfs_growfs /var | grep 'data blocks' || true
  crictl rmi --prune >/dev/null 2>&1 || true
  nsenter -t 1 -m -- df -h /var | tail -1"
