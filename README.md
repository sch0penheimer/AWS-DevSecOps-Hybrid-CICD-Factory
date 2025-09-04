# AWS DevSecOps Hybrid CI/CD Platform

This project implements a robust, automated Hybrid DevSecOps platform on AWS, designed to enforce security and compliance at every stage of the software delivery lifecycle for containerized and EC2-based applications.

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