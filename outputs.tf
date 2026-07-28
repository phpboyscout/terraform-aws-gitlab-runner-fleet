output "worker_asg_name" {
  description = "Name of the spot worker Auto Scaling Group (the fleeting plugin_config target)."
  value       = aws_autoscaling_group.worker.name
}

output "manager_asg_name" {
  description = "Name of the manager Auto Scaling Group (size 1)."
  value       = aws_autoscaling_group.manager.name
}

output "manager_iam_role_arn" {
  description = "ARN of the manager instance role."
  value       = aws_iam_role.manager.arn
}

output "worker_security_group_id" {
  description = "Worker security group ID."
  value       = aws_security_group.worker.id
}

output "cache_s3_bucket" {
  description = "S3 distributed-cache bucket name (empty when S3 cache is disabled)."
  value       = local.cache_bucket
}

output "efs_id" {
  description = "Shared EFS cache filesystem ID (null when EFS cache is disabled)."
  value       = try(aws_efs_file_system.cache[0].id, null)
}
