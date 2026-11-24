# Latest Amazon Linux 2023 image, looked up at plan time (no hard-coded AMI ID)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "web" {
  ami                    = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  tags = { Name = var.app_name } # App=<app_name> comes from default_tags: the pipeline finds the server by it

  # a newer AMI next month should not replace the running server
  lifecycle {
    ignore_changes = [ami]
  }
}
