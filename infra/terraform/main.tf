terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  phase2 = var.lab_phase == 2
  phase3 = var.lab_phase == 3
  phase4 = var.lab_phase == 4
  zone   = coalesce(var.zone, "${var.region}-b")
}

# API activation is retained on destroy so other workloads are not disrupted.
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "oslogin.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# 1. Custom VPC
resource "google_compute_network" "lab" {
  name                    = "cloudfortress-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

# 2. Private subnet
resource "google_compute_subnetwork" "private" {
  name                     = "cloudfortress-subnet"
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = "10.10.10.0/24"
  private_ip_google_access = true
}

# 3. Dedicated application identity
resource "google_service_account" "app" {
  account_id   = "cloudfortress-app"
  display_name = "CloudFortress Runtime Identity"

  depends_on = [google_project_service.apis]
}

# 4. Authenticated Cloud Run application (Internet ingress is allowed)
resource "google_cloud_run_v2_service" "app" {
  name                = "cloudfortress-hello"
  location            = var.region
  deletion_protection = false

  # Network endpoint is reachable, but IAM auth is required.
  ingress = "INGRESS_TRAFFIC_ALL"

  scaling {
    min_instance_count = 0
    max_instance_count = 1
  }

  template {
    service_account = google_service_account.app.email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }

  depends_on = [google_project_service.apis]
}
