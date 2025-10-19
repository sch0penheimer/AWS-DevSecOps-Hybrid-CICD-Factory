#################################################################################
##- File: deploy.ps1
##- Description: Main deployment script (PowerShell) for AWS DevSecOps Hybrid CI/CD Platform
##- Author: Haitam Bidiouane (@sch0penheimer)
##- Last Modified: 27/09/2025
#
##- This script orchestrates the complete deployment:
##- 1. Validates environment configuration
##- 2. Creates Lambda ZIP package
##- 3. Optionally deploys Terraform infrastructure
##- 4. Deploys CloudFormation CI/CD pipeline with Terraform outputs
#################################################################################

param(
    [switch]$SkipInfrastructure,
    [switch]$RollbackDeployment,
    [switch]$Help
)

##- Set error handling -##
$ErrorActionPreference = "Stop"

##- Script configuration -##
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT_DIR = Split-Path -Parent $SCRIPT_DIR
$TERRAFORM_DIR = Join-Path $ROOT_DIR "terraform-manifests"
$CLOUDFORMATION_DIR = Join-Path $ROOT_DIR "cloudformation"
$ENV_FILE = Join-Path $ROOT_DIR ".env"

##- Colors for output -##
$Colors = @{
    RED    = "Red"
    GREEN  = "Green"
    YELLOW = "Yellow"
    CYAN   = "Cyan"
    BLUE   = "Blue"
    PURPLE = "Magenta"
}

function Show-Help {
    Write-Host "AWS DevSecOps Hybrid CI/CD Platform Deployment Script Helping Manual" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Cyan
    Write-Host "    .\deploy.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Cyan
    Write-Host "    -SkipInfrastructure          Skip Terraform infrastructure deployment (use existing infrastructure)"
    Write-Host "    -RollbackDeployment          Rollback existing Terraform infrastructure & CloudFormation stack and exit"
    Write-Host "    -Help                        Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Cyan
    Write-Host "    .\deploy.ps1                               " -NoNewline
    Write-Host "#- Full deployment with new infrastructure -#" -ForegroundColor Blue
    Write-Host "    .\deploy.ps1 -SkipInfrastructure           " -NoNewline
    Write-Host "#- Deploy only CI/CD pipeline to existing infrastructure -#" -ForegroundColor Blue
    Write-Host "    .\deploy.ps1 -RollbackDeployment           " -NoNewline
    Write-Host "#- Rollback deployment and exit -#" -ForegroundColor Blue
    Write-Host ""
    Write-Host "PREREQUISITES:" -ForegroundColor Cyan
    Write-Host "    - PowerShell v5.0+"
    Write-Host "    - AWS CLI v2+"
    Write-Host "    - Terraform v1.0+"
    Write-Host "    - .env file completed with required configuration"
    Write-Host ""
    Write-Host "NOTES:" -ForegroundColor Cyan
    Write-Host "    - All prerequisites MUST be installed before running this script"
    Write-Host "    - Supports Windows"
    Write-Host "    - Script will exit if any prerequisites are missing"
}

function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Type) {
        "ERROR"   { Write-Host "[$timestamp ERROR] $Message" -ForegroundColor $Colors.RED }
        "WARNING" { Write-Host "[$timestamp WARNING] $Message" -ForegroundColor $Colors.YELLOW }
        "SUCCESS" { Write-Host "[$timestamp SUCCESS] $Message" -ForegroundColor $Colors.GREEN }
        "INFO"    { Write-Host "[$timestamp INFO] $Message" -ForegroundColor $Colors.CYAN }
        "DEBUG"   { Write-Host "[$timestamp DEBUG] $Message" -ForegroundColor $Colors.PURPLE }
        default   { Write-Host "[$timestamp LOG] $Message" -ForegroundColor $Colors.BLUE }
    }
}

function Get-OSType {
    return "windows"
}

