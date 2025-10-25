
---
> **Last Updated:** October 10th, 2025  
> **Author:** [Haitam Bidiouane](https://github.com/sch0penheimer)
---

# AWS DevSecOps Hybrid CI/CD Factory

This project implements a fully automated Hybrid DevSecOps Factory/Platform on AWS, designed to enforce security and compliance at every stage of the software delivery lifecycle, while decoupling <ins>**the CI/CD pipeline and related resources**</ins> from <ins>**the main platform**</ins> that hosts ECS EC2-based containerized application workloads, respectively via AWS CloudFormation and Terraform, hence the "Hybrid" label.

> [!NOTE]
> Architected, implemented, and fully documented by **Haitam Bidiouane** (***@sch0penheimer***).

## Table of Contents

### [Section I: Factory Architecture & Infrastructure Overview](#section-i-platform-architecture--infrastructure-overview)
- [Project Overview](#project-overview)
- [Architecture](#architecture)
  - [Hybrid IaC Approach](#hybrid-iac-approach)
  - [High-level AWS Architecture](#high-level-aws-architecture)

### [Section II: Architectural Deep Dive](#section-ii-architectural-deep-dive)
- [Terraform Infrastructure Sub-Architecture](#terraform-infrastructure-sub-architecture)
  - [VPC Architecture](#vpc-architecture)
  - [Public Resources Architecture](#public-resources-architecture)
  - [Private Resources Architecture](#private-resources-architecture)
- [AWS CloudFormation CI/CD Sub-Architecture](#cloudformation-ci/cd-sub-architecture)
  - [CodePipeline Architecture](#codepipeline-architecture)
  - [Pipeline Integration & Workflow](#pipeline-integration--workflow)

### [Section III: Technical Implementation Details & Operations](#section-iii-technical-implementation-details--operations)
- [VPC Internal Networking](#vpc-internal-networking)
  - [Subnetting Strategy & High Availability](#subnetting-strategy--high-availability)
  - [Custom NAT EC2 instances](#custom-nat-ec2-instances)
  - [ALB Load Balancers](#alb-load-balancers)
- [ECS Infrastructure Details](#ecs-infrastructure-details)
  - [Staging & Production Clusters](#staging--production-clusters)
  - [Task Definitions](#task-definitions)
  - [Auto Scaling Groups](#auto-scaling-groups)
  - [ECR Repository](#ecr-repository)
- [CI/CD Pipeline](#cicd-pipeline)
  - [AWS CodePipeline Stages](#codepipeline-stages)
    - [AWS CodeConnections Connection](#aws-codeconnections-connection)
    - [AWS CodeBuild Projects](#aws-codebuild-projects)
  - [S3 Artifact Store](#s3-artifact-store)
  - [Normalization & Aggregation Lambda Function](#security-normalizer-lambda-function)
  - [Blue/Green Deployment Strategy](#blue--green-deployment-strategy)
- [Security & Compliance](#security--compliance)
  - [Security Tools Integration](#security-tools-integration)
    - [Secrets Scanning (git-secrets)](#secrets-scanning)
    - [SAST - Static Application Security Analysis (Snyk)](#sast--static-application-security-analysis)
    - [SCA - Software Composition Analysis](#sca--software-composition-analysis)
    - [DAST - Dynamic Application Security Analysis (OWASP ZAP)](#dast--dynamic-application-security-analysis)
    - [RASP - Runtime Application Security Protection (CNCF Falco)](#rasp--runtime-application-security-protection)
  - [AWS Security Hub Integration](#aws-security-hub-integration)
  - [IAM & Access Control](#iam--access-control)
  - [SSM Parameter Store](#ssm-parameter-store)
  - [Encryption & KMS](#encryption--kms)
- [Event-Driven Architecture](#event-driven-architecture)
  - [AWS EventBridge Rules](#aws-eventbridge-rules)
  - [AWS CloudWatch Events](#aws-cloudwatch-events)
  - [SNS Topics & Subscriptions](#sns-topics--subscriptions)  
- [Monitoring & Observability](#monitoring--observability)
  - [AWS CloudWatch Dedicated Log Groups](#aws-cloudwatch-dedicated-log-groups)
  - [AWS CloudTrail & AWS Config](#cloudtrail--config)

### [Section IV: Deployment & Configuration Guide](#section-iv-deployment--configuration-guide)
- [Deployment Scripts](#deployment-scripts)
- [Configuration Reference](#configuration-reference)
  - [Environment Variables](#environment-variables)
  - [Terraform Variables](#terraform-variables)
  - [CloudFormation Parameters](#cloudformation-parameters)
  - [Cross-IaC Integration](#cross-iac-integration)
- [License](#license)


<br/>

# Section I: Factory Architecture & Infrastructure Overview

## Project Overview

This AWS DevSecOps Hybrid CI/CD Factory represents a <ins>**DevSecOps Software Factory**</ins>, an evolved approach to software delivery that extends traditional DevOps practices by embedding security controls throughout the entire software development lifecycle. The factory concept provides a standardized, automated environment for building, testing, and deploying software with security as a first-class citizen rather than an afterthought.

- **Development**: Secure coding practices integrated from initial commit with automated pre-commit hooks and static analysis
- **Security**: Continuous security scanning through SAST, SCA, DAST, and RASP tools embedded in pipeline stages
- **Operations**: Infrastructure security hardening and runtime monitoring with automated incident response

---

The platform also introduces a novel <ins>**hybrid IaC approach**</ins> that strategically separates infrastructure concerns based on resource characteristics and lifecycle management requirements. This separation provides optimal tooling selection for different infrastructure layers.

Also, the platform is specifically architected for ***AWS Free Tier compatibility***, enabling immediate deployment without incurring charges for evaluation and small-scale production workloads.

---

## Architecture
### Hybrid IaC Approach

This platform implements a *strategic separation of Infrastructure as Code responsibilities* between <ins>**Terraform**</ins> and <ins>**AWS CloudFormation**</ins>, creating a hybrid model that leverages the strengths of each tool while maintaining clear boundaries of concern.

<div align="center">

![Hybrid IaC Architecture](./doc/Metadoc/hybrid_iac.png)

*Figure 1: Hybrid Infrastructure as Code Architecture - Separation of concerns and integration between Terraform and AWS CloudFormation*

</div>

**I) Terraform Infrastructure Layer:**
Manages foundational, reusable infrastructure components and provisions core network and compute resources. This layer is optimized for long‑lived infrastructure that requires complex dependency handling and reliable state tracking

**II) CloudFormation Pipeline Layer:**
Manages orchestration of AWS-native services and pipeline-specific resources, this CloudFormation layer leverages native AWS integrations and built‑in drift detection to ensure reliable, maintainable pipeline lifecycle management.

### Cross-IaC Integration Pattern

1. **Terraform Deployment**: Deployment scripts execute `terraform plan` and `terraform apply` for infrastructure provisioning
2. **Output Capture**: Scripts capture Terraform outputs (VPC ID, subnet IDs, security group IDs) programmatically
3. **CloudFormation Orchestration**: Scripts initiate CloudFormation stack creation with captured Terraform outputs as parameter inputs
4. **Runtime Integration**: CloudFormation stack receives infrastructure identifiers and provisions pipeline resources with proper resource references

**Integration Architecture:**
```
          Deployment Script → Terraform Apply → Capture Outputs → CloudFormation Deploy
                  ↓                ↓                   ↓                   ↓
            Script Logic     Infrastructure    VPC ID, Subnets    Pipeline Resources
            Orchestration    Provisioning      Security Groups,    with References
                                                ECS Clusters, 
                                              Task definitions ...
```

- **Phase 1**: The provided Deployment Scripts execute Terraform deployment and wait for completion
- **Phase 2**: Scripts parse Terraform state or output files to extract resource identifiers
- **Phase 3**: Scripts construct CloudFormation parameter mappings from Terraform outputs
- **Phase 4**: Scripts deploy CloudFormation stack with parameter values for seamless integration

---
### High-level AWS Architecture

<div align="center">

![AWS Platform Architecture](./assets/Main_Architecture/AWS_DevSecOps_Hybrid_CICD_Platform_Architecture.png)

*Figure 2: High-level AWS DevSecOps Factroy Architecture - Complete Software Factory Overview*

***(Click on the architecture for a better full-screen view)***

</div>

The AWS DevSecOps Hybrid CI/CD Factory implements a <ins>**multi-tier cloud-native architecture**</ins> that orchestrates secure software delivery through strategically decoupled infrastructure and pipeline layers. The platform leverages native AWS services to create a comprehensive DevSecOps environment with integrated security controls, automated compliance validation, and event-driven operational patterns.

**1. `Network Foundation Layer`:**
The platform implements a **Custom VPC Architecture** that isolates the network with thoughtfully segmented subnets across multiple Availability Zones to ensure high availability and fault tolerance, a **Custom NAT Strategy** that employs personalized EC2‑based NAT instances to provide controlled and <ins>FREE</ins> egress routing for resources in private subnets, and a **Load Balancing Infrastructure** using Application Load Balancers to efficiently distribute traffic across containerized application tiers.

**2. `Compute & Container Orchestration:`**
The platform uses distinct **ECS Cluster Architecture** by maintaining separate staging and production clusters running on EC2 instances managed by Auto Scaling Groups for dynamic capacity, and also leverages a secure **Container Registry** (Amazon ECR) for scalable image storage with built‑in vulnerability scanning, and implements a **Blue/Green Deployment** strategy to enable zero‑downtime releases by coordinating ECS service updates with ALB target‑group switching.

**3. `CI/CD Pipeline Infrastructure:`**
The factory relies on **AWS CodePipeline** as a multi‑stage orchestrator to integrate source control, coordinate builds, perform security scans, and automate deployments; **AWS CodeBuild** supplies isolated, containerized build environments for compiling code, executing security and compliance analyses, and producing artifacts; and centralized **S3 Artifact Management** handles artifact storage with versioning and lifecycle policies to manage pipeline dependencies.

**4. `Security Integration Layer:`**
**Multi-Stage Security Scanning** is implemented throughout the CI process: SAST, SCA, DAST, and RASP tools are embedded across pipeline stages to continuously detect code, dependency, runtime, and application-layer risks; **AWS Security Hub** centralizes findings while a custom Lambda function normalizes and correlates alerts for unified visibility and automated response;

**5. `Event-Driven Operations:`**
The platform uses **AWS EventBridge** for flexible event routing and automated incident‑response workflows, **CloudWatch Integration** for centralized monitoring, logging, and alerting across all components, and **SNS Topics** to distribute operational and security alerts across multiple channels.

**6. `Compliance & Governance:`**
**AWS Config** provides continuous configuration compliance checks and drift detection across resources, **CloudTrail Auditing** captures comprehensive API activity logs for security and compliance analysis, and **IAM Access Control** enforces least‑privilege access through role‑based permissions and explicit cross‑service trust relationships.

The architecture implements <ins>**separation of concerns**</ins> through distinct operational domains while maintaining seamless integration through AWS-native service communication patterns. Each architectural layer is designed for independent scaling, maintenance, and security policy enforcement.

<ins>**Detailed Technical Specifications:**</ins>

The next chapter provides comprehensive technical deep-dives into each architectural component, implementation details, and operational procedures. Each sub-architecture is documented with specific configuration parameters, security controls, and integration patterns

---

# Section II: Architectural Deep Dive
## Terraform Infrastructure Sub-Architecture
<div align="center">

![](./assets/Pseudo_Architectures/TF-INFRA.png)

*Figure 3: Terraform Infrastructure Sub-Architecture - Complete foundational infrastructure layer managed by Terraform*

***(Click on the architecture for a better full-screen view)***

</div>

### VPC Architecture
<div align="center">

![](./assets/Pseudo_Architectures/TF-INFRA_VPC.png)

*Figure 4: VPC Network Architecture - Multi-AZ VPC design with strategic subnet segmentation and routing configuration*

***(Click on the architecture for a better full-screen view)***

</div>

### Public Resources Architecture
<div align="center">

![](./assets/Pseudo_Architectures/TF-INFRA_Public-Subnets.png)

*Figure 5: Public Subnet Resources Architecture - Internet-facing components including ALB capacities and Custom NAT instances*

***(Click on the architecture for a better full-screen view)***

</div>

### Private Resources Architecture
<div align="center">

![](./assets/Pseudo_Architectures/TF-INFRA_Private_Subnets.png)

*Figure 6: Private Subnet Resources Architecture - Internal ECS clusters and Associated ASGs (Auto-Scaling Groups)*

***(Click on the architecture for a better full-screen view)***

</div>

## AWS CloudFormation CI/CD Sub-Architecture
<div align="center">

![](./assets/Pseudo_Architectures/CF-RESOURCES.png)

*Figure 7: CloudFormation CI/CD Sub-Architecture - Complete pipeline infrastructure and AWS-native service orchestration*

***(Click on the architecture for a better full-screen view)***

</div>

### CodePipeline Architecture
<div align="center">

![](./assets/Pseudo_Architectures/CF-RESOURCES_codePipeline.png)

*Figure 8: CodePipeline Architecture - Multi-stage pipeline with integrated security scanning and deployment automation*

***(Click on the architecture for a better full-screen view)***

</div>

### Pipeline Integration & Workflow
<div align="center">

![](./assets/Pseudo_Architectures/CF-RESOURCES_cicd.png)

*Figure 9: Pipeline Integration & Workflow - End-to-end CI/CD workflow with security gates, artifact management & multi-environment deployment orchestration*

***(Click on the architecture for a better full-screen view)***

</div>