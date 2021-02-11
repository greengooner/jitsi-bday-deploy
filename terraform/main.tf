terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.26.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

#create a new vpc for jitsi
resource "aws_vpc" "jitsi-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bday-2021"
  }
}

#create a new subnet for the vpc in the us-east-2a AZ.
resource "aws_subnet" "jitsi-vpc-subnet" {
  vpc_id            = aws_vpc.jitsi-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    "Name" = "bday-2021"
  }
}

#create a new security group
resource "aws_security_group" "jitsi-sg" {
  vpc_id = aws_vpc.jitsi-vpc.id
  name   = "jitsi-secgropup"

  #SSH Connections
  ingress {
    cidr_blocks = ["<SSH SOURCE SUBNET NETWORK/SUBNET CIDR>"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  #Lets Encrypt ACME
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  #HTTPS
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  #Jitsi Videobridge Traffic
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 4443
    to_port     = 4443
    protocol    = "tcp"
  }

  #Jitsi Videobridge Traffic
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 10000 #Jitsi video traffic
    to_port     = 10000
    protocol    = "udp"
  }

  #All protocols and ports permitted outbound
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    "Name" = "bday-2021"
  }
}

#create a igw for the new vpc
resource "aws_internet_gateway" "jitsi-vpc-inetgw" {
  vpc_id = aws_vpc.jitsi-vpc.id
  tags = {
    "Name" = "bday-2021"
  }
}

#setup the route table
resource "aws_route_table" "jitsi-vpc-rt-tb" {
  vpc_id = aws_vpc.jitsi-vpc.id
  tags = {
    "Name" = "bday-2021"
  }
}

#add IGW as the default route to the route table created above
resource "aws_route" "jitsi-vpc-inetacs" {
  route_table_id         = aws_route_table.jitsi-vpc-rt-tb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.jitsi-vpc-inetgw.id
}

#associate the route table created above to the newly created vpc
resource "aws_route_table_association" "jitsi-vpc-associate" {
  subnet_id      = aws_subnet.jitsi-vpc-subnet.id
  route_table_id = aws_route_table.jitsi-vpc-rt-tb.id
}

#make the route table created above the main route table for the vpc
resource "aws_main_route_table_association" "jitsi-vpc-main-rt-tb" {
  vpc_id         = aws_vpc.jitsi-vpc.id
  route_table_id = aws_route_table.jitsi-vpc-rt-tb.id
}

resource "aws_instance" "jitsi" {
  ami                         = "ami-0a91cd140a1fc148a" #Current Ubuntu 20.04 LTS AMI (x86-64) on 2/7/21
  instance_type               = "t3a.small"
  subnet_id                   = aws_subnet.jitsi-vpc-subnet.id
  vpc_security_group_ids      = [aws_security_group.jitsi-sg.id]
  associate_public_ip_address = true
  key_name                    = "<KEY PAIR NAME>"

  tags = {
    "Name" = "rcbday"
  }
}