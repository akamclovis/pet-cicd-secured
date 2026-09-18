# Spring PetClinic DevSecOps CI/CD on AWS

A hands-on DevSecOps project implementing a secure, automated CI/CD pipeline and AWS container infrastructure for the open-source Spring PetClinic application.

The project demonstrates infrastructure as code, CI/CD automation, container security, secrets management, cloud authentication, vulnerability scanning, and automated application deployment to Amazon ECS.

> **Application attribution:** The application is based on the open-source [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) project. The focus of this repository is the DevSecOps, CI/CD, containerization, security, and AWS infrastructure implemented around the application.

---

## Project Overview

The goal of this project is to implement a production-style DevSecOps delivery workflow around a Java Spring Boot application.

Infrastructure is provisioned with Terraform, while GitHub Actions builds, tests, scans, publishes, and deploys the application.

A merge to `main` triggers an automated pipeline that:

1. Scans the repository for exposed secrets with Gitleaks.
2. Builds and tests the Java application with Maven.
3. Performs static code analysis and enforces the SonarCloud Quality Gate.
4. Scans the application filesystem with Trivy.
5. Builds the Docker image.
6. Scans the container image for HIGH and CRITICAL vulnerabilities.
7. Authenticates to AWS using GitHub OIDC.
8. Publishes the approved image to Amazon ECR using the Git commit SHA as an immutable image tag.
9. Registers a new Amazon ECS task-definition revision.
10. Updates the ECS service to the new revision.
11. Waits for the ECS service to stabilize.
12. Verifies the deployed revision.

No long-lived AWS access keys are required by the deployment pipeline.

---

## Architecture

```text
                           GitHub
                              │
                        Merge to main
                              │
                              ▼
                       GitHub Actions
                              │
          ┌───────────────────┼────────────────────┐
          │                   │                    │
          ▼                   ▼                    ▼
       Gitleaks           SonarCloud             Trivy
      Secret Scan        Quality Gate       Filesystem Scan
                              │
                              │ Sonar token
                              ▼
                       HashiCorp Vault
                              │
          └───────────────────┼────────────────────┘
                              ▼
                       Maven Build/Test
                              │
                              ▼
                         Docker Build
                              │
                              ▼
                       Trivy Image Scan
                              │
                              ▼
                    GitHub OIDC → AWS IAM
                              │
                              ▼
                         Amazon ECR
                    Immutable Git-SHA image
                              │
                              ▼
                   New ECS Task Definition
                              │
                              ▼
                     ECS Service on EC2
                              │
                              ▼
                  Application Load Balancer
                              │
                              ▼
                       Spring PetClinic
```

### AWS Infrastructure

```text
AWS VPC
│
├── Public Subnets (Multi-AZ)
│   ├── Application Load Balancer
│   └── NAT Gateway
│
├── Private Subnets (Multi-AZ)
│   └── ECS EC2 Capacity
│       └── PetClinic Container
│
├── Amazon ECR
├── CloudWatch Logs
└── IAM / GitHub OIDC

Infrastructure provisioned with Terraform
```

The Application Load Balancer is internet-facing, while ECS container capacity runs in private subnets. ECS instances use outbound NAT access and receive application traffic only through the ALB security group.

---

## CI/CD Pipeline

The GitHub Actions workflow implements multiple security and quality gates before an application image can reach Amazon ECS.

| Stage | Tool | Purpose |
|---|---|---|
| Secret scanning | Gitleaks | Detect exposed credentials and secrets |
| Build & unit test | Maven | Compile and validate the application |
| Code quality | SonarCloud | Static analysis and Quality Gate enforcement |
| Filesystem scanning | Trivy | Detect vulnerable dependencies/files |
| Container build | Docker | Build the application image |
| Image scanning | Trivy | Block HIGH/CRITICAL image vulnerabilities |
| AWS authentication | GitHub OIDC | Obtain temporary AWS credentials |
| Image publishing | Amazon ECR | Store approved container images |
| Deployment | Amazon ECS | Deploy a new immutable application revision |
| Runtime verification | AWS CLI / ECS | Confirm service stability and deployed revision |

The deployment stages execute only for pushes to the `main` branch.

---

## Secure Authentication

### GitHub Actions → AWS

GitHub Actions authenticates to AWS using OpenID Connect (OIDC).

This eliminates the need to store permanent AWS access keys in GitHub.

The assumed IAM role has scoped permissions for:

- publishing images to Amazon ECR;
- registering ECS task definitions;
- updating the PetClinic ECS service;
- describing ECS resources required during deployment; and
- passing the ECS task execution role to the ECS service.

### GitHub Actions → HashiCorp Vault

HashiCorp Vault is used to provide sensitive CI credentials at runtime.

GitHub Actions authenticates to Vault using GitHub's OIDC identity rather than storing a permanent Vault token in the repository.

Vault provides the SonarCloud credential required by the quality-analysis stage.

---

## Container Security

The application container is built using Java 17 and runs as a non-root user.

The image is scanned with Trivy before publication. HIGH and CRITICAL vulnerabilities cause the pipeline to fail rather than allowing the affected image to continue to the deployment stage.

Security remediation performed during the project included dependency upgrades for identified PostgreSQL JDBC and embedded Tomcat vulnerabilities.

---

## Infrastructure as Code

AWS infrastructure is provisioned using modular Terraform.

```text
infrastructure/
└── terraform/
    ├── modules/
    │   ├── networking/
    │   ├── ecs-cluster/
    │   ├── ecs-capacity/
    │   ├── alb/
    │   └── ecs-service/
    │
    └── environments/
        └── dev/
```

