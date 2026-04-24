# Secrets necessários no GitHub Actions

Como você optou por não usar OIDC, cadastre as credenciais do usuário IAM já criado em:

`Settings > Secrets and variables > Actions > Secrets`

Crie estes secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`, apenas se estiver usando credencial temporária STS

Crie também esta variável opcional em:

`Settings > Secrets and variables > Actions > Variables`

- `AWS_REGION`, exemplo: `us-east-1`

## Permissões mínimas sugeridas para o usuário IAM do Terraform

Para um laboratório de portfólio, o usuário precisa conseguir administrar os recursos usados pelo projeto:

- EC2: criar, consultar e remover instância e security group
- IAM: criar role, policy, instance profile e anexos
- S3: criar, consultar e remover bucket e objetos

Em ambiente corporativo, prefira OIDC e permissões ainda mais restritas. Para este portfólio, o objetivo é demonstrar Terraform, IAM, EC2, S3, CI/CD e Policy as Code com Rego.
