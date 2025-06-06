variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for the GKE cluster nodes and VM."
  type        = string
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "db_name" {
  type        = string
  default     = "product-sql-test"
  description = "Name of the Cloud SQL database."
}

variable "db_user" {
  type        = string
  default     = "postgres_test"
  description = "Username for the Cloud SQL database."
}