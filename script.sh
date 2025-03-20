#!/bin/bash

# Definir ambiente não interativo para evitar problemas no APT
export DEBIAN_FRONTEND=noninteractive

# Atualizar pacotes do sistema
sudo apt-get update -y && sudo apt-get upgrade -y

# Instalar dependências necessárias
sudo apt-get install -y docker.io docker-compose git nfs-common mysql-client unzip curl

# Iniciar e habilitar Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Instalar AWS CLI (caso queira gerenciar via AWS)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Criar diretório para EFS
sudo mkdir -p /mnt/efs

# Configuração do EFS
EFS_ID="fs-050f37f5cc9058b3d"
REGION="us-east-1"

# Montar EFS
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 fs-050f37f5cc9058b3d.efs.us-east-1.amazonaws.com:/ /mnt/efs

# Persistir montagem no /etc/fstab
echo "fs-050f37f5cc9058b3d.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Criar diretório do WordPress
PROJETOPRESS=/mnt/efs/wordpress
sudo mkdir -p $PROJETOPRESS
sudo chmod -R 777 $PROJETOPRESS
cd $PROJETOPRESS

# Criar arquivo docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<EOL
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: "wordpressbd.c9cweqmayjz8.us-east-1.rds.amazonaws.com"
      WORDPRESS_DB_USER: "admin"
      WORDPRESS_DB_PASSWORD: "202019Mara."
      WORDPRESS_DB_NAME: "wordpress"
      WORDPRESS_TABLE_PREFIX: "wp_"
      WORDPRESS_DEBUG: "1"
    volumes:
      - /mnt/efs/wordpress:/var/www/html
EOL

# Criar arquivo wp-config.php manualmente
sudo tee /mnt/efs/wordpress/wp-config.php > /dev/null <<EOL
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'admin');
define('DB_PASSWORD', '202019Mara.');
define('DB_HOST', 'wordpressbd.c9cweqmayjz8.us-east-1.rds.amazonaws.com');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('FS_METHOD', 'direct');

\$table_prefix = 'wp_';

define('WP_DEBUG', true);
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
EOL

# Iniciar WordPress com Docker Compose
sudo docker-compose up -d

# Criar arquivo de Health Check
sudo tee /mnt/efs/wordpress/healthcheck.php > /dev/null <<EOF
<?php
http_response_code(200);
header('Content-Type: application/json');
echo json_encode(["status" => "OK", "message" => "Health check passed"]);
exit;
?>
EOF

# Registro de logs
echo "Instalação concluída!" >> /var/log/user_data.log