resource "google_container_cluster" "primary" {
  name               = "product-cluster"
  location           = "us-central1-a"
  initial_node_count = 2
  deletion_protection = false

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [var.cloudsql_dep]
}

provider "kubernetes" {
  host                   = google_container_cluster.primary.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default" {}

resource "kubernetes_deployment" "backend" {
  metadata {
    name = "product-backend"
  }

  spec {
    replicas = 2

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
          image = var.backend_image

          port {
            container_port = 5000
          }

          env {
            name  = "DB_HOST"
            value = var.cloudsql_private_ip
          }

          env {
            name  = "DB_USER"
            value = var.db_user
          }

          env {
            name  = "DB_PASSWORD"
            value = var.db_password
          }

          env {
            name  = "DB_NAME"
            value = var.db_name
          }

          env {
            name  = "API_TOKEN"
            value = "mysecrettoken123"
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

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
}

