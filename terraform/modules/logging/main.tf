# Central observability: route VPC Flow Logs into BigQuery for analysis.
# The sink lives in the host project because the flow logs are generated there
# (the Shared VPC subnets belong to the host project).

resource "google_bigquery_dataset" "flow_logs" {
  project    = var.host_project_id
  dataset_id = var.dataset_id
  location   = var.location

  # Demo convenience: let `terraform destroy` remove the dataset with its tables.
  delete_contents_on_destroy = true
}

# Aggregated folder sink with include_children: in Shared VPC the VMs' flow logs
# are written under the SERVICE projects, so a host-only project sink misses them.
# A folder sink captures logs from every project under the folder (host included).
resource "google_logging_folder_sink" "flow_logs" {
  name             = "vpc-flow-logs-to-bq"
  folder           = var.folder_id
  include_children = true
  destination      = "bigquery.googleapis.com/projects/${var.host_project_id}/datasets/${google_bigquery_dataset.flow_logs.dataset_id}"

  # Only VPC Flow Logs.
  filter = "log_id(\"compute.googleapis.com/vpc_flows\")"

  bigquery_options {
    use_partitioned_tables = true
  }
}

# The sink's writer service account is created lazily by Google when the sink is
# created and takes a moment to propagate. BigQuery's setPolicy validates that
# the member exists, so wait before granting to avoid a "does not exist" error.
resource "time_sleep" "wait_for_sink_sa" {
  depends_on      = [google_logging_folder_sink.flow_logs]
  create_duration = "60s"
}

# The sink's writer identity needs to write into the dataset.
resource "google_bigquery_dataset_iam_member" "sink_writer" {
  project    = var.host_project_id
  dataset_id = google_bigquery_dataset.flow_logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_folder_sink.flow_logs.writer_identity

  depends_on = [time_sleep.wait_for_sink_sa]
}
