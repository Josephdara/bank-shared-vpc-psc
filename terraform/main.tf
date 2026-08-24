# Root module: wires the stages together. Apply order is enforced by the
# dependency graph (explicit depends_on where an implicit edge is not enough).

locals {
  # Zones derive from their region so `region` stays the single knob; override
  # the `zone` / `analytics_zone` variables if a specific zone is needed.
  prod_zone      = coalesce(var.zone, "${var.region}-b")
  analytics_zone = coalesce(var.analytics_zone, "${var.analytics_region}-b")
}

# Stage 2: host networking, Shared VPC, subnets, PSC NAT subnet.
module "network" {
  source = "./modules/network"

  host_project_id  = var.host_project_id
  network_name     = var.network_name
  prod_subnet      = { name = "prod-subnet", region = var.region, cidr = var.prod_subnet_cidr }
  analytics_subnet = { name = "analytics-subnet", region = var.analytics_region, cidr = var.analytics_subnet_cidr }
  psc_nat_subnet   = { name = "psc-nat-subnet", region = var.region, cidr = var.psc_nat_subnet_cidr }

  depends_on = [google_project_service.this]
}

# Observability: route VPC Flow Logs (enabled on the subnets above) to BigQuery.
module "logging" {
  source = "./modules/logging"

  host_project_id = var.host_project_id
  folder_id       = var.folder_id
  location        = var.bq_location

  depends_on = [google_project_service.this]
}

# Stage 3: service-project attachment, service accounts, subnet-level IAM.
module "iam" {
  source = "./modules/iam"

  host_project_id      = var.host_project_id
  service_a_project_id = var.service_a_project_id
  service_b_project_id = var.service_b_project_id

  prod_subnet      = { name = module.network.prod_subnet_name, region = var.region }
  analytics_subnet = { name = module.network.analytics_subnet_name, region = var.analytics_region }

  depends_on = [
    google_project_service.this,
    module.network,
  ]

}

# Stage 4: workloads (web/API MIG, database VM) and the central firewall rules.
module "workloads" {
  source = "./modules/workloads"

  host_project_id      = var.host_project_id
  service_a_project_id = var.service_a_project_id
  service_b_project_id = var.service_b_project_id

  network_self_link          = module.network.network_self_link
  prod_subnet_self_link      = module.network.prod_subnet_self_link
  analytics_subnet_self_link = module.network.analytics_subnet_self_link
  psc_nat_subnet_cidr        = var.psc_nat_subnet_cidr

  region         = var.region
  zone           = local.prod_zone
  analytics_zone = local.analytics_zone

  web_app_sa_email = module.iam.web_app_sa_email
  db_sa_email      = module.iam.db_sa_email

  machine_type = var.machine_type
  image        = var.image
  app_port     = var.app_port
  db_port      = var.db_port


  depends_on = [
    google_project_service.this,
    module.iam,
  ]

}

# Stage 5: private partner access, internal LB, PSC service attachment, endpoint.
module "psc" {
  source = "./modules/psc"

  host_project_id      = var.host_project_id
  service_a_project_id = var.service_a_project_id
  partner_project_id   = var.partner_project_id

  network_self_link        = module.network.network_self_link
  prod_subnet_self_link    = module.network.prod_subnet_self_link
  psc_nat_subnet_self_link = module.network.psc_nat_subnet_self_link
  web_instance_group       = module.workloads.web_instance_group

  region   = var.region
  app_port = var.app_port

  partner_network_name = var.partner_network_name
  partner_subnet_cidr  = var.partner_subnet_cidr

  machine_type = var.machine_type
  image        = var.image

  depends_on = [google_project_service.this]
}
