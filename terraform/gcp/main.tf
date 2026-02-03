terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "multi-cloud-terraform-state-gcp-dh"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
 
variable "commit_sha" {
  type    = string
  default = "latest"
}

# Imports removed because variables are not supported in import blocks.
# Use 'terraform import' manually if these resources already exist in state.

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
  project = var.project_id
  topic   = google_pubsub_topic.hello_topic.name
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${google_project_service_identity.pubsub_agent.email}",
    "serviceAccount:${var.compute_service_account}",
  ]
}

resource "google_pubsub_subscription_iam_binding" "subscription_binding" {
  project      = var.project_id
  subscription = google_pubsub_subscription.hello_sub.name
  role         = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:${var.compute_service_account}",
  ]
}

# Using hardcoded default compute service account to avoid data source permission errors in Cloud Build

# 2. Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "cloud-run-source-deploy"
  format        = "DOCKER"
}

# Import removed

# 3. Cloud Run Service
resource "google_cloud_run_v2_service" "default" {
  name     = "spring-boot-hello"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/spring-boot-hello:latest"
      ports {
        container_port = 8080
      }
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "gcp"
      }
      env {
        name  = "COMMIT_SHA"
        value = var.commit_sha
      }
    }
    scaling {
      max_instance_count = 1
    }
  }
}

resource "google_cloud_run_v2_service" "worker" {
  name     = "spring-boot-worker"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL" # Allow all for verification, can be restricted later

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/spring-boot-worker:latest"
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "gcp"
      }
      env {
        name  = "COMMIT_SHA"
        value = var.commit_sha
      }
      ports {
        container_port = 8080
      }
      resources {
        cpu_idle = false
      }
      startup_probe {
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 20
        tcp_socket {
          port = 8080
        }
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

# 5. API Gateway
resource "google_api_gateway_api" "hello_api" {
  provider = google-beta
  api_id   = "spring-boot-hello-api"
}

resource "google_api_gateway_api_config" "api_cfg" {
  provider      = google-beta
  api           = google_api_gateway_api.hello_api.api_id
  api_config_id = "v1"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/openapi.yaml.tftpl", {
        backend_url = google_cloud_run_v2_service.default.uri
      }))
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "gw" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.api_cfg.id
  gateway_id = "hello-gateway"
  region     = var.region
}

output "api_gateway_url" {
  value = "https://${google_api_gateway_gateway.gw.default_hostname}"
}
