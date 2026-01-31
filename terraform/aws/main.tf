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
  region = "us-east-1"
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
  availability_zone = "us-east-1a"
  tags = {
    Name = "spring-boot-dr-subnet"
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

resource "aws_security_group" "dr_sg" {
  name        = "spring-boot-dr-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.dr_vpc.id

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

  container_definitions = jsonencode([
    {
      name      = "spring-boot-hello"
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
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

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = [aws_subnet.dr_subnet.id]
    security_groups  = [aws_security_group.dr_sg.id]
    assign_public_ip = true
  }
}

resource "aws_sqs_queue" "hello_queue" {
  name = "hello-queue"
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
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/aws/ecs/spring-boot-worker"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
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
