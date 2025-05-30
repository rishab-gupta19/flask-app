variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "db_password" {
  type        = string
  sensitive   = true
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "cloudsql" {
  source       = "./modules/cloudsql"
  db_password  = var.db_password
  project_id   = var.project_id
  region       = var.region
}

module "gke" {
  source              = "./modules/gke"
  project_id          = var.project_id
  region              = var.region
  cloudsql_dep        = module.cloudsql
  cloudsql_private_ip = module.cloudsql.private_ip
  db_user             = module.cloudsql.username
  db_password         = var.db_password
  db_name             = module.cloudsql.db_name
  backend_image       = "gcr.io/${var.project_id}/product-backend"
}

resource "google_compute_instance" "frontend_vm" {
  name         = "frontend-vm"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io git curl

    # Pull frontend image from GCR
    docker pull gcr.io/${var.project_id}/product-frontend:latest

    # Create default.conf dynamically from template
    mkdir -p /opt/frontend/conf
    cat <<EOF > /opt/frontend/conf/default.conf
    server {
      listen 80;

      location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
      }

      location /api/ {
        proxy_pass http://${module.gke.backend_internal_ip}/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
      }

      location /health {
        proxy_pass http://${module.gke.backend_internal_ip}/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
      }
    }
EOF

    # Run container with mounted config
    docker run -d --name frontend-nginx \
      -p 80:80 \
      -v /opt/frontend/conf/default.conf:/etc/nginx/conf.d/default.conf:ro \
      gcr.io/${var.project_id}/product-frontend:latest
  EOT

  depends_on = [module.gke]
}
