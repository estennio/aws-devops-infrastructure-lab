# AWS Infrastructure Architecture

## Documentation boundary

This document describes the AWS topology recorded during lab verification. It is not generated from a live AWS inventory, and the repository contains no infrastructure-as-code definition for these resources.

Use the following labels consistently:

- **repository implementation:** source files that can be inspected in this repository;
- **recorded verification:** AWS, EC2, and client results transcribed in [Deployment and Verification](03-deployment-and-verification.md);
- **planned / not implemented:** components with no implementation or recorded deployment.

## Recorded deployed topology

```text
Internet
    |
Internet Gateway
    |
VPC 10.20.0.0/16 (us-east-2)
    |
Public Subnet A 10.20.1.0/24
    |
Security Group
    |
EC2 lab-web-server
i-08f84a35805b6b66d / t3.micro / Ubuntu Server 24.04 LTS
    |-- Administration: SSH and Session Manager
    `-- Nginx
        |-- HTTP :80
        `-- HTTPS :443 / TLS 1.3
```

The public IPv4 used for testing is not recorded as permanent configuration because it can change when no Elastic IP is assigned.

## Component status

| Component | Status represented by this repository | Basis |
|---|---|---|
| VPC, public subnet, Internet Gateway, route table, Security Group | Recorded as deployed and verified | Transcribed AWS environment checks |
| EC2 `lab-web-server` (`t3.micro`) | Recorded as deployed and verified | Transcribed instance and OS checks |
| SSH and Session Manager | Recorded as operational | Transcribed SSH, managed-node, and session results |
| Nginx, HTTP, HTTPS, TLS 1.3 | Recorded as operational | Transcribed service, listener, request, and OpenSSL results |
| Static website | Implemented in the repository | `index.html` and `style.css` |
| GitHub Actions delivery | Implemented in the repository; successful execution recorded | `.github/workflows/deploy.yml` and the verification record |
| Ubuntu/Nginx bootstrap | Reproducible proposal; not verified on EC2 | `scripts/bootstrap.sh` and `configs/nginx/web.lab.test.conf` |

Raw AWS exports, screenshots, terminal captures, and workflow logs are not committed. Consequently, the recorded environment cannot be independently reconstructed or confirmed as currently running from repository contents alone.

## Network and compute record

- **Region:** US East (Ohio), `us-east-2`
- **VPC:** `10.20.0.0/16`
- **Public subnet:** `10.20.1.0/24`
- **Default route:** `0.0.0.0/0` to the Internet Gateway
- **Instance:** `lab-web-server` (`i-08f84a35805b6b66d`), `t3.micro`
- **Operating system:** Ubuntu Server 24.04 LTS
- **Web server:** Nginx

The verification record reports external `200 OK` responses over HTTP and HTTPS. It also reports Nginx listening on TCP 80 and 443, TLS 1.3 negotiation, and a self-signed certificate with CN/SAN `web.lab.test`.

## Administration and security boundary

SSH and Systems Manager Session Manager are recorded as working administration paths. Session Manager did not replace SSH: the deployment workflow still connects over SSH and therefore depends on appropriate network access and GitHub Actions secrets.

The documented application paths use:

- TCP 22 for SSH administration and automated delivery;
- TCP 80 for HTTP;
- TCP 443 for HTTPS/TLS.

The repository does not include Security Group rules, IAM policies, generated certificates, private keys, or GitHub Actions secret values. It now includes a proposed Nginx configuration and bootstrap, documented in [Reproducible Nginx Server Proposal](04-server-bootstrap.md); these files are not asserted to match the active EC2 configuration. The self-signed certificate is a lab artifact and is not publicly trusted.

## Planned / not implemented

The following are future options only:

- additional public or private subnets and availability zones;
- NAT Gateway;
- Amazon RDS PostgreSQL or another database layer;
- database Security Group;
- Load Balancer and Auto Scaling;
- ECS or EKS.

A possible private database design could use private subnets, disabled public access, and TCP 5432 allowed only from the application tier. No database is recorded as deployed.

Docker and Terraform are also not implemented. There is no `Dockerfile`, Compose file, `.tf` configuration, module, or Terraform state in the repository. Terraform-related `.gitignore` entries are preventive only.
