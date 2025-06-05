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

# Add the first version of the secret
# IMPORTANT: Replace "YOUR_CLOUD_SQL_DB_PASSWORD" with your actual strong password.
# Avoid hardcoding sensitive values directly in production;
# consider fetching from a secure CI/CD variable or an interactive prompt.
resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password 
}

# --- Data Source: Retrieve DB Password from Secret Manager for Cloud SQL ---
# This fetches the *value* of the secret from Secret Manager.
# We do this here in the root so we can pass the value to the cloudsql module.
data "google_secret_manager_secret_version" "db_password_cloudsql_fetch" {
  secret = google_secret_manager_secret.db_password.secret_id
  # You can specify a version number here if you need a specific one,
  # otherwise "latest" is the default.
  # version = "latest"
}


module "cloudsql" {
  source       = "./modules/cloudsql"
  db_password = data.google_secret_manager_secret_version.db_password_cloudsql_fetch.secret_data
  //db_password  = var.db_password
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

resource "google_compute_address" "frontend_static_ip" {
  name         = "frontend-vm-static-ip-${random_id.suffix.hex}"
  project      = var.project_id
  region       = var.region # Static external IPs are regional resources
  address_type = "EXTERNAL" 
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

  network_interface {
    network = "default" 

    access_config {
	nat_ip = google_compute_address.frontend_static_ip.address
    }
  }

  tags = ["http-server"]

  # Metadata startup script to install Docker and run the container
  metadata_startup_script = templatefile("${path.module}/startup_script.sh", {
    docker_image_name = "gcr.io/rishab-gupta-cwx-internal/product-frontend"
    gke_backend_ip    = module.gke.backend_internal_ip
  })

  # Service account with necessary permissions for pulling Docker images from GCR
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-frontend-vm"
  network = "default"
 
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
