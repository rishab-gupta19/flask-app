#########################################
# VARIABLES
#########################################

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "db_password" {
  description = "Password for Cloud SQL Postgres user"
  type        = string
  sensitive   = true
}

#########################################
# PROVIDERS
#########################################

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "kubernetes" {
  host                   = google_container_cluster.primary.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

data "google_client_config" "default" {}

#########################################
# CLOUD SQL MODULE
#########################################

module "cloudsql" {
  source       = "./modules/cloudsql"
  db_password  = var.db_password
  project_id   = var.project_id
  region       = var.region
}

#########################################
# GKE CLUSTER
#########################################

resource "google_container_cluster" "primary" {
  name     = "product-cluster"
  location = "us-central1-a"
  initial_node_count = 2

  deletion_protection = false

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [module.cloudsql]
}

#########################################
# KUBERNETES DEPLOYMENT
#########################################

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
          image = "gcr.io/${var.project_id}/product-backend"

          port {
            container_port = 5000
          }

          env {
            name  = "DB_HOST"
            value = module.cloudsql.private_ip
          }

          env {
            name  = "DB_USER"
            value = module.cloudsql.username
          }

          env {
            name  = "DB_PASSWORD"
            value = var.db_password
          }

          env {
            name  = "DB_NAME"
            value = module.cloudsql.db_name
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

#########################################
# KUBERNETES SERVICE
#########################################

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
      port        = 443
      target_port = 5000
    }
  }
}

#########################################
# OUTPUTS
#########################################

output "cloudsql_ip" {
  value = module.cloudsql.private_ip
}

output "service_internal_ip" {
  value = kubernetes_service.backend_service.status[0].load_balancer[0].ingress[0].ip
}

