# Argo CD upgrade and recovery

> Status: target runbook for Phase 1-2. The Argo bootstrap and self-management manifests
> are not present in the repository yet.

## Upgrade

Argo CD is self-managed by `clusters/home/platform/argocd.yaml`.

1. Renovate opens a PR bumping the `argo-cd` chart version.
2. Read the Argo CD release notes and check CRD changes.
3. Merge the PR.
4. Argo auto-syncs its own Application.
5. Watch:

```bash
kubectl -n argocd get pods
kubectl -n argocd get application argocd
kubectl -n argocd logs deploy/argocd-server
```

If the sync is unhealthy, revert the chart version in Git. If Argo cannot reconcile
itself, use the recovery path below.

### CRDs

Argo CD's CRDs are the sharp edge of self-upgrade. A Helm chart bump does not always
upgrade CRDs the way you expect. Test the first upgrade on a maintenance window and
verify the Application/ApplicationSet CRDs before relying on automatic upgrades.

## Recovery

The bootstrap installer is idempotent enough to repair a broken Argo installation:

```bash
export ARGOCD_CHART_VERSION=REPLACE_ME
./bootstrap/argocd/install.sh
```

If the `argocd` namespace is lost, the script recreates it. The root Application
recreates AppProjects and child Applications from Git.

The BSM bootstrap Secret must exist for ESO to recover dependent secrets:

```bash
kubectl -n external-secrets get secret bws-access-token
```

If it is missing, recreate it from BSM and let ESO resync.

## Argo admin access

- Argo is exposed internally at `argocd.home.jonasseidl.com`.
- It is not public.
- Retrieve the initial admin password from the cluster and store it in BSM:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

- Prefer SSO/Cloudflare Access later; do not expose the admin UI publicly without Access.

## What not to do

- Do not run `helm upgrade` manually after Argo has adopted the release.
- Do not manage `argocd-secret` wholesale from Git.
- Do not put repository credentials in Git.
- Do not set `prune: true` on the Argo self-management Application without a recovery plan.
