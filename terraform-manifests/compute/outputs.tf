#-- ECS Cluster Outputs --#
output "staging_cluster_id" {
  description = "ID of the staging ECS cluster"
  value       = aws_ecs_cluster.staging.id
}

output "staging_cluster_arn" {
  description = "ARN of the staging ECS cluster"
  value       = aws_ecs_cluster.staging.arn
}

output "production_cluster_id" {
  description = "ID of the production ECS cluster"
  value       = aws_ecs_cluster.production.id
}

output "production_cluster_arn" {
  description = "ARN of the production ECS cluster"
  value       = aws_ecs_cluster.production.arn
}

#-- Load Balancer Outputs --#
output "staging_alb_arn" {
  description = "ARN of the staging Application Load Balancer"
  value       = aws_lb.staging.arn
}

output "staging_alb_dns_name" {
  description = "DNS name of the staging Application Load Balancer"
  value       = aws_lb.staging.dns_name
}

output "production_alb_arn" {
  description = "ARN of the production Application Load Balancer"
  value       = aws_lb.production.arn
}

output "production_alb_dns_name" {
  description = "DNS name of the production Application Load Balancer"
  value       = aws_lb.production.dns_name
}

#-- ECR Repository Outputs --#
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app_repo.arn
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.app_repo.name
}

#-- ECS Service Outputs --#
output "staging_service_name" {
  description = "Name of the staging ECS service"
  value       = aws_ecs_service.staging.name
}

output "staging_service_arn" {
  description = "ARN of the staging ECS service"
  value       = aws_ecs_service.staging.id
}

output "production_service_name" {
  description = "Name of the production ECS service"
  value       = aws_ecs_service.production.name
}

output "production_service_arn" {
  description = "ARN of the production ECS service"
  value       = aws_ecs_service.production.id
}

output "production_container_name" {
  value = "${var.project_name}-app-prod-container"
}