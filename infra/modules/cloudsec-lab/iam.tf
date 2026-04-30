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

# Política de menor privilégio para o bucket da aplicacao.
resource "aws_iam_policy" "ec2_s3_access" {
  name = "${var.project_name}-${var.environment}-ec2-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListAppBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.app_data.arn
      },
      {
        Sid    = "AllowReadWriteOnlyEc2WritesPrefix"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.app_data.arn}/ec2-writes/*"
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

# Permissao para o Prowler escrever no Bucket ADM
resource "aws_iam_policy" "prowler_report_writer" {
  name = "${local.name_prefix}-prowler-report-writer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteProwlerReports"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.adm_reports.arn}/prowler/*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "prowler-report-writer"
  })
}

data "aws_iam_policy_document" "adm_bucket_policy" {
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
      aws_s3_bucket.adm_reports.arn
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
      "${aws_s3_bucket.adm_reports.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "adm_reports" {
  bucket = aws_s3_bucket.adm_reports.id
  policy = data.aws_iam_policy_document.adm_bucket_policy.json
}

data "aws_iam_role" "ansible_role" {
  name = local.ansible_role_name
}

resource "aws_iam_policy" "ansible_ssm_controller" {
  name = "${local.name_prefix}-ansible-ssm-controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowStartSessionToCloudSecInstances"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/AWS-StartSSHSession",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/AWS-StartInteractiveCommand"
        ]
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Project"     = var.project_name
            "ssm:resourceTag/Environment" = var.environment
            "ssm:resourceTag/Role"        = "web"
          }
        }
      },
      {
        Sid    = "AllowManageOwnSessions"
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession",
          "ssm:ResumeSession"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/$${aws:userid}-*"
      },
      {
        Sid    = "AllowDescribeInstances"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowListBucketAnsiblePrefix"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.adm_reports.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["ansible-ssm/*"]
          }
        }
      },
      {
        Sid    = "AllowAnsibleObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.adm_reports.arn}/ansible-ssm/*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ansible-ssm-controller"
  })
}

resource "aws_iam_role_policy_attachment" "attach_ansible_policy" {
  role       = data.aws_iam_role.ansible_role.name
  policy_arn = aws_iam_policy.ansible_ssm_controller.arn
}

resource "aws_iam_role_policy_attachment" "prowler_report_writer_attach" {
  role       = data.aws_iam_role.prowler_role.name
  policy_arn = aws_iam_policy.prowler_report_writer.arn
}