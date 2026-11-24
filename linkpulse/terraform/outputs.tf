output "instance_id" {
  description = "EC2 instance ID (for aws ssm start-session --target)"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP of the server (changes on every new instance or stop/start)"
  value       = aws_instance.web.public_ip
}

output "url" {
  description = "Open this in the browser"
  value       = "http://${aws_instance.web.public_ip}"
}

output "ecr_repository" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

# The ARNs contain the account ID: hidden in terraform output, read with -raw only when needed
output "gha_role_arn" {
  description = "Role for GitHub Actions; goes into the LINKPULSE_ROLE_ARN secret"
  value       = aws_iam_role.gha.arn
  sensitive   = true
}
