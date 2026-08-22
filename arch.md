## Security controls

### Shared VPC and least-privilege IAM

- Enable the host project as a Shared VPC host and attach service projects A and B.
- Grant project A administrators `roles/compute.networkUser` only on `prod-subnet`.
- Grant project B administrators `roles/compute.networkUser` only on `analytics-subnet`.
- Give administrators the workload-management roles they need inside their own service projects, such as Compute Instance Admin.
- Grant `roles/iam.serviceAccountUser` narrowly. A principal that can attach `web-app-sa` to an arbitrary VM could inherit the database access intended for the web workload.

### Identity-based database firewall rule

Create the rule in the host project because the host owns the Shared VPC:

- Direction: ingress
- Action: allow
- Protocol and port: TCP `5432` (or the selected database port)
- Source service account: `web-app-sa` from service project A
- Target service account: `db-sa` from service project B

This works for Compute Engine VMs whose network interfaces are in the same Shared VPC. Use a database VM for this lab; managed services such as Cloud SQL do not behave like an ordinary VM target for this firewall exercise.

The service-account rule protects the east-west web-to-database flow. PSC producer connectivity and load-balancer health checks can still require narrowly scoped infrastructure CIDRs, so the “no IP ranges” rule should not be interpreted as a ban on every infrastructure firewall rule.

### Partner isolation with Private Service Connect

- Place an internal passthrough Network Load Balancer in front of the web/API workload.
- Create a PSC service attachment pointing to the load balancer.
- Configure explicit acceptance for the partner project or partner VPC.
- Create a PSC endpoint with a private IP in `partner-subnet`.

The partner calls the private endpoint and reaches only the published API. The API, rather than the network, becomes the trust boundary.

## Terraform build order

Apply the configuration in bounded stages:

1. **Bootstrap and projects**
   - Confirm organization, billing account, project-creation quota, and operator permissions.
   - Create all four projects and link billing.
   - Enable Compute Engine, IAM, Service Usage, and the bootstrap APIs required by the Terraform runner.
   - Use `disable_on_destroy = false` for project service resources.

2. **Host networking**
   - Enable the Shared VPC host project.
   - Create the custom-mode Shared VPC network.
   - Create `prod-subnet`, `analytics-subnet`, and `psc-nat-subnet`.

3. **Service-project attachment and IAM**
   - Attach service projects A and B to the host.
   - Create `web-app-sa` and `db-sa`.
   - Apply subnet-level `roles/compute.networkUser` bindings.
   - Apply tightly scoped service-account `actAs` permissions.

4. **Workloads and central firewall**
   - Deploy the web/API VM or managed instance group in `prod-subnet`.
   - Deploy the database VM in `analytics-subnet`.
   - Create the service-account-based TCP `5432` firewall rule in the host project.

5. **Private partner access**
   - Create the internal load balancer and health check.
   - Create the PSC service attachment with explicit consumer acceptance.
   - Create the partner PSC endpoint last.

6. **Verification**
   - Web workload to database on TCP `5432`: **allowed**.
   - VM using an unrelated service account to database: **denied**.
   - Partner client to PSC API endpoint: **allowed**.

## References

- [Shared VPC overview and subnet-level IAM](https://docs.cloud.google.com/vpc/docs/shared-vpc)
- [VPC firewall rules and service-account targets](https://docs.cloud.google.com/firewall/docs/firewalls)
- [Create and access a Private Service Connect published service](https://docs.cloud.google.com/vpc/docs/create-access-private-service-connect-service)
- [Configure a Private Service Connect producer](https://docs.cloud.google.com/vpc/docs/configure-private-service-connect-producer)