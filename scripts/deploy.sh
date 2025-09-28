#!/bin/bash
#################################################################################
# File: deploy.sh
# Description: Main deployment script (Bash) for AWS DevSecOps Hybrid CI/CD Platform
# Author: Haitam Bidiouane (@sch0penheimer)
# Last Modified: 27/09/2025
#
# This script orchestrates the complete deployment:
# 1. Validates environment configuration
# 2. Creates Lambda ZIP package
# 3. Optionally deploys Terraform infrastructure
# 4. Deploys CloudFormation CI/CD pipeline with Terraform outputs
#################################################################################

set -e

##-- Script config --##
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ROOT_DIR/terraform-manifests"
CLOUDFORMATION_DIR="$ROOT_DIR/cloudformation"
ENV_FILE="$ROOT_DIR/.env"

##-- Colors (output) --##
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NOCOLOR='\033[0m'

##-- CLI options --##
SKIP_INFRASTRUCTURE=false
DESTROY_INFRASTRUCTURE=false
SHOW_HELP=false

##-- CLI arguments parsing --##
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-infrastructure)
            SKIP_INFRASTRUCTURE=true
            shift
            ;;
        --destroy-infrastructure)
            DESTROY_INFRASTRUCTURE=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

show_help() {
    echo -e "${CYAN}AWS DevSecOps Hybrid CI/CD Platform Deployment Script Helping Manual${NOCOLOR}"
    echo
    echo -e "${CYAN}USAGE:${NOCOLOR}"
    echo "    $0 [OPTIONS]"
    echo
    echo -e "${CYAN}OPTIONS:${NOCOLOR}"
    echo "    --skip-infrastructure           Skip Terraform infrastructure deployment (use existing infrastructure)"
    echo "    --destroy-infrastructure        Destroy existing Terraform infrastructure and exit"
    echo "    --help, -h                      Show this help message"
    echo
    echo -e "${CYAN}EXAMPLES:${NOCOLOR}"
    echo -e "    $0                                    ${BLUE}#- Full deployment with new infrastructure -#${NOCOLOR}"
    echo -e "    $0 --skip-infrastructure              ${BLUE}#- Deploy only CI/CD pipeline to existing infrastructure -#${NOCOLOR}"
    echo -e "    $0 --destroy-infrastructure           ${BLUE}#- Destroy infrastructure and exit -#${NOCOLOR}"
    echo
    echo -e "${CYAN}PREREQUISITES:${NOCOLOR}"
    echo "    - Bash v4.0+"
    echo "    - AWS CLI v2+"
    echo "    - Terraform v1.0+"
    echo "    - jq (JSON processor)"
    echo "    - zip & unzip (for Lambda packaging)"
    echo "    - .env file completed with required configuration"
    echo
    echo -e "${CYAN}NOTES:${NOCOLOR}"
    echo "    - All prerequisites MUST be installed before running this script"
    echo "    - Supports Windows (Git Bash/WSL), macOS, and Linux"
    echo "    - Script will exit if any prerequisites are missing"
}

##-- Logger function (w/ timestamp & color coding) --##
log_message() {
    local message="$1"
    local type="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $type in
        "ERROR")   echo -e "[$timestamp: ${RED}ERROR${NOCOLOR}] $message" ;;
        "WARNING") echo -e "[$timestamp: ${YELLOW}WARNING${NOCOLOR}] $message" ;;
        "SUCCESS") echo -e "[$timestamp: ${GREEN}SUCCESS${NOCOLOR}] $message" ;;
        "INFO")    echo -e "[$timestamp: ${CYAN}INFO${NOCOLOR}] $message" ;;
        "DEBUG")   echo -e "[$timestamp: ${PURPLE}DEBUG${NOCOLOR}] $message" ;;
        *)         echo -e "[$timestamp: ${BLUE}LOG${NOCOLOR}] $message" ;;
    esac
}

##-- Function to detect OS --##
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

