package terraform.security

# OPA/Rego avalia o JSON gerado por:
# terraform show -json tfplan.binary > tfplan.json
# A pipeline falha quando qualquer regra abaixo retorna uma mensagem em deny[].

default allow := true

resources[resource] {
  resource := input.resource_changes[_]
}

# Permite apenas tipos de instância alinhados ao objetivo Free Tier do laboratório.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_instance"
  instance_type := resource.change.after.instance_type
  not instance_type == "t2.micro"
  not instance_type == "t3.micro"
  msg := sprintf("EC2 %s usa instance_type %s. Use apenas t2.micro ou t3.micro.", [resource.address, instance_type])
}

# Limita a quantidade de EC2 para controlar consumo de horas do Free Tier.
deny[msg] {
  instances := [r | r := resources[_]; r.type == "aws_instance"; not r.change.actions == ["delete"]]
  count(instances) > 2
  msg := "O laboratório deve ter no máximo 2 instâncias EC2 para reduzir risco de custo."
}

# Bloqueia volumes raiz grandes.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_instance"
  block := resource.change.after.root_block_device[_]
  block.volume_size > 30
  msg := sprintf("EC2 %s possui volume EBS acima de 30 GiB.", [resource.address])
}

# Exige IMDSv2 nas EC2.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_instance"
  resource.change.after.metadata_options[0].http_tokens != "required"
  msg := sprintf("EC2 %s deve exigir IMDSv2 com http_tokens = required.", [resource.address])
}

# Bloqueia SSH público.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_security_group"
  ingress := resource.change.after.ingress[_]
  ingress.from_port == 22
  ingress.to_port == 22
  ingress.cidr_blocks[_] == "0.0.0.0/0"
  msg := sprintf("Security Group %s expõe SSH para 0.0.0.0/0.", [resource.address])
}

# Bloqueia ALB aberto para a internet inteira.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_security_group"
  ingress := resource.change.after.ingress[_]
  ingress.from_port == 80
  ingress.to_port == 80
  ingress.cidr_blocks[_] == "0.0.0.0/0"
  msg := sprintf("Security Group %s expõe HTTP para 0.0.0.0/0. Use allowed_public_ip_cidr com /32.", [resource.address])
}

# Exige que as instâncias não aceitem HTTP diretamente da internet inteira.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_security_group"
  ingress := resource.change.after.ingress[_]
  ingress.from_port == 80
  ingress.to_port == 80
  ingress.cidr_blocks[_] == "0.0.0.0/0"
  msg := sprintf("Security Group %s permite HTTP público amplo. Para EC2, permita apenas o Security Group do ALB.", [resource.address])
}

# Garante que buckets S3 tenham Public Access Block com todas as proteções.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_s3_bucket_public_access_block"
  after := resource.change.after
  not after.block_public_acls
  msg := sprintf("S3 Public Access Block %s deve bloquear ACLs públicas.", [resource.address])
}

deny[msg] {
  resource := resources[_]
  resource.type == "aws_s3_bucket_public_access_block"
  after := resource.change.after
  not after.block_public_policy
  msg := sprintf("S3 Public Access Block %s deve bloquear policies públicas.", [resource.address])
}

deny[msg] {
  resource := resources[_]
  resource.type == "aws_s3_bucket_public_access_block"
  after := resource.change.after
  not after.ignore_public_acls
  msg := sprintf("S3 Public Access Block %s deve ignorar ACLs públicas.", [resource.address])
}

deny[msg] {
  resource := resources[_]
  resource.type == "aws_s3_bucket_public_access_block"
  after := resource.change.after
  not after.restrict_public_buckets
  msg := sprintf("S3 Public Access Block %s deve restringir buckets públicos.", [resource.address])
}

# Bloqueia policies IAM administrativas demais no portfólio.
deny[msg] {
  resource := resources[_]
  resource.type == "aws_iam_policy"
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  statement.Effect == "Allow"
  statement.Action == "*"
  statement.Resource == "*"
  msg := sprintf("IAM Policy %s permite Action '*' em Resource '*'.", [resource.address])
}

# Evita GuardDuty no projeto, conforme escopo solicitado.
deny[msg] {
  resource := resources[_]
  startswith(resource.type, "aws_guardduty")
  msg := sprintf("GuardDuty não deve ser utilizado neste portfólio: %s.", [resource.address])
}
