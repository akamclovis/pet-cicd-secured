variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region used by the ECS workload"
  type        = string
}

variable "container_image" {
  description = "Container image URI used by the ECS task"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the PetClinic container"
  type        = number
  default     = 8080
}

variable "container_cpu" {
  description = "CPU units reserved for the PetClinic container"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory in MiB reserved for the PetClinic container"
  type        = number
  default     = 768
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster"
  type        = string
}

variable "capacity_provider_name" {
  description = "ECS capacity provider used by the service"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "desired_count" {
  description = "Desired number of PetClinic tasks"
  type        = number
  default     = 1
}