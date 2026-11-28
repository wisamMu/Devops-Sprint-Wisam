variable "name" {
  description = "Prefix for the Name tags"
  type        = string
}

variable "vpc_cidr" {
  description = "Address range of the VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "Address range of the subnet"
  type        = string
}
