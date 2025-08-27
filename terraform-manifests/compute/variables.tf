variable "vpc_id" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "alb_security_group_id" {}
variable "ecs_security_group_id" {}

variable "instance_types" {
  description = "EC2 instance types for Staging/Prod environments"
  type = map(string)
  default = {
    staging    = "t3.micro"
    production = "t3.micro"
  }
}

variable "ecs_cluster_names" {
  description = "ECS cluster names (Staging/Prod clusters)"
  type = map(string)
  default = {
    staging    = "staging-cluster"
    production = "production-cluster"
  }
}

variable "asg_config" {
  description = "Auto Scaling Group configuration for Staging/Prod environments"
  type = map(object({
    min_size         = number
    max_size         = number
    desired_capacity = number
  }))
  default = {
    staging = {
      min_size         = 0
      max_size         = 2
      desired_capacity = 0
    }
    production = {
      min_size         = 1
      max_size         = 2
      desired_capacity = 1
    }
  }
}