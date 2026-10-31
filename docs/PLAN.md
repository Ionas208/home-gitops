# Home Lab Master Plan

> Historical planning document. The implemented design lives in
> `docs/architecture.md` and `docs/decisions/`; where they disagree, those win.

Status: **Phase 0 - documentation only**  
Cluster name: `home`  
Domain: `jonasseidl.com`  
GitOps repo: `home-gitops`  
Infrastructure repo: `home-infra`

## 1. Purpose

Build a small, reproducible home lab that is:

- managed declaratively with Argo CD
- private by default, with a narrow public surface through Cloudflare Tunnel
- documented well enough to rebuild after hardware failure
- honest about its failure modes

This is a learning and personal-services cluster, not a production HA platform.

## Phase 0 scope (current)

Phase 0 is **documentation only**. Its job is to make the later phases boring.

Deliverables:

- this plan
- architecture, inventory, and network documents
- architecture decision records
- target runbooks for bootstrap, app onboarding, Argo upgrades, and restore
- a clear phase gate for every later phase

Explicitly **not** in Phase 0:

- OpenTofu or Proxmox changes
- Talos machine configs
- Kubernetes manifests or Application CRs
- Helm values
- bootstrap scripts
- CI workflows

Those are introduced only when their phase starts, and each phase ends with a working
verification rather than a pile of unapplied YAML.

Exit criteria:

- the target architecture and constraints are written down
- decisions and open questions are recorded
- the Phase 1 bootstrap sequence is clear enough to execute
- the implementation files do not exist yet

## 2. Current constraints

- One physical Proxmox host is available now: Xeon E3-1231v3, 24 GB DDR3, 256 GB SSD.
- The Proxmox host is old and is treated as disposable infrastructure.
- A newer main server is ordered but not delivered.
- The current Proxmox host has no bulk HDD; the QNAP provides bulk storage.
- Phase 1 runs one Talos control plane and two workers as VMs on the current Proxmox host.
- The control plane is schedulable, so there are three schedulable nodes.
- There is no host-level HA. If the Proxmox host fails, the cluster is down.
- When the new server arrives, the preferred path is to rebuild the cluster with the control plane on the new host and
  keep the old host as workers/storage.

## 3. Hardware

| Component              | Details                                                                 |
|------------------------|-------------------------------------------------------------------------|
| Proxmox host (current) | Xeon E3-1231v3, 24 GB DDR3, 256 GB SATA SSD, passive GT 710             |
| Talos VMs (phase 1)    | 1 control plane + 2 workers, control plane schedulable                  |
| QNAP                   | TS-433-4G, QTS 5.2.9.3410, 4x 4 TB Seagate IronWolf ST4000VN006, RAID 5 |
| QNAP capacity          | ~10.9 TiB usable before snapshots and QTS overhead                      |
| QNAP address           | `<LAN_PREFIX>.254`                                                      |
| Main server            | Ordered, specifications TBD                                             |

The GT 710 is only a console/headless-boot workaround. It is not used for transcoding or compute.

## 4. Cluster topology

```text
Proxmox host (192.0.2.5 placeholder)
├── talos-cp-1      control plane + workloads   192.0.2.10
├── talos-worker-1  worker                      192.0.2.11
└── talos-worker-2  worker                      192.0.2.12
```

- One etcd member on `talos-cp-1`.
- `allowSchedulingOnControlPlanes: true`.
- No API VIP; the endpoint is the control-plane IP.
- Losing the control-plane VM means losing the Kubernetes API until restore/rebuild.
- Losing the Proxmox host means losing the cluster.
- Backups are therefore mandatory, not optional.
- No in-place role migration. Rebuild is the supported path.

## 5. Network and ingress

- LAN clients use the in-cluster CoreDNS resolver (`lan-dns`) at `<DNS_VIP>`.
- DHCP remains on the FRITZ!Box.
- Internal names use `*.home.jonasseidl.com` and resolve only via `lan-dns`.
- Public names are explicit Cloudflare records; no public wildcard.
- Cloudflare Tunnel reaches Traefik over the cluster-internal `web` entrypoint.
- Internal clients reach Traefik over `websecure` with a Let's Encrypt wildcard certificate.
- No router ports are opened for inbound traffic.
- Tailscale operator runs in-cluster for remote/admin access. There is no Tailscale client on Proxmox by default.
- If remote access is needed while the cluster is down, FRITZ!Box WireGuard is the emergency path.

