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