# PSC and Shared VPC test cases

These tests validate both the partner-facing Private Service Connect (PSC) path
and the Shared VPC control and data planes. Control-plane checks run locally
with `gcloud`; data-plane checks run on private VMs through Identity-Aware Proxy
(IAP) SSH tunnels.

The commands contain no fixed project, account, or resource identifiers. Values
are read from Terraform outputs and variables at runtime.

## Prerequisites

- Terraform has completed successfully.
- The PSC endpoint and partner client VM exist.
- The web managed instance group has a healthy backend.
- The tester is authenticated with `gcloud` and is authorized to open IAP SSH
  tunnels to the partner, web, and database VMs.
- The tester is authorized to inspect Shared VPC relationships and workload
  NICs. Creating the narrowly scoped temporary IAP firewall rule also requires
  permission to create and delete firewall rules in the host project.
- Run the setup and tests below from the `terraform` directory in the same Bash
  or Zsh session.

## Test-session setup

```bash
cd terraform

PARTNER_PROJECT_ID="$(terraform output -raw partner_project_id)"
PARTNER_VM="$(terraform output -raw partner_client_vm)"
PARTNER_ZONE="$(terraform output -raw partner_client_zone)"
PSC_ENDPOINT_IP="$(terraform output -raw psc_endpoint_ip)"
ILB_IP="$(terraform output -raw ilb_ip)"
HOST_PROJECT_ID="$(terraform console <<<'var.host_project_id' | tr -d '"')"
SERVICE_A_PROJECT_ID="$(terraform console <<<'var.service_a_project_id' | tr -d '"')"
APP_PORT="$(terraform console <<<'var.app_port' | tr -d '"')"
DB_PORT="$(terraform console <<<'var.db_port' | tr -d '"')"
SERVICE_B_PROJECT_ID="$(terraform console <<<'var.service_b_project_id' | tr -d '"')"
DEPLOY_REGION="$(terraform console <<<'var.region' | tr -d '"')"
ANALYTICS_ZONE="$(terraform console <<<'local.analytics_zone' | tr -d '"')"
ANALYTICS_REGION="$(terraform console <<<'var.analytics_region' | tr -d '"')"
NETWORK_NAME="$(terraform console <<<'var.network_name' | tr -d '"')"
WEB_APP_SA_EMAIL="$(terraform output -raw web_app_sa_email)"
DB_SA_EMAIL="$(terraform output -raw db_sa_email)"
CLOSED_PORT="$((APP_PORT + 1))"

DB_IP="$(gcloud compute instances describe db-vm \
  --project="$SERVICE_B_PROJECT_ID" \
  --zone="$ANALYTICS_ZONE" \
  --format='value(networkInterfaces[0].networkIP)')"

WEB_VM="$(gcloud compute instances list \
  --project="$SERVICE_A_PROJECT_ID" \
  --filter='name~^web-app-' \
  --limit=1 \
  --format='value(name)')"

WEB_ZONE="$(gcloud compute instances list \
  --project="$SERVICE_A_PROJECT_ID" \
  --filter='name~^web-app-' \
  --limit=1 \
  --format='value(zone.basename())')"

ssh_partner() {
  gcloud compute ssh "$PARTNER_VM" \
    --project="$PARTNER_PROJECT_ID" \
    --zone="$PARTNER_ZONE" \
    --tunnel-through-iap \
    --command="$1"
}
```

Confirm that the variables were populated without printing sensitive account
information:

```bash
test -n "$PARTNER_PROJECT_ID"
test -n "$PARTNER_VM"
test -n "$PARTNER_ZONE"
test -n "$PSC_ENDPOINT_IP"
test -n "$ILB_IP"
test -n "$DB_IP"
test -n "$HOST_PROJECT_ID"
test -n "$SERVICE_A_PROJECT_ID"
test -n "$SERVICE_B_PROJECT_ID"
test -n "$WEB_VM"
test -n "$WEB_ZONE"
test -n "$WEB_APP_SA_EMAIL"
test -n "$DB_SA_EMAIL"
echo "PASS: test-session variables are populated"
```

