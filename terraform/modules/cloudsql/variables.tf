variable "db_name" {
  type        = string
  default     = "products_test"
}

variable "db_user" {
  type        = string
  default     = "postgres_test"
}

variable "db_password" {
  type        = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

