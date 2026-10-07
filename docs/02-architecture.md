# AWS Infrastructure Architecture

## Overview

This document describes the AWS topology of the laboratory: network, compute, administration, and web delivery. Results come from the verification sessions transcribed in [Deployment and Verification](03-deployment-and-verification.md) and the screenshots in the [evidence index](../evidence/README.md); the topology is not generated from a live AWS inventory.

Content is labeled as:

- **repository implementation:** source files that can be inspected in this repository;
- **recorded verification:** AWS, EC2, and client results with their supporting evidence;
- **scope decisions:** components deliberately left out of the laboratory.

## Deployed topology

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

## Components

| Component | Status | Basis |
|---|---|---|
| VPC, public subnet, Internet Gateway, route table, Security Group | Deployed and verified | Transcribed AWS environment checks |
| EC2 `lab-web-server` (`t3.micro`) | Deployed and verified | Transcribed instance and OS checks |
| SSH and Session Manager | Operational | Transcribed SSH, managed-node, and session results |
| Nginx, HTTP, HTTPS, TLS 1.3 | Operational | Transcribed service, listener, request, and OpenSSL results |
| Static website | Implemented in the repository | `index.html` and `style.css` |
| GitHub Actions delivery | Implemented; successful runs linked in the evidence index | `.github/workflows/deploy.yml` and the verification record |
| Ubuntu/Nginx bootstrap | Reproducible server configuration | `scripts/bootstrap.sh` and `configs/nginx/web.lab.test.conf` |
| Minimum AWS infrastructure | Terraform configuration for the minimum architecture | `infra/terraform/` |

Curated screenshots of the AWS resources, Session Manager, HTTP/HTTPS, and TLS are committed under `evidence/artifacts/`, and the successful workflow runs are linked in the evidence index. Raw AWS exports and workflow logs are not stored, so the topology is a verified record rather than a live inventory.

## Network and compute record

- **Region:** US East (Ohio), `us-east-2`
- **VPC:** `10.20.0.0/16`
- **Public subnet:** `10.20.1.0/24`
- **Default route:** `0.0.0.0/0` to the Internet Gateway
- **Instance:** `lab-web-server` (`i-08f84a35805b6b66d`), `t3.micro`
- **Operating system:** Ubuntu Server 24.04 LTS
- **Web server:** Nginx

The verification record reports external `200 OK` responses over HTTP and HTTPS, Nginx listening on TCP 80 and 443, TLS 1.3 negotiation, and a certificate with CN/SAN `web.lab.test`. The certificate was first self-signed and was later re-issued by a laboratory Root CA (see the TLS evidence).

## Administration and security boundary

SSH and Systems Manager Session Manager are recorded as working administration paths. Session Manager did not replace SSH: the deployment workflow still connects over SSH and therefore depends on appropriate network access and GitHub Actions secrets.

The documented application paths use:

- TCP 22 for SSH administration and automated delivery;
- TCP 80 for HTTP;
- TCP 443 for HTTPS/TLS.

The repository does not include Security Group rules, IAM policies, generated certificates, private keys, or GitHub Actions secret values. The Nginx configuration and bootstrap are documented in [Server Bootstrap](04-server-bootstrap.md); they are a reproducible configuration and not an export of the active EC2 server. The laboratory certificate is not publicly trusted.

## Scope decisions

The laboratory intentionally keeps a minimal footprint. The following are outside its scope:

- additional public or private subnets and availability zones;
- NAT Gateway;
- Amazon RDS PostgreSQL or another database layer, and a database Security Group;
- Load Balancer and Auto Scaling;
- ECS or EKS;
- Docker and Docker Compose.

A natural extension would be a private database tier: private subnets, disabled public access, and TCP 5432 allowed only from the application tier.

## Infrastructure as code

The minimum architecture is defined in `infra/terraform/` (see its [README](../infra/terraform/README.md)). Terraform state, saved plans, and apply or import results are not committed; applying the configuration and preserving its output as evidence is the next stage of the lab.