## TC-01: IAP SSH access succeeds

Purpose: verify that the tester can reach the private partner VM through IAP.

```bash
ssh_partner 'hostname && id && echo "PASS: IAP SSH access works"'
```

Expected result: the command prints the remote hostname and user, followed by
`PASS: IAP SSH access works`.

## TC-02: Partner VM has no external IP

Purpose: confirm that the test client is not directly exposed to the internet.

```bash
ssh_partner 'external_ip="$(curl -fsS \
  -H "Metadata-Flavor: Google" \
  --max-time 3 \
  "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" \
  2>/dev/null || true)"; \
  if [ -n "$external_ip" ]; then \
    echo "FAIL: partner VM has external IP $external_ip"; exit 1; \
  else \
    echo "PASS: partner VM has no external IP"; \
  fi'
```

Expected result: `PASS: partner VM has no external IP`.

## TC-03: Partner reaches the published API through PSC

Purpose: verify the intended positive path from the partner VPC to the published
web service.

```bash
ssh_partner "curl -fsS --max-time 10 \
  'http://${PSC_ENDPOINT_IP}:${APP_PORT}/' \
  | grep -q 'Connection successful' \
  && echo 'PASS: PSC endpoint returned the expected page'"
```

Expected result: `PASS: PSC endpoint returned the expected page`.

## TC-04: PSC path remains available across repeated requests

Purpose: detect intermittent backend, health-check, or load-balancer failures.

```bash
ssh_partner "for attempt in 1 2 3 4 5; do \
  curl -fsS --max-time 10 \
    'http://${PSC_ENDPOINT_IP}:${APP_PORT}/' >/dev/null || exit 1; \
done; echo 'PASS: five consecutive PSC requests succeeded'"
```

Expected result: `PASS: five consecutive PSC requests succeeded`.

## TC-05: Partner cannot bypass PSC and call the producer ILB

Purpose: confirm that the partner can use the PSC endpoint but cannot directly
reach the producer's internal load-balancer address.

```bash
ssh_partner "if curl -fsS --connect-timeout 3 --max-time 5 \
  'http://${ILB_IP}:${APP_PORT}/' >/dev/null 2>&1; then \
    echo 'FAIL: producer ILB was reachable directly'; exit 1; \
  else \
    echo 'PASS: direct producer ILB access is blocked'; \
  fi"
```

Expected result: `PASS: direct producer ILB access is blocked`.

## TC-06: PSC exposes only the configured application port

Purpose: verify that an adjacent, unpublished TCP port is not reachable through
the PSC endpoint.

```bash
ssh_partner "if curl -fsS --connect-timeout 3 --max-time 5 \
  'http://${PSC_ENDPOINT_IP}:${CLOSED_PORT}/' >/dev/null 2>&1; then \
    echo 'FAIL: an unpublished PSC port was reachable'; exit 1; \
  else \
    echo 'PASS: unpublished PSC port is blocked'; \
  fi"
```

Expected result: `PASS: unpublished PSC port is blocked`.

## TC-07: Partner cannot connect directly to the database

Purpose: verify that the partner cannot bypass the published service and open a
TCP connection directly to the database VM.

```bash
ssh_partner "if timeout 5 bash -c \
  'exec 3<>/dev/tcp/${DB_IP}/${DB_PORT}' 2>/dev/null; then \
    echo 'FAIL: direct database connection succeeded'; exit 1; \
  else \
    echo 'PASS: direct database connection is blocked'; \
  fi"
```

Expected result: `PASS: direct database connection is blocked`.

## TC-08: Service projects are attached to the expected Shared VPC host

Purpose: verify the Shared VPC control-plane relationship for both service
projects.