##-- Prerequisites check (validation only) --##
check_prerequisites() {
    log_message "Checking prerequisites:" "INFO"
    local missing_tools=()
    local all_good=true
    
    #- Check AWS CLI -#
    if ! command -v aws &> /dev/null; then
        log_message "AWS CLI not found" "ERROR"
        missing_tools+=("AWS CLI")
        all_good=false
    else
        local aws_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
        log_message "AWS CLI found: v$aws_version" "SUCCESS"
    fi

    #- Check Terraform -#
    if ! command -v terraform &> /dev/null; then
        log_message "Terraform not found" "ERROR"
        missing_tools+=("Terraform")
        all_good=false
    else
        local tf_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | cut -d' ' -f2)
        log_message "Terraform found: $tf_version" "SUCCESS"
        
        #- Check minimum Terraform version (1.0+) -#
        local tf_major_version=$(echo "$tf_version" | cut -d'.' -f1 | sed 's/v//')
        if [[ "$tf_major_version" -lt 1 ]]; then
            log_message "Terraform version $tf_version is too old. Required: v1.0+" "ERROR"
            missing_tools+=("Terraform v1.0+")
            all_good=false
        fi
    fi
    
    #- Check jq -#
    if ! command -v jq &> /dev/null; then
        log_message "jq not found (required for parsing Terraform outputs)" "ERROR"
        missing_tools+=("jq")
        all_good=false
    else
        local jq_version=$(jq --version 2>/dev/null || echo "jq-unknown")
        log_message "jq found: $jq_version" "SUCCESS"
    fi
    
    #- Check unzip (required for Lambda packaging) -#
    if ! command -v unzip &> /dev/null; then
        log_message "unzip not found (required for Lambda packaging)" "ERROR"
        missing_tools+=("unzip")
        all_good=false
    else
        log_message "unzip found" "SUCCESS"
    fi

    #- Check Bash version -#
    if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
        log_message "Bash version ${BASH_VERSION} is too old. Required: 4.0+" "ERROR"
        missing_tools+=("Bash 4.0+")
        all_good=false
    else
        log_message "Bash version: ${BASH_VERSION}" "SUCCESS"
    fi

    #- Check zip (required for Lambda packaging) -#
    if ! command -v zip &> /dev/null; then
        log_message "zip not found (required for Lambda packaging)" "ERROR"
        missing_tools+=("zip")
        all_good=false
    else
        log_message "zip found" "SUCCESS"
    fi
    
    #- Check .env file -#
    if [[ ! -f "$ENV_FILE" ]]; then
        log_message " .env file not found at: $ENV_FILE" "ERROR"
        missing_tools+=(".env configuration file")
        all_good=false
    else
        log_message ".env file found" "SUCCESS"
    fi
    
    #- Exit if any prerequisites are missing -#
    if [[ "$all_good" == false ]]; then
        log_message "PREREQUISITES CHECK FAILED" "ERROR"
        log_message "Missing tools/requirements: ${missing_tools[*]}" "ERROR"
        log_message "Please install the missing prerequisites and re-run the script." "WARNING"
        exit 1
    fi
    
    log_message "All prerequisites check completed successfully" "SUCCESS"
}

##-- Function to configure AWS credentials --##
configure_aws_credentials() {
    log_message "Configuring AWS credentials:" "INFO"
    
    #- Check if credentials are already available via AWS credential chain -#
    if aws sts get-caller-identity &> /dev/null; then
        local aws_identity=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
        local account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
        log_message "Using existing AWS credentials: $aws_identity" "SUCCESS"
        log_message "AWS Account ID: $account_id" "INFO"
        return 0
    fi

    #- If no credentials found, check .env file -#
    if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]]; then
        log_message "Using AWS credentials from .env file" "INFO"
        
        export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
        export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
        
        if [[ -n "$AWS_REGION" ]]; then
            export AWS_DEFAULT_REGION="$AWS_REGION"
        fi
        
        #- Verify credentials work -#
        if aws sts get-caller-identity &> /dev/null; then
            local aws_identity=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
            local account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
            log_message "AWS credentials from .env verified: $aws_identity" "SUCCESS"
            log_message "AWS Account ID: $account_id" "INFO"
        else
            log_message "AWS credentials from .env are invalid!" "ERROR"
            log_message "Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env file" "ERROR"
            exit 1
        fi
        
    else
        log_message "No AWS credentials found!" "ERROR"
        log_message "Please use one of the following methods:" "INFO"
        log_message "1. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env file" "INFO"
        log_message "2. Run 'aws configure' to set up AWS CLI profile" "INFO"
        log_message "3. Use IAM roles if running on AWS infrastructure" "INFO"
        log_message "4. Configure AWS SSO: 'aws configure sso'" "INFO"
        exit 1
    fi
}

