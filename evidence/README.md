# Evidence Index

## Evidence policy

This directory tracks the verifiable artifacts of the AWS DevOps Infrastructure Lab. A statement in the documentation is supported by an artifact listed here; commands that have not been executed are procedures, not evidence.

Statuses:

- **Available:** a reviewed artifact or public link is present and can be inspected;
- **Recorded:** the result is transcribed in [Deployment and Verification](../docs/03-deployment-and-verification.md); a raw capture can be produced with the collector below;
- **Next stage:** the artifact is produced when the corresponding step is performed.

Artifacts never include credentials, session tokens, private keys, secret values, full environment dumps, instance metadata credentials, or unredacted sensitive console content. Public certificate properties are allowed; certificate private keys are not. Account and session identifiers in screenshots are redacted.

## Evidence matrix

| Component | Evidence | File or link | Status |
|---|---|---|---|
| VPC | AWS Console capture of the lab VPC | [`aws/02-vpc.png`](artifacts/aws/02-vpc.png) | Available |
| Public subnet | Subnet capture | [`aws/03-public-subnet.png`](artifacts/aws/03-public-subnet.png) | Available |
| Internet Gateway | IGW attached to the lab VPC | [`aws/04-internet-gateway.png`](artifacts/aws/04-internet-gateway.png) | Available |
| Routes | Route table with the default route | [`aws/05-route-table.png`](artifacts/aws/05-route-table.png) | Available |
| Security Group | Inbound/outbound rules | [`aws/06-security-group.png`](artifacts/aws/06-security-group.png) | Available |
| EC2 | Instance details | [`aws/01-ec2-instance.png`](artifacts/aws/01-ec2-instance.png) | Available |
| IAM role for SSM | Role used by Systems Manager | [`ssm/02-iam-ssm-role.png`](artifacts/ssm/02-iam-ssm-role.png) | Available |
| SSM managed node | Instance registered and online | [`ssm/01-managed-node.png`](artifacts/ssm/01-managed-node.png) | Available |
| Session Manager | Session to the instance | [`ssm/03-session-manager.png`](artifacts/ssm/03-session-manager.png) | Available |
| Nginx | Listeners on TCP 80/443 | [`web/01-nginx-ports.png`](artifacts/web/01-nginx-ports.png) | Available |
| External HTTP | PowerShell response from the EC2 public endpoint | [`web/02-http-external.png`](artifacts/web/02-http-external.png) | Available |
| External HTTPS | PowerShell response using `-k` (transport/connectivity evidence only) | [`web/03-https-external.png`](artifacts/web/03-https-external.png) | Available |
| Laboratory Root CA | Root CA creation | [`tls/01-root-ca.png`](artifacts/tls/01-root-ca.png) | Available |
| Server certificate | Certificate for `web.lab.test` issued by the laboratory Root CA | [`tls/02-server-cert-issued-by-root-ca.png`](artifacts/tls/02-server-cert-issued-by-root-ca.png) | Available |
| Certificate chain | `openssl verify` against the Root CA returns `OK` | [`tls/03-root-ca-verify.png`](artifacts/tls/03-root-ca-verify.png) | Available |
| Certificate SAN | `DNS:web.lab.test` | [`tls/04-server-cert-san.png`](artifacts/tls/04-server-cert-san.png) | Available |
| TLS 1.3 | Negotiated protocol | [`tls/05-tls13.png`](artifacts/tls/05-tls13.png) | Available |
| Nginx TLS configuration | HTTPS server block | [`tls/06-nginx-tls-config.png`](artifacts/tls/06-nginx-tls-config.png) | Available |
| GitHub Actions | Completed run for `Deploy website to EC2`; it verifies only the steps implemented by that workflow | [Run 37144567040](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/37144567040), commit `c83425515b175a0dc70bd9a6afd9e52b03933014` | Available |
| Local HTTP/HTTPS, service state, `nginx -t` | Collector output with exit statuses | Run [`scripts/collect-evidence.sh`](../scripts/collect-evidence.sh) on the server; results are transcribed in the verification document | Recorded |
| Versioned GitHub Actions deploy | Manual run showing the expected SHA over local and external HTTP/HTTPS, including any rollback result | `.github/workflows/deploy-versioned.yml` | Next stage |
| Terraform | Plan, outputs, live HTTP/HTTPS and SSM checks | `infra/terraform/` | [`artifacts/terraform/`](artifacts/terraform/) |

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
