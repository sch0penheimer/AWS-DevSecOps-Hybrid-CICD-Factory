################################################################################
#  File: scripts/zip_lambda.ps1
#  Description: Zips the Lambda function code for deployment using PowerShell.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Automated packaging of Lambda function code for deployment.
################################################################################

$source = ".\lambda-function\*"
$destination = ".\terraform-manifests\storage\lambda.zip"
if (Test-Path $destination) { Remove-Item $destination }
Compress-Archive -Path $source -DestinationPath $destination -Force
Write-Host "[AWS DevSecOps Hybrid CI/CD Platform]: Lambda function zipped to $destination"