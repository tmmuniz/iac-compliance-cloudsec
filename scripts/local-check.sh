#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../infra"

terraform fmt -recursive
terraform validate
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
opa eval \
  --fail-defined \
  --format pretty \
  --data ../policy/terraform_security.rego \
  --input tfplan.json \
  'data.terraform.security.deny[_]'
