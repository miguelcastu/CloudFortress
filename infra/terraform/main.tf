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

# 1. Custom VPC
resource "google_compute_network" "lab" {
  name                    = "cloudfortress-vpc"
  auto_create_subnetworks = false
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
}

# 4. Private Cloud Run application
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
}