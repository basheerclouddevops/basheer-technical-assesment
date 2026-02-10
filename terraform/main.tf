resource "aws_ecs_cluster" "main" {
  name = "prod-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
