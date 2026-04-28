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