# home-gitops

GitOps-managed Kubernetes desired state for the Seidl home lab.

This repository is public. It must never contain secrets, kubeconfigs, Terraform state,
or private keys. Runtime secrets will come from Bitwarden Secrets Manager through
External Secrets Operator.

## Status

**Phase 2 in progress: MetalLB, Gateway-routed Traefik, TLS and External Secrets are running.**

- `bootstrap/argocd/install.sh` installs the pinned `argo-cd` chart and applies the root Application
- `bootstrap/root-app.yaml` points at `clusters/home/` and is applied once
- `clusters/home/platform/argocd.yaml` makes Argo manage its own release
- MetalLB serves `192.168.178.243-192.168.178.248`; Traefik holds `.243` and routes Gateway API `HTTPRoute`s
- Let's Encrypt wildcard `*.home.jonasseidl.com` via Cloudflare DNS-01, served on the `websecure` listener
- External Secrets reads from Bitwarden; the Cloudflare token never enters Git
- `*.home.jonasseidl.com` resolves from public DNS-only records to `192.168.178.243` (LAN-only address)
- cloudflared connects out to the Cloudflare tunnel; no inbound ports are open
- `jonasseidl.com` serves the portfolio landing page from its own nginx, never through Traefik
- Tailscale operator with a two-replica LAN subnet router and the API server proxy
- Argo UI: `https://argocd.home.jonasseidl.com`
- Still missing: QNAP storage

## Documentation

- [`docs/PLAN.md`](docs/PLAN.md) — goals, constraints, architecture summary, phases
- [`docs/PHASE-0.md`](docs/PHASE-0.md) — Phase 0 checklist and deferred items
- [`docs/architecture.md`](docs/architecture.md) — network, DNS, TLS, GitOps, secrets, storage
- [`docs/inventory.md`](docs/inventory.md) — hardware and cluster inventory
- [`docs/decisions/`](docs/decisions/) — architecture decision records
- [`docs/runbooks/`](docs/runbooks/) — bootstrap, upgrade, restore, and add-app runbooks

## Structure

```text
bootstrap/          one-time Argo CD bootstrap and the root Application
clusters/home/      Argo CD Application CRs, grouped by layer
platform/           platform manifests and Helm values (Phase 2)
apps/               workload manifests (Phase 3)
charts/             local Helm charts, if needed
hack/               local validation helpers
```

Only `bootstrap/` and `clusters/home/` exist today. Later directories are added when
their phase starts.

## Related repository

[`home-infra`](https://github.com/Ionas208/home-infra) owns the foundation:

- Proxmox host configuration
- OpenTofu for Talos VMs
- Talos machine configuration and bootstrap
- Host-side runbooks

## Rules

- One phase at a time; no future-phase manifests in the repository.
- No secrets in Git.
- Public repository: secret scanning and branch protection.
- Every phase ends with a working verification, not just files.
