locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }

  name_prefix       = "${var.project_name}-${var.environment}"
  bucket_name       = lower("${local.name_prefix}-${data.aws_caller_identity.current.account_id}")
}