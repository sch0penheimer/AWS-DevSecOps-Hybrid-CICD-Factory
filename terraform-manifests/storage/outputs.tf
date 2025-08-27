output "artifact_bucket_name" {
  value = aws_s3_bucket.artifact_store.bucket
}

output "lambda_bucket_name" {
  value = aws_s3_bucket.lambda_bucket.bucket
}