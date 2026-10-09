# Server Bootstrap

## Scope

`scripts/bootstrap.sh` and `configs/nginx/web.lab.test.conf` provide a reproducible server configuration for Ubuntu Server 24.04 LTS, prepared from the laboratory's documented procedures and paths.

They describe how to build the server again; they are not an export of the running EC2 instance.

The script does not create or modify AWS resources, Security Groups, IAM permissions, DNS, GitHub secrets, or the GitHub Actions workflow.

## Requirements

- Ubuntu Server 24.04 LTS with `systemd`;
- root access through `sudo`;
- network access to Ubuntu package repositories;
- the complete repository checkout, including `index.html` and `style.css`;
- inbound TCP 80 and 443 allowed outside the script if external access is required;
- local name resolution for `web.lab.test` when testing by hostname.

Run from anywhere inside the checked-out repository with:

```bash
sudo bash scripts/bootstrap.sh
```

The script must run as root because it installs packages, writes under `/etc/nginx` and `/var/www`, changes file ownership and permissions, and controls the Nginx systemd service. The file may also be marked executable and invoked with `sudo ./scripts/bootstrap.sh`.

## Actions performed

The bootstrap:

1. installs `nginx`, `openssl`, `curl`, and `ca-certificates` with `apt`;
2. creates `/var/www/html` and publishes `index.html` and `style.css` there;
3. creates `/etc/nginx/ssl/web.lab.test` with mode `0750`;
4. generates a 2048-bit RSA, SHA-256, self-signed certificate valid for 365 days only when both certificate files are absent;
5. sets the certificate CN to `web.lab.test` and its SAN to `DNS:web.lab.test`;
6. installs the versioned site configuration in `/etc/nginx/sites-available/web.lab.test.conf`;
7. enables it with a single symlink in `/etc/nginx/sites-enabled` and removes Ubuntu's default enabled-site symlink;
8. runs `nginx -t` before reloading an active service or starting an inactive one.

HTTP and HTTPS both serve `/var/www/html`. TLS 1.2 and TLS 1.3 are enabled; TLS 1.3 is therefore supported without excluding compatible TLS 1.2 clients.

## Certificate and repeat execution behavior

The private key is generated only on the server at:

```text
/etc/nginx/ssl/web.lab.test/web.lab.test.key
```

It is owned by `root:root` with mode `0600`. The certificate is stored beside it with mode `0644`. Both extensions are ignored by this repository, and neither file should be copied back into source control.

On later runs, the script preserves an existing certificate and key. Before reusing them, it verifies that:

- both files exist;
- OpenSSL can read both files;
- the certificate is not expired;
- the CN is `web.lab.test`;
- the SAN contains `DNS:web.lab.test`;
- the certificate and private key match.

If a check fails, the script stops without overwriting either file. Certificate rotation must be deliberate: back up or remove the existing pair on the server, then run the bootstrap again. Other installed files converge to the versioned content, and the enabled-site symlink is reused rather than duplicated.

## Compatibility with automated deployment

The existing workflow uploads only `index.html` and `style.css`, installs them in `/var/www/html`, executes `nginx -t`, reloads Nginx, and requests `http://127.0.0.1/`.

This configuration preserves that web root and serves HTTP directly, so the workflow's deployment steps do not need to change. Changes limited to `configs/`, `scripts/`, or `docs/` do not match the workflow's current push path filters.

The optional versioned deployment uses a different document root and requires a deliberate migration after this bootstrap. It is documented separately in [Versioned Deployment and Rollback](04-versioned-deployment.md). Until that migration is performed, `.github/workflows/deploy.yml` is the compatible deployment path and the versioned workflow is not dispatched.

## Verification on the server

After execution, verify locally:

```bash
sudo nginx -t
sudo systemctl is-active nginx
curl -fsSI http://127.0.0.1/
curl -kfsSI --resolve web.lab.test:443:127.0.0.1 https://web.lab.test/
openssl s_client -connect 127.0.0.1:443 -servername web.lab.test -tls1_3 </dev/null
openssl x509 -in /etc/nginx/ssl/web.lab.test/web.lab.test.crt -noout -subject -dates -ext subjectAltName
```

Also confirm ownership and permissions without displaying private-key contents:

```bash
sudo stat -c '%U:%G %a %n' \
  /etc/nginx/ssl/web.lab.test \
  /etc/nginx/ssl/web.lab.test/web.lab.test.key \
  /etc/nginx/ssl/web.lab.test/web.lab.test.crt
```

External HTTP and HTTPS checks additionally require the Security Group rules for TCP 80/443 and, for hostname tests, name resolution for `web.lab.test`.
