# Architecture

> Status: target architecture. Phase 0 document, not an implementation inventory.

## 1. Overview

```text
                         Internet
                            |
                     Cloudflare edge
                            |
                  Cloudflare Tunnel (outbound)
                            |
                 cloudflared (namespace: cloudflared)
                            |
                 Traefik :80 (web entrypoint)
                            |
                 public workloads (portfolio, mcp)

LAN clients
    |
    v
FRITZ!Box :53  (no custom resolver)
    |
    +--> home.jonasseidl.com / *.home.jonasseidl.com
    |        public DNS-only record --> Traefik :443 (websecure)
    |                                      |
    |                                      +--> internal UIs (Argo, Grafana...)
    |
    +--> everything else --> provider resolvers (Internet)
```

The cluster is a single Kubernetes control plane plus two workers on one Proxmox host.
It is not HA against host failure. It is designed to be rebuilt from Git and backups.

## 2. Node and IP plan

All addresses below are placeholders. Replace them with the real LAN plan.

| Node             | Role                      | Address       | Notes                     |
|------------------|---------------------------|---------------|---------------------------|
| Proxmox host     | hypervisor                | `192.0.2.5`   | static, outside DHCP      |
| `talos-cp-1`     | control plane + workloads | `192.0.2.10`  | etcd member, API endpoint |
| `talos-worker-1` | worker                    | `192.0.2.11`  |                           |
| `talos-worker-2` | worker                    | `192.0.2.12`  |                           |
| Traefik          | MetalLB VIP               | `192.0.2.50`  | `web` and `websecure`     |
| QNAP TS-433      | NAS                       | `192.0.2.254` | NFS, backups, snapshots   |

Reserved ranges:

- MetalLB pool: `192.0.2.50-192.0.2.59`
- Pod network: Talos default (`10.244.0.0/16` unless changed)
- Service network: Talos default (`10.96.0.0/12` unless changed)
- DHCP: FRITZ!Box, excluding the addresses above

Keep the LAN, pod, and service CIDRs non-overlapping.

## 3. DNS

### One resolver, and it is not ours

DNS is not run inside the cluster. Clients keep using the FRITZ!Box, which forwards
to the provider, which resolves everything — including `home.jonasseidl.com` — from
Cloudflare, exactly like any public name.

That is deliberate. A LAN resolver on a single Proxmox host is less reliable than
the router it replaces: any host, cluster, CNI, or MetalLB failure would take name
resolution down for the whole LAN while the internet itself was fine. Publishing a
private address costs a little information and buys complete independence from our
own hardware. `kube-system/coredns` remains for cluster service discovery only and
never answers LAN clients.

### Internal names

`home.jonasseidl.com` is public in Cloudflare, **DNS-only** (proxy off):

| Record                  | Target          |
|-------------------------|-----------------|
| `home.jonasseidl.com`   | `<TRAEFIK_VIP>` |
| `*.home.jonasseidl.com` | `<TRAEFIK_VIP>` |

The wildcard covers every service, so a new `HTTPRoute` needs no DNS change, and it
matches the wildcard certificate exactly. The address is RFC1918: off-LAN it simply
does not route and the TLS handshake fails. Hostnames are already public through
Certificate Transparency, so the record discloses little beyond that.

Proxmox is reached by IP. An explicit record would resolve to Traefik and return 404.

### Rebind protection

The FRITZ!Box drops upstream answers that contain private addresses. Therefore
`home.jonasseidl.com` is listed under Netzwerk → Netzwerkeinstellungen →
DNS-Rebind-Schutz as a hostname exception, which also covers its subdomains.

Negative caching matters when records are added: after an NXDOMAIN has been cached,
the router can keep serving it for up to about 30 minutes.

### Public DNS

Other names remain explicit records, proxied through the Cloudflare Tunnel:

| Record                  | Target                                   |
|-------------------------|------------------------------------------|
| `jonasseidl.com`        | Cloudflare Tunnel                        |
| `www.jonasseidl.com`    | Cloudflare Tunnel                        |
| `mcp.jonasseidl.com`    | Cloudflare Tunnel + Access service token |
| `status.jonasseidl.com` | external uptime service (later)          |

