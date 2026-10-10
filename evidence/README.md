# Evidence Index

## Evidence policy

This directory tracks the verifiable artifacts of the AWS DevOps Infrastructure Lab. A statement in the documentation is supported by an artifact listed here; commands that have not been executed are procedures, not evidence.

Statuses:

- **Available:** a reviewed artifact or public link is present and can be inspected;
- **Recorded:** the result is transcribed in [Deployment and Verification](../docs/02-deployment-and-verification.md); a raw capture can be produced with the collector below;
- **Next stage:** the artifact is produced when the corresponding step is performed.

Artifacts never include credentials, session tokens, private keys, secret values, full environment dumps, instance metadata credentials, or unredacted sensitive console content. Public certificate properties are allowed; certificate private keys are not. Account and session identifiers in screenshots are redacted.

## Evidence matrix

Rows marked *earlier console-built instance* are screenshots of the infrastructure created by hand in the console, which Terraform has since replaced. They are kept as history. Rows pointing to `artifacts/terraform/` describe the current Terraform-managed instance.

| Component | Evidence | File or link | Status |
|---|---|---|---|
| VPC | AWS Console capture of the lab VPC | [`aws/02-vpc.png`](artifacts/aws/02-vpc.png) | Available (earlier console-built instance) |
| Public subnet | Subnet capture | [`aws/03-public-subnet.png`](artifacts/aws/03-public-subnet.png) | Available (earlier console-built instance) |
| Internet Gateway | IGW attached to the lab VPC | [`aws/04-internet-gateway.png`](artifacts/aws/04-internet-gateway.png) | Available (earlier console-built instance) |
| Routes | Route table with the default route | [`aws/05-route-table.png`](artifacts/aws/05-route-table.png) | Available (earlier console-built instance) |
| Security Group | Inbound/outbound rules | [`aws/06-security-group.png`](artifacts/aws/06-security-group.png) | Available (earlier console-built instance) |
| EC2 | Instance details | [`aws/01-ec2-instance.png`](artifacts/aws/01-ec2-instance.png) | Available (earlier console-built instance) |
| IAM role for SSM | Role used by Systems Manager | [`ssm/02-iam-ssm-role.png`](artifacts/ssm/02-iam-ssm-role.png) | Available (earlier console-built instance) |
| SSM managed node | Instance registered and online | [`ssm/01-managed-node.png`](artifacts/ssm/01-managed-node.png) | Available (earlier console-built instance) |
| Session Manager | Session to the instance | [`ssm/03-session-manager.png`](artifacts/ssm/03-session-manager.png) | Available (earlier console-built instance) |
| Nginx | Listeners on TCP 80/443 | [`web/01-nginx-ports.png`](artifacts/web/01-nginx-ports.png) | Available (earlier console-built instance) |
| External HTTP | PowerShell response from the EC2 public endpoint | [`web/02-http-external.png`](artifacts/web/02-http-external.png) | Available (earlier console-built instance) |
| External HTTPS | PowerShell response using `-k` (transport/connectivity evidence only) | [`web/03-https-external.png`](artifacts/web/03-https-external.png) | Available (earlier console-built instance) |
| Laboratory Root CA | Root CA creation | [`tls/01-root-ca.png`](artifacts/tls/01-root-ca.png) | Available (earlier console-built instance) |
| Server certificate | Certificate for `web.lab.test` issued by the laboratory Root CA | [`tls/02-server-cert-issued-by-root-ca.png`](artifacts/tls/02-server-cert-issued-by-root-ca.png) | Available (earlier console-built instance) |
| Certificate chain | `openssl verify` against the Root CA returns `OK` | [`tls/03-root-ca-verify.png`](artifacts/tls/03-root-ca-verify.png) | Available (earlier console-built instance) |
| Certificate SAN | `DNS:web.lab.test` | [`tls/04-server-cert-san.png`](artifacts/tls/04-server-cert-san.png) | Available (earlier console-built instance) |
| TLS 1.3 | Negotiated protocol | [`tls/05-tls13.png`](artifacts/tls/05-tls13.png) | Available (earlier console-built instance) |
| Nginx TLS configuration | HTTPS server block | [`tls/06-nginx-tls-config.png`](artifacts/tls/06-nginx-tls-config.png) | Available (earlier console-built instance) |
| GitHub Actions (SSH, removed) | Completed run for the earlier `Deploy website to EC2` workflow; it verifies only the steps implemented by that workflow | [Run 37144567040](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/37144567040), commit `c83425515b175a0dc70bd9a6afd9e52b03933014` | Available |
| Local HTTP/HTTPS, service state, `nginx -t` | Collector output with exit statuses | Run [`scripts/collect-evidence.sh`](../scripts/collect-evidence.sh) on the server; results are transcribed in the verification document | Recorded |
| OIDC and SSM GitHub Actions deploy | Approved manual runs with SSH disabled: a deploy, a deliberate external-validation failure that rolled back through SSM, and a redeploy; served `VERSION` checked from outside after each | [`deployment/01-ssm-deploy-and-rollback.txt`](artifacts/deployment/01-ssm-deploy-and-rollback.txt), runs listed below | Available |
| Terraform | Plan, outputs, live HTTP/HTTPS and SSM checks | `infra/terraform/` | [`artifacts/terraform/`](artifacts/terraform/) |
| Current instance: Nginx, listeners, `nginx -t`, HTTP/HTTPS | Collector output with exit statuses, run through SSM Run Command | [`05-server-evidence.txt`](artifacts/terraform/05-server-evidence.txt) | Available |
| Current instance: TLS 1.3 and certificate | Forced TLS 1.3 handshake; self-signed certificate, `CN`/`SAN` `web.lab.test`, issuer equal to subject (no CA chain) | [`05-server-evidence.txt`](artifacts/terraform/05-server-evidence.txt) | Available |
| Current instance: SSM Run Command | Command status `Success` for the collection run without SSH | [`05-server-evidence.txt`](artifacts/terraform/05-server-evidence.txt) | Available |

