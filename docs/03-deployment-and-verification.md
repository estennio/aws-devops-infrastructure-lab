# Deployment and Verification

## Purpose

This document records the implementation and tests performed against the current AWS laboratory.

The goal is to keep the repository synchronized with the real AWS environment and to avoid claiming functionality without evidence.

## Environment

- AWS Region: `us-east-2`
- VPC: `10.20.0.0/16`
- Public Subnet A: `10.20.1.0/24`
- EC2 instance: `lab-web-server` (`i-08f84a35805b6b66d`), `t3.micro`
- OS: Ubuntu Server 24.04 LTS
- Web server: Nginx
- Administration: SSH and AWS Systems Manager Session Manager

## 1. EC2 Access

The EC2 key pair was downloaded as:

```text
lab-key.pem
```

The private key was stored locally and was **not** added to the repository.

On Windows, OpenSSH initially rejected the key because its NTFS permissions were too broad. The permissions were restricted before connecting.

The successful SSH connection was verified from Windows PowerShell.

## 2. Operating System Verification

Inside the EC2 instance:

```bash
lsb_release -a
```

Verified result:

```text
Distributor ID: Ubuntu
Description: Ubuntu 24.04.4 LTS
Release: 24.04
Codename: noble
```

## 3. SSH Verification

Command:

```bash
systemctl is-active ssh
```

Result:

```text
active
```

The SSH daemon was also verified listening on TCP/22.

## 4. Nginx Deployment

Nginx was installed on the Ubuntu instance.

Service verification:

```bash
systemctl is-active nginx
```

Result:

```text
active
```

The service was also reported by systemd as active and running.

## 5. Local HTTP Verification

Inside the EC2 instance:

```bash
curl -I http://localhost
```

Verified response:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

This proves that Nginx is serving HTTP locally.

## 6. External HTTP Verification

From Windows PowerShell:

```powershell
curl.exe -I http://<public-ip>
```

Verified response:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

This verifies external HTTP connectivity to the EC2 web server.

## 7. HTTPS / TLS Configuration

Nginx was configured to listen on TCP/443 using a laboratory certificate for `web.lab.test`.

The active listeners were verified with:

```bash
sudo ss -lntp | grep -E ':80|:443'
```

The result showed Nginx listening on both TCP/80 and TCP/443.

Nginx configuration validation:

```bash
sudo nginx -t
```

Result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## 8. TLS Certificate Verification

The certificate was inspected with:

```bash
openssl x509 -in /etc/nginx/ssl/web.lab.test/web.lab.test.crt -noout -subject -issuer -dates -ext subjectAltName
```

Verified properties:

```text
CN = web.lab.test
DNS:web.lab.test
notBefore=Oct  1 13:55:19 2026 GMT
notAfter=Oct  1 13:55:19 2027 GMT
```

The certificate is self-signed. It is intended for laboratory verification and is not a publicly trusted production certificate.

## 9. TLS 1.3 Verification

TLS negotiation was verified locally with:

```bash
openssl s_client -connect 127.0.0.1:443 -servername web.lab.test </dev/null 2>/dev/null | grep -E 'Protocol|Cipher|Verify'
```

Verified result:

```text
Protocol  : TLSv1.3
Cipher    : TLS_AES_256_GCM_SHA384
Verify return code: 18 (self-signed certificate)
```

The verification code is expected because the certificate is self-signed.

## 10. Local HTTPS Verification

The hostname-aware HTTPS request was tested locally:

```bash
curl -k -I --resolve web.lab.test:443:127.0.0.1 https://web.lab.test
```

Verified result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

## 11. External HTTPS Verification

From Windows PowerShell:

```powershell
curl.exe -k -I https://<public-ip>
```

Verified result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

A hostname-aware external test was also performed:

```powershell
curl.exe -k -I --resolve web.lab.test:443:<public-ip> https://web.lab.test
```

Verified result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

This verifies that the public HTTPS path reaches Nginx and returns the deployed application.

## 12. Automated Deployment

The GitHub Actions workflow `Deploy website to EC2` was successfully executed.

Deployment path:

```text
Git push
  ↓
GitHub Actions
  ↓
SSH
  ↓
EC2
  ↓
Nginx
  ↓
Deployment validation
```

The workflow successfully uploaded `index.html` and `style.css` and validated the deployment.

## 13. AWS Systems Manager / Session Manager Verification

AWS Systems Manager recognizes `lab-web-server` (`i-08f84a35805b6b66d`) as a managed node. The verified Systems Manager state is:

- SSM Agent: running
- ping status: `Online`
- Session Manager: administrative session opened successfully
- session user: `ssm-user`

Inside the Session Manager session, the Nginx configuration was validated with:

```bash
sudo nginx -t
```

Verified result:

```text
syntax is ok
test is successful
```

The Nginx service state was verified with:

```bash
sudo systemctl is-active nginx
```

Verified result:

```text
active
```

The session also confirmed the following TCP listeners:

```text
0.0.0.0:80 LISTEN
0.0.0.0:443 LISTEN
[::]:80 LISTEN
[::]:443 LISTEN
```

Session Manager is therefore a verified administrative path alongside the existing verified SSH access.

## 14. Current Verification Matrix

| Component | Status |
|---|---|
| VPC | Verified |
| Public Subnet A | Verified |
| Internet Gateway | Verified |
| Public Route Table | Verified |
| Security Group | Verified |
| EC2 | Verified |
| Ubuntu 24.04 LTS | Verified |
| SSH | Verified |
| AWS Systems Manager | Verified |
| Session Manager | Verified |
| Nginx | Verified |
| HTTP local | Verified |
| HTTP external | Verified |
| HTTPS local | Verified |
| HTTPS external | Verified |
| TLS 1.3 | Verified |
| TLS certificate / SAN | Verified |
| GitHub Actions | Verified |
| Automated deployment | Verified |
| RDS | Not deployed |
| NAT Gateway | Not deployed |
| Load Balancer | Not deployed |
| Auto Scaling | Not deployed |
| ECS/EKS | Not deployed |

## Evidence to Preserve

The project should preserve screenshots or terminal captures showing:

- VPC configuration
- Public subnet configuration
- Internet Gateway attachment
- Route table and default route
- Security Group rules
- EC2 instance state
- Successful SSH session
- Systems Manager managed-node status, SSM Agent state, and Online ping status
- Successful Session Manager session as `ssm-user`
- Ubuntu version
- Nginx service status
- HTTP response
- HTTPS response
- TLS 1.3 negotiation
- Certificate subject and SAN
- GitHub Actions successful deployment

Evidence must be generated from the actual environment. No fabricated screenshots or status claims should be added.

## Next Implementation Stage

1. Improve operational security and repeatable verification where appropriate.
2. Continue documenting new operational evidence as the laboratory evolves.
3. Add further AWS services or technologies only when they provide a clear technical objective.
4. Consider a publicly trusted certificate/domain only if it adds a meaningful learning objective.
