# ADR-0001: Repository topology

- Status: accepted
- Date: 2026-10-26

## Context

The lab needs a clear boundary between cluster desired state and the foundation that
creates the cluster. Application source code will appear later.

## Decision

Use two platform repositories plus one repository per application, created lazily:

- `home-gitops`: Argo CD, Kubernetes platform, applications.
- `home-infra`: Proxmox, OpenTofu, Talos configuration/bootstrap, Ansible, host runbooks.
- Application repositories: source, Dockerfile, CI, images.

Both platform repositories are public. They contain no secrets, state, or kubeconfigs.

## Consequences

- Argo CD owns everything inside Kubernetes.
- OpenTofu and Talos own the foundation and are applied deliberately.
- Application repositories build images; deployment manifests stay in `home-gitops`.
- CI never needs cluster credentials.
- Public repositories require secret scanning, branch protection, and careful runner policy.