## Verified GitHub Actions links

The following successful runs were verified through the repository's public GitHub Actions API on 2026-10-03. The links are evidence of the workflow executions and their conclusions, not independent evidence of external HTTPS, certificate trust, or current AWS state.

| Created (UTC) | Event | Commit | Run |
|---|---|---|---|
| 2026-10-03 18:32:16 | `push` | `c83425515b175a0dc70bd9a6afd9e52b03933014` | [37144567040](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/37144567040) |
| 2026-10-03 18:19:57 | `push` | `0f7bb5c65b85f374fbb8104ba204a3ed339b5646` | [37143783941](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/37143783941) |
| 2026-10-02 02:49:37 | `push` | `8443d956235e6788cb4a34630381cc363f084ea8` | [36957408733](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/36957408733) |
| 2026-10-01 16:45:24 | `push` | `71f209e94b0563a6d559a9ac4b18ab3ead2db4be` | [36894367264](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/36894367264) |
| 2026-10-01 15:35:24 | `workflow_dispatch` | `84817223d6b6fcd7de8fc1d5f211680884ec58cf` | [36885439235](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/36885439235) |
| 2026-10-01 15:34:31 | `push` | `84817223d6b6fcd7de8fc1d5f211680884ec58cf` | [36885326913](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/36885326913) |
| 2026-10-01 15:25:57 | `workflow_dispatch` | `bf37106261cebdb992c87719b6d2a0f211542d4f` | [36884204089](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/36884204089) |

Public API source: [workflow runs](https://api.github.com/repos/estennio/aws-devops-infrastructure-lab/actions/runs?per_page=100).

## OIDC and SSM deployment runs

Workflow `Deploy versioned website via SSM`, environment `production` (required reviewer, `main` only). Details, log excerpts and the external `VERSION` checks are in [`deployment/01-ssm-deploy-and-rollback.txt`](artifacts/deployment/01-ssm-deploy-and-rollback.txt). GitHub keeps workflow logs for a limited time; the transcript is the durable record.

| Run | Commit | Result |
|---|---|---|
| [#1, attempt 1](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/38016600883/attempts/1) | `e66bae9` | Denied `sts:AssumeRoleWithWebIdentity`: the trust policy expected the legacy OIDC subject (fixed in #11) |
| [#1, attempt 2](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/38016600883/attempts/2) | `e66bae9` | Success: release uploaded to S3, activated through SSM, validated over HTTP and HTTPS |
| [#2, attempt 1](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/38018487761/attempts/1) | `e234bb0` | Failed on purpose (`EC2_HOST=127.0.0.1`); rollback through SSM succeeded and the instance served `e66bae9` again |
| [#2, attempt 2](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/38018487761/attempts/2) | `e234bb0` | Success after restoring `EC2_HOST`; the instance serves `e234bb0` |

## Server collection

Run on the Ubuntu server from the repository checkout:

```bash
sudo bash scripts/collect-evidence.sh
```

The default output is a new UTC-stamped file under `evidence/artifacts/`. The collector runs every check, records each exit status, writes the complete report, and returns a nonzero overall status if one or more checks fail. It does not convert a failed check into a pass. Certificate inspection reads only the public certificate; the script never prints or copies the private key. `nginx -t` may open the configured key internally as part of Nginx configuration validation.

Before committing an output file:

1. inspect every line;
2. confirm that it contains no credential, token, private key, secret, unexpected hostname, or unrelated network information;
3. keep the UTC timestamp and command exit statuses intact;
4. add the reviewed path to the matrix and mark only the supported rows **Available**.

## External PowerShell checks

Set the temporary public IPv4 explicitly. Do not commit a value that should remain private or temporary.

```powershell
$PublicIp = '<public-ip>'
$Timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$Output = "evidence/artifacts/external-$Timestamp.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $Output) | Out-Null

& {
    "UTC: $([DateTime]::UtcNow.ToString('o'))"

    '=== External HTTP ==='
    curl.exe --fail --silent --show-error --head "http://$PublicIp/"
    "exit_status=$LASTEXITCODE"

    '=== External HTTPS: encryption/connectivity only (-k) ==='
    curl.exe --insecure --fail --silent --show-error --head `
      --resolve "web.lab.test:443:$PublicIp" https://web.lab.test/
    "exit_status=$LASTEXITCODE"

    '=== External HTTPS: default trust validation (no -k) ==='
    curl.exe --fail --silent --show-error --head `
      --resolve "web.lab.test:443:$PublicIp" https://web.lab.test/
    "exit_status=$LASTEXITCODE"
} 2>&1 | Tee-Object -FilePath $Output
```

The `--insecure`/`-k` request verifies that an encrypted HTTPS endpoint can be reached, but it disables certificate-chain verification. It must not be described as proof that the certificate is trusted.

The request without `-k` uses the client's configured trust store and validates both trust and hostname. A self-signed laboratory certificate normally requires deliberate installation in a test trust store or an explicit public-certificate file. If a reviewed copy of the public certificate is available locally, a separate explicit trust test can be run with:

```powershell
curl.exe --cacert .\web.lab.test.crt --fail --silent --show-error --head `
  --resolve "web.lab.test:443:$PublicIp" https://web.lab.test/
```

Do not use or copy the certificate private key for any client-side test. Capture the real command output and exit status before marking the corresponding matrix row **Available**.
