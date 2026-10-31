# Bootstrap runbook

> Status: current for Phase 1. Argo CD is installed and self-manages through
> `clusters/home/platform/argocd.yaml`. Steps 4-9 are Phase 2 and later.

This is the end-to-end sequence for a fresh cluster. Host-side steps live in
[`home-infra`](https://github.com/Ionas208/home-infra); this runbook ties them to Argo CD.

## Prerequisites

- Proxmox installed and reachable at `<PROXMOX_IP>`
- Proxmox API token with least privilege
- Talos ISO uploaded to Proxmox
- Three Talos VMs created by `home-infra` OpenTofu
- QNAP reachable at `<QNAP_IP>` with NFS exports
- Cloudflare zone for `jonasseidl.com`
- Cloudflare Tunnel created, credentials JSON stored in BSM
- BSM machine account token available
- `talosctl`, `kubectl`, `helm`, and `git` installed locally

## 1. Talos

From `home-infra`:

```bash
export TALOS_VERSION=REPLACE_ME
export CLUSTER_ENDPOINT=https://192.0.2.10:6443
./talos/generate.sh

export TALOS_CP_IP=192.0.2.10
export TALOS_WORKER1_IP=192.0.2.11
export TALOS_WORKER2_IP=192.0.2.12
./bootstrap/02-talos.sh
```

Verify:

```bash
kubectl get nodes -o wide
```

Expected: three Ready nodes, `talos-cp-1` schedulable.

## 2. Pin versions

Before installing Argo CD, replace every `REPLACE_ME` in:

- `clusters/home/platform/*.yaml`
- `platform/**/values.yaml`
- `apps/**/deployment.yaml`

At minimum, pin the Argo CD chart version in `clusters/home/platform/argocd.yaml`.
The bootstrap script reads that value or accepts `ARGOCD_CHART_VERSION`.

## 3. Argo CD

From `home-gitops`:

```bash
export ARGOCD_CHART_VERSION=REPLACE_ME
./bootstrap/argocd/install.sh
```

The script:

1. installs the pinned `argo-cd` chart into `argocd`
2. applies `bootstrap/root-app.yaml`
3. lets the root Application create AppProjects and child Applications

Check:

```bash
kubectl -n argocd get applications
kubectl -n argocd get appprojects
```

## 4. BSM bootstrap secret

External Secrets Operator needs its Bitwarden machine-account token once:

```bash
kubectl -n external-secrets create secret generic bitwarden-access-token \
  --from-literal=accessToken='REPLACE_ME'
```

This is the only manual secret. Rotate it by updating the Secret and the BSM machine account.

## 5. Verify platform

```bash
kubectl -n external-secrets get clustersecretstore
kubectl -n cert-manager get clusterissuer
kubectl -n traefik get svc traefik
kubectl -n cloudflared get pods
kubectl -n tailscale get pods
```

Expected:

- `bitwarden` ClusterSecretStore is `Valid`
- `letsencrypt-prod` is `Ready`
- Traefik has `<TRAEFIK_VIP>`
- cloudflared and Tailscale pods are running

## 6. DNS

There is no LAN resolver in the cluster. Internal names are public DNS-only records.

1. Confirm public resolution:
   ```bash
   dig @1.1.1.1 argocd.home.jonasseidl.com   # <TRAEFIK_VIP>
   ```
2. Confirm the FRITZ!Box passes it through. `home.jonasseidl.com` must be listed
   under Netzwerk → Netzwerkeinstellungen → DNS-Rebind-Schutz as a hostname
   exception, or the router drops the private-address answer:
   ```bash
   dig @<ROUTER_IP> argocd.home.jonasseidl.com
   ```
3. Leave "Lokaler DNS-Server" empty. Clients use the router.
4. Do not point Proxmox or Talos host DNS at anything cluster-owned.

## 7. Certificates and ingress

1. Confirm the wildcard Certificate is Ready:
   ```bash
   kubectl -n traefik get certificate
   ```
2. Open `https://argocd.home.jonasseidl.com` from the LAN.
3. Confirm the certificate is trusted.

## 8. Public ingress

1. Confirm the Cloudflare Tunnel is healthy.
2. Confirm `cloudflared` is connected.
3. Open `https://jonasseidl.com`.
4. Confirm `mcp.jonasseidl.com` requires the Cloudflare Access service token.

## 9. Backups

1. Add QNAP `/backups` as Proxmox `vzdump` storage.
2. Schedule VM backups.
3. Schedule etcd snapshots.
4. Configure QNAP snapshots and HBS 3 offsite.
5. Perform a restore test before calling the cluster production.

## Recovery

If Argo CD is broken, rerun:

```bash
./bootstrap/argocd/install.sh
```

If the cluster is lost, rebuild Talos from `home-infra`, restore the control-plane VM or
etcd snapshot, then rerun the Argo bootstrap. Git is the source of truth for cluster state.
