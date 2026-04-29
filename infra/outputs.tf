output "bucket_name" {
  description = "Nome do bucket S3 criado para o laboratório."
  value       = module.cloudsec_lab.bucket_name
}

output "adm_bucket_name" {
  description = "Bucket administrativo usado para Prowler e CloudTrail."
  value       = module.cloudsec_lab.adm_bucket_name
}

output "ec2_instance_ids" {
  description = "IDs das instâncias EC2 criadas."
  value       = module.cloudsec_lab.ec2_instance_ids
}

output "alb_dns_name" {
  description = "DNS do ALB. Acesse via http://<dns>, a partir do CIDR autorizado."
  value       = module.cloudsec_lab.alb_dns_name
}

output "allowed_public_ip_cidr" {
  description = "CIDR liberado para acessar o ALB."
  value       = module.cloudsec_lab.allowed_public_ip_cidr
}
