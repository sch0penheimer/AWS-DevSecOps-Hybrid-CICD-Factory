################################################################################
#  File: global_outputs.tf
#  Description: Global outputs for AWS DevSecOps Hybrid CI/CD Platform
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 28/09/2025
#
#  Purpose: Centralizes root-level Terraform outputs for deployment script consumption
################################################################################


##-- Root Level Outputs --##
output "aws_region" {
  description = "AWS region where infrastucture is deployed"
  value       = var.aws_account_region
}

##-- Network Module Outputs --##
output "vpc_id" {
  description = "The ID of the VPC (Used by CloudFormation)"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (Used by CloudFormation)"
  value       = module.network.private_subnet_ids
}

output "prod_alb_security_group_id" {
  description = "The security group ID for the Production ALB"
  value       = module.network.prod_alb_security_group_id
}

output "prod_ecs_security_group_id" {
  description = "The security group ID for Production ECS instances"
  value       = module.network.prod_ecs_security_group_id
}

output "staging_alb_security_group_id" {
  description = "The security group ID for the Staging ALB"
  value       = module.network.staging_alb_security_group_id
}

output "staging_ecs_security_group_id" {
  description = "The security group ID for Staging ECS instances"
  value       = module.network.staging_ecs_security_group_id
}

output "codebuild_security_group_id" {
  description = "The security group ID for CodeBuild Projects (Used by CloudFormation)"
  value       = module.network.codebuild_security_group_id
}

##-- Storage Module Outputs --##
output "artifact_bucket_name" {
  description = "S3 Artifact bucket name (Used by CloudFormation)"
  value       = module.storage.artifact_bucket_name
}

output "lambda_bucket_name" {
  description = "S3 bucket name of the lambda package name (Used by CloudFormation)"
  value       = module.storage.lambda_bucket_name
}

output "lambda_package_key" {
  description = "S3 key of the lambda package (Used by CloudFormation)"
  value       = module.storage.lambda_package_key
}

##-- Compute Module Outputs --##
output "staging_cluster_name" {
  description = "Name of the staging ECS cluster (Used by CloudFormation)"
  value       = module.compute.staging_cluster_name
}

output "production_cluster_id" {
  description = "ID of the production ECS cluster"
  value       = module.compute.production_cluster_id
}

output "production_cluster_arn" {
  description = "ARN of the production ECS cluster"
  value       = module.compute.production_cluster_arn
}

output "production_cluster_name" {
  description = "Name of the production ECS cluster (Used by CloudFormation)"
  value       = module.compute.production_cluster_name
}

output "staging_alb_arn" {
  description = "ARN of the staging Application Load Balancer"
  value       = module.compute.staging_alb_arn
}

output "staging_alb_dns_name" {
  description = "DNS name of the staging Application Load Balancer (Used by CloudFormation for DAST App URL)"
  value       = module.compute.staging_alb_dns_name
}

output "production_alb_arn" {
  description = "ARN of the production Application Load Balancer"
  value       = module.compute.production_alb_arn
}

output "production_alb_dns_name" {
  description = "DNS name of the production Application Load Balancer"
  value       = module.compute.production_alb_dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.compute.ecr_repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.compute.ecr_repository_arn
}

output "ecr_repository_name" {
  description = "Name of the ECR repository (Used by CloudFormation)"
  value       = module.compute.ecr_repository_name
}

output "staging_service_name" {
  description = "Name of the staging ECS service (Used by CloudFormation)"
  value       = module.compute.staging_service_name
}

output "staging_service_arn" {
  description = "ARN of the staging ECS service"
  value       = module.compute.staging_service_arn
}

output "production_service_name" {
  description = "Name of the production ECS service (Used by CloudFormation)"
  value       = module.compute.production_service_name
}

output "production_service_arn" {
  description = "ARN of the production ECS service"
  value       = module.compute.production_service_arn
}

output "production_container_name" {
  value = module.compute.production_container_name
}

output "staging_task_definition_name" {
  description = "Name of the staging task definition (Used by CloudFormation)"
  value       = module.compute.staging_task_definition_name
}

output "production_task_definition_name" {
  description = "ARN of the production task definition (Used by CloudFormation)"
  value       = module.compute.production_task_definition_name
}

output "production_target_group_name" {
  description = "Name of the production ALB's target group (Used by CloudFormation)"
  value       = module.compute.production_target_group_name
}