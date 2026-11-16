locals {
  phase4_buckets = local.phase4 ? toset(["allowed", "restricted"]) : toset([])
}

resource "google_storage_bucket" "iam_lab" {
  for_each                    = local.phase4_buckets
  name                        = "${var.project_id}-cf-${each.key}-${var.bucket_name_suffix}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  storage_class               = "STANDARD"

  # Prevent soft-delete retention from keeping lab data after cleanup.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  depends_on = [google_project_service.apis]
}

# Known objects distinguish authorization failures from missing-object errors.
resource "google_storage_bucket_object" "fixture" {
  for_each     = local.phase4_buckets
  bucket       = google_storage_bucket.iam_lab[each.key].name
  name         = "health.txt"
  content      = "CloudFortress IAM lab fixture\n"
  content_type = "text/plain"
}

resource "google_service_account" "storage_probe" {
  count        = local.phase4 ? 1 : 0
  account_id   = "cloudfortress-storage-probe"
  display_name = "CloudFortress bucket reader (one bucket only)"
  depends_on   = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "allowed_reader" {
  count  = local.phase4 && var.phase4_allow_read ? 1 : 0
  bucket = google_storage_bucket.iam_lab["allowed"].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.storage_probe[0].email}"
}

resource "google_cloud_run_v2_job" "storage_probe" {
  count               = local.phase4 ? 1 : 0
  name                = "cloudfortress-storage-probe"
  location            = var.region
  deletion_protection = false

  template {
    task_count  = 1
    parallelism = 1
    template {
      service_account = google_service_account.storage_probe[0].email
      max_retries     = 0
      timeout         = "180s"
      containers {
        image   = var.python_container_image
        command = ["python3"]
        args    = ["-u", "-c", file("${path.module}/scripts/storage_probe.py")]
        env {
          name  = "ALLOWED_BUCKET"
          value = google_storage_bucket.iam_lab["allowed"].name
        }
        env {
          name  = "RESTRICTED_BUCKET"
          value = google_storage_bucket.iam_lab["restricted"].name
        }
        env {
          name  = "EXPECTED_ALLOWED_STATUS"
          value = var.phase4_allow_read ? "200" : "403"
        }
        resources {
          limits = { cpu = "1", memory = "512Mi" }
        }
      }
    }
  }

  depends_on = [google_project_service.apis, google_storage_bucket_object.fixture, google_storage_bucket_iam_member.allowed_reader]
}
