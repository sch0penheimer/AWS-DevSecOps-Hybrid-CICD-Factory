#-- EC2 ECS-Optimized AMI --##
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

#-- IAM Role for ECS Instance --#
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecs-instance-role"
  
  /**
    Corresponding trust policy (Who can assume the role)
  **/
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

#-- A role instance profile, since the IAM role concern EC2s --#
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

#---------------------------------------------------------#

#-- ECS Clusters --#
resource "aws_ecs_cluster" "staging" {
  name = var.ecs_cluster_names.staging

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = var.ecs_cluster_names.staging
    Environment = "staging"
  }
}

resource "aws_ecs_cluster" "production" {
  name = var.ecs_cluster_names.production

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = var.ecs_cluster_names.production
    Environment = "production"
  }
}

#-- ECS EC2 Launch Template (Staging) --#
resource "aws_launch_template" "staging" {
  name_prefix   = "${var.project_name}-staging-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.instance_types.staging

  vpc_security_group_ids = [var.ecs_security_group_id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  /**
    User Data script to register the instance within the cluster.
  **/
  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {
    cluster_name = aws_ecs_cluster.staging.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-staging-instance"
      Environment = "staging"
      Cluster     = aws_ecs_cluster.staging.name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

#-- ECS EC2 Launch Template (Production) --#
resource "aws_launch_template" "production" {
  name_prefix   = "${var.project_name}-production-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.instance_types.production

  vpc_security_group_ids = [var.ecs_security_group_id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {
    cluster_name = aws_ecs_cluster.production.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-production-instance"
      Environment = "production"
      Cluster     = aws_ecs_cluster.production.name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

#-- Auto Scaling Group (Staging, starts with 0 instance) --##
resource "aws_autoscaling_group" "staging" {
  name                = "${var.project_name}-staging-autoscaling-group"
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EC2"
  health_check_grace_period = 300

  min_size         = var.asg_config.staging.min_size
  max_size         = var.asg_config.staging.max_size
  desired_capacity = var.asg_config.staging.desired_capacity

  launch_template {
    id      = aws_launch_template.staging.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-staging-autoscaling-group"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = "staging"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = false
  }
}

##-- Auto Scaling Group (Production, starts with 1 instance) --##
resource "aws_autoscaling_group" "production" {
  name                = "${var.project_name}-production-autoscaling-group"
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "ELB"
  health_check_grace_period = 300

  target_group_arns   = [aws_lb_target_group.production.arn]

  min_size         = var.asg_config.production.min_size
  max_size         = var.asg_config.production.max_size
  desired_capacity = var.asg_config.production.desired_capacity

  launch_template {
    id      = aws_launch_template.production.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-production-autoscaling-group"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = false
  }
}

#-----------------------------------------------------------#

#-- Application Load Balancer for Production --##
resource "aws_lb" "production" {
  name               = "${var.project_name}-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-prod-alb"
    Environment = "production"
  }
}

#-- Target Group for Production ALB --#
resource "aws_lb_target_group" "production" {
  name     = "${var.project_name}-prod-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-prod-tg"
    Environment = "production"
  }
}

#-- ALB Listener for Production --##
resource "aws_lb_listener" "production" {
  load_balancer_arn = aws_lb.production.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.production.arn
  }
}

#-- ECS Capacity Providers to link Autoscaling Groups --#
resource "aws_ecs_capacity_provider" "staging" {
  name = "${var.project_name}-staging-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.staging.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }

    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_capacity_provider" "production" {
  name = "${var.project_name}-production-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.production.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }

    managed_termination_protection = "ENABLED"
  }
}

#-- Associate Capacity Providers with Clusters --#
resource "aws_ecs_cluster_capacity_providers" "staging" {
  cluster_name = aws_ecs_cluster.staging.name

  capacity_providers = [aws_ecs_capacity_provider.staging.name]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 1
    capacity_provider = aws_ecs_capacity_provider.staging.name
  }
}

resource "aws_ecs_cluster_capacity_providers" "production" {
  cluster_name = aws_ecs_cluster.production.name

  capacity_providers = [aws_ecs_capacity_provider.production.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = aws_ecs_capacity_provider.production.name
  }
}

#-- ECR Repository --#
resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.project_name}-app_repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-app-repo"
  }
}

#-- ECR Lifecycle Policy --##
resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}