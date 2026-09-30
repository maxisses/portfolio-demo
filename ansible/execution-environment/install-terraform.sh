#!/usr/bin/env bash
# Lädt das offizielle Terraform-Binary von HashiCorp und prüft die SHA256-Summe.
set -euo pipefail
version="$1"
arch="$(uname -m)"; case "$arch" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; esac
base="https://releases.hashicorp.com/terraform/${version}"
cd /tmp
curl -fsSLO "${base}/terraform_${version}_linux_${arch}.zip"
curl -fsSLO "${base}/terraform_${version}_SHA256SUMS"
grep "terraform_${version}_linux_${arch}.zip" "terraform_${version}_SHA256SUMS" | sha256sum -c -
unzip -o "terraform_${version}_linux_${arch}.zip" -d /usr/local/bin
rm -f "terraform_${version}_linux_${arch}.zip" "terraform_${version}_SHA256SUMS"
