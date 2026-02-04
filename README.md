# Multi-Cloud Spring Boot Messaging

This project demonstrates a resilient, cross-cloud messaging architecture using Spring Boot, AWS (SQS/ECS), and GCP (Pub/Sub/Cloud Run). It features automated CI/CD pipelines and Infrastructure as Code (Terraform) to maintain consistent deployments across both platforms.

## Architecture Overview

The system consists of a "Hello" publisher service and a "Worker" consumer service operating in parallel on both AWS and GCP.

```mermaid
graph TD
    subgraph "External Traffic"
        User((User/Client))
    end

    subgraph "AWS (eu-west-1 / us-east-1)"
        CF[CloudFront CDN]
        APIGW_AWS[API Gateway HTTP]
        ALB[Application Load Balancer]
        Hello_AWS[ECS Fargate: spring-boot-hello]
        SQS[AWS SQS: hello-queue]
        Worker_AWS[ECS Fargate: spring-boot-worker]
        REPLAY[AWS SQS: replay-queue]
    end

    subgraph "GCP (us-central1)"
        GCLB[External HTTP Load Balancer]
        APIGW_GCP[Cloud API Gateway]
        Hello_GCP[Cloud Run: spring-boot-hello]
        PubSub[GCP Pub/Sub: hello-topic]
        Worker_GCP[Cloud Run: spring-boot-worker]
    end

    %% AWS Flow
    User --> CF
    CF --> APIGW_AWS
    APIGW_AWS --> ALB
    ALB --> Hello_AWS
    Hello_AWS --> SQS
    SQS --> Worker_AWS
    Worker_AWS --> REPLAY

    %% GCP Flow
    User --> GCLB
    GCLB --> APIGW_GCP
    APIGW_GCP --> Hello_GCP
    Hello_GCP --> PubSub
    PubSub --> Worker_GCP
    Worker_GCP --> REPLAY

    %% Styling
    style CF fill:#ff9900,stroke:#232f3e,color:#fff
    style APIGW_AWS fill:#ff9900,stroke:#232f3e,color:#fff
    style ALB fill:#ff9900,stroke:#232f3e,color:#fff
    style Hello_AWS fill:#ff9900,stroke:#232f3e,color:#fff
    style Worker_AWS fill:#ff9900,stroke:#232f3e,color:#fff
    style REPLAY fill:#ff9900,stroke:#232f3e,color:#fff
    
    style GCLB fill:#4285F4,stroke:#34A853,color:#fff
    style APIGW_GCP fill:#4285F4,stroke:#34A853,color:#fff
    style Hello_GCP fill:#4285F4,stroke:#34A853,color:#fff
    style Worker_GCP fill:#4285F4,stroke:#34A853,color:#fff
```

### Edge & Load Balancing
- **AWS**: High-availability edge termination via **CloudFront** and a dedicated **Application Load Balancer (ALB)** for stable routing to Fargate.
- **GCP**: Global traffic management via an **External HTTP Load Balancer** with **Serverless NEG** targeting the API Gateway.

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
