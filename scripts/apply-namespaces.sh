#!/usr/bin/env bash
# Crée les namespaces dev, qa, staging, prod.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT}/kubernetes/namespaces.yaml"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Fichier introuvable: ${MANIFEST}" >&2
  exit 1
fi

# Si k3s refuse la lecture du kubeconfig sans sudo :
if ! kubectl cluster-info &>/dev/null; then
  if sudo kubectl cluster-info &>/dev/null; then
    exec sudo kubectl apply -f "${MANIFEST}"
  fi
fi

kubectl apply -f "${MANIFEST}"
echo "Namespaces appliqués. Vérifier avec: kubectl get ns -l app.kubernetes.io/part-of=movie-microservices"
