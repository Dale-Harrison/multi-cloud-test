terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "multi-cloud-terraform-state-dh"
    key            = "aws/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "multi-cloud-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
}

variable "commit_sha" {
  type    = string
  default = "latest"
}

# 1. Network Infrastructure (Required for Fargate)
resource "aws_vpc" "dr_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "spring-boot-dr-vpc"
  }
}

resource "aws_subnet" "dr_subnet" {
  vpc_id            = aws_vpc.dr_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "spring-boot-dr-subnet"
  }
}

resource "aws_subnet" "dr_subnet_2" {
  vpc_id            = aws_vpc.dr_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "spring-boot-dr-subnet-2"
  }
}

resource "aws_internet_gateway" "dr_igw" {
  vpc_id = aws_vpc.dr_vpc.id
}

resource "aws_route_table" "dr_rt" {
  vpc_id = aws_vpc.dr_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr_igw.id
  }
}

resource "aws_route_table_association" "dr_rta" {
  subnet_id      = aws_subnet.dr_subnet.id
  route_table_id = aws_route_table.dr_rt.id
}

resource "aws_route_table_association" "dr_rta_2" {
  subnet_id      = aws_subnet.dr_subnet_2.id
  route_table_id = aws_route_table.dr_rt.id
}

resource "aws_security_group" "dr_sg" {
  name        = "spring-boot-dr-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.dr_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name                 = "spring-boot-hello"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# 3. ECS Cluster
resource "aws_ecs_cluster" "dr_cluster" {
  name = "spring-boot-dr-cluster"
}

# 4. Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "spring-boot-hello-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "spring-boot-hello"
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "aws"
        },
        {
          name  = "COMMIT_SHA"
          value = var.commit_sha
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/aws/ecs/spring-boot-hello"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

# 5. IAM Role for ECS Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 7. Task Role (for application SQS access)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_sqs_policy" {
  name = "ecs_task_sqs_policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:*",
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_sqs_queue.hello_queue.arn,
          aws_sqs_queue.replay_queue.arn,
          aws_dynamodb_table.payments.arn,
          aws_dynamodb_table.user_balances.arn
        ]
      }
    ]
  })
}

# IAM User for GCP Worker to access SQS Replay Queue
resource "aws_iam_user" "gcp_worker" {
  name = "gcp-worker-sqs-user"
}

resource "aws_iam_access_key" "gcp_worker" {
  user = aws_iam_user.gcp_worker.name
}

resource "aws_iam_user_policy" "gcp_worker_sqs_policy" {
  name = "GCPWorkerSQSPolicy"
  user = aws_iam_user.gcp_worker.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.replay_queue.arn
        ]
      }
    ]
  })
}

resource "aws_lb" "hello_lb" {
  name               = "hello-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dr_sg.id]
  subnets            = [aws_subnet.dr_subnet.id, aws_subnet.dr_subnet_2.id]
}

resource "aws_lb_target_group" "hello_tg" {
  name        = "hello-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.dr_vpc.id
  target_type = "ip"

  health_check {
    path = "/actuator/health"
    port = "8080"
  }
}

resource "aws_lb_listener" "hello_listener" {
  load_balancer_arn = aws_lb.hello_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello_tg.arn
  }
}

# 6. ECS Service (Fargate)
resource "aws_ecs_service" "app_service" {
  name            = "spring-boot-hello-service"
  cluster         = aws_ecs_cluster.dr_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1 # Warm Standby
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hello_tg.arn
    container_name   = "spring-boot-hello"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  force_new_deployment = true


  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = [aws_subnet.dr_subnet.id, aws_subnet.dr_subnet_2.id]
    security_groups  = [aws_security_group.dr_sg.id]
    assign_public_ip = true
  }
}

# 8. API Gateway (HTTP)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "spring-boot-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# NOTE: In a production environment, you would use an Application Load Balancer (ALB)
# or a VPC Link with Cloud Map for stable service discovery.
# For this demonstration, we'll configure a placeholder integration.
resource "aws_apigatewayv2_integration" "app_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "http://${aws_lb.hello_lb.dns_name}/"

  request_parameters = {
    "overwrite:header.Host"              = "$request.header.Host"
    "append:header.X-Forwarded-Host"     = "$request.header.X-Forwarded-Host"
    "append:header.X-Forwarded-Proto"    = "$request.header.X-Forwarded-Proto"
    "append:header.X-Forwarded-Port"     = "$request.header.X-Forwarded-Port"
    "append:header.X-Forwarded-For"      = "$request.header.X-Forwarded-For"
  }
}

resource "aws_apigatewayv2_authorizer" "auth0" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "auth0-authorizer"

  jwt_configuration {
    audience = ["https://dev-dx0ii0p33yqw4z5c.us.auth0.com/api/v2/"]
    issuer   = "https://dev-dx0ii0p33yqw4z5c.us.auth0.com/"
  }
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.app_integration.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "root_route" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "ANY /"
  target             = "integrations/${aws_apigatewayv2_integration.app_integration.id}"
  authorization_type = "NONE"
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

# 9. CloudFront Distribution
resource "aws_cloudfront_distribution" "api_cdn" {
  origin {
    domain_name = replace(aws_apigatewayv2_api.http_api.api_endpoint, "/^https?:\\/\\//", "")
    origin_id   = "APIGatewayOrigin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront for Multi-Cloud API Gateway"
  default_root_object = ""

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "APIGatewayOrigin"

    forwarded_values {
      query_string = true
      headers      = ["Accept", "Authorization", "Origin", "X-Forwarded-Host", "X-Forwarded-Proto", "X-Forwarded-Port"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.api_cdn.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.api_cdn.id
}

output "alb_dns_name" {
  value = aws_lb.hello_lb.dns_name
}

output "replay_queue_url" {
  value = aws_sqs_queue.replay_queue.id
}

output "gcp_worker_aws_access_key_id" {
  value = aws_iam_access_key.gcp_worker.id
}

output "gcp_worker_aws_secret_access_key" {
  value     = aws_iam_access_key.gcp_worker.secret
  sensitive = true
}

resource "aws_sqs_queue" "hello_queue" {
  name = "hello-queue"
}

resource "aws_sqs_queue" "replay_queue" {
  name = "replay-queue"
}

resource "aws_dynamodb_table" "payments" {
  name           = "payments"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "transactionId"

  attribute {
    name = "transactionId"
    type = "S"
  }
}

resource "aws_cloudwatch_log_group" "hello_log_group" {
  name              = "/aws/ecs/spring-boot-hello"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "worker_log_group" {
  name              = "/aws/ecs/spring-boot-worker"
  retention_in_days = 7
}

resource "aws_ecr_repository" "worker_repo" {
  name = "spring-boot-worker"
}

resource "aws_ecs_task_definition" "worker_task" {
  family                   = "spring-boot-worker-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "spring-boot-worker"
      image     = "${aws_ecr_repository.worker_repo.repository_url}:latest"
      essential = true
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "aws"
        },
        {
          name  = "COMMIT_SHA"
          value = var.commit_sha
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/aws/ecs/spring-boot-worker"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "worker_service" {
  name            = "spring-boot-worker-service"
  cluster         = aws_ecs_cluster.dr_cluster.id
  task_definition = aws_ecs_task_definition.worker_task.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.dr_subnet.id]
    security_groups  = [aws_security_group.dr_sg.id]
    assign_public_ip = true
  }
}
