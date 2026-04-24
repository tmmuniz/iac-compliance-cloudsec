# CloudSec Free Tier Portfolio — Terraform + Rego + AWS ALB

Projeto de portfólio para demonstrar **Cloud Security**, **Terraform**, **Rego/OPA**, **AWS** e **GitHub Actions**, usando recursos simples e controlados para ficar próximo do escopo do **AWS Free Tier**.

> Escopo: sem GuardDuty, sem OIDC e usando credenciais de usuário IAM via GitHub Secrets.

## Objetivo

Provisionar uma arquitetura segura com:

- Application Load Balancer público com acesso restrito ao CIDR informado.
- Duas EC2 `t2.micro` ou `t3.micro` atrás do ALB.
- Página HTML estática instalada via `user_data`, explicando o ambiente.
- Security Group das EC2 aceitando HTTP somente do Security Group do ALB.
- Bucket S3 privado, criptografado e com Public Access Block.
- IAM Role nas EC2 com permissão mínima para acessar somente o bucket do projeto.
- GitHub Actions para plan/apply/destroy.
- Rego/OPA para bloquear configurações inseguras antes do deploy.

## Arquitetura

```text
Usuário autorizado
    │
    │ HTTP/80 somente do CIDR permitido
    ▼
Application Load Balancer
    │
    │ HTTP/80 permitido somente do SG do ALB
    ▼
Target Group
    ├── EC2 t2.micro/t3.micro - AZ A
    └── EC2 t2.micro/t3.micro - AZ B
            │
            │ IAM Role com menor privilégio
            ▼
        S3 privado
```

## Variável para liberar seu IP no ALB

```hcl
allowed_public_ip_cidr = "SEU_IP_PUBLICO/32"
```

Exemplo local:

```bash
cd infra
terraform plan -var='allowed_public_ip_cidr=200.10.10.10/32'
```

No GitHub Actions, cadastre a variável:

```text
ALLOWED_PUBLIC_IP_CIDR=200.10.10.10/32
```

## Serviços usados

| Serviço | Uso | Atenção Free Tier |
|---|---|---|
| EC2 | Duas instâncias Linux para alta disponibilidade | Horas são acumuladas; duas EC2 ligadas o mês inteiro podem exceder 750h |
| EBS | Volume raiz de 8 GiB por EC2 | Mantido pequeno |
| ALB | Balanceamento HTTP | Monitore horas/LCU no Billing |
| S3 | Bucket privado | Remova objetos após testes |
| IAM | Role, policy e instance profile | Sem cobrança direta usual |
| Security Groups | Segmentação de rede | Sem cobrança direta usual |

> Sempre acompanhe o AWS Billing e execute o destroy após a demonstração.

## Estrutura

```text
.
├── .github/workflows/
│   ├── terraform-plan.yml
│   ├── terraform-apply.yml
│   └── terraform-destroy.yml
├── docs/
│   └── github-secrets.md
├── infra/
│   ├── backend.tf.example
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── modules/cloudsec-lab/
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── policy/
│   └── terraform_security.rego
└── scripts/
    └── local-check.sh
```

## Controles de segurança demonstrados

- ALB restrito ao CIDR informado.
- EC2 sem HTTP público direto; acesso somente via ALB.
- EC2 com IMDSv2 obrigatório.
- Bucket S3 privado e criptografado.
- IAM Role em vez de chaves dentro da EC2.
- Política IAM com menor privilégio para S3.
- Validação de segurança com OPA/Rego no pipeline.
- Nenhum recurso GuardDuty, conforme escopo solicitado.

## Regras Rego

As políticas bloqueiam:

- EC2 diferente de `t2.micro` ou `t3.micro`.
- Mais de 2 instâncias EC2.
- Volume raiz maior que 30 GiB.
- EC2 sem IMDSv2 obrigatório.
- SSH aberto para `0.0.0.0/0`.
- HTTP aberto para `0.0.0.0/0`.
- Bucket S3 sem Public Access Block completo.
- IAM Policy com `Action: *` e `Resource: *`.
- Qualquer recurso GuardDuty.

## Execução local

```bash
export TF_VAR_allowed_public_ip_cidr="SEU_IP_PUBLICO/32"
cd infra
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
opa eval --fail-defined --format pretty --data ../policy/terraform_security.rego --input tfplan.json 'data.terraform.security.deny[_]'
```

Ou:

```bash
export TF_VAR_allowed_public_ip_cidr="SEU_IP_PUBLICO/32"
./scripts/local-check.sh
```

## GitHub Actions

Secrets necessários:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN # somente se usar credencial temporária
```

Variables necessárias:

```text
AWS_REGION=us-east-1
ALLOWED_PUBLIC_IP_CIDR=SEU_IP_PUBLICO/32
```

Workflows:

- `terraform-plan.yml`: valida Terraform e Rego.
- `terraform-apply.yml`: deploy manual com confirmação `APPLY`.
- `terraform-destroy.yml`: remoção manual com confirmação `DESTROY`.

## Validação

Após o apply, copie o output `alb_dns_name` e acesse:

```text
http://ALB_DNS_NAME
```

O acesso só deve funcionar a partir do CIDR informado.

## O que este projeto demonstra em entrevista CloudSec

- Infraestrutura como código com Terraform.
- Segmentação entre internet, ALB, EC2 e S3.
- IAM com menor privilégio.
- Policy as Code com Rego/OPA.
- CI/CD com validação antes do deploy.
- Consciência de custo no Free Tier.
