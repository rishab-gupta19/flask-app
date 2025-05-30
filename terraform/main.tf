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

variable "zone" {
  description = "The GCP zone for the GKE cluster nodes and VM."
  type        = string
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
  name         = "frontend-vm-${random_id.suffix.hex}"
  machine_type = "e2-medium"
  zone         = var.zone

  # Boot disk configuration
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Using a stable Debian image
    }
  }

  # Network interface configuration
  network_interface {
    network = "default" 

    # Assign an external IP address for public access
    access_config {
    }
  }

  # Allow HTTP traffic to the VM instance
  tags = ["http-server"]

  # Metadata startup script to install Docker and run the container
  # This script will execute automatically when the VM starts.
  metadata_startup_script = templatefile("${path.module}/startup_script.sh", {
    docker_image_name = "gcr.io/rishab-gupta-cwx-internal/product-frontend"
    # Dynamically fetch the internal IP from the GKE module's output
    gke_backend_ip    = module.gke.backend_internal_ip
  })

  # Service account with necessary permissions for pulling Docker images from GCR
  # and other cloud operations if needed.
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-frontend-vm"
  network = "default" # Apply to the default VPC network

  allow {
    protocol = "tcp"
    ports    = ["80"] # Allow traffic on port 80
  }

  # Apply this rule to instances with the "http-server" tag
  target_tags = ["http-server"]
  source_ranges = ["0.0.0.0/0"]
}

resource "random_id" "suffix" {
  byte_length = 4
}
