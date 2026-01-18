provider "aws" {
  region = "ap-south-1"
}

variable env_prefix {}
variable cird_block {}
variable public_key {}
variable instance_type {}
variable available_zone {}

resource "aws_vpc" "ansible-vpc" {
  cidr_block = var.cird_block
  tags = {
    Name="${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "ansible-subnet" {
  vpc_id     = aws_vpc.ansible-vpc.id
  cidr_block = var.cird_block

  tags = {
    Name="${var.env_prefix}-subnet"
  }
}

resource "aws_route_table" "ansible-rtb" {
  vpc_id = aws_vpc.ansible-vpc.id

  # since this is exactly the route AWS will create, the route will be adopted
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ansible-igw.id
  }
}

resource "aws_internet_gateway" "ansible-igw" {
  vpc_id = aws_vpc.ansible-vpc.id

  tags = {
    Name="${var.env_prefix}-igw"
  }
}

resource "aws_route_table_association" "ansible-rtb-association" {
  subnet_id      = aws_subnet.ansible-subnet.id
  route_table_id = aws_route_table.ansible-rtb.id
}

resource "aws_security_group" "ansible-sg" {
  vpc_id = aws_vpc.ansible-vpc.id

  ingress{
    from_port=22
    to_port=22
    protocol="tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress{
    from_port=80
    to_port=80
    protocol="tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress{
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
     Name="${var.env_prefix}-sg"
  }
  
}

data "aws_ami" "image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_key_pair" "ssh" {
  key_name = "my_key"
  public_key = var.public_key
  
}

resource "aws_instance" "myapp-image" {
  ami= data.aws_ami.image.id
  instance_type = var.instance_type

  subnet_id =aws_subnet.ansible-subnet.id
  vpc_security_group_ids =[aws_security_group.ansible-sg.id]
  availability_zone = var.available_zone
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh.key_name

  tags={
    name="${var.env_prefix}-ec2"
  }
}