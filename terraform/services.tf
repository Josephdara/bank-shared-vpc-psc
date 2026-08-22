# Stage 1 (Terraform side): enable the APIs each project needs.
# bootstrap.sh enabled only Cloud Storage on the host project for state; every
# other service is enabled here. disable_on_destroy=false so a `destroy` of the
# workloads does not tear down APIs (and risk dependent resources elsewhere).

locals {
  project_services = {
    (var.host_project_id) = [
      "compute.googleapis.com",
      "servicenetworking.googleapis.com",
      "iam.googleapis.com",
      "serviceusage.googleapis.com",
      "logging.googleapis.com",
      "bigquery.googleapis.com",
      "networkmanagement.googleapis.com", # Flow Analyzer / Network Intelligence Center UI
    ]
    (var.service_a_project_id) = [
      "compute.googleapis.com",
      "iam.googleapis.com",
      "serviceusage.googleapis.com",
    ]
    (var.service_b_project_id) = [
      "compute.googleapis.com",
      "iam.googleapis.com",
      "serviceusage.googleapis.com",
    ]
    (var.partner_project_id) = [
      "compute.googleapis.com",
      "iam.googleapis.com",
      "serviceusage.googleapis.com",
    ]
  }

  # Flatten {project => [api,...]} into {"project:api" => {project, service}}.
  services_flat = merge([
    for project, apis in local.project_services : {
      for api in apis : "${project}:${api}" => {
        project = project
        service = api
      }
    }
  ]...)
}

resource "google_project_service" "this" {
  for_each = local.services_flat

  project            = each.value.project
  service            = each.value.service
  disable_on_destroy = false
}
