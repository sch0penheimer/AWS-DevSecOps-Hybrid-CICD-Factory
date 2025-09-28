################################################################################
#  File: storage/main.tf
#  Description: Storage resource provisioning for the AWS DevSecOps Hybrid CI/CD Platform.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Provisions S3 buckets and corresponding policies for secure artifact and
#           lambda storage.
################################################################################

resource "aws_s3_bucket" "artifact_store" {
  bucket = "${var.project_name}-artifact-bucket"
  tags = {
    pipeline-name = "${var.project_name}-pipeline"
  }
}

resource "aws_s3_bucket_policy" "artifact_store_policy" {
  bucket = aws_s3_bucket.artifact_store.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnEncryptedObjectUploads"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.artifact_store.arn}/*",
          "${aws_s3_bucket.artifact_store.arn}"
        ]
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid      = "DenyInsecureConnections"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          "${aws_s3_bucket.artifact_store.arn}/*",
          "${aws_s3_bucket.artifact_store.arn}"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.project_name}-lambda-bucket"
  tags = {
    pipeline-name = "${var.project_name}-pipeline"
  }
}

resource "aws_s3_bucket_policy" "lambda_bucket_policy" {
  bucket = aws_s3_bucket.lambda_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaServiceAccess"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.lambda_bucket.arn}/*"
      },
      {
        Sid    = "AllowCloudFormationAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.lambda_bucket.arn}/*"
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.lambda_bucket.arn,
          "${aws_s3_bucket.lambda_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "lambda_package" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda/lambda.zip"
  source = "${path.module}/lambda.zip"
  etag   = filemd5("${path.module}/lambda.zip")
  content_type = "application/zip"
}
