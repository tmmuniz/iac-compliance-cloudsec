locals {
  prowler_role_name = "github-actions-prowler-role"
}

resource "aws_s3_bucket" "prowler_reports" {
  bucket = var.prowler_reports_bucket_name

  tags = merge(local.common_tags, {
    Name = var.prowler_reports_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "prowler_reports" {
  bucket = aws_s3_bucket.prowler_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "prowler_reports" {
  bucket = aws_s3_bucket.prowler_reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prowler_reports" {
  bucket = aws_s3_bucket.prowler_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "github_actions_prowler_role" {
  name = local.prowler_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.prowler_role_name
  })
}

resource "aws_iam_role_policy_attachment" "prowler_security_audit" {
  role       = aws_iam_role.github_actions_prowler_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "prowler_view_only" {
  role       = aws_iam_role.github_actions_prowler_role.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_policy" "prowler_report_writer" {
  name = "prowler-report-writer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteProwlerReports"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.prowler_reports.arn}/prowler/*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "prowler-report-writer"
  })
}

resource "aws_iam_role_policy_attachment" "prowler_report_writer_attach" {
  role       = aws_iam_role.github_actions_prowler_role.name
  policy_arn = aws_iam_policy.prowler_report_writer.arn
}