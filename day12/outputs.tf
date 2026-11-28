output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = module.network.subnet_id
}

output "availability_zone" {
  description = "AZ picked by the data source"
  value       = module.network.availability_zone
}
