# ADR-0007: Public repositories and CI security

- Status: accepted
- Date: 2026-10-26

## Context

`home-gitops` and `home-infra` are public. Public manifests expose internal hostnames,
IPs, and tunnel/tailnet topology. Public source also means untrusted pull requests can
influence workflow execution. Self-hosted ARC runners must never become a path into the LAN.

## Decision

- Keep both platform repositories public, but never commit secrets, state, kubeconfigs,
  private keys, or Talos secrets.
- Enable GitHub secret scanning, push protection, branch protection, and required review.
- Use GitHub-hosted runners for untrusted fork PR validation on public repositories.
- Use ARC only for trusted branches/private application repositories.
- ARC runners are ephemeral, non-root, without cluster credentials, and with egress
  restricted away from RFC1918/link-local ranges.
- Avoid `pull_request_target` with PR code checkout.
- Pin third-party GitHub Actions by SHA as the scaffold matures.

## Consequences

- Public topology is accepted.
- No secret rotation is required for leaked repository credentials, because none exist
  in Git.
- CI security depends on workflow discipline, not on network isolation alone.
- The public repo can still be used for portfolio-style transparency.
