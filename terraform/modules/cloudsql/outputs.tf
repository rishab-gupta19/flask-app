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

