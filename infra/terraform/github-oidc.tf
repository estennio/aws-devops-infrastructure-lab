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

  # Repositories created after 2026-07-15 receive the immutable subject format
  # repo:<owner>@<owner id>/<repo>@<repo id>:..., so a recycled owner or
  # repository name cannot mint a matching token. With both IDs unset, the
  # legacy name-only format repo:<owner>/<repo>:... is used instead.
  github_owner_name      = split("/", var.github_repository)[0]
  github_repository_name = split("/", var.github_repository)[1]
  github_subject_repository = (
    var.github_owner_id != null && var.github_repository_id != null
    ? "${local.github_owner_name}@${var.github_owner_id}/${local.github_repository_name}@${var.github_repository_id}"
    : var.github_repository
  )
  github_oidc_subject = "repo:${local.github_subject_repository}:environment:${var.github_environment}"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://${local.github_oidc_url}"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${local.name_prefix}-github-oidc"
  }
}

# Trust is pinned to one repository (by immutable ID) AND one GitHub environment.
# The environment can require reviewers and restrict deployments to main, which
# is stricter than trusting a branch name alone. Pull requests and forks cannot
# match this subject.
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
      values   = [local.github_oidc_subject]
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

# AWS-0089: access logging would require a second bucket; the bucket holds public site files that are also in git, and CloudTrail covers API activity.
# AWS-0090: versioning is unnecessary; releases are keyed by commit SHA, never overwritten, and expire through the lifecycle rule.
#trivy:ignore:AVD-AWS-0089
#trivy:ignore:AVD-AWS-0090
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

# AWS-0132: releases use SSE-S3 (AES256); a customer-managed KMS key adds cost without benefit for a single-user lab.
#trivy:ignore:AVD-AWS-0132
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
