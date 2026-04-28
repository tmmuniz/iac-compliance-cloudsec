#!/bin/bash

dnf update -y
dnf install -y nginx awscli

systemctl enable nginx
systemctl start nginx

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
HOSTNAME=$(hostname)

cat > /usr/share/nginx/html/index.html <<EOF
<html>
  <head>
    <title>CloudSec Free Tier Lab</title>
  </head>
  <body>
    <h1>CloudSec Free Tier Lab</h1>

    <p>Ambiente com ALB em modo ativo-ativo.</p>

    <h2>Instância que respondeu esta conexão</h2>

    <ul>
      <li><strong>Instance ID:</strong> $INSTANCE_ID</li>
      <li><strong>Hostname:</strong> $HOSTNAME</li>
      <li><strong>Private IP:</strong> $LOCAL_IPV4</li>
      <li><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</li>
    </ul>

    <p>Atualize a página algumas vezes para observar o balanceamento entre as instâncias.</p>

    <p>
      <a href="/prowler/index.html">Abrir relatório Prowler</a>
    </p>
  </body>
</html>
EOF