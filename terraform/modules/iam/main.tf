# Stage 3 — service-project attachment, workload identities, subnet-level IAM.

# Project numbers, used to build the Google APIs (cloudservices) agent members.
data "google_project" "service_a" {
  project_id = var.service_a_project_id
}

# Attach the service projects to the Shared VPC host.
resource "google_compute_shared_vpc_service_project" "a" {
  host_project    = var.host_project_id
  service_project = var.service_a_project_id
}

resource "google_compute_shared_vpc_service_project" "b" {
  host_project    = var.host_project_id
  service_project = var.service_b_project_id
}

# Workload identities. These service accounts are the subjects of the
# identity-based firewall rule (web-app-sa -> db-sa), so the east-west policy
# follows identity, not IP.
resource "google_service_account" "web_app" {
  project      = var.service_a_project_id
  account_id   = "web-app-sa"
  display_name = "Retail web/API workload (service project A)"
}

resource "google_service_account" "db" {
  project      = var.service_b_project_id
  account_id   = "database-sa"
  display_name = "Database workload (service project B)"
}

# Least-privilege Shared VPC access: each workload identity may use only its own
# subnet. compute.networkUser is granted at the subnet level, not the whole VPC.
resource "google_compute_subnetwork_iam_member" "web_prod" {
  project    = var.host_project_id
  region     = var.prod_subnet.region
  subnetwork = var.prod_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.web_app.email}"
}

# Service project A's Google APIs (cloudservices) agent needs networkUser on the
# subnet so the MIG/instance creation can attach NICs on the Shared VPC.
resource "google_compute_subnetwork_iam_member" "service_a_google_apis" {
  project    = var.host_project_id
  region     = var.prod_subnet.region
  subnetwork = var.prod_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${data.google_project.service_a.number}@cloudservices.gserviceaccount.com"
}

resource "google_compute_subnetwork_iam_member" "db_analytics" {
  project    = var.host_project_id
  region     = var.analytics_subnet.region
  subnetwork = var.analytics_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.db.email}"
}