function Test-Prerequisites {
    Write-LogMessage "Checking prerequisites:" "INFO"
    $missing_tools = @()
    
    ##- Check AWS CLI installation -##
    try {
        $null = Get-Command aws -ErrorAction Stop
        $aws_version = (aws --version 2>&1).Split('/')[1].Split(' ')[0]
        Write-LogMessage "AWS CLI found: v$aws_version" "SUCCESS"
    } catch {
        Write-LogMessage "AWS CLI not found" "ERROR"
        $missing_tools += "AWS CLI"
    }

    ##- Check Terraform -##
    try {
        $null = Get-Command terraform -ErrorAction Stop
        $tf_version_output = terraform version 2>$null
        $tf_version = ($tf_version_output | Select-String "Terraform v").ToString().Split(' ')[1]
        Write-LogMessage "Terraform found: $tf_version" "SUCCESS"
        
        ##- Check minimum Terraform version (1.0+) -##
        if ([int]$tf_version.Substring(1).Split('.')[0] -lt 1) {
            Write-LogMessage "Terraform version $tf_version is too old. Required: v1.0+" "ERROR"
            $missing_tools += "Terraform v1.0+"
        }
    } catch {
        Write-LogMessage "Terraform not found" "ERROR"
        $missing_tools += "Terraform"
    }
    
    ##- Check PowerShell version -##
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-LogMessage "PowerShell version $($PSVersionTable.PSVersion) is too old. Required: 5.0+" "ERROR"
        $missing_tools += "PowerShell 5.0+"
    } else {
        Write-LogMessage "PowerShell version: $($PSVersionTable.PSVersion)" "SUCCESS"
    }
    
    ##- Check .env file -##
    if (-not (Test-Path $ENV_FILE)) {
        Write-LogMessage ".env file not found at: $ENV_FILE" "ERROR"
        $missing_tools += ".env configuration file"
    } else {
        Write-LogMessage ".env file found" "SUCCESS"
    }
    
    ##- Exit if any prerequisites are missing -##
    if ($missing_tools.Count -gt 0) {
        Write-LogMessage "PREREQUISITES CHECK FAILED - Missing: $($missing_tools -join ', ')" "ERROR"
        Write-LogMessage "Please install the missing prerequisites and re-run the script." "WARNING"
        exit 1
    }
    
    Write-LogMessage "All prerequisites check completed successfully" "SUCCESS"
}

function Set-AWSCredentials {
    Write-LogMessage "Configuring AWS credentials:" "INFO"
    
    ##- Check if credentials are already available via AWS credential chain -##
    try {
        $aws_identity = aws sts get-caller-identity --query 'Arn' --output text 2>$null
        $account_id = aws sts get-caller-identity --query 'Account' --output text 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Using existing AWS credentials: $aws_identity" "SUCCESS"
            Write-LogMessage "AWS Account ID: $account_id" "INFO"
            return
        }
    } catch {
        #- Ignoring errors here, will check .env next -#
    }

    ##- If no credentials found, check .env file -##
    if ($env:AWS_ACCESS_KEY_ID -and $env:AWS_SECRET_ACCESS_KEY) {
        Write-LogMessage "Using AWS credentials from .env file" "INFO"
        
        if ($env:AWS_REGION) {
            $env:AWS_DEFAULT_REGION = $env:AWS_REGION
        }
        
        ##- Verify credentials work -##
        try {
            $aws_identity = aws sts get-caller-identity --query 'Arn' --output text 2>$null
            $account_id = aws sts get-caller-identity --query 'Account' --output text 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-LogMessage "AWS credentials from .env verified: $aws_identity" "SUCCESS"
                Write-LogMessage "AWS Account ID: $account_id" "INFO"
            } else {
                Write-LogMessage "AWS credentials from .env are invalid!" "ERROR"
                Write-LogMessage "Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env file" "ERROR"
                exit 1
            }
        } catch {
            Write-LogMessage "AWS credentials from .env are invalid!" "ERROR"
            Write-LogMessage "Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env file" "ERROR"
            exit 1
        }
    } else {
        Write-LogMessage "No AWS credentials found!" "ERROR"
        Write-LogMessage "Please use one of the following methods:" "INFO"
        Write-LogMessage "1. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env file" "INFO"
        Write-LogMessage "2. Run 'aws configure' to set up AWS CLI profile" "INFO"
        Write-LogMessage "3. Use IAM roles if running on AWS infrastructure" "INFO"
        Write-LogMessage "4. Configure AWS SSO: 'aws configure sso'" "INFO"
        exit 1
    }
}

