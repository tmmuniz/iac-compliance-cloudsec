#!/bin/bash

# Log completo para troubleshooting
exec > /var/log/cloudsec-user-data.log 2>&1
set -euxo pipefail

echo "=== INICIANDO USER DATA ==="

dnf update -y
dnf install -y nginx awscli

# Garantir diretórios
mkdir -p /usr/share/nginx/html/app-data
mkdir -p /etc/cron.d

# Remover página default do nginx
rm -f /usr/share/nginx/html/index.html
rm -f /etc/nginx/conf.d/default.conf

APP_BUCKET="${bucket_name}"

printf '%s\n' \
'server {' \
'    listen 80 default_server;' \
'    server_name _;' \
'' \
'    root /usr/share/nginx/html;' \
'    index index.html;' \
'' \
'    server_tokens off;' \
'' \
'    add_header X-Content-Type-Options "nosniff" always;' \
'    add_header X-Frame-Options "DENY" always;' \
'    add_header Referrer-Policy "no-referrer" always;' \
'    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;' \
'    add_header Cache-Control "no-store" always;' \
'' \
'    location / {' \
'        try_files /index.html =404;' \
'    }' \
'' \
'    location /app-data/ {' \
'        autoindex off;' \
'        try_files $uri $uri/ =404;' \
'    }' \
'}' \
> /etc/nginx/conf.d/cloudsec.conf

# Iniciar nginx
systemctl enable nginx
systemctl start nginx


echo "=== OBTENDO METADADOS (IMDSv2) ==="

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

LOCAL_IPV4=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

HOSTNAME=$(hostname)

echo "INSTANCE_ID=$INSTANCE_ID"
echo "BUCKET=$APP_BUCKET"

# Criar script de escrita/leitura no S3
cat > /usr/local/bin/write-and-read-app-bucket.sh <<'EOF'
#!/bin/bash
set -euxo pipefail

APP_BUCKET="${bucket_name}"
OUTPUT_DIR="/usr/share/nginx/html/app-data"

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

HOSTNAME=$(hostname)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

OBJECT_KEY="ec2-writes/$INSTANCE_ID-output.txt"

mkdir -p "$OUTPUT_DIR"

echo "=== ESCREVENDO NO S3 ==="

cat > /tmp/ec2-app-write.txt <<EOT
CloudSec Free Tier Lab
Instance ID: $INSTANCE_ID
Hostname: $HOSTNAME
Timestamp UTC: $NOW
Bucket: $APP_BUCKET
EOT

aws s3 cp /tmp/ec2-app-write.txt "s3://$APP_BUCKET/$OBJECT_KEY"

echo "=== LISTANDO OBJETOS ==="

aws s3 ls "s3://$APP_BUCKET/ec2-writes/" > "$OUTPUT_DIR/objects.txt" || true

echo "=== GERANDO HTML ==="

cat > "$OUTPUT_DIR/index.html" <<EOT
<html>
  <head>
    <title>App Bucket Data</title>
  </head>
  <body>
    <h1>Leitura do bucket da aplicação</h1>

    <ul>
      <li><strong>Bucket:</strong> $APP_BUCKET</li>
      <li><strong>Instância:</strong> $INSTANCE_ID</li>
      <li><strong>Hostname:</strong> $HOSTNAME</li>
      <li><strong>Última atualização UTC:</strong> $NOW</li>
    </ul>

    <h2>Objetos encontrados</h2>
    <pre>$(cat "$OUTPUT_DIR/objects.txt")</pre>

    <h2>Conteúdo escrito</h2>
    <pre>$(cat /tmp/ec2-app-write.txt)</pre>

    <p><a href="/">Voltar</a></p>
  </body>
</html>
EOT

rm -f /tmp/ec2-app-write.txt
EOF

chmod 750 /usr/local/bin/write-and-read-app-bucket.sh

echo "=== CRIANDO CRON ==="

cat > /etc/cron.d/write-and-read-app-bucket <<'EOF'
*/5 * * * * root /usr/local/bin/write-and-read-app-bucket.sh
EOF

# Criar página principal
cat > /usr/share/nginx/html/index.html <<EOF
<html>
  <head>
    <title>CloudSec Free Tier Lab</title>
  </head>
  <body>
    <h1>CloudSec Free Tier Lab</h1>

    <h2>Instância atual</h2>
    <ul>
      <li><strong>Instance ID:</strong> $INSTANCE_ID</li>
      <li><strong>Hostname:</strong> $HOSTNAME</li>
      <li><strong>Private IP:</strong> $LOCAL_IPV4</li>
      <li><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</li>
    </ul>

    <h2>Funcionalidades</h2>
    <ul>
      <li>IMDSv2 ativo</li>
      <li>EC2 escreve no bucket S3</li>
      <li>Leitura do bucket via interface web</li>
      <li>ALB ativo/ativo</li>
    </ul>

    <p>
      <a href="/app-data/index.html">Ver dados do bucket</a>
    </p>
  </body>
</html>
EOF

echo "=== EXECUTANDO SCRIPT MANUAL ==="

/usr/local/bin/write-and-read-app-bucket.sh

echo "=== AJUSTANDO PERMISSÕES ==="

chown -R root:nginx /usr/share/nginx/html
find /usr/share/nginx/html -type d -exec chmod 750 {} \;
find /usr/share/nginx/html -type f -exec chmod 640 {} \;

echo "=== VALIDANDO NGINX ==="

nginx -t
systemctl restart nginx

echo "=== USER DATA FINALIZADO ==="