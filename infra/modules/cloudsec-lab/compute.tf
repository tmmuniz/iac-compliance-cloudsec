# AMI Amazon Linux 2023 minimal, sem custo adicional pela AMI.
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

# Duas instâncias em subnets diferentes
resource "aws_instance" "app" {
  count = var.ec2_instance_count

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[count.index]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_key.key_name

  lifecycle {
    create_before_destroy = true
  }

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

  # Utilize o arquivo user_data.sh na inicializacao da instancia
  user_data = templatefile("${path.module}/user_data.sh", {
    instance_name = "cloudsec-app-${count.index + 1}"
    bucket_name   = aws_s3_bucket.app_data.bucket
  })
}
