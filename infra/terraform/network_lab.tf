resource "google_service_account" "ssh_vm" {
  count        = local.phase2 ? 1 : 0
  account_id   = "cloudfortress-ssh-vm"
  display_name = "CloudFortress phase 2 VM (no application roles)"
  depends_on   = [google_project_service.apis]
}

resource "google_compute_instance" "ssh_vm" {
  count        = local.phase2 ? 1 : 0
  name         = "cloudfortress-ssh-vm"
  zone         = local.zone
  machine_type = var.vm_machine_type

  boot_disk {
    initialize_params {
      image = var.debian_image
      size  = 10
      type  = "pd-standard"
    }
  }

  # Deliberately no access_config: this VM has no external IP.
  network_interface {
    subnetwork = google_compute_subnetwork.private.id
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  service_account {
    email  = google_service_account.ssh_vm[0].email
    scopes = []
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    precondition {
      condition     = var.operator_member != null
      error_message = "Phase 2 requires operator_member=user:YOUR_EMAIL (or group:EMAIL)."
    }
    precondition {
      condition     = startswith(local.zone, "${var.region}-")
      error_message = "zone must belong to region."
    }
  }
}

resource "google_compute_firewall" "iap_ssh" {
  count                   = local.phase2 ? 1 : 0
  name                    = "cloudfortress-iap-ssh"
  network                 = google_compute_network.lab.id
  direction               = "INGRESS"
  priority                = 1000
  source_ranges           = ["35.235.240.0/20"]
  target_service_accounts = [google_service_account.ssh_vm[0].email]
  disabled                = !var.phase2_iap_ssh_enabled

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Additive, resource-scoped bindings: do not replace existing IAM policies.
resource "google_compute_instance_iam_member" "os_login" {
  count         = local.phase2 && var.operator_member != null ? 1 : 0
  project       = var.project_id
  zone          = local.zone
  instance_name = google_compute_instance.ssh_vm[0].name
  role          = "roles/compute.osLogin"
  member        = var.operator_member
}

resource "google_iap_tunnel_instance_iam_member" "ssh" {
  count    = local.phase2 && var.operator_member != null ? 1 : 0
  project  = var.project_id
  zone     = local.zone
  instance = google_compute_instance.ssh_vm[0].name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = var.operator_member

  condition {
    title      = "ssh-port-only"
    expression = "destination.port == 22"
  }
}

resource "google_service_account_iam_member" "ssh_act_as" {
  count              = local.phase2 && var.operator_member != null ? 1 : 0
  service_account_id = google_service_account.ssh_vm[0].name
  role               = "roles/iam.serviceAccountUser"
  member             = var.operator_member
}

# gcloud SSH discovery needs project-level read permissions even when OS Login
# and IAP are restricted to a single VM. No create/update permissions or sudo.
resource "google_project_iam_custom_role" "ssh_discovery" {
  count       = local.phase2 ? 1 : 0
  project     = var.project_id
  role_id     = "cloudfortressSshDiscovery"
  title       = "CloudFortress SSH discovery"
  permissions = ["compute.instances.get", "compute.instances.list", "compute.projects.get"]
}

resource "google_project_iam_member" "ssh_discovery" {
  count   = local.phase2 && var.operator_member != null ? 1 : 0
  project = var.project_id
  role    = google_project_iam_custom_role.ssh_discovery[0].name
  member  = var.operator_member
}
