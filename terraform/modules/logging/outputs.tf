output "dataset_id" {
  description = "BigQuery dataset receiving VPC Flow Logs."
  value       = google_bigquery_dataset.flow_logs.dataset_id
}

output "sink_writer_identity" {
  value = google_logging_folder_sink.flow_logs.writer_identity
}
