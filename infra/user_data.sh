#!/bin/bash

dnf update -y
dnf install -y httpd awscli

systemctl enable httpd
systemctl start httpd

cat > /var/www/html/index.html <<EOF
<html>
  <head>
    <title>CloudSec Free Tier Lab</title>
  </head>
  <body>
    <h1>CloudSec Free Tier Lab</h1>

    <p>Ambiente AWS com Terraform, ALB, EC2, S3, IAM, Rego, tfsec e Prowler.</p>

    <ul>
      <li>Infraestrutura como código com Terraform</li>
      <li>Validação preventiva com OPA/Rego</li>
      <li>Scan IaC com tfsec</li>
      <li>Scan CSPM com Prowler</li>
      <li>Relatório armazenado em bucket S3 privado</li>
      <li>Acesso ao relatório apenas via ALB e EC2</li>
    </ul>

    <p>
      <a href="/prowler/index.html">Abrir relatório Prowler</a>
    </p>
  </body>
</html>
EOF

mkdir -p /var/www/html/prowler

cat > /var/www/html/prowler/index.html <<EOF
<html>
  <body>
    <h1>Relatório Prowler ainda não disponível</h1>
    <p>Execute o workflow para gerar e sincronizar o relatório.</p>
  </body>
</html>
EOF

cat > /usr/local/bin/sync-prowler-report.sh <<EOF
#!/bin/bash
aws s3 cp s3://${prowler_bucket_name}/prowler/index.html /var/www/html/prowler/index.html || true
EOF

chmod +x /usr/local/bin/sync-prowler-report.sh

cat > /etc/cron.d/sync-prowler-report <<EOF
*/5 * * * * root /usr/local/bin/sync-prowler-report.sh
EOF

/usr/local/bin/sync-prowler-report.sh