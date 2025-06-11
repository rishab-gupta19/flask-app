provider "kubernetes" {
  # host                   = google_container_cluster.primary.endpoint
  host                   = "https://${data.google_container_cluster.primary.endpoint}:443"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name    = google_container_cluster.primary.name
  location = google_container_cluster.primary.location
}
data "google_secret_manager_secret_version" "db_password_cloudsql_fetch" {
  secret = var.db_password 
  version = "latest"
  project = var.project_id
  depends_on = [var.cloudsql_secret_version_dep]
}
resource "kubernetes_secret" "cloudsql_credentials" {
  metadata {
    name      = "cloudsql-db-credentials"
    namespace = "default"
  }

  data = {
    "DB_PASSWORD" = data.google_secret_manager_secret_version.db_password_cloudsql_fetch.secret_data
    "DB_USER"     = var.db_user
    "DB_HOST"     = var.cloudsql_private_ip
    "DB_NAME"     = var.db_name
    }

  type = "Opaque"
  depends_on = [google_container_cluster.primary]
}

resource "google_container_cluster" "primary" {
  name                = "product-cluster"
  location            = var.zone
  initial_node_count  = 2
  deletion_protection = false

  network    = var.vpc_network
  subnetwork = var.vpc_subnetwork
  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  depends_on = [var.cloudsql_dep]
}

# Kubernetes Deployment for the backend application
resource "kubernetes_deployment" "backend" {
  metadata {
    name = "product-backend"
  }

  spec {
    replicas = 2 # Number of backend application instances

    selector {
      match_labels = { app = "product-backend" }
    }

    template {
      metadata {
        labels = { app = "product-backend" }
      }

      spec {
        container {
          name  = "flask-container"
          # Use the backend_image variable passed from the root module
          image = var.backend_image

          port {
            container_port = 5000 # Port your Flask app listens on inside the container
          }

          env {
            name = "DB_HOST"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudsql_credentials.metadata[0].name # Name of the K8s Secret
                key  = "DB_HOST"
              }
            }
          }

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudsql_credentials.metadata[0].name
                key  = "DB_USER"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudsql_credentials.metadata[0].name
                key  = "DB_PASSWORD"
              }
            }
          }

          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudsql_credentials.metadata[0].name
                key  = "DB_NAME"
              }
            }
          }

          env {
            name  = "API_TOKEN"
            value = "mysecrettoken123"
          }

          # Readiness probe to check if the container is ready to serve traffic
          readiness_probe {
            http_get {
              path = "/health" # Endpoint for health checks
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          # Liveness probe to check if the container is running and healthy
          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }
      }
    }
  }
  depends_on = [google_container_cluster.primary, kubernetes_secret.cloudsql_credentials]
}

resource "kubernetes_service" "backend_service" {
  metadata {
    name = "product-backend-service"
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
    }
  }

  spec {
    selector = {
      app = "product-backend"
    }

    type = "LoadBalancer"

    port {
      port        = 80  
      target_port = 5000
      }
  }
  depends_on = [google_container_cluster.primary]
}
