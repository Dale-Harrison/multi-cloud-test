---
description: Deploy Infrastructure via CI/CD Pipelines
---

# Deploy Infrastructure

> [!IMPORTANT]
> **NEVER** run `terraform apply` locally. All infrastructure changes must be deployed via the CI/CD pipelines.

## AWS Deployment
1. Commit and push your changes to the `main` branch.
   ```bash
   git add .
   git commit -m "Update infrastructure"
   git push
   ```
2. Trigger the AWS CodeBuild project.
   ```bash
   aws codebuild start-build --project-name awsmulticloud
   ```
3. Monitor the build status.
   ```bash
   aws codebuild batch-get-builds --ids <build-id>
   ```

## GCP Deployment
1. Commit and push your changes to the `main` branch.
2. Trigger the Cloud Build trigger (if configured) or submit a build manually.
   ```bash
   gcloud builds submit --config terraform/gcp/cloudbuild.yaml .
   ```
