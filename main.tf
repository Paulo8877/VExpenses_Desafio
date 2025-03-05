provider "aws" {
  region = "us-east-1"
}

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

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  filename = "./${var.projeto}-${var.candidato}-key.pem"
  content  = tls_private_key.ec2_key.private_key_pem
  file_permission = "0600"
}

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