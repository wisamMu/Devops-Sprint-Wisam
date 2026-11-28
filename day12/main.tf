module "network" {
  source = "./modules/network"

  name        = "day12"
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
}
