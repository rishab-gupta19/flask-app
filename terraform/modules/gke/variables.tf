variable "project_id" {}
variable "region" {}
variable "cloudsql_dep" {}
variable "cloudsql_private_ip" {}
variable "db_user" {}
variable "db_password" {
  sensitive = true
}
variable "db_name" {}
variable "backend_image" {}
variable "zone" {}
variable "cloudsql_secret_version_dep" {
  type        = any
}
variable "vpc_network" {
  type        = string
  description = "The self_link of the VPC network for the GKE cluster."
}
variable "vpc_subnetwork" {
  type        = string
  description = "The self_link of the subnetwork for the GKE cluster."
}