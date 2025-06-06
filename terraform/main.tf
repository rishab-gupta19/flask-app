# variable "project_id" {
#   type        = string
#   description = "GCP Project ID"
# }

# variable "region" {
#   type        = string
#   default     = "us-central1"
# }

# variable "zone" {
#   description = "The GCP zone for the GKE cluster nodes and VM."
#   type        = string
# }

# provider "google" {
#   project = var.project_id
#   region  = var.region
# }

# variable "db_name" {
#   type        = string
#   default     = "product-sql-test"
#   description = "Name of the Cloud SQL database."
# }

# variable "db_user" {
#   type        = string
#   default     = "postgres_test"
#   description = "Username for the Cloud SQL database."
# }
provider "random" {
}

# # --- Random Password Generation ---
# # Generates a random, strong password for the database
# resource "random_password" "db_password_generated" {
#   length           = 32
#   special          = true
#   override_special = "!#$%&*()_+-=" # Define allowed special characters if needed
#   upper            = true
#   lower            = true
#   numeric          = true
#   min_upper        = 4
#   min_lower        = 4
#   min_numeric      = 4
#   min_special      = 4
#   keepers = {
#     secret_id_keeper = google_secret_manager_secret.db_password.secret_id
#   }
# }

# resource "google_secret_manager_secret" "db_password" {
#   secret_id = "cloudsql-db-password"
#   project   = var.project_id

#   replication {
#     auto {}
#   }

#   labels = {
#     env = "dev"
#   }
# }

# resource "google_secret_manager_secret_version" "db_password_version" {
#   secret      = google_secret_manager_secret.db_password.id
#   secret_data = random_password.db_password_generated.result 
# }
# data "google_secret_manager_secret_version" "db_password_cloudsql_fetch" {
#   secret = google_secret_manager_secret.db_password.secret_id
# }


module "cloudsql" {
  source       = "./modules/cloudsql"
  project_id   = var.project_id
  region       = var.region
  db_name    = var.db_name
  db_user    = var.db_user
}

module "gke" {
  source              = "./modules/gke"
  project_id          = var.project_id
  region              = var.region
  cloudsql_dep        = module.cloudsql
  cloudsql_private_ip = module.cloudsql.private_ip
  db_user             = module.cloudsql.username
  db_password         = module.cloudsql.db_password_secret_id
  db_name             = module.cloudsql.db_name
  backend_image       = "gcr.io/${var.project_id}/product-backend"
  zone                = var.zone
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

  metadata_startup_script = templatefile("${path.module}/startup_script.sh", {
    docker_image_name = "gcr.io/rishab-gupta-cwx-internal/product-frontend"
    gke_backend_ip    = module.gke.backend_internal_ip
  })

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