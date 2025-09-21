##-- Module Imported Variables --##

variable "project_name" {}

variable "vpc_id" {}

variable "private_subnet_ids" {}

variable "public_subnet_ids" {}

variable "prod_alb_security_group_id" {}

variable "prod_ecs_security_group_id" {}

variable "staging_alb_security_group_id" {}

variable "staging_ecs_security_group_id" {}

#------------------------------------------------------#
##-- Module Specific Variables --##

variable "instance_types" {
  description = "EC2 instance types for the staging/prod ECS environments"
  type = map(string)
  default = {
    staging    = "t2.micro"
    production = "t2.micro"
  }
}

variable "ecs_cluster_names" {
  description = "ECS cluster names"
  type = map(string)
  default = {
    staging    = "staging-cluster"
    production = "production-cluster"
  }
}

variable "asg_config" {
  description = "Auto Scaling Groups configuration"
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