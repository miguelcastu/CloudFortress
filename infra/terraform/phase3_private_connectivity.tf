resource "google_compute_subnetwork" "run" {
  count                    = local.phase3 ? 1 : 0
  name                     = "cloudfortress-run-subnet"
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = "10.10.20.0/26"
  private_ip_google_access = true
}

resource "google_service_account" "http_vm" {
  count        = local.phase3 ? 1 : 0
  account_id   = "cloudfortress-http-vm"
  display_name = "CloudFortress phase 3 HTTP VM (no application roles)"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "network_probe" {
  count        = local.phase3 ? 1 : 0
  account_id   = "cloudfortress-network-probe"
  display_name = "CloudFortress phase 3 job (no application roles)"
  depends_on   = [google_project_service.apis]
}

resource "google_compute_instance" "http_vm" {
  count        = local.phase3 ? 1 : 0
  name         = "cloudfortress-http-vm"
  zone         = local.zone
  machine_type = var.vm_machine_type

  boot_disk {
    initialize_params {
      image = var.debian_image
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/templates/http-startup.sh.tftpl", {
    server_base64 = filebase64("${path.module}/scripts/health_server.py")
  })

  service_account {
    email  = google_service_account.http_vm[0].email
    scopes = []
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    precondition {
      condition     = startswith(local.zone, "${var.region}-")
      error_message = "zone must belong to region."
    }
  }
}

resource "google_compute_firewall" "private_http" {
  count                   = local.phase3 ? 1 : 0
  name                    = "cloudfortress-private-http"
  network                 = google_compute_network.lab.id
  direction               = "INGRESS"
  priority                = 1000
  source_ranges           = [google_compute_subnetwork.run[0].ip_cidr_range]
  target_service_accounts = [google_service_account.http_vm[0].email]
  disabled                = !var.phase3_http_enabled

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_cloud_run_v2_job" "network_probe" {
  count               = local.phase3 ? 1 : 0
  name                = "cloudfortress-network-probe"
  location            = var.region
  deletion_protection = false

  template {
    task_count  = 1
    parallelism = 1
    template {
      service_account = google_service_account.network_probe[0].email
      max_retries     = 0
      timeout         = "300s"

      containers {
        image   = var.python_container_image
        command = ["python3"]
        args    = ["-u", "-c", file("${path.module}/scripts/network_probe.py")]
        env {
          name  = "HEALTH_URL"
          value = "http://${google_compute_instance.http_vm[0].network_interface[0].network_ip}:8080/health"
        }
        resources {
          limits = { cpu = "1", memory = "512Mi" }
        }
      }

      vpc_access {
        egress = "PRIVATE_RANGES_ONLY"
        network_interfaces {
          network    = google_compute_network.lab.name
          subnetwork = google_compute_subnetwork.run[0].name
        }
      }
    }
  }

  depends_on = [google_project_service.apis, google_compute_firewall.private_http]
}
