# Documentação do Projeto - Deploy do WordPress na AWS com Docker

## Visão Geral

Este projeto configura um ambiente AWS para o deploy do WordPress usando Docker. O ambiente inclui VPC, subnets, EC2, RDS, EFS e um Classic Load Balancer (CLB). O WordPress é executado em uma instância privada EC2, com acesso ao banco de dados RDS e armazenamento compartilhado via EFS.

## Recursos Criados

### **1. Virtual Private Cloud (VPC)**

Criação de uma **VPC and more** para isolar os recursos da infraestrutura.

| Configuração | Valor |
|-------------|-------|
| CIDR | `10.0.0.0/16` |
| DNS Hostnames | Habilitados |
| Número de zonas (AZs) | 2 |
| Número de subnets | 2 públicas e 2 privadas |
| NAT Gateways | 1 por AZ |
| VPC Endpoints | Nenhum |

### **2. Subnets**

- **Duas subnets públicas** 
- **Duas subnets privadas** 

### **3. Internet Gateway (IGW) e NAT Gateway**

- **IGW**: Permite o acesso à internet para os recursos na subnet pública.
- **NAT Gateway**: Permite que instâncias privadas tenham acesso à internet para downloads e updates.

### **4. Security Groups (SGs)**

Criamos grupos de segurança para restringir o acesso aos recursos:

| Security Group | Regras de Entrada | Regras de Saída |
|---------------|------------------|----------------|
| **LB_wp** | HTTP e HTTPS -> Qualquer IPV4 | Qualquer destino |
| **EC2_wp** | HTTP e HTTPS -> LB_wp <br> SSH -> Qualquer IPV4 (Somente para testes) | Padrão |
| **RDS_wp** | MySQL -> EC2_wp | Padrão |
| **EFS_wp** | NFS -> EC2_wp| Padrão |

### **5. Banco de Dados no Relational Database Service (RDS)**

O serviço web WordPress necessita de um banco de dados para armazenar suas informações, logs e se manter de forma estática. Para isso, foi configurado um banco de dados MySQL dentro do **nível gratuito (Free Tier)** do RDS.

Como serão utilizadas instâncias com **subnets privadas**, foi necessário criar um grupo de subnets contendo apenas as subnets privadas dentro do RDS.

#### **5.1. Criação do Grupo de Sub-redes Privadas**

No serviço RDS:

- Acesse **Subnet Groups** e clique em **Create DB subnet group**.
- Preencha os seguintes campos:
  - **Nome:** `private-subnet-group`
  - **Descrição:** Grupo com sub-redes privadas da VPC
  - **VPC:** `wordpress-vpc`
  - Escolha as duas **Availability Zones** associadas à VPC.
  - Selecione as **subnets privadas**.
- Clique em **Criar** para finalizar.

#### **5.2. Configuração do Banco de Dados RDS**

| Configuração | Valor |
|-------------|-------|
| Método de configuração | Padrão |
| Tipo de banco de dados | MySQL |
| Modelo | Free Tier |
| Identificador da instância do BD | `wordpress-db` |
| Nome de usuário mestre | `admin` |
| Senha | ************ |
| Instância | `db.t3.micro` |
| Dimensionamento automático de armazenamento | Desativado |

- **VPC:** `wordpress-vpc`
- **Grupo de sub-rede do BD:** `private-subnet-group` 
- **Acesso público:** Não
- **Grupo de Segurança:** `SG-RDS`

#### **Configurações Adicionais**

- **Nome inicial do banco de dados:** `wordpress`
- **Backup automático:** Desativado
- **Criptografia:** Desativada

### **6. EFS (Elastic File System)**

Criamos um **EFS** para armazenar arquivos compartilhados entre instâncias.

- Montado na EC2 privada para armazenar uploads do WordPress

### **7. EC2 Pública (Bastion Host)**

Criamos uma instância EC2 pública que serve como Bastion Host para acessar a EC2 privada.

- AMI: Ubuntu
- Tipo da instância: `t3.micro`
- Conectividade: SSH (porta 22)

### **8. EC2 Privada (WordPress com Docker)**

Criamos uma instância privada para hospedar o WordPress usando Docker.

- AMI: Ubuntu
- Tipo da instância: `t3.micro`
- **Script de inicialização**:
  - Instala Docker e Docker Compose
  - Baixa e inicia contêiner do WordPress e MySQL
  - Configura conexão com o banco de dados RDS e monta o EFS

### **9. Classic Load Balancer (CLB)**

Criamos um **CLB** para distribuir tráfego para a EC2 privada.

- Listeners: HTTP (porta 80)
- Health Checks configurados para monitorar a instância

## Como Utilizar

### **Passo 1: Criar os Recursos AWS**

Os recursos podem ser criados manualmente ou via Terraform/CloudFormation.

### **Passo 2: Conectar no Bastion Host**

```sh
ssh -i chave.pem ec2-user@IP-BASTION
```

### **Passo 3: Conectar na EC2 Privada**

A partir do Bastion Host:

```sh
ssh -i chave.pem ec2-user@PRIVATE-IP-EC2
```

### **Passo 4: Verificar o Docker**

```sh
docker ps
```

### **Passo 5: Acessar o WordPress**

Abra o navegador e acesse:

```
http://DNS-DO-LOAD-BALANCER
```

---

## **Próximos Passos**

- Configurar Auto Scaling para maior disponibilidade
- Adicionar SSL/TLS no Load Balancer
- Melhorar segurança com IAM e roles específicas

