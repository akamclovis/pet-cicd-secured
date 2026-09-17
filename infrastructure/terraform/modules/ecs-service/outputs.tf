output "task_definition_arn" {
  description = "ARN of the PetClinic ECS task definition"
  value       = aws_ecs_task_definition.app.arn
}

output "task_definition_family" {
  description = "Family of the PetClinic ECS task definition"
  value       = aws_ecs_task_definition.app.family
}

output "service_name" {
  description = "Name of the PetClinic ECS service"
  value       = aws_ecs_service.app.name
}