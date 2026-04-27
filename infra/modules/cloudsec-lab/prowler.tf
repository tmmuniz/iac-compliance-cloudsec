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
  role       = var.prowler_role_name
  policy_arn = aws_iam_policy.prowler_report_writer.arn
}