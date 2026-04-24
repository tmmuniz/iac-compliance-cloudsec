package terraform.security

# Bloqueia Security Groups com SSH aberto para a Internet
deny contains msg if {
  resource := input.resource_changes[_]

  resource.type == "aws_security_group"

  ingress := resource.change.after.ingress[_]
  ingress.from_port == 22
  ingress.to_port == 22
  ingress.cidr_blocks[_] == "0.0.0.0/0"

  msg := "Security Group não pode permitir SSH aberto para 0.0.0.0/0"
}

# Bloqueia EC2 com IP público associado diretamente
deny contains msg if {
  resource := input.resource_changes[_]

  resource.type == "aws_instance"
  resource.change.after.associate_public_ip_address == true

  msg := "EC2 não deve possuir IP público diretamente associado"
}

# Bloqueia bucket S3 público
deny contains msg if {
  resource := input.resource_changes[_]

  resource.type == "aws_s3_bucket_public_access_block"
  resource.change.after.block_public_acls == false

  msg := "S3 deve bloquear ACLs públicas"
}

deny contains msg if {
  resource := input.resource_changes[_]

  resource.type == "aws_s3_bucket_public_access_block"
  resource.change.after.block_public_policy == false

  msg := "S3 deve bloquear políticas públicas"
}

deny contains msg if {
  resource := input.resource_changes[_]

  resource.type == "aws_s3_bucket_public_access_block"
  resource.change.after.ignore_public_acls == false

  msg := "S3 deve ignorar ACLs públicas"
}

deny contains msg if {
  resource := input.resource_changes[_]

  resource.type == "aws_s3_bucket_public_access_block"
  resource.change.after.restrict_public_buckets == false

  msg := "S3 deve restringir buckets públicos"
}

# Exige criptografia no bucket S3
deny contains msg if {
  resource := input.resource_changes[_]

  resource.type == "aws_s3_bucket_server_side_encryption_configuration"

  not resource.change.after.rule

  msg := "Bucket S3 deve possuir criptografia server-side configurada"
}

# Exige tags obrigatórias
deny contains msg if {
  resource := input.resource_changes[_]

  required := {"Environment", "Project", "Owner"}
  tags := object.keys(resource.change.after.tags)

  missing := required - {tag | tag := tags[_]}
  count(missing) > 0

  msg := sprintf("Recurso %s está sem tags obrigatórias: %v", [resource.address, missing])
}
