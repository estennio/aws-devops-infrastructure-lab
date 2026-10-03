# AWS DevOps Infrastructure Lab

A hands-on AWS Cloud/DevOps laboratory focused on networking, Linux administration, web deployment, HTTPS/TLS, and progressive automation.

The project is intentionally developed in stages. Documentation distinguishes resources that are **verified in AWS** from components that are still **planned**.

## Current Environment

- **AWS Region:** us-east-2 (US East - Ohio)
- **VPC CIDR:** 10.20.0.0/16
- **Public Subnet A:** 10.20.1.0/24
- **EC2:** `lab-web-server` (`i-08f84a35805b6b66d`) — t3.micro
- **Operating System:** Ubuntu Server 24.04 LTS
- **Web Server:** Nginx
- **Administration:** AWS Systems Manager Session Manager and SSH using an EC2 key pair
- **Web protocols verified:** HTTP and HTTPS/TLS
- **TLS:** TLS 1.3 with a self-signed certificate for `web.lab.test`
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
| EC2 instance | Verified | `lab-web-server` (`i-08f84a35805b6b66d`), running t3.micro |
| Ubuntu 24.04 LTS | Verified | SSH session |
| SSH | Verified | Windows PowerShell → EC2 |
| AWS Systems Manager | Verified | Instance recognized as a managed node; SSM Agent running; ping status Online |
| Session Manager | Verified | Administrative session opened successfully as `ssm-user` |
| Nginx | Verified | `nginx -t` successful; systemd state active; HTTP/HTTPS tests successful |
| Nginx listeners | Verified | TCP 80 and 443 listening on IPv4 and IPv6 |
| HTTP | Verified | External HTTP 200 response |
| HTTPS | Verified | External HTTPS 200 response |
| TLS 1.3 | Verified | OpenSSL negotiation |
| TLS certificate | Verified | CN/SAN `web.lab.test`, self-signed |
| Automated deployment | Verified | Successful GitHub Actions workflow run and deployment validation |

### Systems Manager / Session Manager verification

AWS Systems Manager recognizes `lab-web-server` (`i-08f84a35805b6b66d`) as a managed node. The SSM Agent is running, the Systems Manager ping status is `Online`, and Session Manager successfully opened an administrative session on the instance as `ssm-user`.

The following Nginx checks were run inside that Session Manager session:

```text
$ sudo nginx -t
syntax is ok
test is successful

$ sudo systemctl is-active nginx
active
```

The session also confirmed these listening sockets:

```text
0.0.0.0:80 LISTEN
0.0.0.0:443 LISTEN
[::]:80 LISTEN
[::]:443 LISTEN
```

This validates Session Manager as an operational remote-administration path while preserving the existing, verified SSH configuration.

### External HTTP verification

From Windows PowerShell, an external request to the EC2 public IPv4 returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

The public IPv4 address used during this test is treated as temporary instance state, not as a permanent project configuration.

### External HTTPS verification

From Windows PowerShell, HTTPS was tested against the EC2 public IPv4:

```powershell
curl.exe -k -I https://<public-ip>
```

The request returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

The hostname-aware test used the certificate name while resolving it to the EC2 public IPv4:

```powershell
curl.exe -k -I --resolve web.lab.test:443:<public-ip> https://web.lab.test
```

This also returned `HTTP/1.1 200 OK`.

## HTTPS / TLS Verification

The EC2 Nginx service is listening on TCP/443 and the configuration passes `nginx -t`.

The deployed certificate was inspected with OpenSSL and verified as:

- Common Name: `web.lab.test`
- Subject Alternative Name: `DNS:web.lab.test`
- Validity: 2026-10-01 through 2027-10-01
- Certificate type: self-signed

TLS negotiation was independently verified with OpenSSL:

```text
Protocol  : TLSv1.3
Cipher    : TLS_AES_256_GCM_SHA384
Verify return code: 18 (self-signed certificate)
```

The self-signed verification code is expected for this laboratory certificate. It means the certificate is not trusted by the default public trust store; it does not indicate that the TLS connection failed.

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
   +--> HTTP :80
   |
   +--> HTTPS :443 / TLS 1.3
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
- [x] AWS Systems Manager managed-node status verified
- [x] Session Manager administrative access verified
- [x] Nginx installed and running
- [x] External HTTP access verified
- [x] HTTPS/TLS configured and independently verified
- [x] TLS 1.3 verified
- [x] Automated deployment with GitHub Actions verified

### Next

- [ ] Add additional infrastructure only when it provides a clear technical benefit
- [ ] Consider a publicly trusted certificate/domain only if it adds a meaningful learning objective
- [ ] Continue documenting new validation evidence as the laboratory evolves

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

Both Session Manager and SSH are verified administrative paths for the current laboratory stage. SSH remains configured; the security group should restrict TCP/22 to the administrator's current public IP whenever practical. The current GitHub Actions deployment requires SSH access from GitHub-hosted runners.

The HTTPS certificate is self-signed and intended for laboratory verification. It is not a publicly trusted production certificate.

## Cost Strategy

The laboratory is designed to minimize unnecessary AWS charges.

The project avoids adding expensive or unnecessary infrastructure simply to increase architectural complexity. Services will be introduced only when they provide a meaningful learning or portfolio objective, with AWS pricing and eligibility checked before deployment.

## Documentation

- [AWS infrastructure architecture](docs/02-architecture.md)
- [Deployment and verification](docs/03-deployment-and-verification.md)

## Project Status

**Core AWS infrastructure, remote administration, HTTPS/TLS, and automated deployment: implemented and verified.**

The current environment demonstrates a working AWS public web deployment with verified SSH and Session Manager administration, Nginx, TLS 1.3, and GitHub Actions-based delivery. AWS Systems Manager recognizes the EC2 instance as an online managed node, and Nginx configuration, service state, and listeners on TCP 80 and 443 were verified from the SSM session. Future work will focus on operational improvements rather than adding infrastructure solely for complexity.
