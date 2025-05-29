provider "google" {
  project     = "rishab-gupta-cwx-internal"
  region      = "us-central1"
}

resource "google_sql_database_instance" "product_sql" {
  name             = "product-sql-test"
  database_version = "POSTGRES_14"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/rishab-gupta-cwx-internal/global/networks/default"
    }
  }
  deletion_protection = false
}

resource "google_sql_user" "postgres" {
  name     = "postgres_test"
  instance = google_sql_database_instance.product_sql.name
  password = "rishab1903"
}

resource "google_sql_database" "products_db" {
  name     = "products_test"
  instance = google_sql_database_instance.product_sql.name
}

output "private_ip" {
  value = google_sql_database_instance.product_sql.ip_address[0].ip_address
}

output "connection_name" {
  value = google_sql_database_instance.product_sql.connection_name
}

