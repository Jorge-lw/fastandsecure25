variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bastion_public_key" {
  description = "Public SSH key for bastion host"
  type        = string
  sensitive   = true
}

variable "vulnerable_image_names" {
  description = "List of ECR repository names for vulnerable Docker images"
  type        = list(string)
  default = [
    "vulnerable-web-app",
    "vulnerable-api",
    "vulnerable-database",
    "vulnerable-legacy-app"
  ]
}

