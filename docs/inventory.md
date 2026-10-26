# Inventory

> Status: Phase 0 inventory. Hardware is current; cluster sizing and versions are targets.

## Hardware

| Component              | Model          | Details                                    | Status        |
|------------------------|----------------|--------------------------------------------|---------------|
| Proxmox host (current) | Xeon E3-1231v3 | 4C/8T, 24 GB DDR3, 256 GB SATA SSD, GT 710 | available     |
| Main server            | TBD            | ordered                                    | not delivered |
| NAS                    | QNAP TS-433-4G | QTS 5.2.9.3410, 4x 4 TB, RAID 5            | available     |
| UPS                    | TBD            | optional but recommended                   | not purchased |

## Proxmox host

- CPU: Intel Xeon E3-1231v3, 4 cores / 8 threads
- RAM: 24 GB DDR3
- OS disk: 256 GB SATA SSD
- GPU: low-profile passive GT 710 (console only)
- Bulk storage: none yet; QNAP provides bulk storage over NFS
- Hypervisor: Proxmox VE, version TBD
- Network: 1 GbE assumed; 2.5 GbE NIC upgrade optional
- Address: `<PROXMOX_IP>` (placeholder `192.0.2.5`)

## Talos VMs

| Name             | Role                      | vCPU | RAM  | Disk  | Address      |
|------------------|---------------------------|------|------|-------|--------------|
| `talos-cp-1`     | control plane + workloads | 2    | 4 GB | 40 GB | `192.0.2.10` |
| `talos-worker-1` | worker                    | 2    | 6 GB | 50 GB | `192.0.2.11` |
| `talos-worker-2` | worker                    | 2    | 6 GB | 50 GB | `192.0.2.12` |

Totals: 6 vCPU, 16 GB RAM, 140 GB disk.

Remaining Proxmox budget: ~6 GB RAM and ~100 GB disk for the hypervisor, images,
and local-path PVCs. Keep ARC concurrency low and observability lightweight.

## QNAP

| Item            | Value                                          |
|-----------------|------------------------------------------------|
| Model           | TS-433-4G                                      |
| CPU             | ARM Cortex-A55, 4-core, 2.0 GHz                |
| RAM             | 4 GB, non-expandable                           |
| Firmware        | QTS 5.2.9.3410                                 |
| Bays            | 4                                              |
| Disks           | 4x Seagate IronWolf ST4000VN006, 4 TB          |
| RAID            | RAID 5                                         |
| Usable capacity | ~10.9 TiB before snapshots/QTS overhead        |
| Network         | 1x 2.5GbE, 1x 1GbE                             |
| Address         | `<LAN_PREFIX>.254` (placeholder `192.0.2.254`) |
| Snapshots       | supported; confirm thick volume                |
| UPS             | USB support; model TBD                         |

### QNAP shares

| Share      | Purpose                       | Quota  |
|------------|-------------------------------|--------|
| `/k8s`     | dynamic PVCs, shared app data | 1.5 TB |
| `/media`   | media library                 | 5 TB   |
| `/backups` | Proxmox, etcd, restic         | 2.5 TB |
| `/isos`    | Proxmox ISOs                  | 100 GB |

Keep 10-20% free for snapshots and growth. RAID 5 is one-disk fault tolerance, not
a backup. Offsite copy via HBS 3 is required.

## Network

| Name           | Placeholder             | Notes                   |
|----------------|-------------------------|-------------------------|
| LAN CIDR       | `192.0.2.0/24`          | replace with real LAN   |
| Proxmox        | `192.0.2.5`             | static, outside DHCP    |
| Talos CP       | `192.0.2.10`            | Kubernetes API endpoint |
| Talos worker 1 | `192.0.2.11`            |                         |
| Talos worker 2 | `192.0.2.12`            |                         |
| Traefik VIP    | `192.0.2.50`            | MetalLB                 |
| DNS VIP        | `192.0.2.53`            | MetalLB                 |
| QNAP           | `192.0.2.254`           | static                  |
| MetalLB pool   | `192.0.2.50-192.0.2.59` | resize to fit LAN       |

Placeholders use RFC 5737 TEST-NET-1 addresses. They are not routable and must be
replaced before deployment.

## Domain and DNS

| Item              | Value                                        |
|-------------------|----------------------------------------------|
| Public domain     | `jonasseidl.com`                             |
| Internal zone     | `home.jonasseidl.com`                        |
| Public records    | explicit only; no wildcard                   |
| Internal wildcard | `*.home.jonasseidl.com` -> Traefik VIP       |
| Certificate       | Let's Encrypt wildcard via Cloudflare DNS-01 |
| Public TLS        | Cloudflare edge                              |
| Internal TLS      | cert-manager wildcard                        |

## Software versions

| Component                 | Version    | Notes                         |
|---------------------------|------------|-------------------------------|
| Proxmox VE                | TBD        | install current stable        |
| Talos                     | REPLACE_ME | pin current stable            |
| Kubernetes                | REPLACE_ME | pin compatible with Talos     |
| Argo CD                   | REPLACE_ME | pin Helm chart                |
| Traefik                   | REPLACE_ME | pin Helm chart                |
| cert-manager              | REPLACE_ME | pin Helm chart                |
| External Secrets Operator | REPLACE_ME | pin Helm chart                |
| MetalLB                   | REPLACE_ME | pin Helm chart                |
| cloudflared               | REPLACE_ME | pin image                     |
| csi-driver-nfs            | REPLACE_ME | pin Helm chart                |
| local-path-provisioner    | REPLACE_ME | pin Helm chart                |
| Tailscale operator        | 1.104.2    | pin Helm chart                |

All `REPLACE_ME` values must be pinned before the first successful Argo sync.

## External services

| Service                      | Purpose                       | Secret location             |
|------------------------------|-------------------------------|-----------------------------|
| Cloudflare                   | DNS, Tunnel, Access           | BSM                         |
| Bitwarden Secrets Manager    | secret source of truth        | bootstrap secret + BSM      |
| GitHub                       | source, GHCR, Actions         | GitHub                      |
| Let's Encrypt                | internal wildcard certificate | ACME account key in cluster |
| Tailscale                    | admin/remote access           | BSM OAuth client            |
| Backblaze B2 / Cloudflare R2 | offsite backups               | BSM / QNAP HBS 3            |
