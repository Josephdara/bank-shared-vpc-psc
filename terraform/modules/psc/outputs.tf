output "ilb_ip" {
  description = "Internal LB frontend address (private frontend of the API)."
  value       = google_compute_forwarding_rule.ilb.ip_address
}

output "service_attachment_id" {
  value = google_compute_service_attachment.api.id
}

output "psc_endpoint_ip" {
  description = "Private IP in the partner subnet that reaches the published API."
  value       = google_compute_address.psc_endpoint.address
}

output "partner_client_vm" {
  description = "Name of the partner client VM used to test the published API."
  value       = google_compute_instance.partner_client.name
}

output "partner_client_zone" {
  value = google_compute_instance.partner_client.zone
}
