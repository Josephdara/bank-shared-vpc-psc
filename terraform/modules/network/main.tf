# Stage 2: host networking.

# Promote the host project to a Shared VPC host.
resource "google_compute_shared_vpc_host_project" "host" {
  project = var.host_project_id
}

# Custom-mode network: no auto subnets, we declare each one explicitly.
resource "google_compute_network" "shared" {
  project                 = var.host_project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

resource "google_compute_subnetwork" "prod" {
  project                  = var.host_project_id
  name                     = var.prod_subnet.name
  region                   = var.prod_subnet.region
  ip_cidr_range            = var.prod_subnet.cidr
  network                  = google_compute_network.shared.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "analytics" {
  project                  = var.host_project_id
  name                     = var.analytics_subnet.name
  region                   = var.analytics_subnet.region
  ip_cidr_range            = var.analytics_subnet.cidr
  network                  = google_compute_network.shared.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Dedicated NAT subnet for the PSC producer (service attachment draws from here).
resource "google_compute_subnetwork" "psc_nat" {
  project       = var.host_project_id
  name          = var.psc_nat_subnet.name
  region        = var.psc_nat_subnet.region
  ip_cidr_range = var.psc_nat_subnet.cidr
  network       = google_compute_network.shared.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}
