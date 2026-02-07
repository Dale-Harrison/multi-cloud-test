# Architecture Diagram

This document describes the multi-cloud architecture of the Spring Boot application, featuring high-availability edge layers and automated message processing.

## High-Level Overview

The application is deployed across both **AWS** and **GCP**, utilizing managed services for container orchestration, load balancing, and messaging.

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
    end

    subgraph "GCP (us-central1)"
        GCLB[External HTTP Load Balancer]
        APIGW_GCP[Cloud API Gateway]
        Hello_GCP[Cloud Run: spring-boot-hello]
        PubSub[GCP Pub/Sub: hello-topic]
        Worker_GCP[Cloud Run: spring-boot-worker]
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
    SQS --> Worker_AWS
    Worker_AWS --> REPLAY

    %% GCP Flow
    GCLB --> APIGW_GCP
    APIGW_GCP --> Hello_GCP
    Hello_GCP -. Validate JWT .-> Auth0
    Hello_GCP --> PubSub
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
    
    style GCLB fill:#4285F4,stroke:#34A853,color:#fff
    style APIGW_GCP fill:#4285F4,stroke:#34A853,color:#fff
    style Hello_GCP fill:#4285F4,stroke:#34A853,color:#fff
    style Worker_GCP fill:#4285F4,stroke:#34A853,color:#fff
```

## Component Details

## Security & Authentication

Access to the application is secured using **OAuth2 / OIDC** with **Auth0** as the identity provider.

-   **Authentication**: Users authenticate against Auth0 and receive a JWT.
-   **Authorization**: The JWT is passed in the `Authorization` header (Bearer token) to the application.
-   **Validation**: Each service (`spring-boot-hello`) validates the JWT signature against Auth0's JWKS endpoint.

### Edge Layers
- **AWS CloudFront**: Provides a global CDN and edge termination. Configured with a dedicated ALB backend to ensure stable routing to ECS.
- **GCP External HTTP LB**: Provides a stable global IP address and integrates with Google's edge network. Utilizes a Serverless NEG to target the Cloud API Gateway.

### API Gateways
- **AWS API Gateway**: Acts as the front door for the AWS VPC, proxying requests to the ALB.
- **GCP Cloud Gateway**: Manages API authentication and routing using an OpenAPI 2.0 definition, forwarding requests to Cloud Run.

### Compute & Messaging
- **spring-boot-hello**: The front-end service that accepts HTTP requests and publishes messages to the respective cloud messaging queues.
- **spring-boot-worker**: The back-end processor that consumes messages and performs asynchronous tasks. Now integrated with a central replay service.
- **SQS / PubSub**: Durable message brokers ensuring reliable communication between services.
- **AWS SQS Replay Queue**: A centralized archive that captures a copy of all messages processed by workers in both AWS and GCP.
