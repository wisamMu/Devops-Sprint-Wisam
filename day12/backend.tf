terraform {
  backend "s3" {
    key          = "day12/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
