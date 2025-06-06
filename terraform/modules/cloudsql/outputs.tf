output "private_ip" {
  value = google_sql_database_instance.product_sql.ip_address[0].ip_address
}

output "db_name" {
  value = google_sql_database.products_db.name
}

output "username" {
  value = google_sql_user.postgres.name
}

output "instance_name" {
  value = google_sql_database_instance.product_sql.name
}

output "db_password_secret_id" {
  description = "The Secret Manager Secret ID for the Cloud SQL database password."
  value       = google_secret_manager_secret.db_password.secret_id
}

output "db_password_secret_value" {
  description = "The generated Cloud SQL database password (sensitive)."
  value       = random_password.db_password_generated.result
  sensitive   = true
}