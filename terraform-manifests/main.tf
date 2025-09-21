################################################################################
#  File: main.tf
#  Description: Root Terraform configuration for the AWS DevSecOps Hybrid CI/CD Platform.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 21/09/2025
#
#  Purpose: Orchestrates core modules (network, compute, storage) for compliant 
#           infrastructure provisioning.
################################################################################

provider "aws" {
  region = var.aws_account_region
}

##-- Network Module --##
module "network" {
  source             = "./network"
  project_name       = var.project_name
  availability_zones = var.availability_zones
}

#------------------------------------------------------------------------------#
##-- Compute Module (ECS EC2-based) --##
module "compute" {
  source = "./compute"
  project_name                  = var.project_name
  vpc_id                        = module.network.vpc_id
  public_subnet_ids             = module.network.public_subnet_ids
  private_subnet_ids            = module.network.private_subnet_ids
  prod_alb_security_group_id    = module.network.prod_alb_security_group_id
  prod_ecs_security_group_id    = module.network.prod_ecs_security_group_id
  staging_alb_security_group_id = module.network.staging_alb_security_group_id
  staging_ecs_security_group_id = module.network.staging_ecs_security_group_id
}

#------------------------------------------------------------------------------#

##-- Storage Module --##
module "storage" {
  source       = "./storage"
  project_name = var.project_name
}