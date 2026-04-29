variable "aws_region" {
  description = "Região AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base usado na identificação dos recursos."
  type        = string
  default     = "cloudsec-freetier"
}

variable "environment" {
  description = "Ambiente lógico do deploy."
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "Tipo de instância EC2. Mantenha t2.micro ou t3.micro para Free Tier quando elegível na conta/região."
  type        = string
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Use apenas t2.micro ou t3.micro neste projeto Free Tier."
  }
}

variable "allowed_public_ip_cidr" {
  description = "IP público/CIDR autorizado a acessar o ALB. Recomendado: x.x.x.x/32. Exemplo: 200.10.10.10/32."
  type        = string
  default     = "187.122.60.165/32"

  validation {
    condition     = can(cidrhost(var.allowed_public_ip_cidr, 0)) && var.allowed_public_ip_cidr != "0.0.0.0/0"
    error_message = "Informe um CIDR válido e não use 0.0.0.0/0. Exemplo seguro: x.x.x.x/32."
  }
}

variable "ec2_instance_count" {
  description = "Quantidade de instâncias EC2 atrás do ALB. Use 2 para demonstrar alta disponibilidade."
  type        = number
  default     = 2
}

variable "adm_bucket_name" {
  description = "Nome do bucket S3 para relatórios do Prowler e Logs Cloudtrail"
  type        = string
  default     = "cloudsec-tmmuniz-prowler-bucket"
}

variable "github_repository" {
  description = "Repositório GitHub autorizado no OIDC. Exemplo: usuario/repositorio"
  type        = string
  default     = "tmmuniz/iac-compliance-cloudsec"
}

variable "ssh_public_key" {
  description = "Chave pública SSH para acesso às instâncias"
  type        = string
}