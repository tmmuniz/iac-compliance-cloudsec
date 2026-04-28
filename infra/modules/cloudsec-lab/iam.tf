# Role assumida pelas instâncias EC2. Evita credenciais hardcoded em user-data, código ou arquivos.
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name               = "${local.name_prefix}-ec2-s3-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Política de menor privilégio para o bucket do projeto.
resource "aws_iam_policy" "ec2_s3_access" {
  name = "${var.project_name}-${var.environment}-ec2-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAppBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-s3-access"
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.ec2_s3_access.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
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

data "aws_iam_policy_document" "prowler_reports_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.prowler_reports.arn
    ]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.prowler_reports.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "prowler_reports" {
  bucket = aws_s3_bucket.prowler_reports.id
  policy = data.aws_iam_policy_document.prowler_reports_bucket_policy.json
}