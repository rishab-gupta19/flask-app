resource "random_password" "db_password_generated" {
  length           = 32
  special          = true
  override_special = "!#$%&*()_+-="
  upper            = true
  lower            = true
  numeric          = true
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 4
  keepers = {
    secret_id_keeper = google_secret_manager_secret.db_password.secret_id
  }
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "cloudsql-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    env = "dev"
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data_wo = random_password.db_password_generated.result 
}

resource "google_sql_database_instance" "product_sql" {
  name             = "product-sql-test"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_14"

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      # private_network = "projects/${var.project_id}/global/networks/default"
      private_network = var.vpc_network_link
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
  password_wo = random_password.db_password_generated.result
  instance = google_sql_database_instance.product_sql.name
  depends_on = [google_sql_database_instance.product_sql]
  //depends_on = [null_resource.wait_for_sql_instance]
}