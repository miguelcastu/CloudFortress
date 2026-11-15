output "vpc_name" {
  description = "Name of the custom VPC"
  value       = google_compute_network.lab.name
}

output "subnet_name" {
  description = "Name of the private subnet"
  value       = google_compute_subnetwork.private.name
}

output "service_url" {
  description = "Private Cloud Run service URL"
  value       = google_cloud_run_v2_service.app.uri
}

output "service_account" {
  description = "Application service identity"
  value       = google_service_account.app.email
}