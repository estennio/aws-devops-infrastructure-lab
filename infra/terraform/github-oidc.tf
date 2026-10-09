# GitHub Actions deploys through OIDC federation and SSM Run Command, so no AWS
# access key is stored in GitHub and TCP/22 never needs to be opened to runners.

data "aws_caller_identity" "current" {}

locals {
  release_bucket_name = coalesce(
    var.release_bucket_name,
    "${var.project_name}-releases-${data.aws_caller_identity.current.account_id}"
  )
  release_prefix  = "releases"
  github_oidc_url = "token.actions.githubusercontent.com"
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : (
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.github_oidc_url}"
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://${local.github_oidc_url}"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${local.name_prefix}-github-oidc"
  }
}

# Trust is pinned to one repository AND one GitHub environment. The environment
# can require reviewers and restrict deployments to main, which is stricter than
# trusting a branch name alone. Pull requests and forks cannot match this subject.
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${local.name_prefix}-github-actions"
  description          = "GitHub Actions deployment role (OIDC, SSM Run Command, release uploads)"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600

  tags = {
    Name = "${local.name_prefix}-github-actions"
  }
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "RunCommandOnWebInstanceOnly"
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = [aws_instance.web.arn]
  }

  statement {
    sid       = "UseRunShellScriptDocumentOnly"
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-RunShellScript"]
  }

  # GetCommandInvocation does not support resource-level restrictions.
  statement {
    sid       = "ReadCommandStatus"
    effect    = "Allow"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }

  statement {
    sid       = "UploadReleases"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.releases.arn}/${local.release_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

# The instance only needs to download releases.
data "aws_iam_policy_document" "ec2_read_releases" {
  statement {
    sid       = "ReadReleases"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.releases.arn}/${local.release_prefix}/*"]
  }

  statement {
    sid       = "ListReleases"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.releases.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.release_prefix}/*"]
    }
  }
}

resource "aws_iam_role_policy" "ec2_read_releases" {
  name   = "read-releases"
  role   = aws_iam_role.ssm.id
  policy = data.aws_iam_policy_document.ec2_read_releases.json
}

# Release artifacts are short-lived build outputs; the lab intentionally skips
# access logging, versioning and a customer-managed KMS key to stay in scope.
#trivy:ignore:AVD-AWS-0089
#trivy:ignore:AVD-AWS-0090
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket" "releases" {
  bucket = local.release_bucket_name

  tags = {
    Name = local.release_bucket_name
  }
}

resource "aws_s3_bucket_ownership_controls" "releases" {
  bucket = aws_s3_bucket.releases.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "releases" {
  bucket = aws_s3_bucket.releases.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "releases" {
  bucket = aws_s3_bucket.releases.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "releases" {
  bucket = aws_s3_bucket.releases.id

  rule {
    id     = "expire-old-releases"
    status = "Enabled"

    filter {
      prefix = "${local.release_prefix}/"
    }

    expiration {
      days = var.release_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "releases_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.releases.arn,
      "${aws_s3_bucket.releases.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "releases" {
  bucket = aws_s3_bucket.releases.id
  policy = data.aws_iam_policy_document.releases_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.releases]
}
