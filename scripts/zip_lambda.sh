#!/bin/bash

################################################################################
#  File: scripts/zip_lambda.sh
#  Description: Zips the Lambda function code for deployment using Bash.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Automated packaging of Lambda function code for deployment.
################################################################################

cd lambda-function
zip -r ../terraform-manifests/storage/lambda.zip .
cd ..
echo "[AWS DevSecOps Hybrid CI/CD Platform]: Lambda function zipped to terraform-manifests/storage/lambda.zip"