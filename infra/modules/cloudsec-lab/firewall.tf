# Security Group do ALB: recebe HTTP apenas do IP/CIDR informado pelo usuário.
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Permite acesso HTTP ao ALB somente do CIDR autorizado"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP restrito ao IP publico autorizado"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_public_ip_cidr]
  }

  egress {
    description = "Saida do ALB para as EC2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group das EC2: aceita HTTP somente vindo do Security Group do ALB.
resource "aws_security_group" "ec2" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Permite HTTP somente a partir do ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP vindo apenas do ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []

    content {
      description = "SSH access from allowed IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_public_ip_cidr]
    }
  }

  egress {
    description = "Saida para updates e acesso ao S3 via endpoint publico AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}