terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "websitehosting-403318"
  region  = "us-central1"
}

# 1. Enable Services (Optional, best practice to ensure they are on)
resource "google_project_service" "run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry_api" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# 2. Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = "us-central1"
  repository_id = "cloud-run-source-deploy" # Managing the one created by CLI or a new one
  format        = "DOCKER"
  description   = "Docker repository for Spring Boot Hello World"

  depends_on = [google_project_service.artifact_registry_api]
}

# 3. Cloud Run Service
resource "google_cloud_run_v2_service" "default" {
  name     = "spring-boot-hello"
  location = "us-central1"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      max_instance_count = 1
    }

    containers {
      image = "us-central1-docker.pkg.dev/websitehosting-403318/cloud-run-source-deploy/spring-boot-hello@sha256:b932df9733f8d6dfe81bcaeb6dcb7b1e8189f0a17011ff878491bf68015a9f13" # Updated to current live image
      ports {
        container_port = 8080
      }
    }
  }

  depends_on = [google_project_service.run_api]
}

# 4. Public Access (IAM)
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.default.location
  project  = google_cloud_run_v2_service.default.project
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
