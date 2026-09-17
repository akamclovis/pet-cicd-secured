# PetClinic DevSecOps CI/CD on AWS ECS

## Project Status

The Spring PetClinic application has been successfully provisioned and
deployed to **Amazon ECS on EC2** using **Terraform**.

The first infrastructure deployment completed successfully:

``` text
Apply complete! Resources: 38 added, 0 changed, 0 destroyed.
```

Runtime verification confirmed the ECS host, ECS service, application
container, Application Load Balancer, dynamic port mapping, and
CloudWatch logging are working.

## Architecture

``` text
GitHub Actions
      |
Gitleaks
      |
Maven Build + Unit Tests
      |
SonarCloud
      |
Trivy Filesystem Scan
      |
Docker Build
      |
Trivy Image Scan
      |
GitHub OIDC
      |
Amazon ECR
      |
Application Load Balancer :80
      |
ECS Target Group
      |
EC2 ECS Host : Dynamic Port
      |
Docker Bridge Network
      |
Spring PetClinic :8080
```

The ECS infrastructure runs in a custom VPC. The ALB is in public
subnets while ECS EC2 capacity runs in private subnets. A NAT Gateway
provides outbound connectivity for the private instances.

## Terraform Infrastructure

Terraform is organized into reusable modules:

``` text
infrastructure/terraform/
├── modules/
│   ├── networking/
│   ├── ecs-cluster/
│   ├── ecs-capacity/
│   ├── alb/
│   └── ecs-service/
└── environments/
    └── dev/
```

### Networking

The networking module provisions a VPC, two public subnets, two private
subnets, Internet Gateway, public/private route tables and associations,
Elastic IP, NAT Gateway, ALB security group, and ECS EC2 host security
group.

The ALB accepts HTTP on port `80`. The ECS host security group permits
traffic from the ALB security group to the dynamic ECS host-port range.

### ECS Cluster and EC2 Capacity

The ECS cluster is:

``` text
pet-clinic-dev-cluster
```

Container Insights is enabled.

The capacity layer includes an ECS-optimized Amazon Linux 2023 AMI, EC2
Launch Template, IAM instance role/profile, Auto Scaling Group, ECS
Capacity Provider, managed scaling, and managed termination protection.

The Auto Scaling Group is:

``` text
pet-clinic-dev-ecs-asg
```

Verification confirmed:

``` text
EC2: InService / Healthy
ECS Status: ACTIVE
AgentConnected: True
RunningTasks: 1
PendingTasks: 0
```

### Application Load Balancer

The internet-facing ALB DNS name created during the initial deployment
is:

``` text
pet-clinic-dev-alb-139009644.us-east-1.elb.amazonaws.com
```

The target group uses `target_type = "instance"` because the service
currently uses ECS EC2 with Docker bridge networking.

### ECS Service and Task Definition

The ECS service is:

``` text
pet-clinic-dev-service
```

The initial task definition revision is:

``` text
pet-clinic-dev:1
```

The container listens on port `8080`, while ECS dynamically assigns the
host port (`hostPort = 0`).

During the first deployment:

``` text
EC2 instance: i-024ab6556397835dd
Host port:    32768
Container:    8080
```

Traffic therefore follows:

``` text
Internet
   |
ALB :80
   |
Target Group
   |
EC2 :32768
   |
Docker Bridge
   |
PetClinic :8080
```

The ALB reported the target as `healthy`.

## First Deployment Verification

The deployment was verified layer by layer rather than relying only on
Terraform completion.

-   Terraform: **38 added, 0 changed, 0 destroyed**
-   EC2/ASG: **InService / Healthy**
-   ECS container instance: **ACTIVE**, agent connected
-   ECS task: **1 running**
-   ECS service: deployment completed and reached **steady state**
-   ALB target: EC2 port **32768**, state **healthy**
-   CloudWatch log group: `/ecs/pet-clinic-dev`
-   Spring Boot/Tomcat: application successfully started on container
    port **8080**

