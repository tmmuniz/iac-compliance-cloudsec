# Bucket S3 privado onde o Prowler e Cloudtrail farao a escrita
resource "aws_s3_bucket" "adm_reports" {
  bucket = var.adm_bucket_name

  tags = merge(local.common_tags, {
    Name = var.adm_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "adm_reports" {
  bucket = aws_s3_bucket.adm_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "adm_reports" {
  bucket = aws_s3_bucket.adm_reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "adm_reports" {
  bucket = aws_s3_bucket.adm_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# Bucket S3 privado onde as instancias farao escrita a leitura.
resource "aws_s3_bucket" "app_data" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name        = "cloudsec-app-data"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}