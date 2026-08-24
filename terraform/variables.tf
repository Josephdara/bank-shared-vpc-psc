# ---- Projects (from bootstrap.sh output / .env) ----
variable "host_project_id" {
  type        = string
  description = "Shared VPC host project (central network + security control plane)."
}

variable "service_a_project_id" {
  type        = string
  description = "Service project A: retail web and private API."
}

variable "service_b_project_id" {
  type        = string
  description = "Service project B: analytics and database."
}

variable "partner_project_id" {
  type        = string
  description = "External partner project: PSC consumer."
}

# ---- Regions / zones ----
variable "region" {
  type        = string
  description = "Primary region for prod workloads, PSC NAT, and the published API."
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "Zone for prod (web/API) instances. Null derives '<region>-b'."
  default     = null
}

variable "analytics_region" {
  type        = string
  description = "Region for the analytics subnet and database VM."
  default     = "us-east1"
}

variable "analytics_zone" {
  type        = string
  description = "Zone for the database VM. Null derives '<analytics_region>-b'."
  default     = null
}

# Note: the partner VPC subnet and PSC endpoint always use `region`. PSC requires
# the consumer endpoint and producer service attachment to share a region.

# ---- Networking ----
variable "network_name" {
  type        = string
  description = "Name of the custom-mode Shared VPC network."
  default     = "bank-shared-vpc"
}

variable "prod_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "analytics_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "psc_nat_subnet_cidr" {
  type    = string
  default = "10.0.3.0/28"
}

variable "partner_network_name" {
  type    = string
  default = "partner-vpc"
}

variable "partner_subnet_cidr" {
  type    = string
  default = "192.168.1.0/24"
}

# ---- Workloads ----
variable "app_port" {
  type        = number
  description = "Port the web/API workload (and the published ILB) listens on. Plain HTTP demo, so 80."
  default     = 80
}

variable "db_port" {
  type        = number
  description = "Database port protected by the identity-based firewall rule."
  default     = 5432
}

variable "folder_id" {
  type        = string
  description = "Numeric folder ID containing the four projects (from .env FOLDER_ID). Used for the aggregated flow-logs sink."
}

variable "bq_location" {
  type        = string
  description = "BigQuery dataset location for the VPC Flow Logs sink."
  default     = "US"
}

variable "machine_type" {
  type    = string
  default = "e2-small"
}

variable "image" {
  type    = string
  default = "debian-cloud/debian-12"
}