load_environment() {
    log_message "Loading environment configuration:" "INFO"
    
    if [[ -f "$ENV_FILE" ]]; then
        #- Export variables from .env file -#
        set -a
        source "$ENV_FILE"
        set +a
        
        log_message "Environment configuration loaded successfully" "SUCCESS"
    else
        log_message ".env file not found!" "ERROR"
        exit 1
    fi
    
    #- Validate required environment variables -#
    local required_vars=(
        "GIT_PROVIDER_TYPE" "FULL_GIT_REPOSITORY_ID" "BRANCH_NAME"
        "SNYK_API_KEY" "PIPELINE_NOTIFICATION_MAIL" "PIPELINE_MANUAL_APPROVER_MAIL"
        "AWS_REGION"
    )
    
    log_message "Validating required environment variables:" "INFO"
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_message " Required environment variable $var is not set!" "ERROR"
            missing_vars+=("$var")
        else
            log_message "$var is set" "DEBUG"
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_message " Missing required environment variables: ${missing_vars[*]}" "ERROR"
        log_message "Please update your .env file with the missing variables" "ERROR"
        exit 1
    fi
    
    #- AWS credentials in .env (can use other methods) -#
    if [[ -n "$AWS_ACCESS_KEY_ID" || -n "$AWS_SECRET_ACCESS_KEY" ]]; then
        if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
            log_message " Both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be provided together" "ERROR"
            exit 1
        fi
        log_message "AWS credentials found in .env file" "SUCCESS"
    else
        log_message "No AWS credentials in .env file - will use AWS credential chain" "INFO"
    fi
    
    log_message "Environment validation completed successfully" "SUCCESS"
}

create_lambda_package() {
    log_message "Creating Lambda ZIP package:" "INFO"
    
    local zip_script="$SCRIPT_DIR/zip_lambda.sh"
    if [[ -f "$zip_script" ]]; then
        chmod +x "$zip_script"
        log_message "Executing Lambda packaging script:" "INFO"
        
        if "$zip_script"; then
            log_message "Lambda packaging completed successfully" "SUCCESS"
            
            #- Verify -#
            local lambda_zip_path="$TERRAFORM_DIR/storage/lambda.zip"
            if [[ -f "$lambda_zip_path" ]]; then
                local zip_size=$(du -h "$lambda_zip_path" | cut -f1)
                log_message "Lambda ZIP created: $lambda_zip_path ($zip_size)" "SUCCESS"
            else
                log_message "Lambda ZIP file not found at expected location: $lambda_zip_path" "ERROR"
                exit 1
            fi
        else
            log_message "Lambda packaging script failed with exit code: $?" "ERROR"
            log_message "Check the zip_lambda.sh script for errors" "ERROR"
            exit 1
        fi
    else
        log_message "Lambda ZIP script not found at: $zip_script" "ERROR"
        exit 1
    fi
}

deploy_infrastructure() {
    log_message "Deploying Terraform infrastructure:" "INFO"
    
    cd "$TERRAFORM_DIR"
    
    log_message "Initializing Terraform:" "INFO"
    terraform init
    
    #- Validate Terraform config -#
    log_message "Validating Terraform configuration:" "INFO"
    terraform validate

    #- Plan deployment -#
    log_message "Planning Terraform deployment:" "INFO"
    terraform plan -out=tfplan
    
    #- Apply deployment -#
    log_message "Applying Terraform deployment:" "WARNING"
    terraform apply tfplan
    
    log_message "Terraform infrastructure deployed successfully" "SUCCESS"
    cd "$ROOT_DIR"
}

