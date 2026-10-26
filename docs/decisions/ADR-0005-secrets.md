# ADR-0005: Secrets with Bitwarden Secrets Manager and ESO

- Status: accepted
- Date: 2026-10-26

## Context

Both platform repositories are public. No secret material may be committed. Kubernetes
workloads still need Cloudflare, Tailscale, registry, and application credentials.
Bootstrap secrets must also be recoverable.

## Decision

- Bitwarden Secrets Manager (BSM) is the source of truth.
- External Secrets Operator (ESO) runs in-cluster with the Bitwarden provider.
- A `ClusterSecretStore` named `bitwarden` is shared by workloads.
- The BSM machine-account token is the one manual bootstrap Secret:
  `external-secrets/bws-access-token`, key `token`.
- Cloudflare, Tailscale, and application secrets are synced by ESO.
- Talos secrets and kubeconfigs stay out of Git and are backed up outside the repositories.
- Argo CD does not need repository credentials because `home-gitops` is public.

## Consequences

- No raw secrets in either public repository.
- ESO must be healthy before dependent secrets exist; sync waves enforce ordering.
- BSM token rotation is a documented runbook step.
- Losing the BSM token requires recovery from the password manager/offline recovery kit.
- Bootstrap remains manually gated, which is acceptable for a single-operator lab.
