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


#-- NAT Instance (Free Tier Alternative to NAT Gateway) --#
data "aws_ami" "nat_instance" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#-- NAT Instance --#
resource "aws_instance" "nat_instance" {
  ami                    = data.aws_ami.nat_instance.id
  instance_type          = var.nat_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  
  #- Disable source/destination check (required for NAT functionality) -#
  source_dest_check = false
  
  #- Assign public IP -#
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-nat-instance"
    Type = "NAT"
  }

  #- User data to configure NAT functionality -#
  user_data = <<-EOF
    #!/bin/bash
    sudo yum install iptables-services -y
    sudo systemctl enable iptables
    sudo systemctl start iptables

    #- Enable IP forwarding -#
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/custom-ip-forwarding.conf
    sudo sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf

    PUBLIC_IFACE=$(ip route | awk '/default/ {print $5}')

    sudo /sbin/iptables -t nat -A POSTROUTING -o $PUBLIC_IFACE -j MASQUERADE
    sudo /sbin/iptables -F FORWARD
    sudo service iptables save
  EOF

  depends_on = [
    aws_vpc.main,
    aws_subnet.public[0],
    aws_security_group.nat_instance
  ]
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
  **/

  tags = {
    Name        = "${var.project_name}-private-route-table"
  }

  depends_on = [aws_instance.nat_instance]
}

resource "null_resource" "private_nat_route" {
  depends_on = [aws_instance.nat_instance, aws_route_table.private]

  provisioner "local-exec" {
    command = <<EOT
      aws ec2 create-route --route-table-id ${aws_route_table.private.id} --destination-cidr-block 0.0.0.0/0 --instance-id ${aws_instance.nat_instance.id}
    EOT
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
    Purpose     = "production-internet-access"

  }
}

resource "aws_security_group" "staging_alb" {
  name_prefix = "${var.project_name}-staging-lb-security-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.codebuild.id]
  }

  ingress {
    description     = "HTTPS"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.codebuild.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-staging-lb-security-group"
    Purpose     = "internal-staging_access-only"
  }
}

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

resource "aws_security_group" "staging_ecs" {
  name_prefix = "${var.project_name}-staging-ecs-security-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from Staging ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.staging_alb.id]
  }

  ingress {
    description     = "HTTPS from Staging ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.staging_alb.id]
  }

  ingress {
    description     = "Dynamic port range from Staging ALB"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.staging_alb.id]
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
    Name        = "${var.project_name}-staging-ecs-security-group"
  }
}

##-- Security Group for NAT Instance --##
resource "aws_security_group" "nat_instance" {
  name        = "${var.project_name}-nat-instance-sg"
  description = "Security group for NAT instance"
  vpc_id      = aws_vpc.main.id

  #- Ingress only from private subnets -#
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
    description = "HTTP from private subnets"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
    description = "HTTPS from private subnets (Main ECS Agent Communication Port)"
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
    description = "DNS from private subnets"
  }

  #- DNS TCP (some queries) -#
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
    description = "DNS TCP from private subnets"
  }

  #- Egress to the whole Internet -#
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-nat-instance-sg"
  }
}

##-- CodeBuild Security Group for Exclusive Staging Cluster Access --##
resource "aws_security_group" "codebuild" {
  name_prefix = "${var.project_name}-codebuild-security-group"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "All outbound traffic for CodeBuild operations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-codebuild-security-group"
    Purpose = "dast-build-operations"
  }
}