# ADR-0002: Phase 1 cluster topology

- Status: accepted
- Date: 2026-10-26

## Context

Only the old Proxmox host is available. The new main server is ordered but not delivered.
Running three control planes on one old host would create the appearance of HA without
the failure domains. The control plane should eventually live on the more reliable hardware.

## Decision

Phase 1 runs three Talos VMs on the current Proxmox host:

- one control plane (`talos-cp-1`)
- two workers (`talos-worker-1`, `talos-worker-2`)
- control-plane scheduling enabled, so all three nodes can run workloads

The cluster is explicitly disposable. When the new server arrives, rebuild the cluster
with the control plane on the new host rather than migrating roles in place.

## Consequences

- One etcd member; control-plane VM loss means API loss.
- Proxmox host loss means complete cluster loss.
- No API VIP; the endpoint is the control-plane IP.
- Backups of the control-plane VM and etcd are mandatory.
- Workloads can use 16 GB of the host's 24 GB. ARC and observability must stay small.
- GitOps makes a later rebuild cheap.
