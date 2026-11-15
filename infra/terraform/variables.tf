variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Region for cloud resources"
  type        = string
  default     = "europe-west1"
}
