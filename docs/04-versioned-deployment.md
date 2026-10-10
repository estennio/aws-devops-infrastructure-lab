# Versioned Deployment and Rollback

## Overview

This flow adds SHA-addressed releases, atomic activation, validation, and rollback. It is delivered as repository code and is applied to EC2 through the one-time preparation below:

- `.github/workflows/deploy-ssm.yml` deploys releases through GitHub OIDC, S3 and SSM Run Command, with no SSH and no stored AWS key;
- the workflow is manual and runs only after approval on the `production` environment;
- the EC2 migration is done on the current instance, and the workflow's runs are recorded in the [evidence index](../evidence/README.md#oidc-and-ssm-deployment-runs).

An earlier SSH-based version of this workflow (`deploy-versioned.yml`) used the same server scripts; it was removed once the SSM path had recorded runs.

## Release layout

After migration, Nginx serves the `current` symbolic link:

```text
/var/www/aws-devops-infrastructure-lab/
|-- current  -> releases/<active-version>
|-- previous -> releases/<previous-version>
|-- deploy.lock
`-- releases/
    |-- legacy-<UTC timestamp>/
    |-- <40-character commit SHA>/
    |   |-- index.html
    |   |-- style.css
    |   `-- VERSION
    `-- ...
```

Each workflow release is prepared completely under `/tmp/aws-devops-site/<SHA>`, copied into a new immutable release directory, and only then activated. A temporary symbolic link is renamed over `current` with `mv -T`, making the switch atomic on the same filesystem. Successful activation updates `previous` without deleting either release.

The `VERSION` file contains exactly `${{ github.sha }}`. Local and external HTTP/HTTPS requests read that file and compare it with the workflow commit.

## EC2 prerequisites

Preparation expects Ubuntu 24.04 LTS with the repository's Nginx configuration already active:

- Nginx, curl, `flock`, sudo, and `visudo` available;
- `/var/www/html/index.html` and `/var/www/html/style.css` present;
- `/etc/nginx/sites-enabled/web.lab.test.conf` linking to `/etc/nginx/sites-available/web.lab.test.conf`;
- the active site file exactly matching `configs/nginx/web.lab.test.conf`, or already matching the versioned configuration;
- the existing certificate and private key at `/etc/nginx/ssl/web.lab.test/`;
- the instance registered as an `Online` SSM managed node, with the AWS CLI installed by `scripts/bootstrap.sh`;
- Security Group access for external TCP 80/443 validation from the runner.

These conditions are checked rather than assumed. A different active Nginx layout causes the preparation script to stop so an operator can reconcile it deliberately.

## Prepare the server

On the EC2 instance, check out a reviewed commit containing this flow, inspect the scripts, and run:

```bash
cd /opt/aws-devops-infrastructure-lab
sudo bash scripts/prepare-versioned-deploy.sh "$USER"
```

The preparation script:

1. runs `nginx -t` against the current configuration;
2. preserves the current site as `releases/legacy-<UTC timestamp>` and creates `current`;
3. installs `scripts/versioned-deploy.sh` as `/usr/local/sbin/aws-devops-versioned-deploy`;
4. grants the named deployment user passwordless sudo only for that installed command, whose arguments are validated;
5. backs up the legacy site file as `/etc/nginx/sites-available/web.lab.test.conf.pre-versioned`;
6. installs the versioned Nginx configuration, runs `nginx -t`, and reloads Nginx;
7. confirms the initial `VERSION` through local HTTP and HTTPS transport requests.

`systemctl reload nginx` returns before the old workers exit, so the final check retries for up to 10 seconds; an immediate single check returned a 404 from a worker still serving `/var/www/html`. If the new Nginx configuration or the final HTTP/HTTPS checks still fail, the script restores and reloads the legacy configuration. It leaves the copied release and installed command available for inspection; it does not delete the original `/var/www/html` files.

Verify the preparation before enabling the workflow:

```bash
sudo nginx -t
sudo readlink -f /var/www/aws-devops-infrastructure-lab/current
curl --fail --silent --show-error \
  --resolve web.lab.test:80:127.0.0.1 \
  http://web.lab.test/VERSION
curl --insecure --fail --silent --show-error \
  --resolve web.lab.test:443:127.0.0.1 \
  https://web.lab.test/VERSION
sudo visudo -cf /etc/sudoers.d/aws-devops-versioned-deploy
```

The HTTPS command uses `--insecure` only to prove encrypted HTTPS transport with the self-signed laboratory certificate. It does **not** validate certificate trust. Trust validation requires a separately obtained and verified public certificate, for example with `curl --cacert web.lab.test.crt`; never copy the private key.

## Run the deployment

Only after the preparation and checks succeed:

1. open GitHub Actions and select **Deploy versioned website via SSM**;
2. use **Run workflow** on `main`, then approve the `production` deployment;
3. confirm that the run reports the expected 40-character SHA for HTTP and HTTPS.

The workflow has no push trigger and uses a concurrency group with `cancel-in-progress: false`, so a newer dispatch cannot overlap or cancel an active deployment.

## Validation and automatic rollback

The server-side command validates all of the following after the atomic switch:

- `nginx -t` before reload;
- `index.html` and `style.css` over local HTTP;
- `index.html` and `style.css` over local HTTPS transport;
- `VERSION` over both protocols equals the requested commit SHA.

The runner repeats `index.html`, `style.css`, and `VERSION` requests externally over HTTP and HTTPS. HTTPS uses `--insecure` and is explicitly reported as transport validation, not certificate-trust validation.

If local validation fails, the server command restores `current` to the prior release, tests Nginx, reloads, validates the restored version, and returns failure. If external validation fails, the runner requests the same guarded rollback and fails the job. The rollback refuses to proceed unless the currently served `VERSION` is the failed workflow SHA, preventing it from replacing an unrelated newer version.

## Manual rollback

Find and review the active and previous versions without displaying secrets:

```bash
sudo cat /var/www/aws-devops-infrastructure-lab/current/VERSION
sudo cat /var/www/aws-devops-infrastructure-lab/previous/VERSION
```

Then provide the exact currently served 40-character SHA:

```bash
sudo /usr/local/sbin/aws-devops-versioned-deploy rollback <current-commit-sha>
```

The command atomically exchanges `current` and `previous`, runs `nginx -t` before reload, and validates HTTP, HTTPS transport, and the restored `VERSION`. If rollback validation itself fails, it attempts to restore the release that was active when the command began.

## Restore the legacy layout

This is a separate migration rollback, not an application-release rollback. Review the backup first, then restore it deliberately:

```bash
sudo install -o root -g root -m 0644 \
  /etc/nginx/sites-available/web.lab.test.conf.pre-versioned \
  /etc/nginx/sites-available/web.lab.test.conf
sudo nginx -t
sudo systemctl reload nginx
curl --fail --silent --show-error http://127.0.0.1/ > /dev/null
```

The original `/var/www/html` content is intentionally retained for this recovery path.
