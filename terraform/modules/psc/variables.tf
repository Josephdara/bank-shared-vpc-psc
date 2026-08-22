variable "host_project_id" {
  type = string
}

variable "service_a_project_id" {
  type = string
}

variable "partner_project_id" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "prod_subnet_self_link" {
  type = string
}

variable "psc_nat_subnet_self_link" {
  type = string
}

variable "web_instance_group" {
  type = string
}

# Producer region. The partner endpoint reuses this too: PSC requires the
# consumer endpoint and producer service attachment to share a region.
variable "region" {
  type = string
}

variable "app_port" {
  type = number
}

variable "partner_network_name" {
  type = string
}

variable "partner_subnet_cidr" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "image" {
  type = string
}