CloudWatch logs confirmed Java 17, Spring Boot 4.1.0, Apache Tomcat
11.0.25, Spring Data JPA, Hibernate, HikariCP, and the H2 database
initialized successfully.

## CI / Security Pipeline

The GitHub Actions pipeline currently performs:

``` text
Gitleaks Secret Scan
        |
Maven Build + Unit Tests
        |
SonarCloud Analysis / Quality Gate
        |
Trivy Filesystem Scan
        |
Docker Image Build
        |
Trivy Container Image Scan
        |
AWS Authentication through GitHub OIDC
        |
Push Image to Amazon ECR
```

Security controls implemented include Gitleaks, SonarCloud, Trivy
filesystem/image scans, HIGH/CRITICAL vulnerability gates, GitHub OIDC
for AWS authentication, HashiCorp Vault integration for pipeline
secrets, a non-root application container, IMDSv2 enforcement, private
ECS subnets, and ALB-to-ECS security-group restrictions.

## Amazon ECR Image

Repository:

``` text
945788750616.dkr.ecr.us-east-1.amazonaws.com/pet-clinic
```

The initial deployment image was available using both `latest` and the
Git commit tag:

``` text
dd9c064eae4846064f07176f3f1237a4ea99bfbd
```

The Git-SHA tag provides an immutable identifier for deterministic CD
deployments.

## Vulnerability Remediation

Dependency vulnerabilities discovered during pipeline development were
remediated without weakening the security gates.

-   PostgreSQL JDBC updated to **42.7.12**
-   Apache Tomcat updated to **11.0.25**
-   Maven verification completed with **61 tests, 0 failures, 0 errors,
    2 skipped**

## Terraform and CI/CD Ownership

Terraform owns the AWS infrastructure: VPC, subnets, NAT Gateway,
security groups, ALB/target group, ECS cluster, EC2/ASG, capacity
provider, ECS service infrastructure, IAM, and CloudWatch.

GitHub Actions will own application releases. The intended deployment
model is:

``` text
Application change
      |
CI + Security Gates
      |
Build image
      |
Tag image with Git SHA
      |
Push to ECR
      |
Register new ECS task-definition revision
      |
Update ECS service
      |
ECS rolling deployment
      |
ALB health checks
      |
Healthy -> Success
Failure -> ECS circuit breaker / rollback
```

This separates infrastructure provisioning from routine application
releases.

## Next Phase: Automated ECS Continuous Deployment

The infrastructure and initial ECS deployment are complete. The next
implementation phase is continuous deployment from GitHub Actions to
ECS:

1.  Configure least-privilege ECS deployment permissions for the GitHub
    OIDC role.
2.  Deploy immutable Git-SHA-tagged ECR images instead of relying on
    `latest`.
3.  Render/register a new ECS task-definition revision from GitHub
    Actions.
4.  Update `pet-clinic-dev-service`.
5.  Wait for ECS service stability.
6.  Use ALB health checks and the ECS deployment circuit breaker to
    detect failed releases.
7.  Keep Terraform responsible for infrastructure while CI/CD owns
    application deployments.

## Current Milestone

``` text
Source Code                 COMPLETE
Maven Build / Tests         COMPLETE
Gitleaks                    COMPLETE
SonarCloud                  COMPLETE
Trivy Filesystem            COMPLETE
Docker Build                COMPLETE
Trivy Image Scan            COMPLETE
GitHub -> AWS OIDC          COMPLETE
Amazon ECR                  COMPLETE
Terraform Infrastructure    COMPLETE
ECS EC2 Capacity            COMPLETE
ECS Service                 COMPLETE
ALB                          COMPLETE
Dynamic Port Mapping        COMPLETE
CloudWatch Logs             COMPLETE
Application Runtime         COMPLETE
Automated ECS CD            NEXT
```

The project has reached a stable **Terraform-provisioned ECS deployment
baseline**. The next milestone is to automate ECS application releases
through the existing DevSecOps GitHub Actions pipeline.
s