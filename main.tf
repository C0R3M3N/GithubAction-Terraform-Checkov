
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #   version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAR3HUOA6LCFMHU7X5"
  secret_key = "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"
}


# Create a VPC
resource "aws_vpc" "main-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "main-gw" {
  vpc_id = aws_vpc.main-vpc.id

  tags = {
    Name = "main-gw"
  }
}

# Create Route Table
resource "aws_route_table" "main-route-table" {
  vpc_id     = aws_vpc.main-vpc.id
  depends_on = [aws_vpc.main-vpc, aws_internet_gateway.main-gw]

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.main-gw.id
  }

  tags = {
    Name = "main-r-table"
  }
}

# Create subnet
resource "aws_subnet" "main-subnet" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "main-subnet"
  }
}

#
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main-subnet.id
  route_table_id = aws_route_table.main-route-table.id
}

# Security
resource "aws_security_group" "allow_wed" {
  name        = "allow_wed_traffic"
  description = "Allow wed inbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.allow_wed.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_wed.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_wed.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_wed.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.allow_wed.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_network_interface" "main-nic" {
  subnet_id       = aws_subnet.main-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_wed.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }
}

resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.main-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.main-gw, aws_network_interface.main-nic, aws_instance.web-server-instance]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

resource "aws_instance" "web-server-instance" {
  ami               = "ami-0866a3c8686eaeeba"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1b"
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.main-nic.id
  }


  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server-2"
  }
}
