# AWS DevSecOps Hybrid CI/CD Platform

This project implements a robust, automated Hybrid DevSecOps platform on AWS, designed to enforce security and compliance at every stage of the software delivery lifecycle for containerized and EC2-based applications.

## Table of Contents
- [Project Overview](#project-overview)
- [Quick Start](#quick-start)
  - [Prerequisites](#prerequisites)
  - [Clone and Configure](#clone-and-configure)
  - [Deploy (Terraform + CloudFormation)](#deploy-terraform--cloudformation)
- [Architecture](#architecture)
  - [High-level AWS Architecture](#high-level-aws-architecture)
  - [Component Breakdown](#component-breakdown)
    - [Terraform (Main Platform Infrastructure)](#terraform-platform-infrastructure)
      - [Networking (VPC, Subnets, Security Groups)](#networking-vpc-subnets-security-groups)
      - [...]
    - [CloudFormation (CI/CD Pipeline + Related Resources)](#cloudformation-pipeline)
      - [...]
- [Infrastructure as Code (IaC)](#infrastructure-as-code-iac)
  - [Terraform Structure & Modules](#terraform-structure--modules)
  - [State Management & Backends](#state-management--backends)
  - [CloudFormation Stacks & Parameters](#cloudformation-stacks--parameters)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Pipeline Stages](#pipeline-stages)
  - [CodeBuild Projects & Buildspecs](#codebuild-projects--buildspecs)
  - [Deployment Targets](#deployment-targets)
  - [Manual Approvals & Notifications](#manual-approvals--notifications)
- [Security & Compliance](#security--compliance)
  - [Secrets / Config Management](#secrets-config-management)
  - [SCA / SAST / DAST / RASP Integrations (Clair, Snyk, OWASP ZAP, CNCF Falco)](#sca--sast--dast-integrations)
    - [Clair]()
    - [Snyk]()
    - [OWASP ZAP]()
    - [CNCF Falco]()
  - [Security Hub Centalization & Findings Import](#security-hub-centalization--findings-import)
  - [IAM Design & Least Privilege](#iam-design--least-privilege)
  - [KMS & Encryption](#kms--encryption)
  - [Compliance Mapping & Audit](#compliance-mapping--audit)
- [Monitoring & Observability](#monitoring--observability)
  - [CloudWatch Logs & Metrics](#cloudwatch-logs--metrics)
  - [CloudTrail & AWS Config](#cloudtrail--aws-config)
  - [Alerts & Dashboards](#alerts--dashboards)
- [Repository Layout](#repository-layout)
  - [Top-level Structure](#top-level-structure)
  - [Important Files & Where to Find Them](#important-files--where-to-find-them)
- [Configuration Reference](#configuration-reference)
  - [.env Variables & Secrets](#env-variables--secrets)
  - [Terraform Variables & Outputs](#terraform-variables--outputs)
  - [CloudFormation Parameters](#cloudformation-parameters)
- [License](#license)
- [Contacts & Maintainers](#contacts--maintainers)

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