variable "aws_region" {
  description = "AWS region for everything"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Address range of the VPC"
  type        = string
  default     = "10.50.0.0/16"
}

variable "subnet_cidr" {
  description = "Address range of the subnet"
  type        = string
  default     = "10.50.1.0/24"
}
