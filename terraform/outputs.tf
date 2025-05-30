output "cloudsql_ip" {
  value = module.cloudsql.private_ip
}

output "backend_internal_ip" {
  value = module.gke.backend_internal_ip
}

output "frontend_vm_ip" {
  value = google_compute_instance.frontend_vm.network_interface[0].access_config[0].nat_ip
}

