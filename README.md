# Documentação do Projeto - WordPress na AWS com Docker

## Visão Geral

Este projeto configura um ambiente AWS para o deploy do WordPress usando Docker. O ambiente inclui VPC, subnets, EC2, RDS, EFS e um Classic Load Balancer (CLB). O WordPress é executado em uma instância privada EC2, com acesso ao banco de dados RDS e armazenamento compartilhado via EFS.

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

### **5. Configuração do Banco de Dados no Relational Database Service (RDS)**

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

#### **5.1. Configuração do Acesso**
- **VPC:** `wordpress-vpc`
- **Grupo de sub-rede do BD:** `private-subnet-group`
- **Acesso público:** Não
- **Grupo de Segurança:** `SG-RDS`

### **6. Configuração do EFS (Elastic File System)**

Crie um **EFS** para armazenar arquivos compartilhados entre instâncias.

- Monte o EFS na EC2 privada para armazenar uploads do WordPress.



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
# Cole aqui o script de inicialização
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

Crie um **CLB** para distribuir tráfego para a EC2 privada.

- Listeners: HTTP (porta 80)
- Configure Health Checks para monitorar a instância.

### **9. Testando a Aplicação**
Após configurar todos os recursos, acesse o WordPress pelo Load Balancer:

```
http://DNS-DO-LOAD-BALANCER
```

---

## **Próximos Passos**

- Configurar Auto Scaling para maior disponibilidade
- Adicionar SSL/TLS no Load Balancer
- Melhorar segurança com IAM e roles específicas

