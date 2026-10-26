# ADR-0006: Storage split between local-lvm and QNAP NFS

- Status: accepted
- Date: 2026-10-26

## Context

The Proxmox host has a 256 GB SSD and no bulk HDD. The QNAP TS-433 provides ~10.9 TiB
usable over 2.5GbE/1GbE. NFS is suitable for shared files and backups, not databases or
Prometheus TSDB.

## Decision

- Proxmox `local-lvm` holds Talos VM disks and small/hot `local-path` PVCs.
- `local-path` is the default StorageClass.
- QNAP NFS is exposed through `csi-driver-nfs` as the explicit `nfs-qnap` StorageClass.
- QNAP shares: `/k8s`, `/media`, `/backups`, `/isos`.
- NFSv4.1, explicit client IPs, no broad subnet exports.
- Talos includes the `siderolabs/nfs-utils` extension.
- Prometheus, databases, and etcd do not run on NFS.

## Consequences

- Local PVCs are node-bound and lost on rebuild unless backed up.
- QNAP is the durable shared-data and backup target.
- NFS performance is capped by the network path; 1GbE is expected initially.
- QNAP snapshots and HBS 3 offsite copies are part of the backup design.
- RAID 5 is one-disk fault tolerance and is not a backup.
