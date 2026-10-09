# Deployment and Verification

## Overview

This document is the repository's text record of the checks performed during the lab. The commands and outputs below were transcribed from AWS, EC2, Windows PowerShell, and GitHub Actions activity; they are not rerun automatically when this document changes.

Supporting screenshots are committed under `evidence/artifacts/` and workflow runs are linked in the [evidence index](../evidence/README.md). The static site, deployment workflow, and [server bootstrap](03-server-bootstrap.md) can be inspected directly in the repository.

## Recorded environment

- AWS Region: `us-east-2`
- VPC: `10.20.0.0/16`
- Public Subnet A: `10.20.1.0/24`
- EC2 instance: `lab-web-server` (`i-041c6cfc9e5181d4c`), `t3.micro`, managed by Terraform (replaced the earlier console-created instance)
- OS: Ubuntu Server 24.04 LTS
- Web server: Nginx
- Administration: AWS Systems Manager Session Manager (SSH was recorded on the earlier console-built instance and is disabled by default in Terraform)

## Recorded host and administration checks

The checks in this section and the screenshots under `evidence/artifacts/` (`aws`, `ssm`, `tls`, `web`) were recorded on the earlier console-created instance, which Terraform has since replaced. The Terraform-managed instance has its own evidence in [`evidence/artifacts/terraform/`](../evidence/artifacts/terraform/): the plan, outputs, an HTTP/HTTPS check, and the SSM `Online` status. TLS 1.3 and the laboratory Root CA certificate were not re-verified on it.

The private key `lab-key.pem` was kept outside the repository. After its NTFS permissions were restricted, an SSH connection from Windows PowerShell was recorded as successful.

The operating system check recorded:

```text
$ lsb_release -a
Distributor ID: Ubuntu
Description: Ubuntu 24.04.4 LTS
Release: 24.04
Codename: noble
```

SSH service state was recorded as:

```text
$ systemctl is-active ssh
active
```

The SSH daemon was also recorded as listening on TCP/22.

AWS Systems Manager recorded the instance as a managed node with the SSM Agent running and ping status `Online`. A Session Manager administrative session was opened as `ssm-user`.

From that session, the following results were recorded:

```text
$ sudo nginx -t
syntax is ok
test is successful

$ sudo systemctl is-active nginx
active
```

The session also recorded Nginx listeners on:

```text
0.0.0.0:80 LISTEN
0.0.0.0:443 LISTEN
[::]:80 LISTEN
[::]:443 LISTEN
```

## Recorded HTTP and HTTPS checks

The local HTTP check was:

```text
$ curl -I http://localhost
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

An external request from Windows PowerShell recorded the same status:

```powershell
curl.exe -I http://<public-ip>
```

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

Nginx configuration for HTTPS was checked with `sudo nginx -t`. The certificate inspection command was recorded as:

```bash
openssl x509 -in /etc/nginx/ssl/web.lab.test/web.lab.test.crt -noout -subject -issuer -dates -ext subjectAltName
```

Recorded certificate properties:

```text
CN = web.lab.test
DNS:web.lab.test
notBefore=Oct  1 13:55:19 2026 GMT
notAfter=Oct  1 13:55:19 2027 GMT
```

The certificate was self-signed at this stage and is not publicly trusted. It was later re-issued by a laboratory Root CA, as shown in the TLS screenshots of the [evidence index](../evidence/README.md); that certificate also carries `DNS:web.lab.test`, and `openssl verify` against the laboratory Root CA returns `OK`.

Local TLS negotiation was recorded as:

```text
$ openssl s_client -connect 127.0.0.1:443 -servername web.lab.test
Protocol  : TLSv1.3
Cipher    : TLS_AES_256_GCM_SHA384
Verify return code: 18 (self-signed certificate)
```

The verification code is expected for this self-signed certificate. Local and external HTTPS requests were also recorded:

```bash
curl -k -I --resolve web.lab.test:443:127.0.0.1 https://web.lab.test
```

```powershell
curl.exe -k -I https://<public-ip>
curl.exe -k -I --resolve web.lab.test:443:<public-ip> https://web.lab.test
```

Each recorded response included:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

## Deployment workflow

The repository implements `Deploy website to EC2` in `.github/workflows/deploy.yml`. Successful executions are linked in the [evidence index](../evidence/README.md).

The current workflow:

1. runs for relevant changes on `main` or by manual dispatch;
2. shares a non-canceling concurrency group with the manual versioned workflow;
3. configures SSH from GitHub Actions secrets;
4. uploads `index.html` and `style.css` to a temporary directory on the EC2 host;
5. installs both files in `/var/www/html`;
6. runs `nginx -t` and reloads Nginx;
7. runs `curl -fsS http://127.0.0.1/` and discards the response body.

A successful run demonstrates that the upload and remote commands completed, Nginx accepted its configuration, and the local HTTP request did not return a curl/HTTP error. It does **not** demonstrate that the page contains `Deployed automatically with GitHub Actions.` or any other specific text. It also does not test the external endpoint or HTTPS.

The repository also contains the separate `Deploy versioned website to EC2` workflow. It is manual-only and is used after the EC2 preparation in [Versioned Deployment and Rollback](04-versioned-deployment.md) succeeds. Its implemented checks cover `index.html`, `style.css`, and a SHA-bearing `VERSION` file over local and external HTTP and HTTPS. HTTPS with `--insecure` checks transport through the self-signed laboratory endpoint; it is not evidence of certificate trust. Its first execution follows the EC2 migration, which is the next stage of the lab.

## Status matrix

| Component | Repository | Verification |
|---|---|---|
| Static HTML/CSS site | Implemented | Served over HTTP and HTTPS |
| GitHub Actions SSH deployment | Implemented | Successful runs linked in the evidence index |
| Versioned deployment and rollback | Implemented (manual workflow and server scripts) | Runs after the EC2 migration (next stage) |
| OIDC and SSM deployment | Implemented (`deploy-ssm.yml`, `github-oidc.tf`) | No run recorded yet |
| VPC, subnet, Internet Gateway, route table, Security Group | Terraform configuration | Applied from scratch; outputs in `evidence/artifacts/terraform/`; earlier console screenshots committed |
| EC2, Ubuntu 24.04 LTS, and SSM IAM profile | Terraform configuration | Applied from scratch; instance `Online` in SSM (`evidence/artifacts/terraform/`) |
| Session Manager | Terraform-managed instance profile | `Online` recorded for the current instance; session screenshots are from the earlier instance |
| SSH | Disabled by default in Terraform | Successful access recorded on the earlier instance only |
| Nginx, HTTP, HTTPS | Reproducible bootstrap and configuration | `200 OK` over HTTP and HTTPS recorded on the current instance |
| TLS 1.3 and laboratory Root CA certificate | Bootstrap and Nginx configuration | Recorded on the earlier instance; not re-verified on the current one |
| Terraform / infrastructure-as-code | Minimum configuration in `infra/terraform/` | Applied from scratch (14 resources); plan, outputs, and live checks in `evidence/artifacts/terraform/` |
| RDS, NAT Gateway, Load Balancer, Auto Scaling, ECS/EKS, Docker | Outside the laboratory scope | Not applicable |

## Evidence

The [evidence index](../evidence/README.md) is the source of truth for the artifacts. New artifacts are added only after review, with sensitive values removed: no live secrets, private keys, or credentials.

## Next steps

1. Migrate EC2 to the versioned release layout and record a versioned deployment run.
2. Optionally add a publicly trusted domain and certificate.
