# ADR-0004: App-of-apps with self-managed Argo CD

- Status: accepted
- Date: 2026-10-26

## Context

Argo CD cannot install itself. Once installed, we want Argo to be managed from Git like
everything else, including its own chart upgrades, without giving Terraform ownership of
the same resources.

## Decision

Use a one-time Helm bootstrap followed by app-of-apps and self-management:

1. `bootstrap/argocd/install.sh` installs a pinned Argo CD chart.
2. `bootstrap/root-app.yaml` is applied once and points at `clusters/home/`.
3. The root Application creates AppProjects and child Applications.
4. `clusters/home/platform/argocd.yaml` makes Argo manage itself.
5. Argo chart upgrades are Renovate PRs, reviewed and merged, then applied by Argo.

Argo's own Application uses `prune: false`; other Applications use automated sync,
prune, and self-heal. The bootstrap script is the recovery path.

## Consequences

- Everything after the first install is GitOps.
- No Terraform/Argo ownership conflict.
- A broken Argo self-sync may require `kubectl`/bootstrap recovery.
- Argo CRDs need deliberate handling during chart upgrades.
- The root Application itself stays manual by design.
