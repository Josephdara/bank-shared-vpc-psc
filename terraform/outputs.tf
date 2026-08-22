output "network_self_link" {
  description = "Self link of the Shared VPC network."
  value       = module.network.network_self_link
}

output "web_app_sa_email" {
  description = "Service account attached to the web/API workload (firewall source identity)."
  value       = module.iam.web_app_sa_email
}

output "db_sa_email" {
  description = "Service account attached to the database VM (firewall target identity)."
  value       = module.iam.db_sa_email
}

output "ilb_ip" {
  description = "Internal passthrough load balancer address (private frontend of the API)."
  value       = module.psc.ilb_ip
}

output "service_attachment_id" {
  description = "PSC service attachment the partner connects to."
  value       = module.psc.service_attachment_id
}

output "psc_endpoint_ip" {
  description = "Private IP in the partner subnet that reaches the published API."
  value       = module.psc.psc_endpoint_ip
}

output "partner_project_id" {
  description = "Partner project (host of the client VM and PSC endpoint)."
  value       = var.partner_project_id
}

output "partner_client_vm" {
  description = "Partner client VM to SSH into for testing the published API."
  value       = module.psc.partner_client_vm
}

output "partner_client_zone" {
  value = module.psc.partner_client_zone
}

output "flow_logs_dataset" {
  description = "BigQuery dataset receiving VPC Flow Logs."
  value       = module.logging.dataset_id
}
