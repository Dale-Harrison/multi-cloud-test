terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "multi-cloud-terraform-state-gcp-dh"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "websitehosting-403318"
  region  = "us-central1"
}

# 1. Enable Services (Optional, best practice to ensure they are on)
# Enabled services handled via Cloud Build step to avoid Terraform permission issues
# resource "google_project_service" "enabled_services" {
#   for_each = toset([
#     "run.googleapis.com",
#     "artifactregistry.googleapis.com",
#     "pubsub.googleapis.com",
#     "compute.googleapis.com"
#   ])
#   service            = each.key
#   disable_on_destroy = false
# }

resource "google_pubsub_topic" "hello_topic" {
  name = "hello-topic"
}

resource "google_pubsub_subscription" "hello_sub" {
  name  = "hello-sub"
  topic = google_pubsub_topic.hello_topic.name
}

# Consolidating to v2 API for both services

resource "google_project_service_identity" "pubsub_agent" {
  provider = google-beta
  project  = "websitehosting-403318" # Assuming var.project_id is websitehosting-403318
  service  = "pubsub.googleapis.com"
}

resource "google_pubsub_topic_iam_binding" "binding" {
  project = "websitehosting-403318" # Assuming var.project_id is websitehosting-403318
  topic   = google_pubsub_topic.hello_topic.name
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${google_project_service_identity.pubsub_agent.email}",
    "serviceAccount:619003853605-compute@developer.gserviceaccount.com",
  ]
}

resource "google_pubsub_subscription_iam_binding" "subscription_binding" {
  project      = "websitehosting-403318" # Assuming var.project_id is websitehosting-403318
  subscription = google_pubsub_subscription.hello_sub.name
  role         = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:619003853605-compute@developer.gserviceaccount.com",
  ]
}

# Using hardcoded default compute service account to avoid data source permission errors in Cloud Build

# 2. Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = "us-central1"
  repository_id = "cloud-run-source-deploy"
  format        = "DOCKER"
}

# 3. Cloud Run Service
resource "google_cloud_run_v2_service" "default" {
  name     = "spring-boot-hello"
  location = "us-central1"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "us-central1-docker.pkg.dev/websitehosting-403318/cloud-run-source-deploy/spring-boot-hello@sha256:b932df9733f8d6dfe81bcaeb6dcb7b1e8189f0a17011ff878491bf68015a9f13" # Updated to current live image
      ports {
        container_port = 8080
      }
    }
    scaling {
      max_instance_count = 1
    }
  }
}

resource "google_cloud_run_v2_service" "worker" {
  name     = "spring-boot-worker"
  location = "us-central1"
  ingress  = "INGRESS_TRAFFIC_ALL" # Allow all for verification, can be restricted later

  template {
    containers {
      image = "us-central1-docker.pkg.dev/websitehosting-403318/cloud-run-source-deploy/spring-boot-worker:latest"
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "gcp"
      }
      ports {
        container_port = 8080
      }
    }
    scaling {
      max_instance_count = 1
    }
  }
}

# 4. Public Access (IAM)
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.default.location
  project  = google_cloud_run_v2_service.default.project
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
