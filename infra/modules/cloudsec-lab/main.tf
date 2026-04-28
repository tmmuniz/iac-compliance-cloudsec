# Identifica a conta atual para montar nomes únicos e ARNs corretos.
data "aws_caller_identity" "current" {}

# Usa a VPC default para evitar NAT Gateway e reduzir risco de custo.
data "aws_vpc" "default" {
  default = true
}

# O ALB exige ao menos duas subnets em zonas diferentes.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}