################################################################################
#  File: storage/outputs.tf
#  Description: Output definitions for storage resources.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Exposes S3 bucket names for cross-module and pipeline integration.
################################################################################

output "artifact_bucket_name" {
  description = "S3 Artifact bucket name (Used by CloudFormation)"
  value       = aws_s3_bucket.artifact_store.bucket
}

output "lambda_bucket_name" {
  description = "S3 bucket name of the lambda package name (Used by CloudFormation)"
  value       = aws_s3_bucket.lambda_bucket.bucket
}

output "lambda_package_key" {
  description = "S3 key of the lambda package (Used by CloudFormation)"
  value       = aws_s3_object.lambda_package.key
}