variable "db_name" {
  type        = string
  default     = "products_test"
}

variable "db_user" {
  type        = string
  default     = "postgres_test"
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "vpc_network_link" {
  type        = string
  description = "The self_link of the VPC network for Cloud SQL private IP."
}