destroy_infrastructure() {
    log_message "Destroying Terraform infrastructure:" "WARNING"
    
    cd "$TERRAFORM_DIR"
    
    echo
    log_message "WARNING: This will destroy ALL Terraform-managed infrastructure" "ERROR"
    read -p "Are you absolutely sure? Type 'DESTROY' to continue: " confirmation
    
    if [[ "$confirmation" != "DESTROY" ]]; then
        log_message "Destruction cancelled by user" "INFO"
        exit 0
    fi
    
    terraform destroy -auto-approve

    log_message "Terraform infrastructure destroyed successfully" "SUCCESS"
    cd "$ROOT_DIR"
}

get_terraform_outputs() {
    log_message "Retrieving Terraform outputs:" "INFO"
    
    cd "$TERRAFORM_DIR"
    
    if ! terraform output -json > /tmp/terraform_outputs.json 2>/dev/null; then
        log_message " Failed to retrieve Terraform outputs" "ERROR"
        exit 1
    fi
    
    cd "$ROOT_DIR"
    
    log_message "Terraform outputs retrieved successfully" "SUCCESS"
    echo "/tmp/terraform_outputs.json"
}

update_appspec_files() {
    local terraform_outputs_file="$1"
    
    log_message "Updating AppSpec files with Terraform outputs:" "INFO"
    
    if [[ ! -f "$terraform_outputs_file" ]]; then
        log_message "Terraform outputs file not found - skipping AppSpec updates" "WARNING"
        return 0
    fi
    
    #- Get values from Terraform outputs -#
    local prod_task_definition_arn=$(jq -r '.prod_task_definition_arn.value // empty' "$terraform_outputs_file")
    local container_name=$(jq -r '.container_name.value // empty' "$terraform_outputs_file")
    
    #- Validation -#
    if [[ -z "$prod_task_definition_arn" || -z "$container_name" ]]; then
        log_message "Missing required values for AppSpec update:" "ERROR"
        log_message "  - prod_task_definition_arn: $prod_task_definition_arn" "DEBUG"
        log_message "  - container_name: $container_name" "DEBUG"
        exit 1
    fi

    #- Update AppSpec file -#
    local prod_appspec="$ROOT_DIR/appspecs/5-prod-codedeploy-appspec.yml"
    
    if [[ -f "$prod_appspec" ]]; then
        log_message "Updating production AppSpec file: $prod_appspec" "INFO"
        
        #- Create backup -#
        cp "$prod_appspec" "$prod_appspec.backup"
        
        #- Replace placeholders -#
        sed -i "s|<TASK_DEFINITION>|$prod_task_definition_arn|g" "$prod_appspec"
        sed -i "s|<CONTAINER_NAME>|$container_name|g" "$prod_appspec"
        
        log_message "Production AppSpec updated successfully:" "SUCCESS"
        log_message "  - Task Definition: $prod_task_definition_arn" "DEBUG"
        log_message "  - Container Name: $container_name" "DEBUG"
    else
        log_message "Production AppSpec file not found: $prod_appspec" "WARNING"
    fi
}

