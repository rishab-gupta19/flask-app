output "backend_internal_ip" {
  value = kubernetes_service.backend_service.status[0].load_balancer[0].ingress[0].ip
}

