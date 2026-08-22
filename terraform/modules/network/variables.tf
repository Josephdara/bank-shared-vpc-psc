variable "host_project_id" {
  type = string
}

variable "network_name" {
  type = string
}

variable "routing_mode" {
  type    = string
  default = "GLOBAL"
}

variable "prod_subnet" {
  type = object({
    name   = string
    region = string
    cidr   = string
  })
}

variable "analytics_subnet" {
  type = object({
    name   = string
    region = string
    cidr   = string
  })
}

variable "psc_nat_subnet" {
  type = object({
    name   = string
    region = string
    cidr   = string
  })
}
