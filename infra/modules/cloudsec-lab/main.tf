# Identifica a conta atual para montar nomes únicos e ARNs corretos.
data "aws_caller_identity" "current" {}

# AMI Amazon Linux 2023 mais recente, sem custo adicional pela AMI.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-minimal-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

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

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  bucket_name = lower("${local.name_prefix}-${data.aws_caller_identity.current.account_id}")

  # Página HTML usada como evidência visual do ambiente provisionado.
  html_page = <<-HTML
    <!doctype html>
    <html lang="pt-BR">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>CloudSec Free Tier Portfolio</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; color: #1f2937; }
        .card { max-width: 920px; border: 1px solid #d1d5db; border-radius: 12px; padding: 28px; box-shadow: 0 4px 16px rgba(0,0,0,.08); }
        h1 { color: #0f172a; }
        code { background: #f3f4f6; padding: 2px 6px; border-radius: 6px; }
        .ok { color: #047857; font-weight: bold; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>CloudSec Free Tier Portfolio</h1>
        <p class="ok">Ambiente provisionado com Terraform, validado com Rego/OPA e publicado via Application Load Balancer.</p>
        <h2>Arquitetura</h2>
        <ul>
          <li>Application Load Balancer público com acesso restrito ao CIDR informado em <code>allowed_public_ip_cidr</code>.</li>
          <li>Duas instâncias EC2 <code>${var.instance_type}</code> em subnets diferentes para simular alta disponibilidade.</li>
          <li>Security Group das EC2 aceita HTTP somente a partir do Security Group do ALB.</li>
          <li>Bucket S3 privado com bloqueio de acesso público e criptografia SSE-S3.</li>
          <li>IAM Role anexada às EC2 com acesso mínimo ao bucket do projeto.</li>
          <li>IMDSv2 obrigatório nas instâncias EC2.</li>
        </ul>
        <h2>Objetivo de Segurança</h2>
        <p>Demonstrar princípios de CloudSec: menor privilégio, segmentação de rede, validação automatizada de políticas, infraestrutura como código e controle de exposição pública.</p>
        <h2>Observação Free Tier</h2>
        <p>Este laboratório usa recursos simples e controlados. Ainda assim, acompanhe o AWS Billing e execute o workflow de destroy após os testes.</p>
        <p><strong>Hostname:</strong> $(hostname)</p>
      </div>
    </body>
    </html>
  HTML
}

# Bucket S3 privado do laboratório.
resource "aws_s3_bucket" "app_data" {
  bucket        = local.bucket_name
  force_destroy = true
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

# Política de menor privilégio para o bucket do projeto.
data "aws_iam_policy_document" "ec2_s3_access" {
  statement {
    sid     = "ListProjectBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]

    resources = [aws_s3_bucket.app_data.arn]
  }

  statement {
    sid    = "ReadWriteObjectsInProjectBucket"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = ["${aws_s3_bucket.app_data.arn}/*"]
  }
}

resource "aws_iam_policy" "ec2_s3_access" {
  name        = "${local.name_prefix}-ec2-s3-access"
  description = "Permite que as EC2 acessem somente o bucket S3 do projeto."
  policy      = data.aws_iam_policy_document.ec2_s3_access.json
}

resource "aws_iam_role_policy_attachment" "ec2_s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.ec2_s3_access.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}

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

  egress {
    description = "Saida para updates e acesso ao S3 via endpoint publico AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB público para demonstrar balanceamento e exposição controlada.
resource "aws_lb" "app" {
  name               = substr(replace("${local.name_prefix}-alb", "_", "-"), 0, 32)
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = slice(data.aws_subnets.default.ids, 0, 2)

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app" {
  name     = substr(replace("${local.name_prefix}-tg", "_", "-"), 0, 32)
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf update -y
    dnf install -y nginx awscli
    systemctl enable nginx
    cat > /usr/share/nginx/html/index.html <<'HTML'
    ${local.html_page}
    HTML
    systemctl restart nginx
    echo "Portfolio CloudSec - $(hostname)" > /tmp/portfolio.txt
    aws s3 cp /tmp/portfolio.txt s3://${aws_s3_bucket.app_data.bucket}/ec2-test/$(hostname)-portfolio.txt
  EOT
}

# Duas instâncias em subnets diferentes. Importante: duas EC2 consomem horas acumuladas do Free Tier.
resource "aws_instance" "app" {
  count = var.ec2_instance_count

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[count.index]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = yes
  user_data                   = local.user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${local.name_prefix}-ec2-${count.index + 1}"
    Role        = "web"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count = var.ec2_instance_count

  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}
