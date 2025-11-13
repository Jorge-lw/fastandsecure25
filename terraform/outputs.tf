output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -p 22222 -i <your-key> ubuntu@${aws_eip.bastion.public_ip}"
}

output "bastion_ssh_command_port22" {
  description = "SSH command to connect to bastion host (port 22)"
  value       = "ssh -i <your-key> ubuntu@${aws_eip.bastion.public_ip}"
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    for repo in aws_ecr_repository.vulnerable_images : repo.name => repo.repository_url
  }
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

output "bastion_role_arn" {
  description = "ARN del rol IAM del bastión"
  value       = aws_iam_role.bastion.arn
}

