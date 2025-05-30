output "cloudsql_ip" {
  value = module.cloudsql.private_ip
}

output "frontend_vm_external_ip" {
  description = "The external IP address of the frontend VM."
  value       = google_compute_instance.frontend_vm.network_interface[0].access_config[0].nat_ip
}

output "gke_backend_ip_used" {
  description = "The GKE backend internal IP address used for Nginx proxying."
  value       = module.gke.backend_internal_ip
}
