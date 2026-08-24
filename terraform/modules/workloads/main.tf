# Stage 4: workloads and the central (identity-based) firewall.

# --- Web / API workload (service project A, prod-subnet) -------------------
resource "google_compute_instance_template" "web" {
  project      = var.service_a_project_id
  name_prefix  = "web-app-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = var.prod_subnet_self_link
    # No external IP: reached only via the internal LB / PSC.
  }

  service_account {
    email  = var.web_app_sa_email
    scopes = ["cloud-platform"]
  }

  # Serves a static "connection successful" page on app_port using python3 from
  # the base image (the VM has no egress for package installs).
  metadata_startup_script = templatefile("${path.module}/startup-web.sh.tftpl", {
    app_port = var.app_port
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "web" {
  project            = var.service_a_project_id
  name               = "web-app-mig"
  region             = var.region
  base_instance_name = "web-app"
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.web.id
  }

  named_port {
    name = "app"
    port = var.app_port
  }
}

# --- Database VM (service project B, analytics-subnet) ---------------------
resource "google_compute_instance" "db" {
  project      = var.service_b_project_id
  name         = "db-vm"
  machine_type = var.machine_type
  zone         = var.analytics_zone

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = var.analytics_subnet_self_link
  }

  service_account {
    email  = var.db_sa_email
    scopes = ["cloud-platform"]
  }
}

# --- Central firewall rules (host project owns the Shared VPC) -------------

# The core control: allow the database port ONLY from web-app-sa to db-sa.
# Identity-scoped, with no IP ranges, so it holds regardless of addressing.
resource "google_compute_firewall" "allow_web_to_db" {
  project   = var.host_project_id
  name      = "allow-web-to-db"
  network   = var.network_self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [tostring(var.db_port)]
  }

  source_service_accounts = [var.web_app_sa_email]
  target_service_accounts = [var.db_sa_email]
}

# Health checks for the internal LB must reach the web workload.
resource "google_compute_firewall" "allow_health_check" {
  project   = var.host_project_id
  name      = "allow-lb-health-check"
  network   = var.network_self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port)]
  }

  # Google load-balancer / health-check probe ranges.
  source_ranges           = ["35.191.0.0/16", "130.211.0.0/22"]
  target_service_accounts = [var.web_app_sa_email]
}

# PSC producer traffic arrives from the PSC NAT subnet; allow it to the web app.
resource "google_compute_firewall" "allow_psc_ingress" {
  project   = var.host_project_id
  name      = "allow-psc-to-web"
  network   = var.network_self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port)]
  }

  source_ranges           = [var.psc_nat_subnet_cidr]
  target_service_accounts = [var.web_app_sa_email]
}
