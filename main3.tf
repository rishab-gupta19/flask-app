provider "google" {
  project = "rishab-gupta-cwx-internal"
  region  = "us-central1"
}

provider "kubernetes" {
  host                   = google_container_cluster.primary.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

data "google_client_config" "default" {}

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

resource "null_resource" "wait_for_sql_instance" {
  depends_on = [google_sql_database_instance.product_sql]

  provisioner "local-exec" {
    command = <<EOT
      for i in {1..30}; do
        STATUS=$(gcloud sql instances describe product-sql-test --format='value(state)')
        echo "Cloud SQL state: $STATUS"
        if [ "$STATUS" == "RUNNABLE" ]; then exit 0; fi
        sleep 10
      done
      echo "Cloud SQL did not become RUNNABLE in time"
      exit 1
    EOT
  }
}

resource "google_sql_user" "postgres" {
  name     = "postgres_test"
  instance = google_sql_database_instance.product_sql.name
  password = "rishab1903"
  depends_on = [null_resource.wait_for_sql_instance]
}

resource "google_sql_database" "products_db" {
  name     = "products_test"
  instance = google_sql_database_instance.product_sql.name
  depends_on = [null_resource.wait_for_sql_instance]
}

output "private_ip" {
  value = google_sql_database_instance.product_sql.ip_address[0].ip_address
}

output "connection_name" {
  value = google_sql_database_instance.product_sql.connection_name
}

resource "google_container_cluster" "primary" {
  depends_on = [
    google_sql_user.postgres,
    google_sql_database.products_db
  ]

  name     = "product1-cluster"
  location = "us-central1-a"
  initial_node_count = 2

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  network    = "default"
  subnetwork = "default"
}

data "template_file" "deployment_yaml" {
  template = file("${path.module}/deployment.yaml.tpl")
  vars = {
    DB_USER     = "postgres_test"
    DB_PASSWORD = "rishab1903"
    DB_HOST     = google_sql_database_instance.product_sql.ip_address[0].ip_address
    DB_PORT     = "5432"
    DB_NAME     = "products_test"
    API_TOKEN   = "mysecrettoken123"
  }
}

resource "null_resource" "apply_k8s" {
  depends_on = [google_container_cluster.primary]

  provisioner "local-exec" {
    command = <<EOT
      echo '${data.template_file.deployment_yaml.rendered}' > deployment-final.yaml
      kubectl apply -f deployment-final.yaml
    EOT
  }
}

resource "null_resource" "apply_service" {
  depends_on = [null_resource.apply_k8s]

  provisioner "local-exec" {
    command = <<EOT
      kubectl apply -f ${path.module}/backend-service.yaml
    EOT
  }
}

# Wait and output the internal LB IP from the service
data "external" "get_internal_ip" {
  depends_on = [null_resource.apply_service]

  program = ["bash", "-c", <<EOT
    for i in {1..20}; do
      ip=$(kubectl get svc product-backend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      if [[ ! -z "$ip" ]]; then echo "{\"ip\": \"$ip\"}"; exit 0; fi
      sleep 5
    done
    echo "{\"ip\": \"\"}"
    exit 1
  EOT
  ]
}

output "internal_lb_ip" {
  value = data.external.get_internal_ip.result["ip"]
}