deploy_cloudformation_stack() {
    local terraform_outputs_file="$1"
    
    log_message "Deploying CloudFormation CI/CD pipeline:" "INFO"
    
    local stack_name="aws-devsecops-hybrid-cicd-platform"
    local template_file="$CLOUDFORMATION_DIR/codepipeline.yaml"
    
    if [[ ! -f "$template_file" ]]; then
        log_message " CloudFormation template not found at: $template_file" "ERROR"
        exit 1
    fi
    
    #- Build parameter overrides- #
    local parameters=()
    
    #- Terraform infrastructure outputs as CloudFormation parameters -#
    if [[ -f "$terraform_outputs_file" ]]; then
        log_message "Using Terraform outputs for infrastructure parameters:" "INFO"
        
        local staging_ecs_cluster=$(jq -r '.staging_ecs_cluster_name.value // empty' "$terraform_outputs_file")
        local staging_ecs_service=$(jq -r '.staging_ecs_service_name.value // empty' "$terraform_outputs_file")
        local prod_ecs_cluster=$(jq -r '.prod_ecs_cluster_name.value // empty' "$terraform_outputs_file")
        local prod_ecs_service=$(jq -r '.prod_ecs_service_name.value // empty' "$terraform_outputs_file")
        local prod_target_group=$(jq -r '.prod_target_group_name.value // empty' "$terraform_outputs_file")
        local ecr_registry_name=$(jq -r '.ecr_repository_name.value // empty' "$terraform_outputs_file")
        local artifact_bucket=$(jq -r '.artifact_store_bucket_name.value // empty' "$terraform_outputs_file")
        local lambda_bucket=$(jq -r '.lambda_bucket_name.value // empty' "$terraform_outputs_file")
        local lambda_handler="lambda_handler.lambda_handler"
        local lambda_s3_key=$(jq -r '.lambda_s3_key.value // empty' "$terraform_outputs_file")
        local app_url_for_dast=$(jq -r '.staging_alb_dns_name.value // empty' "$terraform_outputs_file")
        local vpc_id=$(jq -r '.vpc_id.value // empty' "$terraform_outputs_file")
        local private_subnets=$(jq -r '.private_subnet_ids.value | join(",") // empty' "$terraform_outputs_file")
        local codebuild_sg=$(jq -r '.codebuild_security_group_id.value // empty' "$terraform_outputs_file")
        
        parameters+=(
            "StagingECSCluster=$staging_ecs_cluster"
            "StagingECSService=$staging_ecs_service"
            "ProdECSCluster=$prod_ecs_cluster"
            "ProdECSService=$prod_ecs_service"
            "ProdTargetGroup=$prod_target_group"
            "EcrRegistryName=$ecr_registry_name"
            "PipelineArtifactS3Bucket=$artifact_bucket"
            "LambdaS3Bucket=$lambda_bucket"
            "LambdaS3Key=$lambda_s3_key"
            "LambdaHandler=$lambda_handler"
            "AppURLForDAST=$app_url_for_dast"
            "VpcId=$vpc_id"
            "PrivateSubnetIds=$private_subnets"
            "CodeBuildSecurityGroupId=$codebuild_sg"
        )
    else
        #- Prompt user for existing custom infrastructure values -#
        log_message "Provide your existing infrastructure details:" "WARNING"
        echo
        read -p "Staging ECS Cluster Name: " staging_ecs_cluster
        read -p "Staging ECS Service Name: " staging_ecs_service
        read -p "Production ECS Cluster Name: " prod_ecs_cluster
        read -p "Production ECS Service Name: " prod_ecs_service
        read -p "Production Target Group Name: " prod_target_group
        read -p "ECR Repository Name: " ecr_registry_name
        read -p "Pipeline Artifact S3 Bucket Name: " artifact_bucket
        read -p "Lambda S3 Bucket Name: " lambda_bucket
        read -p "Lambda S3 Key (example: lambda/lambda.zip): " lambda_s3_key
        read -p "Lambda Handler (e.g., lambda_function.lambda_handler): " lambda_handler
        read -p "App URL for DAST (Staging): " app_url_for_dast
        read -p "VPC ID: " vpc_id
        read -p "Private Subnet IDs (comma-separated): " private_subnets
        read -p "CodeBuild Security Group ID: " codebuild_sg
        
        parameters+=(
            "StagingECSCluster=$staging_ecs_cluster"
            "StagingECSService=$staging_ecs_service"
            "ProdECSCluster=$prod_ecs_cluster"
            "ProdECSService=$prod_ecs_service"
            "ProdTargetGroup=$prod_target_group"
            "EcrRegistryName=$ecr_registry_name"
            "PipelineArtifactS3Bucket=$artifact_bucket"
            "LambdaS3Bucket=$lambda_bucket"
            "LambdaS3Key=$lambda_s3_key"
            "LambdaHandler=$lambda_handler"
            "AppURLForDAST=$app_url_for_dast"
            "VpcId=$vpc_id"
            "PrivateSubnetIds=$private_subnets"
            "CodeBuildSecurityGroupId=$codebuild_sg"
        )
    fi
    
    #- Environment configuration parameters -#
    parameters+=(
        "GitProviderType=$GIT_PROVIDER_TYPE"
        "FullGitRepositoryId=$FULL_GIT_REPOSITORY_ID"
        "BranchName=$BRANCH_NAME"
        "SnykAPIKey=$SNYK_API_KEY"
        "PipelineNotificationMail=$PIPELINE_NOTIFICATION_MAIL"
        "PipelineManualApproverMail=$PIPELINE_MANUAL_APPROVER_MAIL"
    )
    
    #- Deploy CloudFormation stack -#
    log_message "Deploying CloudFormation stack: $stack_name" "INFO"
    
    if aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides "${parameters[@]}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" \
        --no-fail-on-empty-changeset; then
        
        log_message "CloudFormation stack deployed successfully" "SUCCESS"
        
        #- Get stack outputs -#
        log_message "Retrieving stack outputs:" "INFO"
        aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs' \
            --region "$AWS_REGION" \
            --output table
    else
        log_message " CloudFormation stack deployment failed!" "ERROR"
        exit 1
    fi
}

