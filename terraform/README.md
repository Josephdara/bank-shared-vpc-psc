# Terraform — Shared VPC + PSC

Provisions the secure banking reference architecture from [`../arch.md`](../arch.md)
across four projects created by [`../bootstrap.sh`](../bootstrap.sh).

## Layout

```
terraform/
├── versions.tf      provider + backend (partial; configured at init)
├── providers.tf     google provider (project set per-resource)
├── variables.tf     inputs (project IDs, regions, CIDRs, ports)
├── services.tf      Stage 1: enable APIs on each project
├── main.tf          wires the modules together
├── outputs.tf       verification-relevant values
└── modules/
    ├── network/     Stage 2: Shared VPC host, subnets (+ flow logs), PSC NAT subnet
    ├── iam/         Stage 3: service-project attach, SAs, subnet-level IAM
    ├── workloads/   Stage 4: web MIG, database VM, central firewall rules
    ├── psc/         Stage 5: internal LB, service attachment, partner endpoint + client VM
    └── logging/     Observability: VPC Flow Logs → BigQuery sink (host project)
```

Apply order from `arch.md` is enforced by the dependency graph, so a single
`terraform apply` walks the stages in order.

## Usage

```bash
# 1. Projects + state bucket (from repo root)
./bootstrap.sh

# 2. Configure this module
cd terraform
cp backend.hcl.example backend.hcl               # set bucket = <printed state bucket>
cp terraform.tfvars.example terraform.tfvars     # set the four project IDs

# 3. Init + apply
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Verification (matches arch.md)

After apply:

- Web workload → database on TCP 5432: **allowed** (source `web-app-sa`, target `db-sa`).
- A VM with any other service account → database: **denied**.
- Partner client → PSC endpoint (`psc_endpoint_ip` output): **allowed**.

## Scaffold notes

- The web tier is a minimal single-instance regional MIG. Its startup script
  (`modules/workloads/startup-web.sh.tftpl`) serves a static "connection
  successful" page on `app_port` (default 80) using python3 from the base image —
  no package downloads, since the VM has no egress. The database is a plain VM
  (per `arch.md`, a VM — not Cloud SQL) with no listener yet; add one on `db_port`
  to exercise the web→db firewall path end to end.
- Subnet `networkUser` is granted to the two workload service accounts. Depending
  on how instances are created you may also need to grant it to each service
  project's Compute service agent — add those bindings in `modules/iam` if a plan
  reports a permission gap.
- The partner endpoint reuses `region` (the service attachment region) — PSC
  requires the two to match, so there is no separate partner-region knob.
