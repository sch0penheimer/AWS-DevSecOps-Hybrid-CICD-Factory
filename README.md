# AWS DevSecOps Hybrid CI/CD Platform

This project implements a fully automated Hybrid DevSecOps platform on AWS, designed to enforce security and compliance at every stage of the software delivery lifecycle, while decoupling **the CI/CD pipeline and related resources** from **the main platform** that hosts ECS EC2-based containerized application workloads, respectively via AWS CloudFormation and Terraform, hence the "Hybrid" label.

> [!NOTE]
> Architected, conceptualized, implemented, and fully documented by **Haitam Bidiouane** (**@sch0penheimer**).

## Table of Contents
- [Project Overview](#project-overview)
- [Architecture](#architecture)
  - [High-level AWS Architecture](#high-level-aws-architecture)
  - [Hybrid IaC Approach](#hybrid-iac-approach)
  - [Component Overview](#component-overview)
- [Infrastructure Components](#infrastructure-components)
  - [Terraform Infrastructure (Platform)](#terraform-infrastructure-platform)
    - [Network Module](#network-module)
    - [Compute Module (ECS EC2-based)](#compute-module-ecs-ec2-based)
    - [Storage Module](#storage-module)
  - [CloudFormation Pipeline](#cloudformation-pipeline)
    - [CodePipeline Structure](#codepipeline-structure)
    - [CodeBuild Projects](#codebuild-projects)
    - [Security Integrations](#security-integrations)
- [ECS Infrastructure Details](#ecs-infrastructure-details)
  - [Cluster Configuration](#cluster-configuration)
  - [Task Definitions](#task-definitions)
  - [Auto Scaling Groups](#auto-scaling-groups)
  - [Load Balancers](#load-balancers)
  - [ECR Repository](#ecr-repository)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Pipeline Stages](#pipeline-stages)
  - [Security Scanning](#security-scanning)
  - [Deployment Strategy](#deployment-strategy)
  - [Manual Approvals](#manual-approvals)
- [Security & Compliance](#security--compliance)
  - [Security Tools Integration](#security-tools-integration)
    - [Secrets Scanning (git-secrets)](#secrets-scanning)
    - [Static Analysis (Snyk, Clair)](#static-analysis)
    - [Dynamic Analysis (OWASP ZAP)](#dynamic-analysis)
    - [Runtime Security (CNCF Falco)](#runtime-security)
  - [Security Hub Integration](#security-hub-integration)
  - [IAM & Access Control](#iam--access-control)
  - [Encryption & KMS](#encryption--kms)
- [Monitoring & Observability](#monitoring--observability)
  - [CloudWatch Integration](#cloudwatch-integration)
  - [ECS Container Insights](#ecs-container-insights)
  - [Application Load Balancer Metrics](#application-load-balancer-metrics)
  - [CloudTrail & Config](#cloudtrail--config)
- [Deployment Scripts](#deployment-scripts)
  - [Bash Deployment Script](#bash-deployment-script)
  - [PowerShell Deployment Script](#powershell-deployment-script)
  - [Lambda Packaging](#lambda-packaging)
- [Configuration Reference](#configuration-reference)
  - [Environment Variables](#environment-variables)
  - [Terraform Variables](#terraform-variables)
  - [CloudFormation Parameters](#cloudformation-parameters)
  - [Cross-IaC Integration](#cross-iac-integration)
- [Contributing](#contributing)
- [License](#license)

### **Hybrid IaC Approach**

- **Terraform** manages core infrastructure and shared resources.
- **CloudFormation** manages pipeline orchestration and application-specific resources.
- Cross-tool resource references (e.g., S3 bucket name) are passed via CloudFormation Parameters and Terraform Outputs for cross-IaC integration.

### **Core Components**

- **Infrastructure Provisioning:**  
  - Uses **Terraform** to provision foundational AWS resources, including VPCs, public/private subnets, EC2 instances, security groups, and S3 artifact storage bucket.
  - S3 buckets are configured with strict security policies enforcing server-side encryption (AWS KMS) and secure transport (SSL/TLS).

- **CI/CD Pipeline Orchestration:**  
  - Uses **AWS CloudFormation** to define and deploy a multi-stage **CodePipeline** integrating CodeCommit, CodeBuild, and CodeDeploy.
  - Pipeline stages include source retrieval, secrets scanning, SCA (Static Code Analysis) / SAST (Static Application Security Testing), DAST (Dynamic Application Security Testing), artifact storage, manual approval, and deployment to production EC2 instances.

- **Security Automation:**  
  - Integrates security tools such as **git-secrets**, **Snyk**, and **OWASP ZAP** via CodeBuild projects for automated code and container vulnerability scanning.
  - Security findings are imported into **AWS Security Hub** using Lambda functions for centralized visibility and compliance tracking.

- **Monitoring & Compliance:**  
  - Implements **CloudWatch Logs** for pipeline and build activity monitoring.
  - **CloudTrail** is enabled for auditing API calls and resource changes.
  - **AWS Config Rules** enforce compliance on CodeBuild projects and CloudTrail log validation.

- **Notifications & Approvals:**  
  - **SNS Topics** are used for pipeline state change notifications and manual approval requests, integrating with email for stakeholder communication.

- **IAM:**  
  - Fine-grained IAM roles and policies restrict access and permissions for pipeline, build, and Lambda execution.

- **KMS:**  
  - **KMS keys** are used for artifact encryption and secure key management.

### **Security Best Practices**

- All artifact storage is encrypted and accessible only over secure connections.
- Automated security scans block deployments on critical findings.
- Least-privilege IAM roles and policies are enforced.
- All changes and deployments are logged and auditable.

---

**Summary:**  
This project delivers a production-grade, security-focused DevSecOps pipeline platform on AWS, leveraging both Terraform and CloudFormation for modular, scalable, and compliant infrastructure and application delivery.