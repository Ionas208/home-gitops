# home-gitops

GitOps-managed Kubernetes desired state for the Seidl home lab.

This repository is public. It must never contain secrets, kubeconfigs, Terraform state,
or private keys. Runtime secrets will come from Bitwarden Secrets Manager through
External Secrets Operator.

## Status

**Phase 0: documentation only.**

No manifests, bootstrap scripts, or cluster resources exist yet. The directory structure
and implementation are added one phase at a time, after the preceding phase works.

The implementation scaffold that was drafted early has been preserved outside the
repository and will be reintroduced only when its phase starts.

## Documentation

- [`docs/PLAN.md`](docs/PLAN.md) — goals, constraints, architecture summary, phases
- [`docs/PHASE-0.md`](docs/PHASE-0.md) — Phase 0 checklist and deferred items
- [`docs/architecture.md`](docs/architecture.md) — network, DNS, TLS, GitOps, secrets, storage
- [`docs/inventory.md`](docs/inventory.md) — hardware and cluster inventory
- [`docs/decisions/`](docs/decisions/) — architecture decision records
- [`docs/runbooks/`](docs/runbooks/) — target runbooks for later phases

## Planned structure

Created in later phases, not present now:

```text
bootstrap/          one-time Argo CD bootstrap
clusters/home/      Argo CD Application CRs and AppProjects
platform/           platform manifests and Helm values
apps/               workload manifests
charts/             local Helm charts, if needed
hack/               local validation helpers
```

Phase 0 deliberately contains only the documentation needed to make the later phases
boring and repeatable.

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