function Import-Environment {
    Write-LogMessage "Loading environment configuration:" "INFO"
    
    if (Test-Path $ENV_FILE) {
        ##- Load variables from .env file -##
        Get-Content $ENV_FILE | ForEach-Object {
            if ($_ -match '^([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim().Trim('"')
                if ($value) {
                    Set-Item -Path "env:$name" -Value $value
                }
            }
        }
        
        Write-LogMessage "Environment configuration loaded successfully" "SUCCESS"
    } else {
        Write-LogMessage ".env file not found!" "ERROR"
        exit 1
    }
    
    ##- Validate required environment variables -##
    $required_vars = @(
        "GIT_PROVIDER_TYPE", "FULL_GIT_REPOSITORY_ID", "BRANCH_NAME",
        "SNYK_API_KEY", "PIPELINE_NOTIFICATION_MAIL", "PIPELINE_MANUAL_APPROVER_MAIL",
        "AWS_REGION", "DOCKERHUB_USERNAME", "DOCKERHUB_PASSWORD"
    )
    
    Write-LogMessage "Validating required environment variables:" "INFO"
    $missing_vars = @()
    
    foreach ($var in $required_vars) {
        $value = Get-Item -Path "env:$var" -ErrorAction SilentlyContinue
        if (-not $value -or -not $value.Value) {
            Write-LogMessage "Required environment variable $var is not set!" "ERROR"
            $missing_vars += $var
        } else {
            Write-LogMessage "$var is set" "DEBUG"
        }
    }
    
    if ($missing_vars.Count -gt 0) {
        Write-LogMessage "Missing required environment variables: $($missing_vars -join ', ')" "ERROR"
        Write-LogMessage "Please update your .env file with the missing variables" "ERROR"
        exit 1
    }
    
    ##- AWS credentials in .env (can use other methods) -##
    if ($env:AWS_ACCESS_KEY_ID -or $env:AWS_SECRET_ACCESS_KEY) {
        if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY) {
            Write-LogMessage "Both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be provided together" "ERROR"
            exit 1
        }
        Write-LogMessage "AWS credentials found in .env file" "SUCCESS"
    } else {
        Write-LogMessage "No AWS credentials in .env file - will use AWS credential chain" "INFO"
    }
    
    Write-LogMessage "Environment validation completed successfully" "SUCCESS"
}

