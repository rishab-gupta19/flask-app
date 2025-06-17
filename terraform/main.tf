resource "google_compute_network" "product_vpc" {
  name                    = "product-vpc-${random_id.suffix.hex}"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL" 
}

# --- Custom Subnetwork within the VPC ---
resource "google_compute_subnetwork" "product_subnet" {
  name          = "product-subnet-${random_id.suffix.hex}"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.product_vpc.id
  project       = var.project_id
  private_ip_google_access = true
}

resource "google_compute_global_address" "private_service_access_ip_range" {
  name          = "google-managed-services-ip-range-${random_id.suffix.hex}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.product_vpc.id
  project       = var.project_id
}


resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.product_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access_ip_range.name]
  depends_on = [
    google_compute_network.product_vpc,
    google_compute_global_address.private_service_access_ip_range
  ]
}

module "cloudsql" {
  source       = "./modules/cloudsql"
  project_id   = var.project_id
  region       = var.region
  db_name    = var.db_name
  db_user    = var.db_user
  vpc_network_link = google_compute_network.product_vpc.self_link
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

module "gke" {
  source              = "./modules/gke"
  project_id          = var.project_id
  region              = var.region
  cloudsql_dep        = module.cloudsql
  cloudsql_private_ip = module.cloudsql.private_ip
  cloudsql_secret_version_dep = module.cloudsql.db_password_secret_version_resource
  db_user             = module.cloudsql.username
  db_password         = module.cloudsql.db_password_secret_id
  db_name             = module.cloudsql.db_name
  backend_image       = "gcr.io/${var.project_id}/product-backend"
  zone                = var.zone
  vpc_network           = google_compute_network.product_vpc.self_link
  vpc_subnetwork        = google_compute_subnetwork.product_subnet.self_link
}

resource "google_compute_address" "frontend_static_ip" {
  name         = "frontend-vm-static-ip-${random_id.suffix.hex}"
  project      = var.project_id
  region       = var.region
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
    network    = google_compute_network.product_vpc.self_link
    subnetwork = google_compute_subnetwork.product_subnet.self_link

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
  network = google_compute_network.product_vpc.name
 
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Apply this rule to instances with the "http-server" tag
  target_tags = ["http-server"]
  source_ranges = ["0.0.0.0/0"] # Allow traffic on port 80
  depends_on = [
    google_compute_network.product_vpc
  ]
}

resource "random_id" "suffix" {
  byte_length = 4
}
