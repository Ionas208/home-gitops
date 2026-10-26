# Add an application

> Status: target runbook for Phase 3. The referenced paths and manifests do not exist yet.

## 1. Build the image

In the application repository:

- add a Dockerfile
- build and push to GHCR with an immutable tag (commit SHA and/or semver)
- make the package public, or add an image pull secret via ESO
- run CI on pull requests

## 2. Add manifests

Create `apps/<name>/`:

```text
apps/<name>/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
├── ingressroute.yaml        # only if it needs ingress
└── external-secret.yaml     # only if it needs secrets
```

Use `apps/portfolio` or `apps/strava-mcp` as a starting point.

## 3. Add the Argo Application

Create `clusters/home/apps/<name>.yaml`:

- `project: apps`
- `destination.namespace: <name>`
- `source.path: apps/<name>`
- `sync-wave: "60"`
- `resources-finalizer.argoproj.io`
- automated sync, prune, self-heal

Update the `apps` AppProject if a new destination namespace is needed.

## 4. Secrets

Add the secret to BSM, then create an `ExternalSecret` in the app directory.
Never put the value in Git.

## 5. DNS and ingress

- Internal: add an IngressRoute on `websecure` with
  `Host("<name>.home.jonasseidl.com")` and the wildcard TLS secret.
- Public: add an IngressRoute on `web` and a Cloudflare Tunnel ingress rule /
  Access policy. Public names are explicit; do not add a public wildcard.

## 6. Verify

```bash
kubectl -n argocd get application <name>
kubectl -n <name> get pods,svc,externalsecret
```

Check the Argo UI and the application URL.

## 7. Update policy

Renovate should update the image tag. Pin images by digest for reproducibility.