The wildcard is scoped to `home`, never `*.jonasseidl.com`, so the apex and every
other subdomain keep their proxied, tunnel-backed records.

### DHCP

- DHCP stays on the FRITZ!Box.
- "Lokaler DNS-Server" stays empty, so clients receive the router as their resolver,
  the same as before this cluster existed.
- No custom resolver means no LAN-wide DNS outage caused by the cluster or the host.
- Proxmox and Talos host DNS point at public resolvers.

Do not move DHCP into the cluster.

## 4. TLS

```text
cert-manager
  ClusterIssuer: letsencrypt-prod
  DNS-01 via Cloudflare API
        |
        v
  Certificate: *.home.jonasseidl.com
  Secret: wildcard-home-jonasseidl-com-tls (namespace: traefik)
        |
        v
  Traefik websecure
```

Public traffic:

```text
Client --TLS--> Cloudflare edge --tunnel--> cloudflared --HTTP--> Traefik :80
```

Cloudflare terminates public TLS. The tunnel origin is plain HTTP inside the cluster.
Internal traffic uses Traefik `websecure` with the wildcard certificate.

### Internal certificates

Not everything uses a public CA. Cluster-internal services get certificates from a
private CA, because their names never resolve publicly and no public CA would sign
them:

- `ClusterIssuer selfsigned` → `Certificate bitwarden-sdk-ca` (10 years)
- `Issuer bitwarden-sdk-ca` → `Certificate bitwarden-sdk-server` (1 year, renewed)
- External Secrets trusts it via `caProvider` on the `ClusterSecretStore`

That trust is not cluster-wide. Only the client that names the CA in `caProvider`
accepts it; no node or other workload does.

### Entrypoints

| Entrypoint  | Container port | Service port | Used by                       |
|-------------|----------------|--------------|-------------------------------|
| `web`       | 8000           | 80           | cloudflared, public HTTPRoutes |
| `websecure` | 8443           | 443          | LAN clients, internal HTTPRoutes |

Ingress objects are not used. Routing is Gateway API only:

- `GatewayClass` `traefik`, created by the Traefik chart
- `Gateway` `traefik` in the `traefik` namespace, address `<TRAEFIK_VIP>`
- `HTTPRoute` resources in application namespaces

The `kubernetesIngress` provider is disabled, so `Ingress` objects are ignored.
Traefik runs as a DaemonSet with `externalTrafficPolicy: Local` so client
addresses survive and every node can answer for the VIP.

There is no global HTTP-to-HTTPS redirect. Redirecting inside the cluster would
break the tunnel origin. Internal routes attach to the `websecure` listener
explicitly.

## 5. GitOps flow

```text
bootstrap/argocd/install.sh
  └─ helm install Argo CD (pinned chart + platform/argocd/values.yaml)

bootstrap/root-app.yaml
  └─ root Application -> clusters/home/

clusters/home/
  ├─ projects.yaml                     AppProjects
  ├─ platform/argocd.yaml              Argo manages itself
  ├─ platform/argocd-route.yaml        HTTPRoute for the Argo UI
  ├─ platform/external-secrets.yaml    chart + Bitwarden SDK server
  ├─ platform/external-secrets-store.yaml  ClusterSecretStore
  ├─ platform/metallb.yaml             chart
  ├─ platform/metallb-config.yaml      IPAddressPool + L2Advertisement
  ├─ platform/gateway-api.yaml         Gateway API CRDs
  ├─ platform/traefik-crds.yaml        Traefik CRDs (Argo skips chart crds/)
  ├─ platform/traefik.yaml             chart, Gateway provider
  ├─ platform/cert-manager.yaml        chart
  ├─ platform/cert-manager-internal.yaml   private CA, before ESO
  ├─ platform/cert-manager-acme.yaml   Let's Encrypt issuers and wildcard
  ├─ platform/dns.yaml
  ├─ platform/cloudflared.yaml
  ├─ platform/tailscale.yaml
  ├─ platform/local-path.yaml
  ├─ platform/nfs-csi.yaml
  └─ apps/portfolio.yaml, apps/strava-mcp.yaml
```

