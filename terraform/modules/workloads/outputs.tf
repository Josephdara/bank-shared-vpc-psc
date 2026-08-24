output "web_instance_group" {
  description = "Regional MIG instance group: backend for the internal LB."
  value       = google_compute_region_instance_group_manager.web.instance_group
}

output "db_instance_ip" {
  description = "Private IP of the database VM."
  value       = google_compute_instance.db.network_interface[0].network_ip
}
