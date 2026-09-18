# PetClinic DevSecOps CI/CD on AWS ECS

## Project Status

The Spring PetClinic application is deployed to **Amazon ECS on EC2** using infrastructure provisioned with **Terraform** and an automated **GitHub Actions DevSecOps CI/CD pipeline**.

The project supports end-to-end automated application delivery from a merge to `main` through security and quality validation, container image publication, ECS task-definition registration, ECS service deployment, Application Load Balancer health validation, and deployment verification.

The latest infrastructure recreation completed successfully:

```text
Apply complete! Resources: 40 added, 0 changed, 0 destroyed.
```

Current deployment verification:

```text
ECS Service:        ACTIVE
Desired Tasks:      1
Running Tasks:      1
Pending Tasks:      0
Task Definition:    pet-clinic-dev:3
ALB New Target:     healthy
Previous Target:    draining
Terraform Drift:    none
```

A post-deployment `terraform plan` returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirms that Terraform and GitHub Actions operate within their intended ownership boundaries.

---

## Architecture

```text
                         GitHub
                            |
                      Merge to main
                            |
                            v
                     GitHub Actions
                            |
       +--------------------+--------------------+
       |                    |                    |
       v                    v                    v
    Gitleaks            SonarCloud             Trivy
   Secret Scan         Quality Gate       Filesystem Scan
                            |
                            | Sonar credential
                            v
                     HashiCorp Vault
                            |
                            v
                     Maven Build/Test
                            |
                            v
                       Docker Build
                            |
                            v
                    Trivy Image Scan
                            |
                            v
                  GitHub OIDC -> AWS IAM
                            |
                            v
                       Amazon ECR
                  Immutable Git-SHA Image
                            |
                            v
                 New ECS Task Definition
                            |
                            v
                    ECS Service on EC2
                            |
                            v
                 Application Load Balancer
                            |
                            v
                     Spring PetClinic
```

The AWS infrastructure runs inside a custom VPC. The ALB is in public subnets while ECS EC2 capacity runs in private subnets. A NAT Gateway provides outbound connectivity for private instances.

---

## Terraform Infrastructure

```text
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

The networking module provisions a VPC, two public subnets, two private subnets, Internet Gateway, public/private route tables and associations, Elastic IP, NAT Gateway, ALB security group, and ECS EC2 host security group.

The ALB accepts HTTP on port `80`. The ECS host security group permits traffic from the ALB security group to the dynamic ECS host-port range.

### ECS Cluster and EC2 Capacity

Cluster:

```text
pet-clinic-dev-cluster
```

Container Insights is enabled. The capacity layer includes an ECS-optimized Amazon Linux 2023 AMI, EC2 Launch Template, IAM instance role/profile, Auto Scaling Group, ECS Capacity Provider, managed scaling, managed termination protection, and IMDSv2 enforcement.

Auto Scaling Group:

```text
pet-clinic-dev-ecs-asg
```

Development capacity:

```text
Instance type: t3.small
Minimum:       1
Desired:       1
Maximum:       2
```

---

## Application Load Balancer

The internet-facing ALB uses a target group with `target_type = "instance"` because the ECS service runs on EC2 with Docker bridge networking.

```text
Internet
   |
ALB :80
   |
Target Group
   |
EC2 : Dynamic Host Port
   |
Docker Bridge
   |
PetClinic :8080
```

---

## ECS Service and Task Definition

Service:

```text
pet-clinic-dev-service
```

Container:

```text
pet-clinic
```

Port mapping:

```text
containerPort = 8080
hostPort      = 0
```

ECS dynamically allocates an available host port. The deployment circuit breaker and rollback capability are enabled.

Terraform creates the ECS service infrastructure and baseline task definition. Application task-definition revisions are created by the CI/CD pipeline.

---

## CI/CD Pipeline

```text
Gitleaks Secret Scan
        |
Maven Build + Unit Tests
        |
SonarCloud Quality Gate
        |
Trivy Filesystem Scan
        |
Docker Image Build
        |
Trivy Container Image Scan
        |
GitHub OIDC -> AWS
        |
Push Image to Amazon ECR
        |
Register ECS Task Definition
        |
Update ECS Service
        |
Wait for Service Stability
        |
