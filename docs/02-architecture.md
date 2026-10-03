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
EC2 lab-web-server
i-08f84a35805b6b66d · t3.micro
Ubuntu Server 24.04 LTS
    |
    +--> Administration: SSH / Session Manager
    |
    +--> Nginx
           |
           +--> HTTP :80
           |
           +--> HTTPS :443 / TLS 1.3
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

- **Name:** `lab-web-server`
- **Instance ID:** `i-08f84a35805b6b66d`
- **Instance type:** `t3.micro`
- **Operating system:** Ubuntu Server 24.04 LTS
- **Subnet:** Public Subnet A
- **Administration:** SSH and AWS Systems Manager Session Manager
- **Web server:** Nginx

The instance was successfully accessed from Windows PowerShell using the EC2 key pair. AWS Systems Manager also recognizes it as an Online managed node with the SSM Agent running, and Session Manager successfully opened an administrative session as `ssm-user`.

## Security

The current application requires:

- TCP 22 for SSH administration
- TCP 80 for HTTP
- TCP 443 for HTTPS/TLS

TCP 80 and TCP 443 are active and verified for the current Nginx service. HTTPS uses TLS 1.3 with a self-signed certificate whose CN/SAN is `web.lab.test`. The certificate is intended for laboratory verification and is not a publicly trusted production certificate.

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

### AWS Systems Manager / Session Manager

The EC2 instance was verified in AWS Systems Manager with the following state:

- recognized as a managed node
- SSM Agent running
- ping status `Online`
- Session Manager administrative session opened successfully
- session user `ssm-user`

SSH remains configured and verified; Session Manager is an additional verified administration path and does not replace the documented SSH workflow.

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

### External HTTPS and TLS

From Windows PowerShell, requests to both the EC2 public IPv4 and the certificate hostname resolved to that address returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

TLS negotiation was verified as TLS 1.3. The self-signed certificate was verified with:

- Common Name: `web.lab.test`
- Subject Alternative Name: `DNS:web.lab.test`

Nginx was also verified listening on TCP/80 and TCP/443 over IPv4 and IPv6.

## Future Architecture

The repository previously considered a larger architecture containing:

- Public Subnet B
- Private Subnet A
- Private Subnet B
- Amazon RDS PostgreSQL
- Database Security Group
- NAT Gateway
- Load Balancer
- Auto Scaling
- ECS/EKS
- Additional availability zones

These components are **not deployed** and remain future considerations only.

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
- AWS Systems Manager managed node (`Online`)
- SSM Agent running
- Session Manager access as `ssm-user`
- Nginx
- External HTTP access
- External HTTPS access
- TLS 1.3
- Self-signed certificate with CN/SAN `web.lab.test`
- GitHub Actions
- Automated deployment via SSH to EC2

### Pending / Not Deployed

- Additional public or private subnets, if justified
- NAT Gateway, if justified
- RDS or another database layer, if justified
- Load Balancer and Auto Scaling, if justified
- ECS/EKS, if justified
- Additional availability zones, if justified

The deployed AWS environment takes priority over any older planning diagrams or documentation.
