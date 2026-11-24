# Private image store. Immutable tags: one git SHA = one image, forever.
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # terraform destroy also removes the images

  encryption_configuration {
    encryption_type = "AES256" # free; KMS would cost money
  }
}

resource "aws_ecr_lifecycle_policy" "keep_last_3" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep the last 3 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}
