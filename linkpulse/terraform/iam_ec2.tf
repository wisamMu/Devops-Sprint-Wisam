# ---------- EC2 role: SSM agent + pull this app's images ----------

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "ec2-${var.app_name}"
  description        = "${var.app_name} EC2: SSM + pull ${var.app_name}"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ec2_pull" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PullThisRepoOnly"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "ec2_pull" {
  name   = "ecr-pull-${var.app_name}"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_pull.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-${var.app_name}"
  role = aws_iam_role.ec2.name
}
