output "instance_role_name" {
  description = "Name of the ECS EC2 instance IAM role"
  value       = aws_iam_role.ecs_instance.name
}

output "instance_role_arn" {
  description = "ARN of the ECS EC2 instance IAM role"
  value       = aws_iam_role.ecs_instance.arn
}

output "instance_profile_name" {
  description = "Name of the ECS EC2 instance profile"
  value       = aws_iam_instance_profile.ecs_instance.name
}

output "instance_profile_arn" {
  description = "ARN of the ECS EC2 instance profile"
  value       = aws_iam_instance_profile.ecs_instance.arn
}

output "launch_template_id" {
  description = "ID of the ECS EC2 launch template"
  value       = aws_launch_template.ecs.id
}

output "launch_template_latest_version" {
  description = "Latest version of the ECS EC2 launch template"
  value       = aws_launch_template.ecs.latest_version
}

output "ecs_optimized_ami_id" {
  description = "ECS-optimized Amazon Linux 2023 AMI ID"
  value       = data.aws_ssm_parameter.ecs_optimized_ami.value
}

output "autoscaling_group_name" {
  description = "Name of the ECS Auto Scaling Group"
  value       = aws_autoscaling_group.ecs.name
}

output "capacity_provider_name" {
  description = "Name of the ECS capacity provider"
  value       = aws_ecs_capacity_provider.this.name
}