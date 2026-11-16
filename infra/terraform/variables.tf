variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Region for cloud resources"
  type        = string
  default     = "europe-west1"
}

variable "lab_phase" {
  description = "Active lab: 1 = baseline, 2 = IAP SSH, 3 = private HTTP, 4 = bucket IAM. Only one phase is active at a time."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2, 3, 4], var.lab_phase)
    error_message = "lab_phase must be 1, 2, 3 or 4."
  }
}

variable "zone" {
  description = "Compute Engine zone in region; defaults to REGION-b."
  type        = string
  default     = null
}

variable "vm_machine_type" {
  description = "Machine type for the active lab VM."
  type        = string
  default     = "e2-micro"
}

variable "debian_image" {
  description = "Debian image with Python 3 preinstalled for phase 3; no Internet package installation is performed."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "operator_member" {
  description = "Phase 2 SSH operator, e.g. user:alice@example.com. Separate from the Terraform deployer identity."
  type        = string
  default     = null

  validation {
    condition     = var.operator_member == null ? true : can(regex("^(user|group):[^[:space:]]+@[^[:space:]]+$", var.operator_member))
    error_message = "Use user:EMAIL or group:EMAIL for operator_member."
  }
}

variable "phase2_iap_ssh_enabled" {
  description = "Temporarily disable only the phase 2 IAP SSH firewall rule for the negative test."
  type        = bool
  default     = true
}

variable "phase3_http_enabled" {
  description = "Temporarily disable only the phase 3 private HTTP firewall rule for the negative test."
  type        = bool
  default     = true
}

variable "phase4_allow_read" {
  description = "Grant/revoke the application objectViewer binding on the allowed bucket."
  type        = bool
  default     = true
}

variable "bucket_name_suffix" {
  description = "Suffix to resolve global bucket name collisions; keep the same value until destroy."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.bucket_name_suffix))
    error_message = "Use 1 to 10 lowercase letters or digits."
  }
}

variable "python_container_image" {
  description = "Python runtime for lab jobs. Set an approved immutable digest for reproducible deployments."
  type        = string
  default     = "docker.io/library/python:3.12-slim"
}
