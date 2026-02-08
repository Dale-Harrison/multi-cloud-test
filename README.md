# Multi-Cloud Spring Boot Messaging

This project demonstrates a resilient, cross-cloud messaging architecture using Spring Boot, AWS (SQS/ECS), and GCP (Pub/Sub/Cloud Run). It features automated CI/CD pipelines and Infrastructure as Code (Terraform) to maintain consistent deployments across both platforms.

## Architecture Overview

The system consists of a "Hello" publisher service and a "Worker" consumer service operating in parallel on both AWS and GCP.

```mermaid
graph TD
    subgraph "Identity Provider"
        Auth0[Auth0]
    end

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
        DynamoDB[(AWS DynamoDB: payments, balances)]
    end

    subgraph "GCP (us-central1)"
        GCLB[External HTTP Load Balancer]
        APIGW_GCP[Cloud API Gateway]
        Hello_GCP[Cloud Run: spring-boot-hello]
        PubSub[GCP Pub/Sub: hello-topic]
        Worker_GCP[Cloud Run: spring-boot-worker]
        Firestore[(GCP Firestore: payments, balances)]
    end

    %% Auth Flow
    User -- 1. Login --> Auth0
    Auth0 -- 2. JWT --> User
    User -- 3. Request + JWT --> CF
    User -- 3. Request + JWT --> GCLB

    %% AWS Flow
    CF --> APIGW_AWS
    APIGW_AWS --> ALB
    ALB --> Hello_AWS
    Hello_AWS -. Validate JWT .-> Auth0
    Hello_AWS --> SQS
    Hello_AWS --> DynamoDB
    SQS --> Worker_AWS
    Worker_AWS --> REPLAY

    %% GCP Flow
    GCLB --> APIGW_GCP
    APIGW_GCP --> Hello_GCP
    Hello_GCP -. Validate JWT .-> Auth0
    Hello_GCP --> PubSub
    Hello_GCP --> Firestore
    Hello_GCP -- Replication (Cross-Cloud) --> DynamoDB
    PubSub --> Worker_GCP
    Worker_GCP --> REPLAY

    %% Styling
    style Auth0 fill:#EB5424,stroke:#333,color:#fff
    style CF fill:#ff9900,stroke:#232f3e,color:#fff
    style APIGW_AWS fill:#ff9900,stroke:#232f3e,color:#fff
    style ALB fill:#ff9900,stroke:#232f3e,color:#fff
    style Hello_AWS fill:#ff9900,stroke:#232f3e,color:#fff
    style Worker_AWS fill:#ff9900,stroke:#232f3e,color:#fff
    style REPLAY fill:#ff9900,stroke:#232f3e,color:#fff
    style DynamoDB fill:#ff9900,stroke:#232f3e,color:#fff
    
    style GCLB fill:#4285F4,stroke:#34A853,color:#fff
    style APIGW_GCP fill:#4285F4,stroke:#34A853,color:#fff
    style Hello_GCP fill:#4285F4,stroke:#34A853,color:#fff
    style Worker_GCP fill:#4285F4,stroke:#34A853,color:#fff
    style Firestore fill:#4285F4,stroke:#34A853,color:#fff
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
    -   AWS services use deployment circuit breakers for safe rollouts.
    -   `COMMIT_SHA` deployment logic ensures fresh code is always forced into production.
-   **Secure Identity**:
    -   Integrated with **Auth0** for OAuth2/OIDC authentication.
    -   Services validate JWT tokens against Auth0 JWKS.
-   **Cross-Cloud Replication**:
    -   Payments processed on GCP are continuously replicated to AWS DynamoDB to ensure data durability.

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
