resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-key"
  })
}
