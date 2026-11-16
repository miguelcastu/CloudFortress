output "vpc_name" {
  description = "Name of the custom VPC"
  value       = google_compute_network.lab.name
}

output "subnet_name" {
  description = "Name of the private subnet"
  value       = google_compute_subnetwork.private.name
}

output "service_url" {
  description = "Authenticated Cloud Run service URL (Internet ingress allowed)"
  value       = google_cloud_run_v2_service.app.uri
}

output "service_account" {
  description = "Application service identity"
  value       = google_service_account.app.email
}

output "active_phase" {
  value       = var.lab_phase
  description = "Currently selected lab phase."
}

output "phase2" {
  description = "IAP SSH resources; null unless phase 2 is selected."
  value = local.phase2 ? {
    vm_name  = google_compute_instance.ssh_vm[0].name
    zone     = local.zone
    firewall = google_compute_firewall.iap_ssh[0].name
  } : null
}

output "phase3" {
  description = "Private HTTP test resources; null unless phase 3 is selected."
  value = local.phase3 ? {
    vm_name    = google_compute_instance.http_vm[0].name
    zone       = local.zone
    private_ip = google_compute_instance.http_vm[0].network_interface[0].network_ip
    job_name   = google_cloud_run_v2_job.network_probe[0].name
    firewall   = google_compute_firewall.private_http[0].name
  } : null
}

output "phase4" {
  description = "IAM test resources; null unless phase 4 is selected."
  value = local.phase4 ? {
    allowed_bucket    = google_storage_bucket.iam_lab["allowed"].name
    restricted_bucket = google_storage_bucket.iam_lab["restricted"].name
    service_account   = google_service_account.storage_probe[0].email
    job_name          = google_cloud_run_v2_job.storage_probe[0].name
    read_enabled      = var.phase4_allow_read
  } : null
}
