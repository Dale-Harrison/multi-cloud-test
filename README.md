# Multi-Cloud Spring Boot Messaging

This project demonstrates a resilient, cross-cloud messaging architecture using Spring Boot, AWS (SQS/ECS), and GCP (Pub/Sub/Cloud Run). It features automated CI/CD pipelines and Infrastructure as Code (Terraform) to maintain consistent deployments across both platforms.

## Architecture Overview

The system consists of a "Hello" publisher service and a "Worker" consumer service operating in parallel on both AWS and GCP.

```mermaid
graph TD
    subgraph "GCP Environment (Cloud Run)"
        GCP_Hello["spring-boot-hello (Publisher)"]
        GCP_PubSub["GCP Pub/Sub (hello-topic)"]
        GCP_Worker["spring-boot-worker (Consumer)"]
        GCP_Logs["Cloud Logging"]
        
        GCP_Hello -- "Publish Message" --> GCP_PubSub
        GCP_PubSub -- "Pull Message" --> GCP_Worker
        GCP_Hello -- "Logs" --> GCP_Logs
        GCP_Worker -- "Logs" --> GCP_Logs
    end

    subgraph "AWS Environment (ECS Fargate)"
        AWS_Hello["spring-boot-hello (Publisher)"]
        AWS_SQS["AWS SQS (hello-queue)"]
        AWS_Worker["spring-boot-worker (Consumer)"]
        AWS_Logs["CloudWatch Logs"]
        
        AWS_Hello -- "Send Message" --> AWS_SQS
        AWS_SQS -- "Listen" --> AWS_Worker
        AWS_Hello -- "Logs" --> AWS_Logs
        AWS_Worker -- "Logs" --> AWS_Logs
    end

    User((User)) -- "HTTP Request" --> GCP_Hello
    User -- "HTTP Request" --> AWS_Hello

    subgraph "CI/CD & Management"
        TF["Terraform (Infrastructure as Code)"]
        CB_GCP["GCP Cloud Build"]
        CB_AWS["AWS CodeBuild"]
        
        TF -- "Manage Resources" --> GCP_Hello & GCP_Worker & AWS_Hello & AWS_Worker
        CB_GCP -- "Deploy" --> GCP_Hello & GCP_Worker
        CB_AWS -- "Deploy" --> AWS_Hello & AWS_Worker
    end
```

## Key Features

-   **Multi-Cloud Messaging**: Implements `MessagePublisher` and `MessageConsumer` interfaces for both AWS SQS and GCP Pub/Sub using Spring Profiles (`aws`, `gcp`).
-   **Infrastructure as Code**: Full environment setup using Terraform, including VPCs, IAM roles, ECS Cluster, and Cloud Run services.
-   **Automated CI/CD**: 
    -   **AWS**: Uses CodeBuild with `buildspec.yml` to build Docker images and apply Terraform.
    -   **GCP**: Uses Cloud Build with `cloudbuild.yaml` for automated container deployments.
-   **Resiliency**: 
    -   GCP Workers use "Always Allocated CPU" to minimize message processing latency.
    -   AWS services use deployment circuit breakers for safe rollouts.
    -   `COMMIT_SHA` deployment logic ensures fresh code is always forced into production.

## Project Structure

-   `/spring-boot-hello`: The publisher service.
-   `/spring-boot-worker`: The consumer service.
-   `/terraform/aws`: AWS infrastructure and CodeBuild configuration.
-   `/terraform/gcp`: GCP infrastructure and Cloud Build configuration.

## Requirements

-   Java 17+
-   Terraform
-   AWS CLI (configured with appropriate profile)
-   Google Cloud SDK (configured with appropriate project)

## Local Development

Each service can be run locally by activating the relevant spring profile:

```bash
# Run with AWS SQS (requires local AWS credentials)
./mvnw spring-boot:run -Dspring-boot.run.profiles=aws

# Run with GCP Pub/Sub (requires local Google Application Credentials)
./mvnw spring-boot:run -Dspring-boot.run.profiles=gcp
```

## Deployment

Deployments are triggered automatically via Git push to the `main` branch, which initiates the respective cloud build pipelines.
