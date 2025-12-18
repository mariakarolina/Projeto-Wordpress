# Documentação do Projeto - WordPress na AWS com Docker

Este projeto tem como objetivo implementar um ambiente WordPress na AWS utilizando serviços gerenciados e escaláveis.






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
No console do EFS, clique em "Create file system".
- Selecione a VPC `wordpress-vpc`.
- Selecione as subnets privadas.
-  Configure o security group `EFS_WP`.
-   evise e crie o EFS.

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

## Configuração do Auto Scaling e CloudWatch 

## 1. Criar Alarme no CloudWatch

### 1.1 Acessar o AWS CloudWatch
1. Vá para o **AWS CloudWatch** e acesse **Alarmes**.
2. Clique em **Criar Alarme**.

### 1.2 Escolher a métrica
1. Selecione **EC2 → Auto Scaling → Metrics → CPUUtilization**.
2. Escolha o grupo **Auto Scaling Group do WordPress**

### 1.3 Configurar os alarmes

#### **Alarme de Scale-Out (Aumento de instância)**
- **Métrica**: CPUUtilization
- **Operador**: `> 70%`
- **Duração**: `60 segundos (teste) ou 300 segundos (produção)`
- **Ação**: Chamar a política **scaleinpolicy** do Auto Scaling

#### **Alarme de Scale-In (Redução de instância)**
- **Métrica**: CPUUtilization
- **Operador**: `< 30%`
- **Duração**: `300 segundos (recomendado)`
- **Ação**: Chamar a política **scaleoutpolicy** do Auto Scaling

#### Criar um Tópico SNS para Notificações
1. Acesse o **SNS** no console da AWS.
2. Clique em **Criar tópico** e escolha o tipo de tópico que preferir (ex: padrão).
3. Configure o nome do tópico e as permissões necessárias.
4. Clique em **Criar tópico**.

#### Adicionar uma Assinatura ao Tópico SNS
1. No console do SNS, selecione o tópico que você criou.
2. Clique em **Criar assinatura**.
3. Escolha o **protocol** como `Email`.
4. Insira o **endereço de e-mail** que receberá as notificações.
5. Clique em **Criar assinatura**.
6. Verifique seu e-mail e confirme a assinatura.

#### Associar o Tópico SNS aos Alarmes do CloudWatch
1. No console do **CloudWatch**, acesse **Alarmes**.
2. Selecione o alarme que você criou (por exemplo, o alarme de Scale-Out ou Scale-In).
3. Clique em **Editar**.
4. Na seção **Ações**, marque a opção para **Publicar no tópico SNS**.
5. Selecione o tópico SNS que você criou anteriormente.
6. Clique em **Salvar** para aplicar as alterações.


## 2. Configurar o Auto Scaling Group

### 2.1 Criar um Launch Configuration
1. No console do **EC2**, vá para **Launch Configurations**.
2. Crie um **Launch Configuration** usando a **mesma AMI e tipo de instância** da EC2 privada.
3. Associe o **Security Group EC2_WP**.
4. No **User Data**, insira o mesmo script da EC2 privada.

### 2.2 Criar o Auto Scaling Group
1. No console do **EC2**, vá para **Auto Scaling Groups**.
2. Crie um **Auto Scaling Group** usando o Launch Configuration criado.
3. **Selecione as subnets privadas**.
4. Configure:
   - **Tamanho desejado**: `2`
   - **Mínimo**: `2`
   - **Máximo**: `4`
5. Configure as **políticas de escalonamento** baseadas no uso da CPU.
6. **Associe o Load Balancer (CLB) ao Auto Scaling Group**.

## 3. Criar a Regra no Auto Scaling

### 3.1 Acessar o Auto Scaling Groups
1. No console do **EC2**, vá para **Auto Scaling Groups**.
2. Selecione o grupo **AS-wp**.
3. Vá até a aba **Scaling Policies** e clique em **Criar Política**.

### 3.2 Configurar a Política de Escalonamento

#### **Política de Scale-Out (Adicionar instância)**
- **Adicionar 1 instância** quando **CPU > 70%**
- **Cooldown**: `60s (teste) ou 300s (produção)`

#### **Política de Scale-In (Remover instância)**
- **Remover 1 instância** quando **CPU < 30%**
- **Cooldown**: `60s (teste) ou 300s (produção)`

4. Associe as políticas aos alarmes criados no CloudWatch.

## Testar e Monitorar
- Acesse o **CloudWatch Metrics** para verificar a utilização da CPU.
- No **EC2 → Auto Scaling Groups → Activity History**, veja o histórico de eventos.


## Criar um Dashboard no CloudWatch
1. No console do **CloudWatch**, clique em **Dashboards**.
2. Clique em **Criar dashboard**.
3. Dê um nome ao seu dashboard e clique em **Criar**.
4. Adicione widgets ao seu dashboard:
   - **Métricas de Utilização de CPU**
   - **Métricas do EFS**: Adicione as métricas relevantes do EFS.
   - **Métricas do RDS**: Adicione as métricas relevantes do RDS.
5. Para adicionar alarmes ao dashboard:
   - Clique em **Adicionar widget**.
   - Selecione **Alarmes**.
   - Escolha os alarmes que você deseja monitorar.
   - Clique em **Adicionar ao dashboard**.
6. Configure cada widget de acordo com suas preferências de visualização.
7. Clique em **Salvar dashboard**.

---

![image](https://github.com/user-attachments/assets/1f40443f-4c3b-4d8f-8937-5235d6a89d30)




![image](https://github.com/user-attachments/assets/3c688624-35ca-476f-bd9d-493bd9d49ebc)





![image](https://github.com/user-attachments/assets/690d23c8-16bc-44f4-8bc4-d3fda50e7963)


