variable "host_project_id" {
  type = string
}

variable "service_a_project_id" {
  type = string
}

variable "service_b_project_id" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "prod_subnet_self_link" {
  type = string
}

variable "analytics_subnet_self_link" {
  type = string
}

variable "psc_nat_subnet_cidr" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "analytics_zone" {
  type = string
}

variable "web_app_sa_email" {
  type = string
}

variable "db_sa_email" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "image" {
  type = string
}

variable "app_port" {
  type = number
}

variable "db_port" {
  type = number
}