Component directories under `platform/` hold their chart values at the root; each
subdirectory is one sync unit named for its purpose (`cert-manager/internal`,
`cert-manager/acme`, `external-secrets/store`).

The root Application is applied once and is not self-managed. It creates the real
AppProjects and child Applications. Child Applications carry sync-wave annotations
so ordering is explicit: MetalLB, then CRDs, then Traefik, then consumers.

The two cert-manager config Applications exist because of dependency direction,
not resource type: `internal` must finish before External Secrets starts (it signs
the Bitwarden SDK server certificate), while `acme` must wait for External Secrets
(it reads its Cloudflare token from the store).

Argo CD's own Application uses `prune: false`; everything else uses automated sync,
prune, and self-heal. Argo chart upgrades are proposed by Renovate, reviewed, merged,
and applied by Argo. The bootstrap script is the recovery path.

## 6. Secrets flow

```text
Bitwarden Secrets Manager
        |
        v
External Secrets Operator (ClusterSecretStore: bitwarden)
        |
        +--> cloudflare-api-token        (cert-manager)
        +--> cloudflared credentials     (cloudflared)
        +--> tailscale operator OAuth    (tailscale)
        +--> strava-mcp secrets          (strava-mcp)
```

The only manual bootstrap secret is the BSM machine-account token:
`external-secrets/bws-access-token`, key `token`.

Because `home-gitops` is public, Argo CD does not need repository credentials.
No secret values are stored in Git.

## 7. Storage

```text
Proxmox local-lvm
  ├─ Talos VM disks
  └─ local-path PVCs (small, hot, node-bound)

QNAP TS-433 (NFSv4.1)
  ├─ /k8s      -> nfs-qnap StorageClass, shared data
  ├─ /media    -> media library
  ├─ /backups  -> Proxmox vzdump, etcd snapshots, restic
  └─ /isos     -> Proxmox ISOs
```

`local-path` is the default StorageClass. `nfs-qnap` is explicit.

Do not put databases, etcd, or Prometheus TSDB on NFS. NFS is for shared files,
media, and backups. The Talos node needs the `siderolabs/nfs-utils` extension.

## 8. Backups

| What          | How                      | Target                        |
|---------------|--------------------------|-------------------------------|
| Talos VMs     | Proxmox `vzdump`         | QNAP `/backups/proxmox`       |
| etcd          | `talosctl etcd snapshot` | QNAP `/backups/etcd`          |
| QNAP shares   | QNAP snapshots           | same QNAP (not offsite)       |
| Critical data | HBS 3                    | Backblaze B2 or Cloudflare R2 |
| GitOps state  | Git                      | GitHub                        |

RAID 5 and QNAP snapshots do not protect against fire, theft, ransomware with
admin access, or a failed rebuild. The offsite copy is mandatory.

## 9. Failure modes

| Failure                | Impact                                                | Recovery                                        |
|------------------------|-------------------------------------------------------|-------------------------------------------------|
| Worker VM down         | Some pods restart elsewhere                           | Proxmox restart / node rejoin                   |
| Control-plane VM down  | Kubernetes API unavailable; running pods may continue | Restore VM/etcd or rebuild                      |
| Proxmox host down      | Whole cluster down                                    | Restore host; VMs restart                       |
| QNAP down              | NFS PVCs unavailable; backups fail                    | Restore QNAP; local-path apps continue          |
| Cloudflare DNS down    | All name resolution fails, internal and public        | Wait for Cloudflare; use IPs meanwhile          |
| Cloudflare tunnel down | Public services unavailable                           | Restart cloudflared; internal access unaffected |
| Argo CD down           | No reconciliation; workloads keep running             | Bootstrap/recovery runbook                      |
| Certificate expiry     | Internal TLS breaks                                   | cert-manager; manual reissue                    |

## 10. Public exposure rules

- No router port forwarding.
- No public Kubernetes API.
- No public Argo CD or Grafana.
- Public services only through Cloudflare Tunnel.
- Admin services only on `websecure` and/or Tailscale.
- Cloudflare Access service tokens for machine-to-machine public endpoints.
- ARC runners never receive cluster credentials.
