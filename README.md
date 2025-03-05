# README - Infraestrutura AWS com Terraform

## Resumo do Código

O arquivo Terraform denominado `main.tf` define a criação de uma infraestrutura básica na AWS (Amazon Web Services) utilizando recursos como VPC, SubNet, Grupo de Segurança, Key Pair e uma instância EC2.

---

## Provedor AWS

```hcl
provider "aws" {
  region = "us-east-1"
}
```
**Comentário:**
Define a região onde os recursos serão provisionados pelo servidor AWS. 

---

## Definição de Variáveis

```hcl
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}
```
**Comentário:**
Define variáveis do tipo string para receber valores do projeto e do candidato.

---

## Geração de Chave SSH

```hcl
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}
```
**Comentário:**
- Gera um par de chaves SSH para autenticação segura na AWS.
- A chabe privada é do tipo RSA, que usa duas chaves para criptografar e descriptografar mensagens.
- Criação de uma chave publica associada a chave privada. 

---

## Definição da Rede (VPC, Subnet, Internet Gateway, Rota)

### Definição da VPC
```hcl
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}
```
**Comentário:**
- Cria uma VPC com a faixa de IP `10.0.0.0/16`.

### Definição da Subnet Pública
```resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```
**Comentário:**
- Cria uma subnet publica dentro da VPC com faixa de ip de “10.0.1.0/24”.

### Definição do Gateway na AWS
```hcl
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}
```
**Comentário:**
- Cria um gateway de internet permitindo comunicação com a AWS.

### Definição da Tabela de Rotas
```hcl
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}
```
**Comentário:**
- Permite tráfego externo para a rede configurada de forma segura.
- Existe uma falha de segurança aqui.

### Associação da Tabela de Rotas
```hcl
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}
```
**Comentário:**
- Associa a tabela de rotas à subnet criada anteriormente.

---

## Grupo de Segurança

```hcl
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de qualquer lugar e todo o tráfego de saída"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
```
**Comentário:**
- O grupo de segurança permite acesso SSH irrestrito, o que pode representar um risco de segurança.

---

## Definição e Busca da AWS AMI Debian 12

```hcl
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}
```
**Comentário:**
- Obtém a imagem mais recente do Debian 12 na AWS.

---

## Definição da Instância EC2

```hcl
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```
**Comentário:**
- Cria a instância EC2 baseada na AMI do Debian 12.
- Define recursos de armazenamento e processamento para maquina virtual. 
- O script `user_data` apenas atualiza o sistema, mas não instala ou configura serviços como o Nginx.

---

## Geração dos Outputs

```hcl
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
```
**Comentário:**
- O output expõe a chave privada, o que pode comprometer a segurança.
- Também expõe a chave pública. 

---

## Falhas de Segurança
- O código define uma infraestrutura funcional na AWS, mas possui alguns problemas de segurança:
  - O grupo de segurança permite acesso irrestrito à porta SSH.
  - A chave privada pode ser acessada por terceiros.
  - A chave publica é exposta aos usuarios. 
  - O script `user_data` não instala e configura serviços essenciais, como o Nginx.
