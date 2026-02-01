variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP region"
}

variable "compute_service_account" {
  type        = string
  description = "The email of the compute service account"
}