Terraform provisions the networking, ECS cluster and capacity, Application Load Balancer, IAM resources, CloudWatch logging, and ECS service infrastructure.

---

## Terraform and CI/CD Ownership

A deliberate ownership boundary prevents Terraform and the deployment pipeline from fighting over application revisions.

### Terraform owns

- VPC and subnet infrastructure
- Internet and NAT connectivity
- Security groups
- Application Load Balancer
- ECS cluster
- ECS EC2 capacity
- Auto Scaling
- IAM infrastructure
- CloudWatch logging
- ECS service infrastructure
- Baseline task definition

### GitHub Actions owns application releases

- Docker image creation
- ECR image publication
- immutable Git-SHA image selection
- new ECS task-definition revisions
- ECS service application updates
- deployment stability verification

The ECS service Terraform configuration ignores application task-definition revision changes:

```hcl
lifecycle {
  ignore_changes = [
    task_definition
  ]
}
```

This allows GitHub Actions to deploy newer application revisions without a future Terraform run reverting the ECS service to Terraform's original baseline revision.

This behavior was validated after an automated deployment: Terraform reported no infrastructure changes even though the CI/CD pipeline had deployed a newer ECS task-definition revision.

---

## ECS Deployment Strategy

The ECS service uses ECS on EC2 with bridge networking.

The application exposes container port `8080`, while ECS dynamically allocates the host port.

During a deployment:

```text
Existing task
     │
     ├── remains available while replacement starts
     │
     ▼
New task revision
     │
     ▼
Dynamic host port
     │
     ▼
ALB health check
     │
     ├── unhealthy → deployment fails/rolls back
     │
     └── healthy
            │
            ▼
       Traffic shifts
            │
            ▼
       Old task drains
```

The ECS deployment circuit breaker and rollback capability are enabled.

---

## Verified Automated Deployment

The automated deployment workflow has been validated end-to-end.

A successful deployment:

- published an image tagged with the Git commit SHA;
- registered a new ECS task-definition revision;
- updated the ECS service;
- started the replacement container using a dynamically assigned host port;
- registered the replacement target with the Application Load Balancer;
- reached a healthy ALB target state;
- drained the previous target; and
- reached ECS service stability.

The running ECS task was verified to reference the exact immutable Git-SHA image produced by the GitHub Actions run.

A subsequent `terraform plan` returned:

```text
No changes. Your infrastructure matches the configuration.
```

This validated the separation between Terraform-managed infrastructure and CI/CD-managed application releases.

---

## Observability

Application container logs are sent to Amazon CloudWatch Logs.

```text
/ecs/pet-clinic-dev
```

CloudWatch provides centralized runtime logs for troubleshooting application startup and deployment issues.

---

## Security Controls

The project incorporates multiple security layers:

- GitHub OIDC authentication to AWS
- GitHub OIDC authentication to HashiCorp Vault
- least-privilege IAM permissions
- Gitleaks secret scanning
- SonarCloud static code analysis
- SonarCloud Quality Gate enforcement
- Trivy filesystem vulnerability scanning
- Trivy container-image vulnerability scanning
- non-root application container
- private ECS subnets
- ALB-to-ECS security-group restrictions
- IMDSv2 enforcement on ECS EC2 instances
- immutable Git-SHA container image deployment
- ECS deployment circuit breaker and rollback

---

## Technology Stack

**Application**
- Java 17
- Spring Boot
- Maven

**CI/CD & DevSecOps**
- GitHub Actions
- Gitleaks
- SonarCloud
- Trivy
- HashiCorp Vault

**Containers**
- Docker
- Amazon ECR
- Amazon ECS

**AWS**
- VPC
- EC2
- ECS
- ECR
- Application Load Balancer
- Auto Scaling
- IAM
- CloudWatch
- NAT Gateway

**Infrastructure as Code**
- Terraform

---

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── pipeline.yaml
│
├── infrastructure/
│   └── terraform/
│       ├── modules/
│       │   ├── networking/
│       │   ├── ecs-cluster/
│       │   ├── ecs-capacity/
│       │   ├── alb/
│       │   └── ecs-service/
│       └── environments/
│           └── dev/
│
├── docs/
│   └── PETCLINIC_DEVSECOPS_DEPLOYMENT.md
│
├── Dockerfile
├── pom.xml
└── README.md
```

---

## Engineering Highlights

This project demonstrates hands-on implementation of:

- modular AWS infrastructure with Terraform;
- ECS-on-EC2 container orchestration;
- secure CI/CD authentication without long-lived AWS credentials;
- centralized secrets retrieval from HashiCorp Vault;
- automated security gates before deployment;
- immutable container releases tied to Git commits;
- automated ECS task-definition registration and service deployment;
- ALB health-based traffic transition;
- least-privilege deployment IAM permissions; and
- separation of infrastructure and application deployment ownership.

---

## Further Documentation

Detailed implementation and deployment notes are available in:

[`docs/PETCLINIC_DEVSECOPS_DEPLOYMENT.md`](docs/PETCLINIC_DEVSECOPS_DEPLOYMENT.md)

---

## Future Improvements

Potential next iterations include:

- HTTPS using ACM
- Route 53 DNS integration
- CloudWatch alarms and deployment alerting
- enhanced application health endpoints
- deployment notifications
- automated rollback testing
- additional observability and dashboards

---

## Application Attribution

This project uses the open-source Spring PetClinic application as the workload for demonstrating DevSecOps and AWS deployment engineering.

Spring PetClinic is maintained by the Spring community and is licensed under the Apache License 2.0.

Original project:

https://github.com/spring-projects/spring-petclinic

The infrastructure, containerization, security integrations, CI/CD workflow, and AWS deployment implementation in this repository are the focus of this project.