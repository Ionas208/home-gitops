#!/usr/bin/env bash
# One-time Argo CD bootstrap.
#
# Installs the pinned argo-cd chart, then applies the root Application, which
# hands Argo over to Git. Safe to rerun as a recovery path: Helm upgrades the
# existing release and the root Application is applied idempotently.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
RELEASE="${ARGOCD_RELEASE_NAME:-argocd}"
MANIFEST="$ROOT/clusters/home/platform/argocd.yaml"
ROOT_APP="$ROOT/bootstrap/root-app.yaml"

if [[ ! -f "$MANIFEST" ]]; then
  echo "missing $MANIFEST" >&2
  exit 1
fi

if [[ -z "${ARGOCD_CHART_VERSION:-}" ]]; then
  ARGOCD_CHART_VERSION="$(
    sed -n 's/^[[:space:]]*targetRevision:[[:space:]]*"\?\([^"]*\)"\?[[:space:]]*$/\1/p' "$MANIFEST" | head -n1
  )"
fi

if [[ -z "$ARGOCD_CHART_VERSION" ]]; then
  echo "could not determine the argo-cd chart version" >&2
  exit 1
fi

echo "==> installing argo-cd $ARGOCD_CHART_VERSION into $NAMESPACE"
helm repo add argo https://argoproj.github.io/argo-helm --force-update >/dev/null
helm repo update argo >/dev/null

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "$RELEASE" argo/argo-cd \
  --namespace "$NAMESPACE" \
  --version "$ARGOCD_CHART_VERSION" \
  --wait --timeout 10m

echo "==> applying the root Application"
kubectl apply -f "$ROOT_APP"

echo "==> waiting for the root Application to sync"
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NAMESPACE" get application root \
    -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)"
  if [[ "$status" == "Synced/Healthy" ]]; then
    break
  fi
  sleep 5
done

kubectl -n "$NAMESPACE" get applications

echo
echo "Argo CD $ARGOCD_CHART_VERSION installed."
echo "Admin password:"
echo "  kubectl -n $NAMESPACE get secret ${RELEASE}-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "UI:"
echo "  kubectl -n $NAMESPACE port-forward svc/${RELEASE}-server 8080:443"
