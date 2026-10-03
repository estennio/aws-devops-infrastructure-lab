# Deployment and Verification

## Evidence boundary

This document is the repository's text record of checks performed during the lab. The commands and outputs below were previously transcribed from AWS, EC2, Windows PowerShell, and GitHub Actions activity; they are not rerun automatically when this document changes.

No screenshots, terminal capture files, AWS inventory exports, or GitHub Actions logs are committed. Treat these entries as recorded operational evidence. The static site, deployment workflow, and [proposed server bootstrap](04-server-bootstrap.md) are implementation directly inspectable in the repository; the proposal has not been tested on EC2.

## Recorded environment

- AWS Region: `us-east-2`
- VPC: `10.20.0.0/16`
- Public Subnet A: `10.20.1.0/24`
- EC2 instance: `lab-web-server` (`i-08f84a35805b6b66d`), `t3.micro`
- OS: Ubuntu Server 24.04 LTS
- Web server: Nginx
- Administration: SSH and AWS Systems Manager Session Manager

## Recorded host and administration checks

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

The certificate is self-signed and is not publicly trusted.

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

The repository implements `Deploy website to EC2` in `.github/workflows/deploy.yml`. A successful execution is recorded from the lab, but its run URL and raw log are not archived here.

The current workflow:

1. runs for relevant changes on `main` or by manual dispatch;
2. configures SSH from GitHub Actions secrets;
3. uploads `index.html` and `style.css` to a temporary directory on the EC2 host;
4. installs both files in `/var/www/html`;
5. runs `nginx -t` and reloads Nginx;
6. runs `curl -fsS http://127.0.0.1/` and discards the response body.

Therefore, a successful current run demonstrates that the upload and remote commands completed, Nginx accepted its configuration, and the local HTTP request did not return a curl/HTTP error. It does **not** demonstrate that the page contains `Deployed automatically with GitHub Actions.` or any other specific text. It also does not test the external endpoint or HTTPS.

## Status matrix

| Component | Repository status | Evidence represented here |
|---|---|---|
| Static HTML/CSS site | Implemented | Source files are committed |
| GitHub Actions SSH deployment | Implemented | Workflow is committed; successful execution is recorded |
| VPC, subnet, Internet Gateway, route table, Security Group | No implementation files | Deployment and checks are recorded |
| EC2 and Ubuntu 24.04 LTS | No implementation files | Instance and OS checks are recorded |
| SSH and Session Manager | No implementation files | Successful access and service state are recorded |
| Nginx, HTTP, HTTPS, TLS 1.3 | Reproducible configuration proposal committed; not applied by this change | Earlier service, request, listener, and TLS results are recorded separately |
| RDS, NAT Gateway, Load Balancer, Auto Scaling, ECS/EKS | Not implemented | None claimed |
| Docker / Docker Compose | Not implemented | None claimed |
| Terraform / infrastructure-as-code | Not implemented | None claimed |

## Evidence to preserve in future

Future updates should attach or link real artifacts when practical, such as:

- AWS resource configuration exports or screenshots;
- SSH and Session Manager terminal captures with sensitive values removed;
- Nginx service, listener, HTTP/HTTPS, and TLS output;
- a specific successful GitHub Actions run.

Do not add fabricated screenshots, live secrets, private keys, credentials, or unverified status claims.

## Next implementation stage

1. Improve repeatable verification and preserve non-sensitive evidence.
2. Improve operational security where appropriate.
3. Add AWS services or technologies only for a clear technical objective.
4. Consider a publicly trusted domain and certificate only if they add useful scope.
