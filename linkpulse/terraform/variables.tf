variable "aws_region" {
  description = "AWS region for everything"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Name used for the ECR repo, roles, tags and resource names"
  type        = string
  default     = "linkpulse"
}

variable "availability_zone" {
  description = "The one AZ for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "Address range of the VPC"
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Address range of the public subnet"
  type        = string
  default     = "10.30.1.0/24"
}

variable "instance_type" {
  description = "EC2 size (k3s needs 2 GB RAM)"
  type        = string
  default     = "t3.small"
}

variable "github_sub" {
  description = "Who may assume the GitHub role: this repo (immutable IDs), linkpulse-main branch only"
  type        = string
  default     = "repo:wisamMu@66379795/Devops-Sprint-Wisam@1443987341:ref:refs/heads/linkpulse-main"
}

variable "my_ip" {
  description = "Your public IP; the only address allowed on port 80 (set it in terraform.tfvars)"
  type        = string

  validation {
    condition     = can(cidrhost("${var.my_ip}/32", 0))
    error_message = "my_ip must be a plain IPv4 address, e.g. 203.0.113.10"
  }
}
