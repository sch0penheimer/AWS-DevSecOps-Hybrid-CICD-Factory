**I- Terraform Domain - Platform Infrastructure:**
- **Scope**: Long-lived, foundational infrastructure components that form the platform backbone
- **Resources**: VPC, subnets, security groups, EC2 instances, ECS clusters, S3 buckets, ECR Registry, ECS Task Definitions, ECS Services
- **Rationale**: Terraform excels at managing complex resource dependencies, state tracking, and cross-cloud compatibility
- **Lifecycle**: Infrastructure provisioned once per environment with infrequent updates

**II- CloudFormation Domain - Pipeline Orchestration:**
- **Scope**: AWS-native services requiring tight integration and rapid iteration
- **Resources**: AWS CodePipeline, AWS CodeBuild projects, AWS Lambda aggreagtion & normalization function, AWS EventBridge rules, IAM roles, CloudWatch Log Groups and all related resources (Events, Streams, ...)
- **Rationale**: CloudFormation provides native AWS service integration, drift detection, and rollback capabilities
- **Lifecycle**: Pipeline components updated frequently as application requirements evolve
- **State Management**: Native CloudFormation stack management with automatic drift detection