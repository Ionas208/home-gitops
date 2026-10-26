# Restore runbook

> Status: target runbook for Phase 3-4. Nothing in this runbook can be executed until
> the cluster, backups, and storage exist.

## Scope

This covers the control-plane VM, etcd, and QNAP-backed data. Git restores Kubernetes
desired state; this runbook restores the things Git cannot recreate.

## 1. Control-plane VM

Preferred recovery for a lost or corrupted `talos-cp-1`:

1. Stop the VM in Proxmox.
2. Restore the latest `vzdump` backup of `talos-cp-1`.
3. Start the VM.
4. Verify the Kubernetes API and etcd:
   ```bash
   kubectl get nodes
   kubectl -n kube-system get pods
   ```
5. If the API is unavailable but etcd data is intact, follow the Talos disaster-recovery
   process for the control plane.

## 2. etcd snapshot

If the VM is rebuilt and an etcd snapshot is available:

1. Rebuild `talos-cp-1` from `home-infra` with the same machine config.
2. Bootstrap the control plane.
3. Restore the etcd snapshot using the Talos recovery procedure.
4. Rejoin workers.
5. Verify Argo CD and workloads.

Test this procedure before relying on it. An untested etcd restore is not a backup.

## 3. QNAP data

- Restore a QNAP snapshot through Snapshot Manager.
- Restore from HBS 3 offsite if the QNAP is lost.
- For a single file, restore to a temporary share first.

## 4. Argo CD

After the cluster is back:

```bash
export ARGOCD_CHART_VERSION=REPLACE_ME
./bootstrap/argocd/install.sh
```

Then recreate the BSM bootstrap Secret if needed:

```bash
kubectl -n external-secrets create secret generic bws-access-token \
  --from-literal=token='REPLACE_ME'
```

Argo recreates the rest from Git.

## 5. Verification checklist

- [ ] three Talos nodes Ready
- [ ] etcd healthy
- [ ] Argo CD Synced
- [ ] BSM ClusterSecretStore Valid
- [ ] cert-manager Certificate Ready
- [ ] `lan-dns` answering on `<DNS_VIP>`
- [ ] Traefik reachable on `<TRAEFIK_VIP>`
- [ ] public tunnel healthy
- [ ] application smoke tests
- [ ] backup schedule running again

## 6. Recovery kit

Keep these outside the repositories:

- Talos secrets bundle
- Talos configs / kubeconfig
- BSM machine-account token
- Cloudflare API token and tunnel credentials
- QNAP admin recovery information
- Proxmox root recovery information

Store them in BSM and an offline encrypted backup.
