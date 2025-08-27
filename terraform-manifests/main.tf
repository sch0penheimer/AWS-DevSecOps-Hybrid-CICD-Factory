provider "aws" {
  region = var.aws_account_region
}

##-- Network Module --##
module "network" {
  source             = "./network"
  project_name       = var.project_name
  availability_zones = var.availability_zones
}

#---------------------------------------#

##-- Compute Module (ECS EC2-based) --##
module "compute" {
  source = "./compute"
  project_name          = var.project_name
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  ecs_security_group_id = module.network.ecs_security_group_id
}

#----------------------------------------#

##-- Storage Module --##
module "storage" {
  source       = "./storage"
  project_name = var.project_name
}