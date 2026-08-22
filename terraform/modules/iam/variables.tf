variable "host_project_id" {
  type = string
}

variable "service_a_project_id" {
  type = string
}

variable "service_b_project_id" {
  type = string
}

variable "prod_subnet" {
  type = object({
    name   = string
    region = string
  })
}

variable "analytics_subnet" {
  type = object({
    name   = string
    region = string
  })
}
