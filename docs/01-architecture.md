# AWS Infrastructure Architecture

## Overview

This document describes the AWS topology of the laboratory: network, compute, administration, and web delivery. Results come from the verification sessions transcribed in [Deployment and Verification](02-deployment-and-verification.md) and the screenshots in the [evidence index](../evidence/README.md); the topology is not generated from a live AWS inventory.

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
i-041c6cfc9e5181d4c / t3.micro / Ubuntu Server 24.04 LTS
    |-- Administration: Session Manager (SSH disabled by default)
    `-- Nginx
        |-- HTTP :80
        `-- HTTPS :443 / TLS 1.3
```

The instance's primary network interface is a separate Terraform resource that holds an Elastic IP, so the public IPv4 stays the same when the instance is replaced. The address itself is not recorded in the repository; `terraform output instance_public_ip` shows it, and the deploy workflow reads it from SSM Parameter Store.

## Components

| Component | Status | Basis |
|---|---|---|
| VPC, public subnet, Internet Gateway, route table, Security Group | Deployed and verified | Transcribed AWS environment checks |
| EC2 `lab-web-server` (`t3.micro`) | Deployed and verified | Transcribed instance and OS checks |
| Session Manager and SSM Run Command | Verified on the Terraform-managed instance (`Online`; the evidence collection itself ran through SSM Run Command) | [`04-ssm-online.txt`](../evidence/artifacts/terraform/04-ssm-online.txt), [`05-server-evidence.txt`](../evidence/artifacts/terraform/05-server-evidence.txt); earlier session screenshots from the console-built instance |
| SSH | Recorded on the earlier console-built instance only; disabled by default in Terraform | Transcribed SSH results |
| Nginx, HTTP, HTTPS | `nginx -t`, service state, TCP 80/443 listeners, and HTTP/HTTPS `200 OK` verified on the Terraform-managed instance | [`03-http-https-check.txt`](../evidence/artifacts/terraform/03-http-https-check.txt), [`05-server-evidence.txt`](../evidence/artifacts/terraform/05-server-evidence.txt) |
| TLS 1.3 with a self-signed certificate | Verified on the Terraform-managed instance: TLS 1.3, `CN`/`SAN` `web.lab.test`, issuer equal to subject | [`05-server-evidence.txt`](../evidence/artifacts/terraform/05-server-evidence.txt) |
| Laboratory Root CA chain | Historical: recorded on the earlier console-built instance only; not claimed for the current one | TLS screenshots in the evidence index |
| Static website | Implemented in the repository | `index.html` and `style.css` |
| GitHub Actions delivery over SSH | Historical: successful runs linked in the evidence index; the workflows were removed | Git history and the verification record |
| GitHub Actions delivery over OIDC and SSM | Verified: deploy, rollback test and redeploy with SSH disabled | [`01-ssm-deploy-and-rollback.txt`](../evidence/artifacts/deployment/01-ssm-deploy-and-rollback.txt), runs in the evidence index |
| Ubuntu/Nginx bootstrap | Reproducible server configuration | `scripts/bootstrap.sh` and `configs/nginx/web.lab.test.versioned.conf` |
| Minimum AWS infrastructure | Terraform configuration for the minimum architecture | `infra/terraform/` |

Curated screenshots of the AWS resources, Session Manager, HTTP/HTTPS, and TLS are committed under `evidence/artifacts/`, and the successful workflow runs are linked in the evidence index. Raw AWS exports and workflow logs are not stored, so the topology is a verified record rather than a live inventory.

## Network and compute record

- **Region:** US East (Ohio), `us-east-2`
- **VPC:** `10.20.0.0/16`
- **Public subnet:** `10.20.1.0/24`
- **Default route:** `0.0.0.0/0` to the Internet Gateway
- **Instance:** `lab-web-server` (`i-041c6cfc9e5181d4c`), `t3.micro`
- **Operating system:** Ubuntu Server 24.04 LTS
- **Web server:** Nginx

The verification record reports external `200 OK` responses over HTTP and HTTPS, Nginx listening on TCP 80 and 443, TLS 1.3 negotiation, and a certificate with CN/SAN `web.lab.test`. On the earlier console-built instance the certificate was first self-signed and later re-issued by a laboratory Root CA (historical TLS evidence). The current instance uses the self-signed certificate that `scripts/bootstrap.sh` generates, with no CA chain.

## Administration and security boundary

Session Manager is verified on the Terraform-managed instance. SSH was recorded as working on the earlier console-built instance; the Terraform configuration leaves it disabled by default. Deployments no longer use SSH: the OIDC and SSM workflow (`deploy-ssm.yml`) needs neither an open port nor a stored key, and its runs are recorded on the current instance with SSH disabled. The earlier SSH workflows were removed.

The application paths use:

- TCP 22 for SSH, only when `enable_ssh` is set in Terraform or on the earlier instance;
- TCP 80 for HTTP;
- TCP 443 for HTTPS/TLS.

The repository does not include Security Group rules, IAM policies, generated certificates, private keys, or GitHub Actions secret values. The Nginx configuration and bootstrap are documented in [Server Bootstrap](03-server-bootstrap.md); they are a reproducible configuration and not an export of the active EC2 server. The laboratory certificate is not publicly trusted.

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

The minimum architecture is defined in `infra/terraform/` (see its [README](../infra/terraform/README.md)). The configuration was applied from scratch (plan: 14 resources to add) and now manages the infrastructure described here, replacing the instance originally created by hand in the console (`i-08f84a35805b6b66d`). The plan, outputs, live HTTP/HTTPS check, and SSM status are in [`evidence/artifacts/terraform/`](../evidence/artifacts/terraform/); state and tfvars are not committed.
