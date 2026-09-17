variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster the EC2 instances will join"
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group ID assigned to ECS container instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "t3.small"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the ECS Auto Scaling Group"
  type        = list(string)
}

variable "asg_min_size" {
  description = "Minimum number of ECS container instances"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of ECS container instances"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired number of ECS container instances"
  type        = number
  default     = 1
}