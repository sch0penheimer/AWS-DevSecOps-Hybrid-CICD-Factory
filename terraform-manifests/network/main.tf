#######################################################################
#  File: network/main.tf
#  Description: Network infrastructure provisioning for the AWS DevSecOps
#               Hybrid CI/CD Platform.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 21/09/2025
#
#  Purpose: Provisions VPC, subnets, route tables, and security groups 
#           for the platform.
#######################################################################

/**    
  To resolve your public IP for SSH (for personal use + fetches the RUNNER'S 
  public IP, so be careful from where you run Terraform)
**/
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-custom-vpc" 
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { 
    Name = "${var.project_name}-internet-gateway"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Type        = "Public"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Type        = "Private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  /**
    No need to add the default in-vpc default route:
      route {
        cidr_block = "${var.vpc_cidr}"
        gateway_id = local
      }
  **/

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-route-table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  /**
    No need to add the default in-vpc default route:
      route {
        cidr_block = "${var.vpc_cidr}"
        gateway_id = local
      }
    Also, it's the ONLY route in a private subnet's route table.
  **/

  tags = {
    Name        = "${var.project_name}-private-route-table"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "prod_alb" {
  name_prefix = "${var.project_name}-prod-lb-security-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-prod-lb-security-group"
  }
}

##- Staging LB SG to go -##

resource "aws_security_group" "prod_ecs" {
  name_prefix = "${var.project_name}-prod-ecs-security-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.prod_alb.id]
  }

  ingress {
    description     = "HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.prod_alb.id]
  }

  ingress {
    description     = "Dynamic port range from ALB"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.prod_alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-prod-ecs-security-group"
  }
}

##- Staging ECS SG to go -##