terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "model" {
  name = "lumen-skin-model"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole-lumen"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "lumen" {
  name = "lumen-model-cluster"
}

resource "aws_security_group" "alb_sg" {
  name        = "lumen-alb-sg"
  description = "Allow HTTP to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "ecs_sg" {
  name        = "lumen-ecs-sg"
  description = "Allow traffic from ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb" {
  name               = "lumen-model-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "tg" {
  name     = "lumen-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_ecs_task_definition" "model_task" {
  family                   = "lumen-skin-model"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "model-server",
      image     = "${data.aws_region.current == var.aws_region ? aws_ecr_repository.model.repository_url : aws_ecr_repository.model.repository_url}:${var.image_tag}",
      essential = true,
      portMappings = [ { containerPort = var.container_port, hostPort = var.container_port, protocol = "tcp" } ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/lumen-model",
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "model_service" {
  name            = "lumen-model-service"
  cluster         = aws_ecs_cluster.lumen.id
  task_definition = aws_ecs_task_definition.model_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
  subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "model-server"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.front_end]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_region" "current" {}


resource "null_resource" "set_lambda_env" {
  # Only create this when a lambda name is provided
  count = var.lambda_function_name != "" ? 1 : 0

  triggers = {
    alb_dns = aws_lb.alb.dns_name
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/update_lambda_env.py '${var.lambda_function_name}' '${aws_lb.alb.dns_name}' '${var.aws_region}'"
  }

  depends_on = [aws_ecs_service.model_service]
}
