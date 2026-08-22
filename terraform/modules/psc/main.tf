# Stage 5 — private partner access via Private Service Connect.

locals {
  # Partner resources share the producer region (PSC requires it); derive a zone.
  partner_zone = "${var.region}-b"
}

# --- Producer: internal passthrough LB in front of the web/API MIG --------
resource "google_compute_region_health_check" "web" {
  project = var.service_a_project_id
  name    = "web-app-hc"
  region  = var.region

  tcp_health_check {
    port = var.app_port
  }
}

resource "google_compute_region_backend_service" "web" {
  project               = var.service_a_project_id
  name                  = "web-app-backend"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"
  health_checks         = [google_compute_region_health_check.web.id]

  backend {
    group          = var.web_instance_group
    balancing_mode = "CONNECTION"
  }
}

# Internal passthrough LB frontend — the private frontend of the API.
resource "google_compute_forwarding_rule" "ilb" {
  project               = var.service_a_project_id
  name                  = "web-app-ilb"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.web.id
  ports                 = [tostring(var.app_port)]
  network               = var.network_self_link
  subnetwork            = var.prod_subnet_self_link
}

# --- Producer: PSC service attachment (publishes the ILB) -----------------
# Explicit acceptance: only the partner project may connect. The attachment
# draws its NAT addresses from the dedicated psc-nat-subnet.
resource "google_compute_service_attachment" "api" {
  project = var.service_a_project_id
  name    = "retail-api-psc"
  region  = var.region

  connection_preference = "ACCEPT_MANUAL"
  enable_proxy_protocol = false
  nat_subnets           = [var.psc_nat_subnet_self_link]
  target_service        = google_compute_forwarding_rule.ilb.self_link

  consumer_accept_lists {
    project_id_or_num = var.partner_project_id
    connection_limit  = 1
  }
}

# --- Consumer: partner VPC and the PSC endpoint ---------------------------
# The partner has its own custom-mode VPC and reaches the bank only through the
# PSC endpoint below — the single published service, nothing else.
resource "google_compute_network" "partner" {
  project                 = var.partner_project_id
  name                    = var.partner_network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "partner" {
  project       = var.partner_project_id
  name          = "partner-subnet"
  region        = var.region
  ip_cidr_range = var.partner_subnet_cidr
  network       = google_compute_network.partner.id
}

resource "google_compute_address" "psc_endpoint" {
  project      = var.partner_project_id
  name         = "psc-endpoint-ip"
  region       = var.region
  subnetwork   = google_compute_subnetwork.partner.id
  address_type = "INTERNAL"
}

# The PSC endpoint: a forwarding rule that targets the service attachment.
resource "google_compute_forwarding_rule" "psc_endpoint" {
  project               = var.partner_project_id
  name                  = "psc-endpoint"
  region                = var.region
  load_balancing_scheme = "" # empty scheme marks this as a PSC consumer endpoint
  target                = google_compute_service_attachment.api.id
  network               = google_compute_network.partner.id
  subnetwork            = google_compute_subnetwork.partner.id
  ip_address            = google_compute_address.psc_endpoint.id
}

# --- Consumer: client VM to exercise the published API --------------------
# Allow IAP-tunneled SSH so the client needs no public IP.
resource "google_compute_firewall" "partner_iap_ssh" {
  project   = var.partner_project_id
  name      = "partner-allow-iap-ssh"
  network   = google_compute_network.partner.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # Google IAP range
}

resource "google_compute_instance" "partner_client" {
  project      = var.partner_project_id
  name         = "partner-client"
  machine_type = var.machine_type
  zone         = local.partner_zone

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.partner.id
    # No external IP: SSH arrives via IAP, the API call goes to the PSC endpoint.
  }
}
