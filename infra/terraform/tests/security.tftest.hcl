# All runs use a mock provider and plan only: no credentials or cloud writes.
mock_provider "google" {}

variables {
  project_id      = "cloudfortress-test"
  operator_member = "user:operator@example.com"
}

run "baseline" {
  command = plan
  assert {
    condition     = length(google_compute_instance.ssh_vm) == 0 && length(google_compute_instance.http_vm) == 0 && length(google_storage_bucket.iam_lab) == 0
    error_message = "The default phase must not create extra VMs or buckets."
  }
  assert {
    condition     = alltrue([for api in google_project_service.apis : api.disable_on_destroy == false])
    error_message = "Destroy must not disable project APIs."
  }
}

run "secure_ssh" {
  command = plan
  variables { lab_phase = 2 }
  assert {
    condition     = length(google_compute_instance.ssh_vm[0].network_interface[0].access_config) == 0 && google_compute_instance.ssh_vm[0].metadata["enable-oslogin"] == "TRUE"
    error_message = "SSH VM must have OS Login and no public IP."
  }
  assert {
    condition     = google_compute_firewall.iap_ssh[0].source_ranges == toset(["35.235.240.0/20"]) && one(google_compute_firewall.iap_ssh[0].allow).ports == tolist(["22"])
    error_message = "Only IAP TCP/22 may reach the SSH VM."
  }
  assert {
    condition     = google_compute_instance_iam_member.os_login[0].role == "roles/compute.osLogin" && google_iap_tunnel_instance_iam_member.ssh[0].condition[0].expression == "destination.port == 22"
    error_message = "Operator access must exclude sudo and restrict the IAP port."
  }
  assert {
    condition     = length(google_compute_instance.http_vm) == 0 && length(google_cloud_run_v2_job.storage_probe) == 0
    error_message = "Phase 2 must not create other phase workloads."
  }
}

run "ssh_blocked" {
  command = plan
  variables {
    lab_phase              = 2
    phase2_iap_ssh_enabled = false
  }
  assert {
    condition     = google_compute_firewall.iap_ssh[0].disabled
    error_message = "The negative SSH test must disable the firewall rule."
  }
}

run "ssh_requires_operator" {
  command = plan
  variables {
    lab_phase       = 2
    operator_member = null
  }
  expect_failures = [google_compute_instance.ssh_vm[0]]
}

run "private_http" {
  command = plan
  variables { lab_phase = 3 }
  assert {
    condition     = google_compute_subnetwork.run[0].ip_cidr_range == "10.10.20.0/26" && length(google_compute_instance.http_vm[0].network_interface[0].access_config) == 0
    error_message = "HTTP VM must remain private and Cloud Run must have its own /26 subnet."
  }
  assert {
    condition     = google_compute_firewall.private_http[0].source_ranges == toset(["10.10.20.0/26"]) && one(google_compute_firewall.private_http[0].allow).ports == tolist(["8080"])
    error_message = "Only the Cloud Run subnet may reach TCP/8080."
  }
  assert {
    condition     = google_cloud_run_v2_job.network_probe[0].template[0].template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY" && length(google_cloud_run_v2_job.network_probe[0].template[0].template[0].vpc_access[0].network_interfaces) == 1
    error_message = "Use Direct VPC egress rather than a connector."
  }
}

run "http_blocked" {
  command = plan
  variables {
    lab_phase           = 3
    phase3_http_enabled = false
  }
  assert {
    condition     = google_compute_firewall.private_http[0].disabled
    error_message = "The negative HTTP test must disable its rule."
  }
}

run "bucket_scope" {
  command = plan
  variables { lab_phase = 4 }
  assert {
    condition     = length(google_storage_bucket.iam_lab) == 2 && alltrue([for bucket in google_storage_bucket.iam_lab : bucket.public_access_prevention == "enforced" && bucket.uniform_bucket_level_access && !bucket.force_destroy])
    error_message = "Both buckets must be private and preserve unexpected user data."
  }
  assert {
    condition     = length(google_storage_bucket_iam_member.allowed_reader) == 1 && google_storage_bucket_iam_member.allowed_reader[0].bucket == google_storage_bucket.iam_lab["allowed"].name && google_storage_bucket_iam_member.allowed_reader[0].role == "roles/storage.objectViewer" && length(google_project_iam_member.ssh_discovery) == 0
    error_message = "The application must receive objectViewer on the allowed bucket only, with no project IAM grant."
  }
  assert {
    condition     = length(google_storage_bucket_object.fixture) == 2 && length(google_compute_instance.http_vm) == 0
    error_message = "Both buckets need real test objects, and phase 4 must not create a VM."
  }
}

run "reader_revoked" {
  command = plan
  variables {
    lab_phase         = 4
    phase4_allow_read = false
  }
  assert {
    condition     = length(google_storage_bucket_iam_member.allowed_reader) == 0
    error_message = "Revoking access must remove the bucket binding."
  }
  assert {
    condition     = one([for env in google_cloud_run_v2_job.storage_probe[0].template[0].template[0].containers[0].env : env.value if env.name == "EXPECTED_ALLOWED_STATUS"]) == "403"
    error_message = "The revoked test must expect 403 for the previously allowed bucket."
  }
}

run "invalid_phase" {
  command = plan
  variables { lab_phase = 5 }
  expect_failures = [var.lab_phase]
}

run "zone_must_match_region" {
  command = plan
  variables {
    lab_phase = 3
    zone      = "us-central1-a"
  }
  expect_failures = [google_compute_instance.http_vm[0]]
}
