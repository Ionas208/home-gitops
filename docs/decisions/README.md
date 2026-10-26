# Architecture decision records

| ADR                                  | Decision                                           |
|--------------------------------------|----------------------------------------------------|
| [0001](ADR-0001-repo-topology.md)    | Two platform repos, app repos on demand            |
| [0002](ADR-0002-cluster-topology.md) | One control plane, two workers, disposable phase 1 |
| [0003](ADR-0003-dns.md)              | ~~In-cluster CoreDNS for LAN DNS~~ (superseded)   |
| [0004](ADR-0004-gitops-argo.md)      | App-of-apps with self-managed Argo CD              |
| [0005](ADR-0005-secrets.md)          | BSM + ESO; one manual bootstrap token              |
| [0006](ADR-0006-storage.md)          | local-path + QNAP NFS                              |
| [0007](ADR-0007-public-repo.md)      | Public repos with no secrets and careful CI        |
| [0008](ADR-0008-tailscale.md)        | Tailscale operator only                            |
| [0009](ADR-0009-phase-gates.md)      | Phased delivery with explicit gates                |
| [0010](ADR-0010-public-dns.md)       | Public DNS-only records for internal names         |
