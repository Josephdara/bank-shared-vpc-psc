output "web_app_sa_email" {
  value = google_service_account.web_app.email
}

output "db_sa_email" {
  value = google_service_account.db.email
}