```bash
SERVICE_A_HOST="$(gcloud compute shared-vpc get-host-project \
  "$SERVICE_A_PROJECT_ID" --format='value(name)')"
SERVICE_B_HOST="$(gcloud compute shared-vpc get-host-project \
  "$SERVICE_B_PROJECT_ID" --format='value(name)')"

case "$SERVICE_A_HOST" in
  "$HOST_PROJECT_ID"|"projects/$HOST_PROJECT_ID") ;;
  *) echo "FAIL: service project A is attached to an unexpected host"; exit 1 ;;
esac

case "$SERVICE_B_HOST" in
  "$HOST_PROJECT_ID"|"projects/$HOST_PROJECT_ID") ;;
  *) echo "FAIL: service project B is attached to an unexpected host"; exit 1 ;;
esac

echo "PASS: both service projects use the expected Shared VPC host"
```

Expected result: `PASS: both service projects use the expected Shared VPC host`.

## TC-09: Workloads use subnets owned by the host project

Purpose: prove that the web and database NICs use the intended Shared VPC
subnets, rather than local networks in their service projects.

```bash
WEB_SUBNET="$(gcloud compute instances describe "$WEB_VM" \
  --project="$SERVICE_A_PROJECT_ID" \
  --zone="$WEB_ZONE" \
  --format='value(networkInterfaces[0].subnetwork)')"

DB_SUBNET="$(gcloud compute instances describe db-vm \
  --project="$SERVICE_B_PROJECT_ID" \
  --zone="$ANALYTICS_ZONE" \
  --format='value(networkInterfaces[0].subnetwork)')"

case "$WEB_SUBNET" in
  *"/projects/${HOST_PROJECT_ID}/regions/${DEPLOY_REGION}/subnetworks/prod-subnet") ;;
  *) echo "FAIL: web VM is not using the host prod subnet"; exit 1 ;;
esac

case "$DB_SUBNET" in
  *"/projects/${HOST_PROJECT_ID}/regions/${ANALYTICS_REGION}/subnetworks/analytics-subnet") ;;
  *) echo "FAIL: database VM is not using the host analytics subnet"; exit 1 ;;
esac

echo "PASS: both workloads use the intended host-project subnets"
```

Expected result: `PASS: both workloads use the intended host-project subnets`.

## Temporary IAP access for Shared VPC SSH tests

The configuration intentionally exposes IAP SSH only to the partner VM. The
remaining Shared VPC data-plane tests therefore use one temporary firewall rule
restricted to Google's IAP source range, TCP port 22, and the two workload
service accounts. Run this section only when authorized to make that temporary
host-project change.

```bash
IAP_TEST_RULE="shared-vpc-test-allow-iap-ssh"
CREATED_IAP_TEST_RULE=0

if ! gcloud compute firewall-rules describe "$IAP_TEST_RULE" \
  --project="$HOST_PROJECT_ID" >/dev/null 2>&1; then
  gcloud compute firewall-rules create "$IAP_TEST_RULE" \
    --project="$HOST_PROJECT_ID" \
    --network="$NETWORK_NAME" \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --target-service-accounts="$WEB_APP_SA_EMAIL,$DB_SA_EMAIL"
  CREATED_IAP_TEST_RULE=1
fi

ssh_web() {
  gcloud compute ssh "$WEB_VM" \
    --project="$SERVICE_A_PROJECT_ID" \
    --zone="$WEB_ZONE" \
    --tunnel-through-iap \
    --command="$1"
}

ssh_db() {
  gcloud compute ssh db-vm \
    --project="$SERVICE_B_PROJECT_ID" \
    --zone="$ANALYTICS_ZONE" \
    --tunnel-through-iap \
    --command="$1"
}
```

Delete this rule in the cleanup section after running the SSH tests.

## TC-10: Workloads run with the expected service-account identities

Purpose: confirm the source and target identities used by the identity-based
firewall rule.

```bash
ssh_web "remote_sa=\$(curl -fsS \
  -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email'); \
  test \"\$remote_sa\" = '$WEB_APP_SA_EMAIL' \
  && echo 'PASS: web VM uses the expected identity'"

ssh_db "remote_sa=\$(curl -fsS \
  -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email'); \
  test \"\$remote_sa\" = '$DB_SA_EMAIL' \
  && echo 'PASS: database VM uses the expected identity'"
```

