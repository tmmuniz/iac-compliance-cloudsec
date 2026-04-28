#!/bin/bash

dnf update -y
dnf install -y nginx awscli

systemctl enable nginx
systemctl start nginx

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
HOSTNAME=$(hostname)

mkdir -p /usr/share/nginx/html/app-data

cat > /usr/local/bin/write-and-read-app-bucket.sh <<'EOF'
#!/bin/bash

APP_BUCKET="${bucket_name}"
OUTPUT_DIR="/usr/share/nginx/html/app-data"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=$(hostname)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OBJECT_KEY="ec2-writes/$${INSTANCE_ID}.txt"

mkdir -p "$OUTPUT_DIR"

cat > /tmp/ec2-app-write.txt <<EOT
CloudSec Free Tier Lab
Instance ID: $INSTANCE_ID
Hostname: $HOSTNAME
Timestamp UTC: $NOW
Bucket: $APP_BUCKET
EOT

aws s3 cp /tmp/ec2-app-write.txt "s3://$APP_BUCKET/$OBJECT_KEY"

aws s3 ls "s3://$APP_BUCKET/ec2-writes/" > "$OUTPUT_DIR/objects.txt" || true

cat > "$OUTPUT_DIR/index.html" <<EOT
<html>
  <head>
    <title>App Bucket Data</title>
  </head>
  <body>
    <h1>Leitura do bucket da aplicação</h1>

    <p>Esta página mostra evidência de escrita e leitura no bucket S3 privado da aplicação.</p>

    <ul>
      <li><strong>Bucket:</strong> $APP_BUCKET</li>
      <li><strong>Última instância que atualizou:</strong> $INSTANCE_ID</li>
      <li><strong>Hostname:</strong> $HOSTNAME</li>
      <li><strong>Última atualização UTC:</strong> $NOW</li>
    </ul>

    <h2>Objetos em s3://$APP_BUCKET/ec2-writes/</h2>
    <pre>
$(cat "$OUTPUT_DIR/objects.txt")
    </pre>

    <h2>Conteúdo escrito por esta instância</h2>
    <pre>
$(cat /tmp/ec2-app-write.txt)
    </pre>

    <p><a href="/">Voltar</a></p>
  </body>
</html>
EOT
EOF

chmod +x /usr/local/bin/write-and-read-app-bucket.sh

cat > /etc/cron.d/write-and-read-app-bucket <<EOF
*/5 * * * * root /usr/local/bin/write-and-read-app-bucket.sh
EOF

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

    <h2>Integrações de Segurança</h2>

    <ul>
      <li>Bucket do Prowler privado, sem leitura pela EC2.</li>
      <li>CloudTrail gravando logs em uma pasta <code>cloudtrail/</code> no bucket privado do Prowler.</li>
      <li>EC2 escreve e lê objetos no bucket privado da aplicação.</li>
    </ul>

    <p>
      <a href="/app-data/index.html">Ver dados escritos no bucket da aplicação</a>
    </p>

    <p>Atualize a página algumas vezes para observar o balanceamento entre as instâncias.</p>
  </body>
</html>
EOF

/usr/local/bin/write-and-read-app-bucket.sh

systemctl restart nginx