print_next_steps() {
    echo
    log_message "AWS DevSecOps Hybrid CI/CD Platform deployment deployed successfully" "SUCCESS"
    echo
    log_message "Next steps:" "INFO"
    echo "   1. Complete the CodeConnections connection in AWS Console"
    echo "   2. Verify SNS email subscriptions in your inbox"
    echo "   3. Monitor pipeline execution in AWS CodePipeline console"
    echo
}

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NOCOLOR}"
    echo -e "${BLUE}║                    AWS DevSecOps Hybrid CI/CD Platform                       ║${NOCOLOR}"
    echo -e "${BLUE}║                         Deployment Script (bash) v2.0                        ║${NOCOLOR}"
    echo -e "${BLUE}║                                                                              ║${NOCOLOR}"
    echo -e "${BLUE}║${NOCOLOR}                  Author: Haitam Bidiouane (@sch0penheimer)                   ${BLUE}║${NOCOLOR}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NOCOLOR}"
    echo
    
    if [[ "$SHOW_HELP" == true ]]; then
        show_help
        exit 0
    fi
    
    log_message "Starting AWS DevSecOps Hybrid CI/CD Platform deployment:" "SUCCESS"
    log_message "OS detected: $(detect_os)" "INFO"
    
    check_prerequisites
    
    load_environment
    
    configure_aws_credentials

    #- Handle destroy operation -#
    if [[ "$DESTROY_INFRASTRUCTURE" == true ]]; then
        destroy_infrastructure
        log_message "Infrastructure destruction completed." "SUCCESS"
        exit 0
    fi
    
    #- I. Create Lambda ZIP package -#
    create_lambda_package
    
    #- II. Deploy platform infrastructure (or skip) -#
    local terraform_outputs_file=""
    if [[ "$SKIP_INFRASTRUCTURE" == false ]]; then
        echo
        read -p "Do you want to deploy new platform (standard) infrastructure using Terraform? (y/N): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            deploy_infrastructure
            terraform_outputs_file=$(get_terraform_outputs)
            
            #- 1) Update AppSpec files with Terraform outputs -#
            update_appspec_files "$terraform_outputs_file"
        else
            log_message "Skipping infrastructure deployment. Will use existing infrastructure." "WARNING"
        fi
    else
        log_message "Infrastructure deployment skipped as requested." "WARNING"
    fi

    #- III. Deploy CloudFormation pipeline stack -#
    deploy_cloudformation_stack "$terraform_outputs_file"

    #- IV. Print guiding next steps -#
    print_next_steps
}

#- Trap errors and cleanup -#
trap 'log_message "Script interrupted or failed" "ERROR"; exit 1' ERR INT TERM

#- Execute main function -#
main "$@"