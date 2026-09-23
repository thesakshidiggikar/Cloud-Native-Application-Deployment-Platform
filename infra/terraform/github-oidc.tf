# GitHub Actions receives short-lived credentials only for semantic version tags.
# Set github_oidc_provider_arn to the account's existing GitHub provider, or let
# the module below create it when no provider exists in that account.
variable "github_owner" {
  description = "GitHub repository owner used to scope the publishing role trust."
  type        = string
  default     = "thesakshidiggikar"
}

variable "github_repository" {
  description = "GitHub repository used to scope the publishing role trust."
  type        = string
  default     = "Cloud-Native-Application-Deployment-Platform"
}

variable "github_oidc_provider_arn" {
  description = "Existing account-level GitHub OIDC provider ARN, or empty to create it."
  type        = string
  default     = ""
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count           = var.github_oidc_provider_arn == "" ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
  tags            = var.tags
}

locals {
  github_oidc_provider_arn = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github_actions[0].arn
}

data "aws_iam_policy_document" "github_publish_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repository}:ref:refs/tags/v*.*.*"]
    }
  }
}

resource "aws_iam_role" "github_publish" {
  name                 = "${var.project_name}-${var.environment}-github-ecr-publish"
  assume_role_policy   = data.aws_iam_policy_document.github_publish_assume_role.json
  max_session_duration = 3600
  tags                 = var.tags
}

data "aws_iam_policy_document" "github_publish_ecr" {
  statement {
    sid       = "ECRAuthorization"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid    = "PublishOnlyThisRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.api.arn]
  }
}

resource "aws_iam_role_policy" "github_publish_ecr" {
  name   = "publish-devopshere-image"
  role   = aws_iam_role.github_publish.id
  policy = data.aws_iam_policy_document.github_publish_ecr.json
}

output "github_actions_role_arn" {
  description = "Set this as the GitHub Actions repository variable AWS_ROLE_TO_ASSUME."
  value       = aws_iam_role.github_publish.arn
}
