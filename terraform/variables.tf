variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "private_subnets" {
  type        = list(string)
  description = "Existing private subnet IDs"
}

variable "alb_security_group_id" {
  type        = string
  description = "Existing ALB security group"
}

variable "ecs_instance_security_group_id" {
  type        = string
  description = "Existing ECS instance security group"
}

variable "ssm_db_password_arn" {
  type        = string
  description = "ARN of existing SSM secret"
}
