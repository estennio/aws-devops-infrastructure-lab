# Evidence artifacts

Place only reviewed, non-sensitive evidence files in these folders.

```text
evidence/artifacts/
├── aws/
│   ├── 01-ec2-instance.png
│   ├── 02-vpc.png
│   ├── 03-public-subnet.png
│   ├── 04-internet-gateway.png
│   ├── 05-route-table.png
│   └── 06-security-group.png
├── ssm/
│   ├── 01-managed-node.png
│   ├── 02-iam-ssm-role.png
│   └── 03-session-manager.png
├── web/
│   ├── 01-nginx-ports.png
│   ├── 02-http-external.png
│   └── 03-https-external.png
├── tls/
│   ├── 01-certificate-san.png
│   ├── 02-root-ca.png
│   ├── 03-root-ca-verify.png
│   ├── 04-tls13.png
│   └── 05-nginx-tls-config.png
└── deployment/
    └── optional screenshots or exported logs
```

Before adding an image, review it for account IDs, public IPs you do not want published, personal location details, credentials, tokens, private keys, or unrelated information.

Do not mark a row in `evidence/README.md` as **Available** until the corresponding artifact has actually been added and reviewed.
