# Versioned Deployment and Rollback

## Overview

This flow adds SHA-addressed releases, atomic activation, validation, and rollback:

- `scripts/bootstrap.sh` creates the release layout on first boot, so every new instance is ready for deployments;
- `.github/workflows/deploy-ssm.yml` deploys releases through GitHub OIDC, S3 and SSM Run Command, with no SSH and no stored AWS key;
- the workflow reads the instance ID, public address and release bucket from SSM Parameter Store, where Terraform writes them;
- the workflow is manual and runs only after approval on the `production` environment; its runs are recorded in the [evidence index](../evidence/README.md#oidc-and-ssm-deployment-runs).

An earlier SSH-based version of this workflow (`deploy-versioned.yml`) used the same server scripts; it was removed once the SSM path had recorded runs.

## Release layout

Nginx serves the `current` symbolic link:

```text
/var/www/aws-devops-infrastructure-lab/
|-- current  -> releases/<active-version>
|-- previous -> releases/<previous-version>
|-- deploy.lock
`-- releases/
    |-- <commit SHA checked out at first boot>/
    |-- <40-character commit SHA>/
    |   |-- index.html
    |   |-- style.css
    |   `-- VERSION
    `-- ...
```

Each workflow release is prepared completely under `/tmp/aws-devops-site/<SHA>`, copied into a new immutable release directory, and only then activated. A temporary symbolic link is renamed over `current` with `mv -T`, making the switch atomic on the same filesystem. Successful activation updates `previous` without deleting either release.

The `VERSION` file contains exactly `${{ github.sha }}`. Local and external HTTP/HTTPS requests read that file and compare it with the workflow commit.

## Server preparation

There is no separate preparation step. On first boot, `user_data` runs `scripts/bootstrap.sh`, which creates the layout above, a first release from the checked-out commit, the `current` link, the versioned Nginx site and `/usr/local/sbin/aws-devops-versioned-deploy` (see [Server Bootstrap](03-server-bootstrap.md)). The deployment also needs:

- the instance registered as an `Online` SSM managed node, with the AWS CLI that the bootstrap installs;
- `terraform apply` completed, so the deploy targets exist in SSM Parameter Store;
- Security Group access for external TCP 80/443 validation from the runner.

The servers deployed before this change were migrated once with `scripts/prepare-versioned-deploy.sh`, which preserved the old `/var/www/html` site as a `legacy-<UTC timestamp>` release. That script was removed once the bootstrap created the layout itself; it remains in the Git history.

To check a server through Session Manager:

```bash
sudo nginx -t
sudo readlink -f /var/www/aws-devops-infrastructure-lab/current
curl --fail --silent --show-error \
  --resolve web.lab.test:80:127.0.0.1 \
  http://web.lab.test/VERSION
curl --insecure --fail --silent --show-error \
  --resolve web.lab.test:443:127.0.0.1 \
  https://web.lab.test/VERSION
```

The HTTPS command uses `--insecure` only to prove encrypted HTTPS transport with the self-signed laboratory certificate. It does **not** validate certificate trust. Trust validation requires a separately obtained and verified public certificate, for example with `curl --cacert web.lab.test.crt`; never copy the private key.

## Run the deployment

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

To test the rollback path on purpose, set the optional **validation_host** input to `127.0.0.1` when starting the workflow. The release still activates on the instance, but the external check from the runner fails, so the workflow requests the rollback. Leave the input empty for normal deployments.

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
