# AWS DevOps Infrastructure Lab

[![Validate](https://github.com/estennio/aws-devops-infrastructure-lab/actions/workflows/validate.yml/badge.svg)](https://github.com/estennio/aws-devops-infrastructure-lab/actions/workflows/validate.yml)

Hands-on AWS/DevOps laboratory: a static website served by Nginx on an Ubuntu EC2 instance inside a custom VPC, with HTTPS/TLS 1.3, Session Manager administration, automated GitHub Actions delivery, versioned releases with rollback, and Terraform for the minimum infrastructure.

## Highlights

| Area | Result |
|---|---|
| Networking | Custom VPC `10.20.0.0/16`, public subnet `10.20.1.0/24`, Internet Gateway, public route table, and Security Group in `us-east-2` |
| Compute | EC2 `lab-web-server` (`t3.micro`, Ubuntu Server 24.04 LTS) |
| Administration | Key-based SSH and AWS Systems Manager Session Manager (managed node `Online`, IAM role for SSM) |
| Web and TLS | Nginx on TCP 80/443, HTTP and HTTPS `200 OK` locally and externally, TLS 1.3, certificate for `web.lab.test` with matching CN/SAN, issued by a laboratory Root CA |
| Delivery | GitHub Actions deployment over SSH with successful runs linked in the [evidence index](evidence/README.md) |
| Releases | SHA-addressed releases, atomic activation, validation over HTTP/HTTPS, and automatic rollback |
| Infrastructure as code | Terraform for the VPC, subnet, routing, Security Group, EC2, and SSM IAM profile |
| Evidence | Curated screenshots, verified workflow runs, and a server-side evidence collector |

## Architecture

```text
Internet
   |
Internet Gateway
   |
VPC 10.20.0.0/16
   |
Public Subnet A 10.20.1.0/24
   |
Security Group
   |
EC2 t3.micro / Ubuntu 24.04 LTS
   |-- SSH and Session Manager
   `-- Nginx
       |-- HTTP :80
       `-- HTTPS :443 / TLS 1.3
```

Details, component table, and design decisions: [AWS Infrastructure Architecture](docs/02-architecture.md).

## What is in the repository

| Artifact | Purpose |
|---|---|
| `index.html`, `style.css` | Static portfolio page describing the lab, responsive and dependency-free. |
| `.github/workflows/deploy.yml` | Deploys the site to EC2 over SSH on relevant pushes to `main` or manual dispatch. |
| `.github/workflows/deploy-versioned.yml` | Manual SHA-addressed deployment with atomic activation, validation, and rollback. |
| `configs/nginx/web.lab.test.conf` | HTTP/HTTPS virtual host serving `/var/www/html` with TLS 1.2/1.3. |
| `configs/nginx/web.lab.test.versioned.conf` | Virtual host serving the atomic `current` release link. |
| `scripts/bootstrap.sh` | Idempotent Ubuntu 24.04 bootstrap: Nginx, site files, and certificate. |
| `scripts/prepare-versioned-deploy.sh`, `scripts/versioned-deploy.sh` | Server migration to the release layout, plus release activation and rollback. |
| `scripts/collect-evidence.sh` | Collector for non-sensitive operational evidence with per-check exit statuses. |
| `infra/terraform/` | Terraform for the minimum AWS architecture. |
| `evidence/` | Evidence index and curated screenshots. |

## Deployment pipeline

The deployment workflow:

1. reads the SSH key, host key, host, and user from GitHub Actions secrets;
2. uploads `index.html` and `style.css` with `scp` to a temporary directory;
3. installs them under `/var/www/html`;
4. runs `nginx -t`, reloads Nginx, and requests `http://127.0.0.1/` with `curl -fsS`.

The final request confirms that the local HTTP endpoint answers without an HTTP error. The workflow does not search the response for a specific phrase and does not test the external endpoint, HTTPS, or the contents of `style.css`.

The versioned workflow publishes complete releases by commit SHA, switches a symbolic link atomically, compares the served `VERSION` with the workflow SHA, validates local and external HTTP/HTTPS transport, and rolls back on failure. It is manual-only and targets the versioned layout described in [Versioned Deployment and Rollback](docs/05-versioned-deployment.md).

Both workflows share one concurrency group with in-progress cancellation disabled, so EC2 deployments never overlap or interrupt a running deployment.

## Documentation

| Document | Content |
|---|---|
| [Architecture](docs/02-architecture.md) | Topology, components, administration and security boundary, scope decisions |
| [Deployment and Verification](docs/03-deployment-and-verification.md) | Recorded host, SSM, HTTP, HTTPS, and TLS results; pipeline behavior; status matrix |
| [Server Bootstrap](docs/04-server-bootstrap.md) | Reproducible Nginx server setup and certificate handling |
| [Versioned Deployment and Rollback](docs/05-versioned-deployment.md) | Release layout, server preparation, validation, and rollback |
| [Terraform](infra/terraform/README.md) | Minimum AWS infrastructure, variables, usage, import, and cost notes |
| [Evidence index](evidence/README.md) | Screenshots, verified workflow runs, and collection procedures |

## Repository structure

```text
.
|-- .github/workflows/
|   |-- deploy.yml
|   `-- deploy-versioned.yml
|-- configs/nginx/
|   |-- web.lab.test.conf
|   `-- web.lab.test.versioned.conf
|-- docs/
|   |-- 02-architecture.md
|   |-- 03-deployment-and-verification.md
|   |-- 04-server-bootstrap.md
|   `-- 05-versioned-deployment.md
|-- evidence/
|   |-- README.md
|   `-- artifacts/
|-- infra/terraform/
|-- scripts/
|   |-- bootstrap.sh
|   |-- collect-evidence.sh
|   |-- prepare-versioned-deploy.sh
|   `-- versioned-deploy.sh
|-- .gitignore
|-- README.md
|-- index.html
`-- style.css
```

## Security and cost

- No EC2 private key, AWS credential, password, token, workflow secret, or certificate private material is committed. State, saved plans, local variable files, and certificates are excluded by `.gitignore`.
- SSH should be restricted to the administrator's current public IP whenever practical. The GitHub-hosted runner deployment requires an allowed SSH path to the instance.
- The certificate is issued by a laboratory CA and is intended for laboratory verification, not public trust.
- The design avoids NAT Gateway, Load Balancer, RDS, and additional instances to keep the laboratory inexpensive.

## Scope and limits

This is a single-instance laboratory, and the documentation distinguishes three kinds of content:

| Category | Meaning |
|---|---|
| Implemented in the repository | Files that can be inspected here: site, workflows, Nginx configuration, scripts, evidence collector, and Terraform. |
| Recorded verification | Results observed in the AWS/EC2 environment, transcribed in [Deployment and Verification](docs/03-deployment-and-verification.md) and supported by the [evidence index](evidence/README.md). They are a record, not a live check. |
| Scope decisions | Components intentionally left out: additional subnets and Availability Zones, NAT Gateway, RDS, Load Balancer and Auto Scaling, ECS/EKS, and Docker. |

Two operational steps follow the repository work and are tracked as the next stage: running `terraform apply`/import against AWS, and migrating the EC2 instance to the versioned release layout.

## Next steps

1. Apply (or import) the Terraform configuration and preserve the plan and apply output as evidence.
2. Migrate EC2 to the versioned layout and record a versioned deployment run.
3. Optionally add a publicly trusted domain and certificate.
