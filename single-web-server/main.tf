# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

variable "databricks_workspace" {
  type        = string
  description = "Name of the Databricks workspace"
  default     = "isee_perception"
}


resource "aws_vpc" "workspace-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "${var.databricks_workspace}_vpc"
  }
}


resource "aws_internet_gateway" "workspace-vpc-gw" {
  vpc_id = aws_vpc.workspace-vpc.id

  tags = {
    Name = "${var.databricks_workspace}_vpc_igw"
  }
}


resource "aws_route_table" "workspace-vpc-rt" {
  vpc_id = aws_vpc.workspace-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.workspace-vpc-gw.id
  }

  tags = {
    Name = "${var.databricks_workspace}_vpc_igw"
  }
}


resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.workspace-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1f"

  tags = {
    Name = "${var.databricks_workspace}_public"
  }
}


resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.workspace-vpc-rt.id
}


resource "aws_security_group" "sg" {
  name        = "${var.databricks_workspace}_allow_web_and_ssh"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.workspace-vpc.id

  ingress {
    description      = "HTTPS Traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP Traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH Traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "ICMP Traffic"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.databricks_workspace}_allow_web_and_ssh"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.public-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.sg.id]

  tags = {
    Name = "${var.databricks_workspace}_web_server_nic"
  }  
}

resource "aws_eip" "web_server_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.workspace-vpc-gw]

  tags = {
    Name = "${var.databricks_workspace}_eip"
  }
}

output "web_server_eip" {
  value = aws_eip.web_server_eip.public_ip
  description = "Web server elastic interface IP"
}

output "web_server_private_ip" {
  value = aws_instance.web_server_instance.private_ip
}


resource "aws_instance" "web_server_instance" {
  ami           = "ami-0cff7528ff583bf9a"
  instance_type = "t3.micro"
  availability_zone = "us-east-1f"

  key_name          = "isee-dev-andrei"
  network_interface {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
  }
  
  user_data = <<-EOF
    #! /bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "<h1>Deployed via Terraform again</h1>" | sudo tee /var/www/html/index.html
  EOF

  tags = {
    Name = "${var.databricks_workspace}_web_server"
  }  
}