function New-LambdaPackage {
    Write-LogMessage "Creating Lambda ZIP package:" "INFO"
    
    $zip_script = Join-Path $SCRIPT_DIR "zip_lambda.ps1"
    if (Test-Path $zip_script) {
        Write-LogMessage "Executing Lambda packaging script:" "INFO"
        
        try {
            & $zip_script
            if ($LASTEXITCODE -eq 0) {
                Write-LogMessage "Lambda packaging completed successfully" "SUCCESS"
                
                ##- Verify -##
                $lambda_zip_path = Join-Path $TERRAFORM_DIR "storage\lambda.zip"
                if (Test-Path $lambda_zip_path) {
                    $zip_size = [math]::Round((Get-Item $lambda_zip_path).Length / 1KB, 2)
                    Write-LogMessage "Lambda ZIP created: $lambda_zip_path ($zip_size KB)" "SUCCESS"
                } else {
                    Write-LogMessage "Lambda ZIP file not found at expected location: $lambda_zip_path" "ERROR"
                    exit 1
                }
            } else {
                Write-LogMessage "Lambda packaging script failed with exit code: $LASTEXITCODE" "ERROR"
                Write-LogMessage "Check the zip_lambda.ps1 script for errors" "ERROR"
                exit 1
            }
        } catch {
            Write-LogMessage "Lambda packaging script failed: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    } else {
        Write-LogMessage "Lambda ZIP script not found at: $zip_script" "ERROR"
        exit 1
    }
}

function Deploy-Infrastructure {
    Write-LogMessage "Deploying Terraform infrastructure:" "INFO"
    
    Set-Location $TERRAFORM_DIR
    
    Write-LogMessage "Initializing Terraform:" "INFO"
    terraform init
    if ($LASTEXITCODE -ne 0) { Write-LogMessage "Terraform initialization failed!" "ERROR"; exit 1 }
    
    ##- Validate Terraform config -##
    Write-LogMessage "Validating Terraform configuration:" "INFO"
    terraform validate
    if ($LASTEXITCODE -ne 0) { Write-LogMessage "Terraform validation failed!" "ERROR"; exit 1 }

    ##- Plan deployment -##
    Write-LogMessage "Planning Terraform deployment:" "INFO"
    terraform plan -out=tfplan
    if ($LASTEXITCODE -ne 0) { Write-LogMessage "Terraform planning failed!" "ERROR"; exit 1 }
    
    ##- Apply deployment -##
    Write-LogMessage "Applying Terraform deployment:" "WARNING"
    terraform apply tfplan
    if ($LASTEXITCODE -ne 0) { Write-LogMessage "Terraform apply failed!" "ERROR"; exit 1 }
    
    Write-LogMessage "Terraform infrastructure deployed successfully" "SUCCESS"
    Set-Location $ROOT_DIR
}

function Remove-Infrastructure {
    Write-LogMessage "Destroying Terraform infrastructure:" "WARNING"
    
    Set-Location $TERRAFORM_DIR
    
    Write-Host ""
    Write-LogMessage "WARNING: This will destroy everything deployed : Terraform-managed infrastructure + CloudFormation Stack" "ERROR"
    $confirmation = Read-Host "Are you absolutely sure? Type 'DESTROY' to continue"
    
    if ($confirmation -ne "DESTROY") {
        Write-LogMessage "Destruction cancelled by user" "INFO"
        Set-Location $ROOT_DIR
        exit 0
    }
    
    Write-LogMessage "Proceeding with infrastructure destruction..." "INFO"
    
    terraform destroy -auto-approve
    if ($LASTEXITCODE -eq 0) {
        Write-LogMessage "Terraform infrastructure destroyed successfully" "SUCCESS"
        
        ##- Clean up state files -##
        Write-LogMessage "Cleaning up Terraform state files" "INFO"
        
        Remove-Item -Path "terraform.tfstate" -ErrorAction SilentlyContinue
        Remove-Item -Path "terraform.tfstate.backup" -ErrorAction SilentlyContinue
        Remove-Item -Path ".terraform.lock.hcl" -ErrorAction SilentlyContinue
        Remove-Item -Path "tfplan" -ErrorAction SilentlyContinue
        Remove-Item -Path ".terraform" -Recurse -ErrorAction SilentlyContinue
        Write-LogMessage "Terraform directory cleaned up" "INFO"
        
        Write-LogMessage "State cleanup completed - ready for fresh deployment" "SUCCESS"
        
    } else {
        Write-LogMessage "Terraform destruction failed!" "ERROR"
        Write-LogMessage "You may need to manually clean up resources in AWS Console" "WARNING"
        Set-Location $ROOT_DIR
        exit 1
    }
    
    Set-Location $ROOT_DIR
}

function Get-TerraformOutputs {
    Write-LogMessage "Retrieving Terraform outputs:" "INFO"
    
    Set-Location $TERRAFORM_DIR
    
    ##- Check if terraform state exists -##
    if (-not (Test-Path "terraform.tfstate")) {
        Write-LogMessage "No Terraform state file found - infrastructure may not be deployed" "ERROR"
        Set-Location $ROOT_DIR
        exit 1
    }
    
    ##- Check if state has resources -##
    try {
        $state_json = terraform show -json 2>$null | ConvertFrom-Json
        $resource_count = 0
        if ($state_json.values.root_module.child_modules) {
            foreach ($module in $state_json.values.root_module.child_modules) {
                if ($module.resources) {
                    $resource_count += $module.resources.Count
                }
            }
        }
        if ($resource_count -eq 0) {
            Write-LogMessage "Terraform state exists but no resources found" "ERROR"
            Set-Location $ROOT_DIR
            exit 1
        }
    } catch {
        $resource_count = 0
    }
    
    ##- Generate outputs JSON file -##
    $outputs_file = "$env:TEMP\terraform_outputs.json"
    
    Write-LogMessage "Generating Terraform outputs JSON..." "INFO"
    
    terraform output -json > $outputs_file 2>&1
    if ($LASTEXITCODE -eq 0 -and (Test-Path $outputs_file) -and (Get-Item $outputs_file).Length -gt 0) {
        try {
            $outputs = Get-Content $outputs_file | ConvertFrom-Json
            $output_count = ($outputs | Get-Member -MemberType NoteProperty).Count
            Write-LogMessage "Terraform outputs retrieved successfully ($output_count outputs)" "SUCCESS"

            Write-LogMessage "Available outputs:" "DEBUG"
            $outputs | Get-Member -MemberType NoteProperty | ForEach-Object {
                Write-LogMessage "  - $($_.Name)" "DEBUG"
            }
            
            Set-Location $ROOT_DIR
        } catch {
            Write-LogMessage "Failed to parse Terraform outputs JSON" "ERROR"
            Set-Location $ROOT_DIR
            exit 1
        }
    } else {
        Write-LogMessage "Failed to retrieve Terraform outputs or file is empty" "ERROR"
        if (Test-Path $outputs_file) {
            Get-Content $outputs_file
        }
        Set-Location $ROOT_DIR
        exit 1
    }
}

function Deploy-CloudFormationStack {
    param([string]$TerraformOutputsFile)
    
    Write-LogMessage "Deploying CloudFormation CI/CD pipeline:" "INFO"
    
    $stack_name = "devsecops-cloudformation"
    $template_file = Join-Path $CLOUDFORMATION_DIR "codepipeline.yaml"
    
    if (-not (Test-Path $template_file)) {
        Write-LogMessage "CloudFormation template not found at: $template_file" "ERROR"
        exit 1
    }
    
    ##- Build parameter overrides -##
    $parameters = @()
    
    ##- Terraform infrastructure outputs as CloudFormation parameters -##
    if ($TerraformOutputsFile -and (Test-Path $TerraformOutputsFile)) {
        Write-LogMessage "Using Terraform outputs for infrastructure parameters:" "INFO"
        
        try {
            $terraform_outputs = Get-Content $TerraformOutputsFile | ConvertFrom-Json
            
            $staging_ecs_cluster = if ($terraform_outputs.staging_cluster_name.value) { $terraform_outputs.staging_cluster_name.value } else { " }
            Write-LogMessage "Staging ECS Cluster: $staging_ecs_cluster" "DEBUG"
            $staging_ecs_service = if ($terraform_outputs.staging_service_name.value) { $terraform_outputs.staging_service_name.value } else { " }
            Write-LogMessage "Staging ECS Service: $staging_ecs_service" "DEBUG"
            $prod_ecs_cluster = if ($terraform_outputs.production_cluster_name.value) { $terraform_outputs.production_cluster_name.value } else { " }
            Write-LogMessage "Production ECS Cluster: $prod_ecs_cluster" "DEBUG"
            $prod_ecs_service = if ($terraform_outputs.production_service_name.value) { $terraform_outputs.production_service_name.value } else { " }
            Write-LogMessage "Production ECS Service: $prod_ecs_service" "DEBUG"
            $staging_auto_scaling_group = if ($terraform_outputs.staging_auto_scaling_group_name.value) { $terraform_outputs.staging_auto_scaling_group_name.value } else { " }
            Write-LogMessage "Staging Auto Scaling Group: $staging_auto_scaling_group" "DEBUG"
            $staging_ecs_task_definition = if ($terraform_outputs.staging_task_definition_name.value) { $terraform_outputs.staging_task_definition_name.value } else { " }
            Write-LogMessage "Staging ECS Task Definition: $staging_ecs_task_definition" "DEBUG"
            $prod_ecs_task_definition = if ($terraform_outputs.production_task_definition_name.value) { $terraform_outputs.production_task_definition_name.value } else { " }
            Write-LogMessage "Production ECS Task Definition: $prod_ecs_task_definition" "DEBUG"
            $ecr_registry_name = if ($terraform_outputs.ecr_repository_name.value) { $terraform_outputs.ecr_repository_name.value } else { " }
            Write-LogMessage "ECR Repository Name: $ecr_registry_name" "DEBUG"
            $artifact_bucket = if ($terraform_outputs.artifact_bucket_name.value) { $terraform_outputs.artifact_bucket_name.value } else { " }
            Write-LogMessage "Artifact S3 Bucket: $artifact_bucket" "DEBUG"
            $lambda_bucket = if ($terraform_outputs.lambda_bucket_name.value) { $terraform_outputs.lambda_bucket_name.value } else { " }
            Write-LogMessage "Lambda S3 Bucket: $lambda_bucket" "DEBUG"
            $lambda_s3_key = if ($terraform_outputs.lambda_package_key.value) { $terraform_outputs.lambda_package_key.value } else { " }
            Write-LogMessage "Lambda S3 Key: $lambda_s3_key" "DEBUG"
            $lambda_handler = "lambda_handler.lambda_handler"
            $vpc_id = if ($terraform_outputs.vpc_id.value) { $terraform_outputs.vpc_id.value } else { " }
            Write-LogMessage "VPC ID: $vpc_id" "DEBUG"
            $private_subnets = if ($terraform_outputs.private_subnet_ids.value) { $terraform_outputs.private_subnet_ids.value -join "," } else { " }
            Write-LogMessage "Private Subnet IDs: $private_subnets" "DEBUG"
            $codebuild_sg = if ($terraform_outputs.codebuild_security_group_id.value) { $terraform_outputs.codebuild_security_group_id.value } else { " }
            Write-LogMessage "CodeBuild Security Group ID: $codebuild_sg" "DEBUG"
            $app_url_for_dast = if ($terraform_outputs.staging_alb_dns_name.value) { $terraform_outputs.staging_alb_dns_name.value } else { " }
            Write-LogMessage "App URL for DAST: $app_url_for_dast" "DEBUG"

            $parameters += @(
                "StagingECSCluster=$staging_ecs_cluster",
                "StagingECSService=$staging_ecs_service",
                "ProdECSCluster=$prod_ecs_cluster",
                "ProdECSService=$prod_ecs_service",
                "StagingECSTaskDefinition=$staging_ecs_task_definition",
                "ProdECSTaskDefinition=$prod_ecs_task_definition",
                "StagingASGName=$staging_auto_scaling_group",
                "EcrRegistryName=$ecr_registry_name",
                "PipelineArtifactS3Bucket=$artifact_bucket",
                "LambdaS3Bucket=$lambda_bucket",
                "LambdaS3Key=$lambda_s3_key",
                "LambdaHandler=$lambda_handler",
                "VpcId=$vpc_id",
                "PrivateSubnetIds=$private_subnets",
                "CodeBuildSecurityGroupId=$codebuild_sg",
                "AppURLForDAST=$app_url_for_dast"
            )
        } catch {
            Write-LogMessage "Failed to parse Terraform outputs: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    } else {
        Write-LogMessage "Provide your existing infrastructure details:" "WARNING"
        Write-Host ""
            $staging_ecs_cluster = Read-Host "Staging ECS Cluster Name"
        $staging_ecs_service = Read-Host "Staging ECS Service Name"
        $prod_ecs_cluster = Read-Host "Production ECS Cluster Name"
        $prod_ecs_service = Read-Host "Production ECS Service Name"
        $staging_auto_scaling_group = Read-Host "Staging Auto Scaling Group Name"
        $staging_ecs_task_definition = Read-Host "Staging ECS Task Definition Name"
        $prod_ecs_task_definition = Read-Host "Production ECS Task Definition Name"
        $ecr_registry_name = Read-Host "ECR Repository Name"
        $artifact_bucket = Read-Host "Pipeline Artifact S3 Bucket Name"
        $lambda_bucket = Read-Host "Lambda S3 Bucket Name"
        $lambda_s3_key = Read-Host "Lambda S3 Key (example: lambda/lambda.zip)"
        $lambda_handler = Read-Host "Lambda Handler (e.g., lambda_function.lambda_handler)"
        $app_url_for_dast = Read-Host "App URL for DAST (Staging)"
        $vpc_id = Read-Host "VPC ID"
        $private_subnets = Read-Host "Private Subnet IDs (comma-separated)"
        $codebuild_sg = Read-Host "CodeBuild Security Group ID"
        
        $parameters += @(
            "StagingECSCluster=$staging_ecs_cluster",
            "StagingECSService=$staging_ecs_service",
            "ProdECSCluster=$prod_ecs_cluster",
            "ProdECSService=$prod_ecs_service",
            "StagingECSTaskDefinition=$staging_ecs_task_definition",
            "ProdECSTaskDefinition=$prod_ecs_task_definition",
            "StagingASGName=$staging_auto_scaling_group",
            "EcrRegistryName=$ecr_registry_name",
            "PipelineArtifactS3Bucket=$artifact_bucket",
            "LambdaS3Bucket=$lambda_bucket",
            "LambdaS3Key=$lambda_s3_key",
            "LambdaHandler=$lambda_handler",
            "VpcId=$vpc_id",
            "PrivateSubnetIds=$private_subnets",
            "CodeBuildSecurityGroupId=$codebuild_sg",
            "AppURLForDAST=$app_url_for_dast"
        )
    }
    
    ##- Environment configuration parameters -##
    $parameters += @(
        "GitProviderType=$env:GIT_PROVIDER_TYPE",
        "FullGitRepositoryId=$env:FULL_GIT_REPOSITORY_ID",
        "BranchName=$env:BRANCH_NAME",
        "SnykAPIKey=$env:SNYK_API_KEY",
        "PipelineNotificationMail=$env:PIPELINE_NOTIFICATION_MAIL",
        "PipelineManualApproverMail=$env:PIPELINE_MANUAL_APPROVER_MAIL",
        "DockerHubUsername=$env:DOCKERHUB_USERNAME",
        "DockerHubPassword=$env:DOCKERHUB_PASSWORD"
    )
    
    ##- Deploy CloudFormation stack -##
    Write-LogMessage "Deploying CloudFormation stack: $stack_name" "INFO"
    
    $deployment_args = @(
        "cloudformation", "deploy",
        "--template-file", $template_file,
        "--stack-name", $stack_name,
        "--parameter-overrides"
    ) + $parameters + @(
        "--capabilities", "CAPABILITY_NAMED_IAM",
        "--region", $env:AWS_REGION,
        "--no-fail-on-empty-changeset"
    )
    
    & aws @deployment_args
    
    if ($LASTEXITCODE -eq 0) {
        Write-LogMessage "CloudFormation stack deployed successfully" "SUCCESS"
        
        ##- Get stack outputs -##
        Write-LogMessage "Retrieving stack outputs:" "INFO"
        aws cloudformation describe-stacks --stack-name $stack_name --query 'Stacks[0].Outputs' --region $env:AWS_REGION --output table
    } else {
        Write-LogMessage "CloudFormation stack deployment failed!" "ERROR"
        exit 1
    }
}

function Remove-CloudFormationStack {
    $stack_name = "devsecops-cloudformation"
    
    Write-LogMessage "Destroying CloudFormation stack: $stack_name" "WARNING"
    
    aws cloudformation delete-stack --stack-name $stack_name --region $env:AWS_REGION
    if ($LASTEXITCODE -eq 0) {
        Write-LogMessage "CloudFormation stack deletion initiated" "INFO"
        Write-LogMessage "Waiting for stack to be deleted..." "INFO"
        
        aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $env:AWS_REGION
        
        Write-LogMessage "CloudFormation stack deleted successfully" "SUCCESS"
    } else {
        Write-LogMessage "Failed to initiate CloudFormation stack deletion!" "ERROR"
        exit 1
    }
}

function Show-NextSteps {
    Write-LogMessage "AWS DevSecOps Hybrid CI/CD Platform deployment deployed successfully" "SUCCESS"
    Write-LogMessage "Next steps:" "INFO"
    Write-Host "   1. Complete the CodeConnections connection in AWS Console"
    Write-Host "   2. Create an AWS Organization for AWS Security Hub [if not done already]"
    Write-Host "   3. Enable AWS Security Hub CSPM (Services + Policies) in your account [if not done already]"
    Write-Host "   4. Verify SNS email subscriptions in your inbox"
    Write-Host "   5. Monitor pipeline execution in AWS CodePipeline console"
}

function Main {
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║                    AWS DevSecOps Hybrid CI/CD Platform                       ║" -ForegroundColor Blue
    Write-Host "║                    Deployment Script (PowerShell) v2.0                       ║" -ForegroundColor Blue
    Write-Host "║                                                                              ║" -ForegroundColor Blue
    Write-Host "║                  Author: Haitam Bidiouane (@sch0penheimer)                   ║" -ForegroundColor Blue
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    
    if ($Help) {
        Show-Help
        exit 0
    }
    
    Write-LogMessage "Starting AWS DevSecOps Hybrid CI/CD Platform deployment:" "SUCCESS"
    Write-LogMessage "OS detected: $(Get-OSType)" "INFO"
    
    Test-Prerequisites
    
    Import-Environment
    
    Set-AWSCredentials

    ##- Handle rollback operation -##
    if ($RollbackDeployment) {
        Remove-Infrastructure
        Write-LogMessage "Infrastructure destruction completed." "SUCCESS"
        Remove-CloudFormationStack
        Write-LogMessage "CloudFormation stack destruction completed." "SUCCESS"
        Write-LogMessage "Deployment Rollbacked Successfully !" "SUCCESS"
        exit 0
    }

    ##- I. Create Lambda ZIP package
    New-LambdaPackage
    
    ##- II. Deploy platform infrastructure (or skip)
    $terraform_outputs_file = "
    if (-not $SkipInfrastructure) {
        Write-LogMessage "Proceeding with Terraform platform infrastructure deployment:" "INFO"
        
        Deploy-Infrastructure
        
        Get-TerraformOutputs
        
        $terraform_outputs_file = "$env:TEMP\terraform_outputs.json"
    } else {
        Write-LogMessage "Platform Infrastructure deployment skipped as requested." "WARNING"
    }

    ##- III. Deploy CloudFormation pipeline stack
    Deploy-CloudFormationStack -TerraformOutputsFile $terraform_outputs_file

    ##- IV. Print guiding next steps
    Show-NextSteps
}

##- Trap errors and cleanup --##
trap {
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}

##- Execute main function --##
Main