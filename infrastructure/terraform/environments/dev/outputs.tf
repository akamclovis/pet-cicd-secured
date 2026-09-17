output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.cluster_arn
}

output "ecs_instance_role_name" {
  description = "Name of the ECS EC2 instance role"
  value       = module.ecs_capacity.instance_role_name
}

output "ecs_instance_profile_name" {
  description = "Name of the ECS EC2 instance profile"
  value       = module.ecs_capacity.instance_profile_name
}

output "ecs_launch_template_id" {
  description = "ID of the ECS EC2 launch template"
  value       = module.ecs_capacity.launch_template_id
}

output "ecs_optimized_ami_id" {
  description = "ECS-optimized AL2023 AMI selected for the cluster"
  value       = nonsensitive(module.ecs_capacity.ecs_optimized_ami_id)
}

output "ecs_autoscaling_group_name" {
  description = "Name of the ECS Auto Scaling Group"
  value       = module.ecs_capacity.autoscaling_group_name
}

output "ecs_capacity_provider_name" {
  description = "Name of the ECS capacity provider"
  value       = module.ecs_capacity.capacity_provider_name
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_target_group_arn" {
  description = "ARN of the PetClinic ALB target group"
  value       = module.alb.target_group_arn
}

output "ecs_task_definition_arn" {
  description = "ARN of the PetClinic ECS task definition"
  value       = module.ecs_service.task_definition_arn
}

output "ecs_service_name" {
  description = "Name of the PetClinic ECS service"
  value       = module.ecs_service.service_name
}