Expected result: both identity checks print `PASS`.

## TC-11: Web identity reaches the database on the allowed port

Purpose: exercise the identity-based firewall rule from the web service account
to the database service account. The test starts a temporary HTTP listener on
the configured database port, confirms it locally, and then calls it from the web
VM.

```bash
ssh_db "nohup python3 -m http.server '$DB_PORT' \
  --bind 0.0.0.0 --directory /tmp \
  >/tmp/shared-vpc-db-test.log 2>&1 \
  & echo \$! >/tmp/shared-vpc-db-test.pid; \
  sleep 1; \
  curl -fsS --max-time 5 'http://127.0.0.1:${DB_PORT}/' >/dev/null \
  && echo 'PASS: temporary database-port listener is running'"

ssh_web "curl -fsS --max-time 10 \
  'http://${DB_IP}:${DB_PORT}/' >/dev/null \
  && echo 'PASS: web identity reached the database port'"
```

Expected result: the database listener starts and the web-to-database request
prints `PASS`.

## TC-12: Web VM reaches the internal load balancer through Shared VPC

Purpose: verify service-project access to the internal load-balancer frontend on
the host network.

```bash
ssh_web "curl -fsS --max-time 10 \
  'http://${ILB_IP}:${APP_PORT}/' \
  | grep -q 'Connection successful' \
  && echo 'PASS: web VM reached the internal load balancer'"
```

Expected result: `PASS: web VM reached the internal load balancer`.

## Shared VPC test cleanup

Stop the temporary listener and remove the temporary IAP firewall rule if this
test session created it:

```bash
ssh_db 'if [ -f /tmp/shared-vpc-db-test.pid ]; then \
  kill "$(cat /tmp/shared-vpc-db-test.pid)" 2>/dev/null || true; \
  rm -f /tmp/shared-vpc-db-test.pid /tmp/shared-vpc-db-test.log; \
fi'

if [ "$CREATED_IAP_TEST_RULE" -eq 1 ]; then
  gcloud compute firewall-rules delete "$IAP_TEST_RULE" \
    --project="$HOST_PROJECT_ID" \
    --quiet
fi

echo "PASS: temporary Shared VPC test resources were removed"
```

## Interpreting failures

| Failure | Likely cause |
|---|---|
| TC-01 | Missing IAP permission, SSH key setup, or partner IAP firewall rule |
| TC-02 | An external access configuration was added to the partner VM |
| TC-03 or TC-04 | Unhealthy web MIG, missing Shared VPC Network User binding for the service project's Google APIs service account, failed health check, or rejected PSC connection |
| TC-05 | An unintended route, peering relationship, VPN, or firewall path exposes the producer network |
| TC-06 | The forwarding rule publishes more ports than intended |
| TC-07 | An unintended network path or firewall rule exposes the database to the partner VPC |
| TC-08 | A service project was not attached, or was attached to a different Shared VPC host |
| TC-09 | A workload NIC references the wrong project, region, or subnet |
| TC-10 | An instance template or VM uses the wrong service account |
| TC-11 | Missing identity-based firewall rule, incorrect service-account target/source, listener failure, or routing problem |
| TC-12 | Unhealthy internal load-balancer backend or missing Shared VPC route/firewall access |

## Current coverage boundary

The default SSH tests enter through the partner client. The Shared VPC SSH tests
temporarily add narrowly scoped IAP access to the web and database workloads,
then remove it during cleanup. Together the tests validate PSC reachability,
partner isolation, Shared VPC attachment and subnet placement, workload
identity, and the allowed web-to-database path.

The following architecture checks require additional test fixtures and are not
claimed by this suite:

- An unrelated service-account identity to the database is denied.

Testing the unrelated-identity denial requires a dedicated negative-test VM or
runner with a third service account. Do not weaken the production firewall or
reuse one of the trusted workload identities merely to create that fixture.
