/*variable "db_name" {
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
}*/

resource "google_sql_database_instance" "product_sql" {
  name             = "product-sql-test"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_14"

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/${var.project_id}/global/networks/default"
    }
  }

  deletion_protection = false
}

/*resource "null_resource" "wait_for_sql_instance" {
  depends_on = [google_sql_database_instance.product_sql]

  provisioner "local-exec" {
    command = <<EOT
      for i in $(seq 1 30); do
        STATUS=$(gcloud sql instances describe ${google_sql_database_instance.product_sql.name} --project=${var.project_id} --format='value(state)')
        echo "Cloud SQL state: $STATUS"
        if [ "$STATUS" = "RUNNABLE" ]; then exit 0; fi
        sleep 10
      done
      echo "Cloud SQL did not become RUNNABLE in time"
      exit 1
    EOT
  }
}*/

resource "google_sql_database" "products_db" {
  name     = var.db_name
  instance = google_sql_database_instance.product_sql.name
  depends_on = [google_sql_database_instance.product_sql]
  //depends_on = [null_resource.wait_for_sql_instance]
}

resource "google_sql_user" "postgres" {
  name     = var.db_user
  password = var.db_password
  instance = google_sql_database_instance.product_sql.name
  depends_on = [google_sql_database_instance.product_sql]
  //depends_on = [null_resource.wait_for_sql_instance]
}

/*output "private_ip" {
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
}*/
