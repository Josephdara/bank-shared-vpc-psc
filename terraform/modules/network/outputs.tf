output "network_self_link" {
  value = google_compute_network.shared.self_link
}

output "prod_subnet_self_link" {
  value = google_compute_subnetwork.prod.self_link
}

output "prod_subnet_name" {
  value = google_compute_subnetwork.prod.name
}

output "analytics_subnet_self_link" {
  value = google_compute_subnetwork.analytics.self_link
}

output "analytics_subnet_name" {
  value = google_compute_subnetwork.analytics.name
}

output "psc_nat_subnet_self_link" {
  value = google_compute_subnetwork.psc_nat.self_link
}