### Placeholder IPs

| Placeholder          | Example        |
|----------------------|----------------|
| `<LAN_CIDR>`         | `192.0.2.0/24` |
| `<PROXMOX_IP>`       | `192.0.2.5`    |
| `<TALOS_CP_IP>`      | `192.0.2.10`   |
| `<TALOS_WORKER1_IP>` | `192.0.2.11`   |
| `<TALOS_WORKER2_IP>` | `192.0.2.12`   |
| `<TRAEFIK_VIP>`      | `192.0.2.50`   |
| `<DNS_VIP>`          | `192.0.2.53`   |
| `<QNAP_IP>`          | `192.0.2.254`  |

Replace the placeholders before applying anything. They are RFC 5737 TEST-NET addresses, not real LAN addresses.

## 6. DNS and TLS

### DNS

- `lan-dns` is a GitOps-managed CoreDNS Deployment, separate from the Talos-managed cluster CoreDNS.
- It serves the authoritative `home.jonasseidl.com` zone.
- `*.home.jonasseidl.com` points at the Traefik VIP.
- Explicit records point at Proxmox, QNAP, and Talos host IPs.
- Public queries are forwarded to public resolvers.
- No ad-blocking is performed.
- FRITZ!Box DHCP advertises `<DNS_VIP>` as primary DNS; a public resolver or the FRITZ!Box remains secondary.
- Proxmox and Talos host DNS must not depend on `lan-dns`.

### TLS

- cert-manager issues `*.home.jonasseidl.com` through Let's Encrypt DNS-01 using Cloudflare.
- The certificate lives in the `traefik` namespace.
- Public hostnames use Cloudflare edge TLS; the tunnel origin is HTTP inside the cluster.
- Internal admin UIs are exposed only on `websecure`.

## 7. GitOps and Argo CD

- Argo CD is installed once with Helm by `bootstrap/argocd/install.sh`.
- The root Application is applied once from `bootstrap/root-app.yaml`.
- Argo CD then manages itself through `clusters/home/platform/argocd.yaml`.
- Argo chart upgrades are proposed by Renovate, reviewed, merged, and applied by Argo.
- Argo's own Application uses `prune: false` as a safety measure.
- Everything else uses automated sync, prune, and self-heal.
- The bootstrap script remains the disaster-recovery path.

## 8. Secrets

- Bitwarden Secrets Manager is the source of truth.
- External Secrets Operator runs in-cluster and uses a BSM machine-account token.
- The BSM token is the one manual bootstrap Secret.
- Repository credentials for Argo are not needed because `home-gitops` is public.
- Cloudflare API token, tunnel credentials, Tailscale OAuth client, and application secrets are sourced from BSM.
- No secret values, kubeconfigs, Talos secrets, or Terraform state are committed.

## 9. Storage and backups

### Kubernetes storage

- `local-path` is the default StorageClass for small and hot PVCs.
- `nfs-qnap` uses `csi-driver-nfs` against the QNAP.
- Use `nfs-qnap` for shared data and backups, not databases or Prometheus TSDB.
- Talos includes the `siderolabs/nfs-utils` extension.

### QNAP shares

| Share      | Purpose                                              |
|------------|------------------------------------------------------|
| `/k8s`     | dynamic PVCs and shared application data             |
| `/media`   | media library                                        |
| `/backups` | Proxmox backups, etcd snapshots, restic repositories |
| `/isos`    | Proxmox ISOs                                         |

NFSv4.1, explicit node/Proxmox IP exports, no broad subnet access.

### Backups

- Proxmox `vzdump` of all three Talos VMs to QNAP `/backups`.
- `talosctl etcd snapshot` to QNAP `/backups/etcd`.
- QNAP snapshots of `/k8s`, `/media`, `/backups`.
- QNAP HBS 3 offsite copy to Backblaze B2 or Cloudflare R2 for backups and critical data.
- Restore tests are required before the backup plan is considered complete.
- RAID 5 is not a backup.

