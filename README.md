# README - Desafio Prático da VExpenses

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

# Melhorias a Serem Feitas no Terraform

## Melhoria do Provedor AWS

```hcl
terraform {
  required_version = ">= 1.11.1"
}

provider "aws" {
  region = "us-east-1"
}

```
**Comentário:**
- Para evitar problemas de atualizações do próprio Terraform, busquei a versão mais recente dele na plataforma da HashiCorp.

---

## Melhoria das Variáveis

```hcl
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "Seu Nome"
}
```

**Comentário:**
- Sem mudanças aqui.

---

## Melhoria das chaves SSH

```hcl
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  filename         = "./${var.projeto}-${var.candidato}-key.pem"
  content          = tls_private_key.ec2_key.private_key_pem
  file_permission  = "0600"
}
```

**Comentário:**
- Aqui temos a criação de um arquivo local para armazenar a chave privada, definindo também permissões de acesso apenas para pessoas que possuem permissão local de administrador definido pelo “0600”.

---

## Melhoria da VPC

```hcl
variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_dns_support" {
  description = "Enable DNS support for the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames for the VPC"
  type        = bool
  default     = true
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
```

**Comentário:**
- Criação de uma variável para “cidr_block” que pode permitir usos futuros no código. 
- O parâmetro “enable_dns_hostnanes” agora é controlado por variável, permitindo a personalização da resolução do DNS. 
- Essa configuração personalizada do DNS permite a empresa ajustar o código conforme as necessidades do ambiente empresarial ou requisitos de segurança. 

---

## Melhoria da Subnet

```hcl
variable "cidr_block_subnet" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "us-east-1a"
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.cidr_block_subnet
  availability_zone = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```

**Comentário:**
- Criacao da variável “cidr_block_subnet” para garantir uma maior flexibilidade e grau de adaptação as necessidades da empresa. 
- A zona de disponibilidade (caso não haja) vai ser redirecionada para primeira zona AWS disponível na região, garantindo o funcionamento em caso de falhas da AWS. 
- Esse código torna a criação da subnet mais flexível, podendo ser adaptada para os diferentes níveis estruturais da empresa. 

---

## Melhoria do Gateway 

```hcl
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-private_route_table"
  }
}

resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-private_association"
  }
}

resource "aws_nat_gateway" "main_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-nat_gateway"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-eip"
  }
}
```

**Comentário:**
- As instâncias privadas foram configuradas em sub-redes que não têm acesso direto à internet. Isso melhora a segurança da infraestrutura, uma vez que reduz os possíveis ataques. 
- A tabela de rotas da sub-rede privada não contém rota para `0.0.0.0/0`, evitando exposição externa (que foi o principal erro identificado). 
- Para as instâncias privadas que necessitam de acesso à internet, como para atualizações de pacotes, foi configurado um NAT Gateway. Este gateway oferece saída para a internet sem expor as instâncias diretamente.
- Criação da regra de entrada SSH, configurada para permitir acesso de qualquer lugar (`0.0.0.0/0`), mas como eu não tenho acesso aos IPs da empresa, recomendo a adaptar essa parte aos IPs internos da empresa. 
- Criação das regras de saída, que permite todo tráfego de saída da VPC. Dependendo das necessidades, você pode querer restringir isso para casos específicos, como permitir apenas o tráfego de saída para o NAT Gateway ou outros recursos de rede, isso novamente vai de acordo com a empresa. 
- Embora a configuração de SSH esteja aberta para qualquer origem, em organizações é altamente recomendável restringir o acesso SSH apenas para endereços IPs confiáveis. 
- A tabela de rotas privada não tem acesso direto à internet, garantindo que apenas instâncias necessárias sejam expostas à internet.

---

## Melhoria nas Rotas das Tabelas Associadas

```hcl
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name        = "${var.projeto}-${var.candidato}-route_table_association"
    Environment = "production"
    Purpose     = "public"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main_nat.id
  }

  tags = {
    Name        = "${var.projeto}-${var.candidato}-private_route_table"
    Environment = "production"
    Purpose     = "private"
  }
}
```

**Comentário:**
- A melhoria da associação da tabela de rotas à sub-rede garante que instancias nessa sub-rede tenham acesso à internet ou outras redes de forma adequada.
- A inclusão das tags “environment” e “purpose” ajuda a organizar os recursos de maneira mais eficiente, principalmente no ambiente da organização que lida com múltiplos recursos e diferentes finalidades entre eles. 
- A rota para 0.0.0.0/0 é direcionada ao NAT Gateway, permitindo que as instâncias privadas acessem a internet, mas sem serem expostas diretamente a ela, solucionando assim um dos problemas de segurança relacionados a exposição das instancias privadas. 
- Mudanças nas regras de entrada e saída para permitir apenas o acesso por IPs específicos. Esses IPs devem ser adaptados conforme a necessidade da empresa (foi colocado os IPs gerados anteriormente).

---

## Melhoria do Grupo de Segurança 

