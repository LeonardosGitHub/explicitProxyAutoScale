provider "aws" {
  region = var.aws_region
}

########################################
# BUILDING THE VPC FOR THE ENVIRONMENT #
########################################

resource "aws_vpc" "terraform-vpc-LOBexample" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags = {
    Name = "terraform_${var.emailid}"
  }
}

#################################################
# BUILDING SUBNETS FOR VPC IN TWO DIFFERENT AZ'S#
#################################################

resource "aws_subnet" "f5-management-a" {
  vpc_id                  = aws_vpc.terraform-vpc-LOBexample.id
  cidr_block              = "10.0.101.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "terraform_management"
  }
}

resource "aws_subnet" "f5-management-b" {
  vpc_id                  = aws_vpc.terraform-vpc-LOBexample.id
  cidr_block              = "10.0.102.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name = "terraform_management"
  }
}

resource "aws_subnet" "public-a" {
  vpc_id                  = aws_vpc.terraform-vpc-LOBexample.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "terraform_public"
  }
}

resource "aws_subnet" "private-a" {
  vpc_id                  = aws_vpc.terraform-vpc-LOBexample.id
  cidr_block              = "10.0.100.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "terraform_private"
  }
}

resource "aws_subnet" "public-b" {
  vpc_id                  = aws_vpc.terraform-vpc-LOBexample.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name = "terraform_public"
  }
}

resource "aws_subnet" "private-b" {
  vpc_id                  = aws_vpc.terraform-vpc-LOBexample.id
  cidr_block              = "10.0.200.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name = "terraform_private"
  }
}

######################################
# BUILDING INTERNET GATEWAY & ROUTING#
######################################

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.terraform-vpc-LOBexample.id

  tags = {
    Name = "terraform_internet-gateway"
  }
}

resource "aws_route_table" "rt1" {
  vpc_id = aws_vpc.terraform-vpc-LOBexample.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "terraform_default_route"
  }
}

resource "aws_main_route_table_association" "association-subnet" {
  vpc_id         = aws_vpc.terraform-vpc-LOBexample.id
  route_table_id = aws_route_table.rt1.id
}

###########################################
# BUILDING SECURITY GROUP FOR WEB SERVERS #
###########################################
/*
resource "aws_security_group" "instance" {
  name   = "terraform-example-instance-LOBexample"
  vpc_id = aws_vpc.terraform-vpc-LOBexample.id

  ingress {
    from_port   = var.bigip_port
    to_port     = var.bigip_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
*/
#################################
# BUILDING WEB SERVER IN AZ A #
#################################

/*
resource "aws_instance" "example-a" {
  count = 1

  ami                         = var.web_server_ami[var.aws_region]
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public-a.id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  key_name                    = var.aws_keypair
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              /sbin/chkconfig --add docker
              service docker start
              docker run -d -p 80:80 --net host -e F5DEMO_APP=website -e F5DEMO_NODENAME="Public Cloud Lab: AZ #1" --restart always --name f5demoapp chen23/f5-demo-app:latest
  EOF


  tags = {
    Name = "web-az1.${count.index}: ${var.DeploymentSpecificName}"
    serviceDiscovery1 = "LOB1"
  }
}

#################################
# BUILDING WEB SERVER IN AZ B #
#################################

resource "aws_instance" "example-b" {
  count = 1

  #ami                    = "{var.web_server_ami}"
  ami = var.web_server_ami[var.aws_region]
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public-b.id
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name = var.aws_keypair
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              /sbin/chkconfig --add docker
              service docker start
              docker run -d -p 80:80 --net host -e F5DEMO_APP=website -e F5DEMO_NODENAME="Public Cloud Lab: AZ #2" --restart always --name f5demoapp chen23/f5-demo-app:latest
  EOF

  tags = {
    Name              = "web-az2.${count.index}: ${var.DeploymentSpecificName}"
    serviceDiscovery2 = "LOB2"
  }
}
*/
