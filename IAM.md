# IAM roles for deployment

This document lists the IAM roles required by the human user or automation
principal that runs `bootstrap.sh` and Terraform. It intentionally excludes IAM
bindings granted to workload and Google-managed service accounts.

## Least-privilege approach

The role assignments follow the principle of least privilege: give the
deployment principal only the access needed for the task, at the narrowest
resource scope that supports it.

- Prefer the dedicated deployment folder over the organization when a role
  supports folder-level assignment.
- Grant project-specific roles only on the project where their permissions are
  used.
- Grant billing access only on the selected billing account.
- Treat project and folder creation permissions as bootstrap-only access and
  remove them when the principal no longer creates environments.
- Replace state-bucket creation access with bucket-scoped object access after
  bootstrap.
- Do not use broad roles such as Owner or Organization Administrator for routine
  deployment.

This is a least-privilege baseline using Google predefined roles. A custom role
could be made narrower by including only the individual permissions exercised by
this configuration, but it would require ongoing maintenance as the deployment
changes.

## Organization and folder roles

Use the dedicated deployment folder unless organization-wide Shared VPC
administration is intentional.

| Role | Preferred scope | Purpose |
|---|---|---|
| `roles/compute.xpnAdmin` | Demo folder | Enable the Shared VPC host and attach service projects |
| `roles/resourcemanager.projectIamAdmin` | Demo folder | Manage the project IAM needed for Shared VPC administration |
| `roles/compute.networkViewer` | Demo folder | Read the network resources involved in folder-scoped Shared VPC administration |
| `roles/resourcemanager.projectCreator` | Demo folder | Create the four projects under the folder |
| `roles/resourcemanager.folderCreator` | Organization | Create the demo folder when an existing `FOLDER_ID` is not supplied |

`roles/resourcemanager.folderCreator` is unnecessary when the deployment uses an
existing folder. The other Shared VPC roles can be assigned at organization
scope, but doing so grants access to every current and future project in the
organization and is broader than this deployment requires.

## Billing role

Grant the following role only on the billing account selected for the deployment.

| Role | Purpose |
|---|---|
| `roles/billing.user` | Link the newly created projects to the billing account |

`roles/billing.admin` is not required.

## Role required on all four projects

This role can be assigned to the deployment principal on each project or inherited
from the dedicated demo folder.

| Role | Purpose |
|---|---|
| `roles/serviceusage.serviceUsageAdmin` | Enable the APIs declared in `terraform/services.tf` |

## Host project

| Role | Purpose |
|---|---|
| `roles/compute.networkAdmin` | Create and manage the Shared VPC, subnets, PSC NAT subnet, and subnet IAM |
| `roles/compute.securityAdmin` | Create and manage the central firewall rules |
| `roles/logging.configWriter` | Create and manage the VPC Flow Logs sink |
| `roles/bigquery.admin` | Create, manage, and destroy the flow-log dataset and its IAM policy |
| `roles/storage.admin` | Create and configure the Terraform state bucket during bootstrap |

After bootstrap, replace project-level `roles/storage.admin` with
`roles/storage.objectAdmin` granted on
`gs://<STATE_BUCKET>`. Terraform needs object access to read, write,
lock, and version its state, but it does not need to administer every bucket in
the host project.

## Service project A

| Role | Purpose |
|---|---|
| `roles/compute.networkAdmin` | Create the internal passthrough load balancer and PSC service attachment |
| `roles/compute.instanceAdmin.v1` | Create the instance template and managed instance group |
| `roles/iam.serviceAccountAdmin` | Create and manage the web workload service account |
| `roles/iam.serviceAccountUser` | Attach the web workload service account to instances |

## Service project B

| Role | Purpose |
|---|---|
| `roles/compute.instanceAdmin.v1` | Create and manage the database VM |
| `roles/iam.serviceAccountAdmin` | Create and manage the database workload service account |
| `roles/iam.serviceAccountUser` | Attach the database workload service account to the VM |

## Partner project

| Role | Purpose |
|---|---|
| `roles/compute.networkAdmin` | Create the partner VPC, subnet, address, and PSC endpoint |
| `roles/compute.securityAdmin` | Create and manage the IAP ingress firewall rule |
| `roles/compute.instanceAdmin.v1` | Create and manage the partner client VM |

## Roles deliberately excluded

The deployment does not require the routine deployment principal to have these
broad roles:

- `roles/owner`
- `roles/resourcemanager.organizationAdmin`
- `roles/billing.admin`
- `roles/resourcemanager.projectMover`
- `roles/billing.creator`
- `roles/cloudasset.viewer`
- `roles/iam.workforcePoolAdmin`

Service-account bindings are also outside the scope of this document. Terraform
or the platform should manage those bindings separately so that deployment-user
access and workload access remain independently auditable.

## References

- [Shared VPC administrators and IAM](https://cloud.google.com/vpc/docs/shared-vpc)
- [Provision Shared VPC](https://cloud.google.com/vpc/docs/provisioning-shared-vpc)
- [Internal passthrough Network Load Balancer permissions](https://cloud.google.com/load-balancing/docs/internal/setting-up-internal)
- [Configure Cloud Logging sinks](https://cloud.google.com/logging/docs/export/configure_export_v2)
- [Terraform GCS backend permissions](https://developer.hashicorp.com/terraform/language/backend/gcs)
