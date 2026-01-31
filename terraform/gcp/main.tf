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
resource "google_project_service" "enabled_services" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "compute.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

resource "google_pubsub_topic" "hello_topic" {
  name = "hello-topic"
}

resource "google_pubsub_subscription" "hello_sub" {
  name  = "hello-sub"
  topic = google_pubsub_topic.hello_topic.name
}

resource "google_cloud_run_service" "worker_service" {
  name     = "spring-boot-worker"
  location = "us-central1" # Assuming var.region is us-central1 for this context

  template {
    spec {
      containers {
        image = "gcr.io/websitehosting-403318/spring-boot-worker:latest" # Assuming var.project_id is websitehosting-403318
        env {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "gcp"
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

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
    "serviceAccount:${data.google_compute_default_service_account.default.email}",
  ]
}

resource "google_pubsub_subscription_iam_binding" "subscription_binding" {
  project      = "websitehosting-403318" # Assuming var.project_id is websitehosting-403318
  subscription = google_pubsub_subscription.hello_sub.name
  role         = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}",
  ]
}

data "google_compute_default_service_account" "default" {
}

# 2. Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = "us-central1"
  repository_id = "cloud-run-source-deploy"
  format        = "DOCKER"
  depends_on    = [google_project_service.enabled_services["artifactregistry.googleapis.com"]]
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
  depends_on = [google_project_service.enabled_services["run.googleapis.com"]]
}

resource "google_cloud_run_v2_service" "worker" {
  name     = "spring-boot-worker"
  location = "us-central1"
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    containers {
      image = "gcr.io/websitehosting-403318/spring-boot-worker:latest"
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "gcp"
      }
    }
    scaling {
      max_instance_count = 1
    }
  }
  depends_on = [google_project_service.enabled_services["run.googleapis.com"]]
}

# 4. Public Access (IAM)
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.default.location
  project  = google_cloud_run_v2_service.default.project
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