```hcl
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH apenas em ambientes da organização e trafego de saida controlado"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada (Ingress)
ingress {
  description      = "Allow SSH from a specific IP range"
  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  cidr_blocks      = ["10.0.1.0/24"]  
  ipv6_cidr_blocks = ["::/0"] 
}

# Regras de saída (Egress)
egress {
  description      = "Allow egress to specific internal services"
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["10.0.0.0/16"]  
  ipv6_cidr_blocks = ["::/0"]  
  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
 }
}
```

**Comentário:**
- Mudanças nas regras de entrada e saída para permitir apenas o acesso por IPs específicos. Esses IPs devem ser adaptados conforme a necessidade da empresa.

---

## Melhoria da AWS AMI Debian 12

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
              sudo apt-get update -y
              sudo apt-get upgrade -y
              sudo apt-get install -y nginx
              sudo systemctl enable nginx
              sudo systemctl start nginx
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```

**Comentário:**
- Antes o usuário não tinha as permissões corretas por erros na utilização dos comandos Linux. Agora foram adicionadas novas linhas de código que possibilitam a instalação e atualização corretas dos pacotes.
- Aplicação de Super Usuário aos comandos Linux, que é representado por “sudo”. Isso deve ser capaz de fornecer aos comandos permissão de “root”, podendo realizar qualquer modificação no sistema, incluindo atualizações.
- sudo apt-get install -y nginx: Instala o Nginx.
- sudo systemctl enable nginx: Habilita o Nginx para iniciar automaticamente com o sistema.
- sudo systemctl start nginx: Inicia o serviço do Nginx.

---

## Melhoria nos Outputs

```hcl
resource "local_file" "private_key" {
  filename         = "./${var.projeto}-${var.candidato}-key.pem"
  content          = tls_private_key.ec2_key.private_key_pem
  file_permission  = "0600"
}

output "private_key_file" {
  description = "Chave privada para acessar a instância EC2"
  value       = local_file.private_key.filename
  sensitive   = true
}

variable "expose_public_ip" {
  description = "Determina se o IP público da instância será exposto"
  type        = bool
  default     = false
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
  sensitive   = true
  condition   = var.expose_public_ip
}
```

**Comentário:**
- Criação de um arquivo local para armazenar a chave privada, no qual so vai ter acesso pessoas que possuem permissões locais de administrador definido pelo “0600”. 
- Criação de uma variável para controlar se o IP publico será exposto ou não. Aqui deve ser adicionado alguma outra logica em caso de exposição. Aqui pode ser adaptado algum sistema de gerenciamento de chaves para esconder ela em caso de exposição indevida.  

---

# Conclusão e Resultados Esperados

O script Terraform elaborado para a criação e configuração da infraestrutura na AWS foi modificado e melhorado com o objetivo de garantir o correto funcionamento do codigo em execução, as melhorias foram realizadas visando corrigir erros nos recursos de VPC, Subnet, Grupo de Segurança, Key Pair e da instância EC2.

## Criação de VPC e Sub-redes:
- A infraestrutura agora é configurada com uma VPC customizada, incluindo sub-redes públicas e privadas, podendo se adaptar aos reais recursos de rede a serem utilizados. 
- A alocação de blocos CIDR adequados para a VPC e sub-redes garante que a comunicação interna seja eficiente, enquanto a comunicação externa seja controlada por uma gateway de internet (IGW) e um NAT Gateway.

## Controle de Acesso com Grupos de Segurança:
- A implementação de um grupo de segurança (Security Group) restringe o acesso SSH à instância EC2, permitindo apenas conexões provenientes da sub-rede interna, o que melhora a segurança da aplicação.
- As regras de egress estão configuradas para permitir tráfego para a rede interna, sem expor desnecessariamente a instância ao tráfego externo.

## Instância EC2 com Nginx:
- Uma instância EC2 foi provisionada usando a imagem Debian 12, com a instalação automática do servidor web Nginx. O servidor é configurado para iniciar automaticamente, proporcionando uma infraestrutura pronta para servir aplicações web desde o primeiro momento.
- O processo de provisionamento da instância também inclui o comando de atualização do sistema, garantindo que a máquina esteja com os pacotes mais recentes e seguros.

## Configuração de IP Público e Roteamento:
- A instância EC2 foi configurada para ter um IP público associado, o que permite o acesso direto à aplicação Nginx através de um navegador web, caso o acesso ao IP público esteja habilitado.
- O roteamento foi aprimorado para permitir que a instância EC2, que reside em uma sub-rede privada, possa acessar a internet via NAT Gateway. Isso garante que a instância tenha a capacidade de acessar recursos externos de maneira segura, sem expor diretamente o IP da sub-rede privada.

## Execução Automatizada:
- A configuração de `user_data` garante que todas as ações de instalação e configuração sejam realizadas automaticamente durante a inicialização da instância, sem a necessidade de intervenção manual.

# Considerações Finais:
Agradeço imensamente pela oportunidade de trabalhar neste desafio. Com toda a certeza, este projeto formentou em mim uma motivação para aprofundar meus conhecimentos em Terraform, em estruturas da AWS e em redes para o cumprimento deste, e de futuros desafios. 