## 10. CI

- GitHub Actions Runner Controller (ARC) is planned for phase 3.
- Public repositories use GitHub-hosted runners for untrusted fork PRs.
- ARC is limited to trusted branches/private repositories, with ephemeral runners, no cluster credentials, and
  restricted egress.
- Renovate proposes image and chart updates.
- Argo deploys; CI does not need cluster credentials.

## 11. Workloads

Phase 1-3:

- Argo CD
- External Secrets Operator
- MetalLB
- Traefik
- cert-manager
- CoreDNS (`lan-dns`)
- cloudflared
- Tailscale operator
- local-path provisioner
- csi-driver-nfs
- metrics-server
- Portfolio (public)
- Strava MCP server (public with Cloudflare Access service token)

Deferred:

- Home Assistant (no USB radios assumed for now)
- Observability stack beyond metrics-server
- ARC
- Media stack

## 12. Repository topology

| Repository    | Responsibility                                                    |
|---------------|-------------------------------------------------------------------|
| `home-gitops` | Kubernetes desired state, Argo CD, platform, apps                 |
| `home-infra`  | Proxmox, OpenTofu, Talos config/bootstrap, Ansible, host runbooks |
| `portfolio`   | Portfolio source and container image (later)                      |
| `strava-mcp`  | Strava MCP source and container image (later)                     |

Both platform repositories are public. No secrets in either.

## 13. Roadmap

### Phase 0 - document and decide

- Create both repositories and the Phase 0 documentation.
- Record ADRs.
- Define placeholder IPs and the Phase 1 bootstrap sequence.
- Do not add implementation files yet.
- Exit: docs are reviewable; no Kubernetes, Talos, or OpenTofu files exist.

### Phase 1 - Proxmox, Talos, Argo (current)

- Install Proxmox on the current host.
- Add OpenTofu for three Talos VMs.
- Add Talos configs, bootstrap the control plane, join workers.
- Add the minimum Argo CD bootstrap and root Application.
- Exit: three Ready nodes; Argo Synced; cluster survives VM restarts.

### Phase 2 - core platform

- MetalLB, Traefik, `lan-dns`, cert-manager, ESO, cloudflared, Tailscale.
- Internal and public test routes with working DNS/TLS.
- QNAP NFS storage class.
- Exit: one internal and one public test app reachable; secrets sourced from BSM.

### Phase 3 - workloads and CI

- Portfolio and Strava MCP deployed from GHCR.
- ARC and Renovate.
- Backup jobs and restore test.
- Exit: push -> image -> Renovate PR -> merge -> Argo deploy works.

### Phase 4 - new hardware

- Install Proxmox on the new server.
- Rebuild the cluster with the control plane on the new host.
- Keep the old host as workers/storage or retire it.
- Exit: workloads restored; backups verified.

## 14. Phase gates

A phase is complete only when its gate is demonstrated. Creating files is not completion.

| Phase | Gate                                                                                     |
|-------|------------------------------------------------------------------------------------------|
| 0     | Docs and ADRs are committed; no implementation files exist                               |
| 1     | `kubectl get nodes` shows three Ready nodes; Argo CD is Synced; VM restart test passes   |
| 2     | One internal and one public test route work with DNS/TLS; ESO produces a secret from BSM |
| 3     | Push to an app repo produces an image, Renovate PR, merge, and Argo deploy               |
| 4     | Workloads restored on the new host; a restore test passes                                |

Do not start the next phase until the current gate is met. If a later-phase idea appears,
write it down and defer it.

## 15. Open items

- Pin all Helm chart versions and Talos/Kubernetes versions.
- Replace RFC 5737 IP placeholders with the real LAN plan.
- Confirm Cloudflare Tunnel ID and Access policies.
- Confirm QNAP snapshot volume type and offsite target.
- Add UPS and graceful shutdown.
- Decide whether to add a 2.5GbE NIC to Proxmox for QNAP throughput.
- Add observability and alerting after the cluster is stable, including a
  pending-reboot alert for the Proxmox host (`/var/run/reboot-required`).
