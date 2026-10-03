# AWS DevOps Infrastructure Lab

Hands-on AWS/DevOps laboratory for a static website, Linux administration, networking, HTTPS/TLS, and deployment automation.

The repository separates what is inspectable in source code from operational results recorded during the lab and from future ideas. This distinction avoids treating documentation as infrastructure-as-code or as proof of the current live AWS state.

## Scope and evidence

| Category | Meaning in this project |
|---|---|
| Implemented in the repository | Files that can be inspected here: the static site and its GitHub Actions deployment workflow. |
| Recorded verification | Commands and results observed in the AWS/EC2 environment and transcribed in [Deployment and Verification](docs/03-deployment-and-verification.md). Raw screenshots and workflow logs are not stored in this repository. |
| Planned / not implemented | Ideas with no deployed component or implementation file in the repository. |

Documentation of an AWS result is a record of that verification, not a live check. The repository does not contain Terraform or other infrastructure-as-code from which the AWS environment can be recreated.

## Repository implementation

| Artifact | What it implements |
|---|---|
| `index.html` | Static portfolio page describing the lab. |
| `style.css` | Responsive presentation for the page, with no runtime dependency. |
| `.github/workflows/deploy.yml` | Deployment of `index.html` and `style.css` to an EC2 host over SSH. |

The workflow runs on relevant pushes to `main` or by manual dispatch. It:

1. reads the SSH key, host key, host, and user from GitHub Actions secrets;
2. creates a remote temporary directory and uploads the two website files with `scp`;
3. installs them under `/var/www/html`;
4. runs `nginx -t`, reloads Nginx, and requests `http://127.0.0.1/` with `curl -fsS`.

The final request checks that the local HTTP endpoint responds without an HTTP error. The workflow does **not** search the response for a specific phrase, and it does not validate the external endpoint, HTTPS, or the contents of `style.css`.

## Recorded environment

The following state is recorded from the lab's AWS and EC2 verification sessions:

| Area | Recorded state |
|---|---|
| Region and network | `us-east-2`; VPC `10.20.0.0/16`; public subnet `10.20.1.0/24`; Internet Gateway, public route, and Security Group |
| Compute | EC2 `lab-web-server` (`i-08f84a35805b6b66d`), `t3.micro`, Ubuntu Server 24.04 LTS |
| Administration | Key-based SSH and Systems Manager Session Manager; managed-node status recorded as `Online` with SSM Agent running |
| Web service | Nginx recorded as active, with successful configuration test and listeners on TCP 80 and 443 |
| Connectivity | HTTP and HTTPS `200 OK` responses recorded locally and from an external client |
| TLS | TLS 1.3; self-signed certificate for `web.lab.test` with matching CN/SAN |
| Delivery | A successful run of the GitHub Actions deployment is recorded in the verification document |

The public IPv4 used during testing is intentionally omitted because it is temporary instance state. Detailed commands and recorded outputs are kept in [Deployment and Verification](docs/03-deployment-and-verification.md).

## Documented architecture

```text
Internet
   |
Internet Gateway
   |
VPC 10.20.0.0/16
   |
Public Subnet A 10.20.1.0/24
   |
Security Group
   |
EC2 t3.micro / Ubuntu 24.04 LTS
   |-- SSH and Session Manager
   `-- Nginx
       |-- HTTP :80
       `-- HTTPS :443 / TLS 1.3
```

This diagram represents the environment recorded during verification; it is not generated from infrastructure code. See [AWS Infrastructure Architecture](docs/02-architecture.md) for boundaries and planned components.

## Planned or not implemented

The following components are not part of the documented deployment:

- additional public or private subnets and availability zones;
- NAT Gateway;
- Amazon RDS or another database layer;
- Load Balancer and Auto Scaling;
- ECS or EKS;
- Docker or Docker Compose;
- Terraform or another infrastructure-as-code implementation.

Ignore rules for Terraform state, variable files, credentials, keys, and certificates are preventive security controls; they do not indicate that Terraform is implemented.

## Security and cost notes

- No EC2 private key, AWS credential, password, token, workflow secret, or certificate private material should be committed.
- SSH should be restricted to the administrator's current public IP whenever practical. The present GitHub-hosted runner deployment also requires an allowed SSH path to the instance.
- The self-signed certificate is suitable for laboratory verification, not public production trust.
- Optional AWS services should be introduced only when they add a clear technical objective and their cost is understood.

## Repository structure

```text
.
|-- .github/workflows/deploy.yml
|-- docs/
|   |-- 02-architecture.md
|   `-- 03-deployment-and-verification.md
|-- .gitignore
|-- README.md
|-- index.html
`-- style.css
```

## Project status

The repository contains a complete static site and an SSH-based GitHub Actions deployment workflow. AWS networking, EC2, administration, Nginx, HTTP/HTTPS, TLS, and a successful automated deployment are documented as previously verified operational results. The live AWS state is not queried by this repository, and the environment is not reproducible from infrastructure-as-code.