Verify Deployed Revision
```

Deployment stages execute only for pushes to `main`. Pull requests can run validation without deploying application changes.

---

## Security Controls

- Gitleaks repository secret scanning
- SonarCloud static analysis and Quality Gate enforcement
- Trivy filesystem and container-image scanning
- HIGH/CRITICAL vulnerability gates
- GitHub OIDC authentication to AWS
- GitHub OIDC/JWT authentication to HashiCorp Vault
- temporary AWS credentials
- least-privilege ECS deployment permissions
- non-root application container
- private ECS subnets
- ALB-to-ECS security-group restrictions
- IMDSv2 enforcement
- immutable Git-SHA deployment
- ECS deployment circuit breaker and rollback

No long-lived AWS access keys are required by the deployment pipeline.

---

## HashiCorp Vault Integration

GitHub Actions authenticates to HashiCorp Vault using GitHub's OIDC/JWT identity. Vault supplies the SonarCloud credential required by the quality-analysis stage.

```text
GitHub Actions
      |
      +---- OIDC/JWT ----> HashiCorp Vault
      |
      +---- OIDC --------> AWS IAM
```

This avoids permanent Vault authentication credentials and AWS access keys in the workflow.

---

## Amazon ECR Image Strategy

Images are published to the `pet-clinic` ECR repository as:

```text
pet-clinic:<git-sha>
pet-clinic:latest
```

ECS deployment uses the immutable **Git-SHA-tagged image**, not `latest`.

The validated automated deployment used:

```text
5edeb3da8fad8227fcfaf48a21908c8a1f431453
```

The running ECS task was verified to reference the corresponding immutable ECR image.

---

## Automated ECS Continuous Deployment

After CI and security gates succeed on `main`, GitHub Actions:

1. authenticates to AWS through GitHub OIDC;
2. logs into Amazon ECR;
3. publishes the Git-SHA-tagged image;
4. retrieves the current ECS task definition;
5. verifies the expected `pet-clinic` container exists;
6. replaces its image with the immutable ECR image;
7. removes AWS-generated task-definition metadata;
8. registers a new task-definition revision;
9. updates `pet-clinic-dev-service`;
10. waits for ECS service stability; and
11. verifies the deployed revision.

The GitHub Actions IAM policy provides the ECS/ECR permissions required for deployment and `iam:PassRole` for the ECS task execution role.

---

## Validated Automated Deployment

The first fully automated ECS deployment advanced the application to:

```text
Task Definition: pet-clinic-dev:3
Image Tag:       5edeb3da8fad8227fcfaf48a21908c8a1f431453
```

During the rolling deployment:

```text
Port    State
32769   healthy
32768   draining
```

The new task received dynamic host port `32769` and became healthy before the previous task on `32768` was removed from service.

```text
Old Task Revision
       |
New Task Revision Starts
       |
Dynamic Host Port Assigned
       |
ALB Registers New Target
       |
Health Check Passes
       |
New Target Healthy
       |
Old Target Draining
       |
ECS Service Stable
```

---

## Deployment Verification

```text
GitHub Actions pipeline       PASS
Gitleaks                      PASS
Maven build/test              PASS
SonarCloud Quality Gate       PASS
Trivy filesystem scan         PASS
Docker build                  PASS
Trivy image scan              PASS
AWS OIDC authentication       PASS
ECR publication               PASS
ECS task registration         PASS
ECS service update            PASS
ECS service stability         PASS
ALB target health             HEALTHY
Immutable SHA image           VERIFIED
Terraform ownership check     PASS
```

ECS service:

```text
Desired: 1
Pending: 0
Running: 1
Status:  ACTIVE
Task Definition: pet-clinic-dev:3
```

---

## Terraform and CI/CD Ownership

### Terraform Owns

- VPC, subnets, gateways, routing, and security groups
- Application Load Balancer and target group
- ECS cluster and EC2 capacity
- Auto Scaling Group and ECS Capacity Provider
- IAM infrastructure
- CloudWatch logging
- ECS service infrastructure
- baseline ECS task definition

### GitHub Actions Owns

- application build and tests
- security validation
- Docker image creation
- ECR image publication
- immutable Git-SHA release selection
- ECS task-definition revisions
- ECS service application updates
- deployment stability verification

The Terraform ECS service contains:

```hcl
lifecycle {
  ignore_changes = [
    task_definition
  ]
}
```

This prevents Terraform from reverting application revisions deployed by GitHub Actions.

---

## Terraform Ownership Validation

After GitHub Actions deployed task definition `pet-clinic-dev:3`, Terraform was run against the live environment:

```bash
terraform plan
```

Result:

```text
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your
configuration and found no differences, so no changes are needed.
```

This validates the intended responsibility model:

```text
              AWS Environment
                     |
        +------------+------------+
        |                         |
    Terraform                GitHub Actions
        |                         |
 Infrastructure              Application
   Lifecycle                   Lifecycle
        |                         |
 VPC / ALB / ECS            Build / Scan
 EC2 / IAM / Logs           ECR / Deploy
