# Existing resources (made by CLI earlier), now managed by Terraform

resource "aws_ecr_repository" "hello_web" {
  name                 = "hello-web"
  image_tag_mutability = "IMMUTABLE"

  tags = { App = "hello-web" }
}

resource "aws_iam_role" "ec2_hello" {
  name        = "ec2-hello"
  description = "hello-web EC2: SSM + pull hello-web"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { App = "hello-web" }
}
