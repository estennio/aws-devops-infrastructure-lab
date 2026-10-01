# Deployment and Verification

## Purpose

This document records the implementation and tests performed against the current AWS laboratory.

The goal is to keep the repository synchronized with the real AWS environment and to avoid claiming functionality without evidence.

## Environment

- AWS Region: `us-east-2`
- VPC: `10.20.0.0/16`
- Public Subnet A: `10.20.1.0/24`
- EC2 instance: `t3.micro`
- OS: Ubuntu Server 24.04 LTS
- Web server: Nginx

## 1. EC2 Access

The EC2 key pair was downloaded as:

```text
lab-key.pem
```

The private key was stored locally and was **not** added to the repository.

On Windows, OpenSSH initially rejected the key because its NTFS permissions were too broad. The permissions were restricted to the local administrator account before connecting.

The successful connection was:

```powershell
ssh -i .\lab-key.pem ubuntu@<public-ip>
```

Successful login confirmed Ubuntu Server 24.04.4 LTS.

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
Content-Type: text/html
```

This proves that Nginx is serving HTTP locally.

## 6. External HTTP Verification

After leaving the SSH session, the test was executed from Windows PowerShell:

```powershell
curl.exe -I http://<public-ip>
```

Verified response:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
```

This verifies external HTTP connectivity to the EC2 web server.

## 7. Listening Ports

Inside the EC2 instance:

```bash
sudo ss -lntp | grep -E ':22|:80|:443'
```

The verified listeners were:

- TCP 22 — SSH
- TCP 80 — Nginx HTTP

No HTTPS service was verified during this stage.

## 8. Evidence to Preserve

The project should preserve screenshots or terminal captures showing:

- VPC configuration
- Public subnet configuration
- Internet Gateway attachment
- Route table and default route
- Security Group rules
- EC2 instance state
- Successful SSH session
- Ubuntu version
- Nginx service status
- Local HTTP response
- External HTTP response
- Browser rendering of the deployed application

Evidence must be generated from the actual environment. No fabricated screenshots or status claims should be added.

## 9. Current Verification Matrix

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
| Nginx | Verified |
| HTTP local | Verified |
| HTTP external | Verified |
| HTTPS | Pending |
| CI/CD | Pending |
| RDS | Not deployed |
| NAT Gateway | Not deployed |

## Next Implementation Stage

1. Synchronize the portfolio website with the verified infrastructure.
2. Implement HTTPS/TLS and verify it independently.
3. Add automated deployment with GitHub Actions.
4. Evaluate whether AWS Systems Manager should replace direct SSH for administration.
5. Add further AWS services only when they provide a clear technical objective.
