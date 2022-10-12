
output "backend" {
  description = "The Backend Service resource created"
  value       = google_compute_backend_service.b
}

output "health" {
  description = "A 0- or 1-entry list of Health Check resource created"
  value       = google_compute_health_check.h
}

output "negs" {
  description = "A map from Compute Zone names to the NEG resource records"
  value       = data.google_compute_network_endpoint_group.neg
}

