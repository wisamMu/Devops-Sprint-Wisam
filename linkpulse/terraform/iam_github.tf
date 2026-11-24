# ---------- Lookups (read only, create nothing) ----------

data "aws_caller_identity" "current" {}

# The GitHub OIDC provider already exists (Day 9); there can be only one per account.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ---------- GitHub role: push to ECR + deploy via SSM ----------

data "aws_iam_policy_document" "gha_trust" {
  statement {
    sid     = "GitHubActionsLinkpulseMainOnly"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_sub]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gha" {
  name                 = "gha-${var.app_name}"
  description          = "GitHub Actions (linkpulse-main): push ${var.app_name} to ECR and deploy it via SSM"
  assume_role_policy   = data.aws_iam_policy_document.gha_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "gha_permissions" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushAndCheckThisRepoOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid       = "FindTheInstance"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "RunCommandOnThisAppsInstancesOnly"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/App"
      values   = [var.app_name]
    }
  }

  statement {
    sid       = "OnlyTheShellScriptDocument"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"]
  }

  statement {
    sid       = "ReadCommandResults"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "gha" {
  name   = "${var.app_name}-push-and-deploy"
  role   = aws_iam_role.gha.id
  policy = data.aws_iam_policy_document.gha_permissions.json
}
