variable "project_name" {
  description = "Nome base usado na identificação dos recursos."
  type        = string
  default     = "cloudsec-free-tier"
}

variable "environment" {
  description = "Ambiente lógico do deploy."
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "Tipo da instância EC2 Free Tier elegível."
  type        = string
}

variable "owner" {
  description = "Responsável pelo ambiente"
  type        = string
  default     = "cloudsec-team"
}

variable "allowed_public_ip_cidr" {
  description = "CIDR público autorizado a acessar o ALB. Use x.x.x.x/32 para liberar somente seu IP."
  type        = string
}

variable "ec2_instance_count" {
  description = "Quantidade de instâncias EC2 atrás do ALB. Duas instâncias demonstram alta disponibilidade, mas consomem horas do Free Tier de forma acumulada."
  type        = number
  default     = 2

  validation {
    condition     = var.ec2_instance_count >= 1 && var.ec2_instance_count <= 2
    error_message = "Para manter o laboratório controlado, use 1 ou 2 instâncias."
  }
}

variable "prowler_reports_bucket_name" {
  description = "Nome do bucket do Prowler"
  type        = string
}

variable "github_repository" {
  description = "Repositório GitHub autorizado no OIDC. Exemplo: usuario/repositorio"
  type        = string
}

variable "prowler_role_name" {
  description = "Nome da role IAM criada manualmente para o Prowler"
  type        = string
  default     = "github-actions-prowler-role"
}
