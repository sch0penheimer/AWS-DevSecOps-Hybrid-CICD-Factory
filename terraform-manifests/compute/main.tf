resource "aws_instance" "staging" {
  ami           = var.ec2_staging.ami
  instance_type = var.ec2_staging.instance_type
  subnet_id     = var.private_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  tags = { Name = "staging-ec2" }
}

resource "aws_instance" "prod" {
  ami           = var.ec2_prod.ami
  instance_type = var.ec2_prod.instance_type
  subnet_id     = var.private_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  tags = { Name = "prod-ec2" }
}

resource "aws_ecr_repository" "main_ecr_repo" {
  name                 = "${var.project_name}-ecr-repo"
  image_tag_mutability = "MUTABLE"
  tags = {
    Name        = "${var.project_name}-ecr-repo"
  }
}