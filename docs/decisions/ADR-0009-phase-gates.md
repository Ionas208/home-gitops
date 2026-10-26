# ADR-0009: Phased delivery and explicit phase gates

- Status: accepted
- Date: 2026-10-26

## Context

The early scaffold put platform manifests, app manifests, OpenTofu, and Talos configs
into the repositories before the foundation existed. That blurred the line between a
documented plan and an implementation and made the work harder to reason about.

## Decision

Deliver the lab in phases with explicit gates:

0. documentation only
1. Proxmox, Talos, Argo CD
2. core platform: networking, DNS, TLS, secrets, storage
3. applications and CI
4. new hardware rebuild

A phase is complete only when its verification gate is demonstrated. Do not commit files
for future phases until that phase starts. Later-phase ideas are captured in the plan,
not implemented.

## Consequences

- The repository reflects reality: docs first, then the minimum files for the current phase.
- Each phase can be reviewed and tested independently.
- The bootstrap path is slower to produce files, but much easier to debug.
- Deferred scaffold work may need to be rewritten against the versions and addresses that
  exist at that phase.
