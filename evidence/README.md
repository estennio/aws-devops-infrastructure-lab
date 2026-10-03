# Evidence Index

## Evidence policy

This directory tracks verifiable artifacts for the AWS DevOps Infrastructure Lab. A statement in project documentation is not, by itself, a captured evidence artifact. Commands that have not been executed are procedures, not evidence.

Use these statuses:

- **Available:** a real artifact or public link is present and can be inspected;
- **Pending:** the required artifact has not been captured or added;
- **Review required:** an artifact exists locally but must be checked for sensitive content before it is committed.

Never include credentials, session tokens, private keys, secret values, full environment dumps, instance metadata credentials, or unredacted sensitive console content. Public certificate properties are allowed; certificate private keys are not.

## Evidence matrix

| Component | Required evidence | File or link | Status |
|---|---|---|---|
| VPC | Sanitized AWS Console capture or CLI JSON showing VPC ID, CIDR, Region, and state | No artifact committed | Pending |
| Public subnet | Sanitized capture or CLI JSON showing subnet ID, VPC association, CIDR, Availability Zone, and public-address behavior | No artifact committed | Pending |
| Internet Gateway | Sanitized capture or CLI JSON showing the IGW ID and attachment to the lab VPC | No artifact committed | Pending |
| Routes | Sanitized route-table capture or CLI JSON showing subnet association and `0.0.0.0/0` target | No artifact committed | Pending |
| Security Group | Sanitized inbound/outbound rule capture showing the group attached to EC2; redact unrelated addresses and descriptions when necessary | No artifact committed | Pending |
| EC2 | Sanitized instance capture or CLI JSON showing instance ID, type, state, subnet/VPC, OS image description, and attached IAM role | No artifact committed | Pending |
| IAM role for SSM | Sanitized instance-profile and role-policy evidence showing the permissions used by Systems Manager; no credentials or tokens | No artifact committed | Pending |
| Session Manager | Capture showing a real session to the instance, UTC time, session user, and a harmless command result | No artifact committed | Pending |
| Nginx | Collector output containing service state, `nginx -t`, and TCP 80/443 listeners | Run [`scripts/collect-evidence.sh`](../scripts/collect-evidence.sh); review the generated `evidence/artifacts/server-*.txt` | Pending |
| Local HTTP | Collector output containing the real response headers from `http://127.0.0.1/` | Same reviewed server artifact | Pending |
| External HTTP | PowerShell capture containing the real response from the EC2 public endpoint and UTC time | Add a reviewed `evidence/artifacts/external-*.txt` | Pending |
| Local HTTPS | Collector output from an HTTPS request using `-k`, explicitly treated as transport/connectivity evidence only | Same reviewed server artifact | Pending |
| External HTTPS | PowerShell capture with both an explicitly insecure `-k` test and a separate trust-validating test | Add a reviewed `evidence/artifacts/external-*.txt` | Pending |
| Certificate SAN | Collector output from `openssl x509 -noout -ext subjectAltName` showing `DNS:web.lab.test` | Same reviewed server artifact | Pending |
| TLS 1.3 | Collector output from a forced TLS 1.3 handshake showing the negotiated protocol | Same reviewed server artifact | Pending |
| GitHub Actions | Public completed run for `Deploy website to EC2`; the run verifies only the steps implemented by that workflow | [Run 37144567040](https://github.com/estennio/aws-devops-infrastructure-lab/actions/runs/37144567040), commit `c83425515b175a0dc70bd9a6afd9e52b03933014` | Available |
| Versioned GitHub Actions deploy | Completed manual run showing the expected SHA in local and external HTTP/HTTPS checks, including any rollback result | `.github/workflows/deploy-versioned.yml`; no run link is available | Pending |

The AWS and EC2 rows remain pending even though earlier results are described in `docs/03-deployment-and-verification.md`: no corresponding raw capture or exported artifact is currently committed.

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
4. add the reviewed path to the matrix and change only the supported rows to **Available**.

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

Do not use or copy the certificate private key for any client-side test. Capture the real command output and exit status before marking the corresponding matrix row as available.
