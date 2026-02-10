##############################
# DATA SOURCES (EXISTING VPC)
##############################

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["default"]   # <-- change if your VPC name is different
  }
}

##############################
# ECS CLUSTER
##############################

resource "aws_ecs_cluster" "main" {
  name = "prod-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

##############################
# IAM ROLES (LEAST PRIVILEGE)
##############################

# Execution role (pull images + read SSM)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role (app identity + SSM access)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ssm_read_policy" {
  name = "ecs-ssm-read"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = var.ssm_db_password_arn
    }]
  })
}

##############################
# LAUNCH TEMPLATE (NO PUBLIC IP)
##############################

resource "aws_launch_template" "ecs_lt" {
  name = "ecs-ec2-lt"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ecs_instance_security_group_id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=prod-ecs-cluster >> /etc/ecs/ecs.config
EOF
  )
}

##############################
# AUTO SCALING GROUP (MIXED)
##############################

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ecs-asg"
  vpc_zone_identifier = var.private_subnets
  desired_capacity    = 2
  min_size            = 2
  max_size            = 10

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity = 2
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs_lt.id
        version            = "$Latest"
      }
    }
  }
}

##############################
# ECS CAPACITY PROVIDER
##############################

resource "aws_ecs_capacity_provider" "ecs_cp" {
  name = "ecs-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 75
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "cp" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.ecs_cp.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 1
  }
}

##############################
# APPLICATION LOAD BALANCER
##############################

resource "aws_lb" "alb" {
  name               = "prod-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.private_subnets
}

resource "aws_lb_target_group" "tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

##############################
# ECS TASK DEFINITION
##############################

resource "aws_ecs_task_definition" "nginx" {
  family                   = "nginx-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "nginx"
    image     = "nginx:latest"
    essential = true

    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = var.ssm_db_password_arn
    }]

    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

##############################
# ECS SERVICE (ZERO DOWNTIME)
##############################

resource "aws_ecs_service" "nginx_svc" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 4

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 1
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "nginx"
    container_port   = 80
  }
}
