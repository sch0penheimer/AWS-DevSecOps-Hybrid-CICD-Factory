################################################################################
#  File: storage/outputs.tf
#  Description: Output definitions for storage resources.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Exposes S3 bucket names for cross-module and pipeline integration.
################################################################################

output "artifact_bucket_name" {
  value = aws_s3_bucket.artifact_store.bucket
}

output "lambda_bucket_name" {
  value = aws_s3_bucket.lambda_bucket.bucket
}