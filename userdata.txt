#!/bin/bash

# Atualiza pacotes do sistema
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala dependências
sudo apt-get install -y docker.io git nfs-common mysql-client binutils rustc cargo pkg-config libssl-dev

# Instala e configura o EFS Utils
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
sudo apt-get install -y ./build/amazon-efs-utils*deb

# Criar diretório para o EFS
sudo mkdir -p /mnt/efs

# Configuração do EFS
EFS_ID="fs-072b3298578b52d6a"
REGION="us-east-1"

# Montar o EFS usando efs-utils
sudo mount -t efs -o tls fs-072b3298578b52d6a.efs.us-east-1.amazonaws.com:/ /mnt/efs

# Adicionar montagem ao /etc/fstab para persistência
echo "fs-072b3298578b52d6a.efs.us-east-1.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Criar diretório do WordPress
PROJETOPRESS=/mnt/efs/wordpress
sudo mkdir -p $PROJETOPRESS
sudo chmod -R 777 $PROJETOPRESS
cd $PROJETOPRESS

# Criar docker-compose.yml
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
      WORDPRESS_DB_HOST: 
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: ""
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - /mnt/efs/projetopress:/var/www/html
EOL

# Iniciar WordPress com Docker Compose
sudo docker-compose up -d

# Criar arquivo de Health Check
echo "Criando o arquivo healthcheck.php..."
sudo tee /mnt/efs/projetopress/healthcheck.php > /dev/null <<EOF
<?php
http_response_code(200);
header('Content-Type: application/json');
echo json_encode(["status" => "OK", "message" => "Health check passed"]);
exit;
?>
EOF


if sudo docker exec -i wordpress ls /var/www/html/healthcheck.php > /dev/null 2>&1; then
  echo "Arquivo healthcheck.php criado com sucesso!"
else
  echo "Falha ao criar o arquivo healthcheck.php."
fi

echo "Instalação concluída!"
