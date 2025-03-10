# Documentação do Projeto - WordPress na AWS com Docker

## Visão Geral

Este projeto configura um ambiente AWS para o deploy do WordPress usando Docker. O ambiente inclui VPC, subnets, EC2, RDS, EFS e um Classic Load Balancer (CLB). O WordPress é executado em uma instância privada EC2, com acesso ao banco de dados RDS e armazenamento compartilhado via EFS.


![image](https://github.com/user-attachments/assets/d50b2031-7a44-40b0-8f97-9efc5beba1b7)



## Recursos Criados

### **1. Virtual Private Cloud (VPC)**

Você deve criar uma **VPC and more** para isolar os recursos da infraestrutura.

| Configuração | Valor |
|-------------|-------|
| CIDR | `10.0.0.0/16` |
| DNS Hostnames | Habilitados |
| Número de zonas (AZs) | 2 |
| Número de subnets | 2 públicas e 2 privadas |
| NAT Gateways | 1 por AZ |
| VPC Endpoints | Nenhum |

### **2. Subnets**

- **Crie duas subnets públicas** 
- **Crie duas subnets privadas** 

### **3. Internet Gateway (IGW) e NAT Gateway**

- **Crie um IGW**: Ele permite o acesso à internet para os recursos na subnet pública.
- **Crie um NAT Gateway**: Ele permite que instâncias privadas tenham acesso à internet para downloads e updates.

### **4. Security Groups (SGs)**

Você deve configurar os grupos de segurança para restringir o acesso aos recursos:

| Security Group | Regras de Entrada | Regras de Saída |
|---------------|------------------|----------------|
| **LB_WP** | HTTP e HTTPS -> Qualquer IPV4 | Qualquer destino |
| **EC2_WP** | HTTP e HTTPS -> LB_WP <br> SSH -> Qualquer IPV4 (Somente para testes) | Padrão |
| **RDS_WP** | MySQL -> EC2_WP | Padrão |
| **EFS_WP** | NFS -> EC2_WP | Padrão |

### 5. Configuração do Banco de Dados no Relational Database Service (RDS)

#### 5.1. Criação do Grupo de Sub-redes Privadas do RDS

- Na aba lateral esquerda do serviço RDS, acesse **Subnet groups** e clique em **Create DB subnet group**.
- Preencha todos os campos:
  - **Nome**: `private-subnet-group`
  - **Descrição**: Grupo com sub-redes privadas da VPC
  - **VPC**: `wordpress-vpc`
  - Escolha as duas Availability Zones que você criou juntamente com a VPC.
  - Escolha as sub-redes privadas de cada zona.
- Clique em **Criar** para finalizar a criação do grupo de sub-redes privadas.

| Configuração                             | Valor              |
|-----------------------------------------|--------------------|
| Método de configuração                  | Padrão             |
| Tipo de banco de dados                  | MySQL              |
| Modelo                                  | Free Tier          |
| Identificador da instância do BD        | `wordpress-db`     |
| Nome de usuário mestre                   | `admin`            |
| Senha                                   | ************       |
| Instância                               | `db.t3.micro`      |
| Dimensionamento automático de armazenamento | Desativado     |
| Nome inicial do banco de dados          | `wordpress`        | <!-- Importante para a imagem do WordPress subir sem problemas. -->
| Backups automatizados                   | Desativado         |
| Criptografia                            | Desativada         |

#### 5.2. Configuração do Acesso

- **VPC:** `wordpress-vpc`
- **Grupo de sub-rede do BD:** `private-subnet-group`
- **Acesso público:** Não
- **Grupo de Segurança:** `SG-RDS`


### 6. Configuração do EFS (Elastic File System)

Crie um **EFS** para armazenar arquivos compartilhados entre instâncias.

6.1  **Crie um EFS:**
    * No console do EFS, clique em "Create file system".
    * Selecione a VPC `wordpress-vpc`.
    * Selecione as subnets privadas.
    * Configure o security group `EFS_WP`.
    * Revise e crie o EFS.

### **7. Configuração das Instâncias EC2**

O projeto requer duas instâncias EC2:
1. **Instância pública** (Bastion Host) para acessar a instância privada.
2. **Instância privada** para rodar o WordPress.

| Configuração | Instância Pública (Bastion) | Instância Privada (WordPress) |
|-------------|------------------------|--------------------------|
| AMI | Ubuntu 22.04 | Ubuntu 22.04 |
| Tipo | `t3.micro` | `t3.micro` |
| Subnet | Pública | Privada |
| VPC | `wordpress-vpc` | `wordpress-vpc` |
| Security Group | `EC2_WP` | `EC2_WP` |
| Conectividade | SSH (porta 22) | Apenas via Bastion Host |

#### **5.1. Criar a Instância Privada**
Você deve configurar a instância privada para rodar o WordPress:
- Escolha a **AMI Ubuntu 22.04**.
- Selecione a **subnet privada** dentro da VPC `wordpress-vpc`.
- Associe o **grupo de segurança EC2_WP**.
- Script no **User Data**

```sh
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
EFS_ID=""
REGION="us-east-1"

# Montar o EFS usando efs-utils
sudo mount -t efs -o tls fs-.us-east-1.amazonaws.com:/ /mnt/efs

# Adicionar montagem ao /etc/fstab para persistência
echo "fs-efs.us-east-1.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

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
```

#### **5.2. Criar a Instância Pública (Bastion Host)**
O Bastion Host serve para acessar a instância privada.
- Escolha a **Ubuntu**.
- Selecione a **subnet pública** dentro da VPC `wordpress-vpc`.
- Associe o **grupo de segurança EC2_WP**.

#### **5.3. Acessar a Instância Privada via Bastion Host**
Para acessar a instância privada, siga os passos:

1️⃣ **Conecte-se ao Bastion Host**
```sh
ssh -i chave.pem Ubuntu@IP-BASTION
```

2️⃣ **A partir do Bastion, conecte-se à Instância Privada**
```sh
ssh -i chave.pem ubuntu@PRIVATE-IP-EC2
```

3️⃣ **Verifique se o Docker está rodando**
```sh
docker ps
```

### **8. Configuração do Classic Load Balancer (CLB)**
No console do EC2, clique em "Load Balancers".
- Clique em "Create Load Balancer".
- Selecione "Classic Load Balancer".
- Configure o nome, VPC e listeners (HTTP porta 80).
- Configure o security group `LB_WP`.
- Configure Health Checks para monitorar a instância EC2 privada.
- Adicione a instância EC2 privada ao CLB.
- Revise e crie o CLB.

### **9. Testando a Aplicação**
Após configurar todos os recursos, acesse o WordPress pelo Load Balancer:

```
http://DNS-DO-LOAD-BALANCER
```

---

## 10. Configuração do Auto Scaling
No console do EC2, clique em "Launch Configurations".
-  Crie um Launch Configuration usando a mesma AMI e tipo de instância da EC2 privada.
- Associe o security group `EC2_WP`.
- Use o mesmo script de User Data da EC2 privada.

### **10.1 o console do EC2, clique em "Auto Scaling Groups".**
- Crie um Auto Scaling Group usando o Launch Configuration criado.
- Selecione as subnets privadas.
- Configure o tamanho desejado, mínimo e máximo do grupo.
- Configure as políticas de escalonamento (por exemplo, com base no uso da CPU).
- Associe o CLB ao Auto Scaling Group.



![image](https://github.com/user-attachments/assets/3c688624-35ca-476f-bd9d-493bd9d49ebc)





![image](https://github.com/user-attachments/assets/690d23c8-16bc-44f4-8bc4-d3fda50e7963)