```

---

## Vulnerability Remediation

```text
PostgreSQL JDBC: 42.7.12
Apache Tomcat:   11.0.25
```

Maven verification:

```text
61 tests
0 failures
0 errors
2 skipped
```

Security gates remain enabled rather than being weakened to allow vulnerable builds through.

---

## Container Security

The image uses Java 17 and an Alpine-based Java runtime. Package updates are applied during the build, PetClinic runs as a non-root user, application port `8080` is exposed, and Trivy scans the image before publication.

---

## CloudWatch Logging

Application container logs are sent to:

```text
/ecs/pet-clinic-dev
```

Runtime verification confirmed successful startup with Java 17, Spring Boot 4.1.0, Apache Tomcat 11.0.25, Spring Data JPA, Hibernate, HikariCP, and H2.

---

## Deployment Failure Protection

Security or quality-gate failures stop downstream publication and deployment. HIGH or CRITICAL findings detected by the configured Trivy gates prevent the affected image from reaching deployment.

The ECS deployment circuit breaker and rollback capability protect the service if a replacement task cannot become healthy. ALB health checks validate replacement tasks before the deployment reaches stable state.

Application deployment occurs only from `main`.

---

## Current Milestone

```text
Source Code                  COMPLETE
Maven Build / Tests          COMPLETE
Gitleaks                     COMPLETE
SonarCloud                   COMPLETE
Trivy Filesystem             COMPLETE
Docker Build                 COMPLETE
Trivy Image Scan             COMPLETE
GitHub -> Vault OIDC         COMPLETE
GitHub -> AWS OIDC           COMPLETE
Amazon ECR                   COMPLETE
Terraform Infrastructure     COMPLETE
ECS EC2 Capacity             COMPLETE
ECS Service                  COMPLETE
ALB                          COMPLETE
Dynamic Port Mapping         COMPLETE
CloudWatch Logs              COMPLETE
Application Runtime          COMPLETE
ECS Deployment IAM           COMPLETE
Immutable SHA Deployment     COMPLETE
Task Definition Automation   COMPLETE
ECS Service Update           COMPLETE
Service Stability Check      COMPLETE
ALB Rolling Transition       COMPLETE
Terraform/CD Ownership Test  COMPLETE
Automated ECS CD             COMPLETE
```

The project has reached a stable **Terraform-provisioned and GitHub-Actions-deployed ECS DevSecOps architecture**.

---

## Engineering Decisions Demonstrated

- Modular Terraform separates infrastructure responsibilities.
- ECS application capacity runs in private subnets.
- Internet traffic enters through an Application Load Balancer.
- Dynamic host-port allocation avoids fixed host-port coupling.
- GitHub OIDC removes long-lived AWS access keys from CI/CD.
- Vault OIDC/JWT authentication avoids permanent Vault credentials.
- Security and quality gates run before publication and deployment.
- Git-SHA image tags provide immutable release identification.
- GitHub Actions owns application releases while Terraform owns infrastructure.
- Terraform lifecycle configuration prevents infrastructure automation from rolling back CI/CD releases.
- ECS health checks and deployment controls protect rolling application updates.

---

## Next Improvements

The core DevSecOps delivery workflow is complete. Potential future improvements include:

- HTTPS using AWS Certificate Manager (ACM)
- Route 53 DNS integration
- CloudWatch alarms
- deployment notifications
- enhanced application health endpoint
- automated rollback testing
- additional monitoring dashboards

---

## Project Outcome

```text
Code Change
    |
Security + Quality Validation
    |
Build
    |
Container Security Validation
    |
Immutable ECR Image
    |
Automated ECS Deployment
    |
ALB Health Validation
    |
Running Application
```

A merge to `main` can securely build, test, scan, publish, and deploy Spring PetClinic to Amazon ECS without manual AWS deployment steps or long-lived AWS access credentials.

The implementation combines **Terraform, GitHub Actions, AWS ECS, Amazon ECR, Docker, HashiCorp Vault, Gitleaks, SonarCloud, Trivy, IAM/OIDC, Application Load Balancing, and CloudWatch** into a complete DevSecOps application delivery workflow.

---

## Application Attribution

This project uses the open-source **Spring PetClinic** application as the workload for demonstrating DevSecOps and AWS deployment engineering.

The application itself is maintained by the Spring community. The infrastructure, containerization, security integrations, CI/CD workflow, and AWS deployment implementation documented here are the focus of this project.
