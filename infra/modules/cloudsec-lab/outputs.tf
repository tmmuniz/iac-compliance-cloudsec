output "bucket_name" {
  description = "Nome do bucket S3 privado do laboratório."
  value       = aws_s3_bucket.app_data.bucket
}

output "adm_bucket_name" {
  description = "Bucket administrativo usado para Prowler e CloudTrail."
  value       = aws_s3_bucket.adm_reports.bucket
}

output "ec2_instance_ids" {
  description = "IDs das instâncias EC2 atrás do ALB."
  value       = aws_instance.app[*].id
}

output "alb_dns_name" {
  description = "DNS público do Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "allowed_public_ip_cidr" {
  description = "CIDR liberado para acessar o ALB."
  value       = var.allowed_public_ip_cidr
}
