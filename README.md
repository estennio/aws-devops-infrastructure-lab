# AWS DevOps Infrastructure Lab

A hands-on AWS Cloud/DevOps laboratory focused on networking, Linux administration, web deployment, and progressive automation.

The project is intentionally developed in stages. Documentation distinguishes resources that are **verified in AWS** from components that are still **planned**.

## Current Environment

- **AWS Region:** us-east-2 (US East - Ohio)
- **VPC CIDR:** 10.20.0.0/16
- **Public Subnet A:** 10.20.1.0/24
- **EC2:** t3.micro
- **Operating System:** Ubuntu Server 24.04 LTS
- **Web Server:** Nginx
- **Administration:** SSH using an EC2 key pair
- **Web protocol currently verified:** HTTP
- **Automated deployment:** GitHub Actions via SSH

## Verified Infrastructure

| Component | Status | Evidence |
|---|---|---|
| AWS Region | Verified | AWS Console |
| VPC | Verified | VPC configuration |
| Public Subnet A | Verified | Subnet configuration |
| Internet Gateway | Verified | Attached to the VPC |
| Public Route Table | Verified | 0.0.0.0/0 route to IGW |
| Security Group | Verified | EC2 access rules |
| EC2 instance | Verified | Running t3.micro |
| Ubuntu 24.04 LTS | Verified | SSH session |
| SSH | Verified | Windows PowerShell → EC2 |
| Nginx | Verified | systemd + local HTTP test |
| HTTP | Verified | External HTTP 200 response |
| Automated deployment | Verified | Successful GitHub Actions workflow run and deployment validation |

### External HTTP verification

From Windows PowerShell, an external request to the EC2 public IPv4 returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

The public IPv4 address used during this test is treated as temporary instance state, not as a permanent project configuration.

## Automated Deployment

The `Deploy website to EC2` GitHub Actions workflow has executed successfully. It deploys `index.html` and `style.css` to the EC2 instance over SSH and validates the website after deployment.

```text
Git push → GitHub Actions → SSH → EC2 → Nginx → validation
```

The workflow validation confirmed that the deployed site contains `Deployed automatically with GitHub Actions.`

## Current Architecture

```text
Internet
   |
   v
Internet Gateway
   |
   v
VPC 10.20.0.0/16
   |
   v
Public Subnet A 10.20.1.0/24
   |
   v
Security Group
   |
   v
EC2 t3.micro
Ubuntu 24.04 LTS
   |
   v
Nginx
   |
   v
Web Application
```

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml
├── README.md
├── index.html
├── style.css
└── docs/
    ├── 02-architecture.md
    └── 03-deployment-and-verification.md
```

## Development Roadmap

### Completed / Verified

- [x] AWS region selected
- [x] VPC created
- [x] Public subnet created
- [x] Internet Gateway attached
- [x] Public route configured
- [x] Security Group configured
- [x] EC2 t3.micro deployed
- [x] Ubuntu Server 24.04 LTS running
- [x] SSH access verified
- [x] Nginx installed and running
- [x] External HTTP access verified
- [x] Automated deployment with GitHub Actions verified

### Next

- [ ] Implement and independently verify HTTPS/TLS
- [ ] Evaluate AWS Systems Manager as an alternative to direct SSH
- [ ] Add additional infrastructure only when it provides a clear technical benefit

## Intentionally Not Deployed

The repository contains planning material for a larger architecture, but these resources have **not** been created as part of the current environment:

- Additional public subnets
- Private subnets
- NAT Gateway
- Amazon RDS PostgreSQL
- Load Balancer
- Auto Scaling
- ECS/EKS

They should not be represented as deployed infrastructure until independently verified.

## Security

Never commit:

- EC2 private keys
- AWS access keys
- passwords
- tokens
- secrets
- Terraform state containing sensitive values

The repository's `.gitignore` is configured to exclude common private-key and AWS credential files.

SSH is used for the current laboratory stage. The security group should restrict TCP/22 to the administrator's current public IP whenever practical.

## Cost Strategy

The laboratory is designed to minimize unnecessary AWS charges.

The project avoids adding expensive or unnecessary infrastructure simply to increase architectural complexity. Services will be introduced only when they provide a meaningful learning or portfolio objective, with AWS pricing and eligibility checked before deployment.

## Documentation

- [AWS infrastructure architecture](docs/02-architecture.md)
- [Deployment and verification](docs/03-deployment-and-verification.md)

## Project Status

**Core AWS infrastructure and automated deployment: implemented and verified.**

The GitHub Actions delivery workflow is verified. HTTPS/TLS remains unimplemented and is the next principal stage.
