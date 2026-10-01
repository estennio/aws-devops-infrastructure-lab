# AWS Infrastructure Architecture

## Overview

This document describes the **current verified AWS infrastructure** and separates it from future architecture ideas.

- **AWS Region:** US East (Ohio)
- **Region code:** `us-east-2`
- **VPC CIDR:** `10.20.0.0/16`
- **Public Subnet A:** `10.20.1.0/24`

The current environment uses a single public subnet and one EC2 application server. Additional private/public layers remain future options and are not part of the deployed environment.

## Current Verified Architecture

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
Ubuntu Server 24.04 LTS
    |
    v
Nginx
    |
    v
Web Application
```

## Network Components

| Resource | Current state |
|---|---|
| VPC | Created and verified |
| Public Subnet A | Created and verified |
| Internet Gateway | Created, attached, and verified |
| Public Route Table | Created and verified |
| Default route | `0.0.0.0/0` → Internet Gateway |
| Security Group | Created and used by EC2 |
| Public IPv4 | Assigned to EC2 during testing |

The public IPv4 address is intentionally not documented as a permanent value because an EC2 public IPv4 address can change when instance lifecycle operations occur unless an Elastic IP is used.

## Compute

The deployed compute instance is:

- **Instance type:** `t3.micro`
- **Operating system:** Ubuntu Server 24.04 LTS
- **Subnet:** Public Subnet A
- **Administration:** SSH
- **Web server:** Nginx

The instance was successfully accessed from Windows PowerShell using the EC2 key pair.

## Security

The current application requires:

- TCP 22 for SSH administration
- TCP 80 for HTTP

TCP 443 is intended for the future HTTPS stage and must not be described as an active HTTPS service until TLS is configured and tested.

SSH access should be restricted to the administrator's current public IP whenever practical. Public SSH exposure should not be treated as the desired production configuration.

## Verified Connectivity

### SSH

The following was verified from Windows PowerShell:

```text
ssh -i .\\lab-key.pem ubuntu@<public-ip>
```

Inside the instance:

```text
systemctl is-active ssh
active
```

The SSH daemon was also verified listening on TCP/22.

### Nginx

Nginx was verified as running:

```text
systemctl is-active nginx
active
```

A local HTTP request returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

### External HTTP

From Windows PowerShell, an external request to the EC2 public IPv4 address returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
```

This verifies the complete path from the external client through the AWS public network path to Nginx.

## Future Architecture

The repository previously considered a larger architecture containing:

- Public Subnet B
- Private Subnet A
- Private Subnet B
- Amazon RDS PostgreSQL
- Database Security Group
- AWS Systems Manager
- Additional availability zones

These components are **planned only**.

They must not be represented as deployed until they are independently created and verified.

### Private database concept

A future RDS design may use:

- PostgreSQL
- Private subnets
- Public access disabled
- Database Security Group
- TCP 5432 allowed only from the application tier

No RDS database currently exists in this laboratory.

## NAT Gateway

A NAT Gateway is deliberately not part of the current environment.

The project does not need to incur NAT Gateway costs merely to increase architectural complexity. It can be evaluated later if private resources require outbound Internet access.

## Current Status

### Verified

- VPC
- Public Subnet A
- Internet Gateway
- Public Route Table
- EC2 t3.micro
- Ubuntu Server 24.04 LTS
- SSH
- Nginx
- External HTTP access

### Pending

- HTTPS/TLS
- Automated deployment
- GitHub Actions
- Systems Manager evaluation
- Additional network layers, if justified
- Database layer, if justified

The deployed AWS environment takes priority over any older planning diagrams or documentation.
