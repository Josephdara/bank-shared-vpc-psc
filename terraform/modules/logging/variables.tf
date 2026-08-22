variable "host_project_id" {
  type = string
}

variable "folder_id" {
  type        = string
  description = "Folder containing all projects. An aggregated sink here captures flow logs from every project (in Shared VPC they are written under the service projects, not the host)."
}

variable "dataset_id" {
  type    = string
  default = "vpc_flow_logs"
}

variable "location" {
  type        = string
  description = "BigQuery dataset location (region or multi-region, e.g. US)."
  default     = "US"
}
