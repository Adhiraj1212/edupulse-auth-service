# EduPulse Auth Service (`edupulse-auth-service`)

> 📖 **Full System Deployment Handbook:**  
> For complete end-to-end setup instructions, AWS keyless architecture (OIDC & SSM), and zero-SSH deployment steps for the entire EduPulse stack, read the [**EduPulse DevSecOps & GitOps Handbook**](docs/EDUPULSE_DEVOPS_HANDBOOK.md) (or view on [GitHub](https://github.com/Adhiraj1212/edupulse-platform/blob/main/docs/EDUPULSE_DEVOPS_HANDBOOK.md)).

Authentication and Session Management Microservice for the EduPulse System.

---

## EduPulse Multi-Repo Ecosystem

| Repository | Purpose | Tech / Ports |
| :--- | :--- | :--- |
| [**`edupulse-platform`**](https://github.com/Adhiraj1212/edupulse-platform) | GitOps Infrastructure, Data Tier & Handbook | MySQL (3306), Redis (6379), RabbitMQ (5672) |
| [**`edupulse-frontend`**](https://github.com/Adhiraj1212/edupulse-frontend) | Web UI & Nginx Reverse Proxy | Port 80 (public) -> 8080 (container) |
| [**`edupulse-backend`**](https://github.com/Adhiraj1212/edupulse-backend) | Student Management REST API | Port 5000 (Node.js 22) |
| [**`edupulse-auth-service`**](https://github.com/Adhiraj1212/edupulse-auth-service) *(this repo)* | Session Auth & Rate Limiting | Port 4000 (Node.js 22) |
| [**`edupulse-audit-service`**](https://github.com/Adhiraj1212/edupulse-audit-service) | Event Consumer & Audit Logging | Port 6000 (Node.js 22) |

---

## Architecture

* **Runtime:** Node.js 22 (runs as non-root user `node` on port `4000`).
* **Session Store:** Redis 7 (stores ephemeral sessions with TTL).
* **Security Controls:**
  - Brute-force rate limiting and lockout counters.
  - HttpOnly secure session cookies.
  - Verification endpoint `/auth/verify` consumed by Nginx reverse proxy `auth_request`.
* **Event Publishing:** Emits audit and login telemetry to RabbitMQ.
* **Health Check:** `GET /healthz` returns `200 OK`.

---

## DevSecOps CI/CD Pipeline

Every push to `main` triggers `.github/workflows/ci-cd.yml`:
1. **Secret Scanning:** `gitleaks` checks for hardcoded tokens and credentials.
2. **SCA & Dependency Vulnerability Gate:** `npm audit --omit=dev --audit-level=high` fails on high-risk dependencies.
3. **SAST Syntax & Linting:** `node --check` validates JavaScript files.
4. **Dockerfile Linting:** `hadolint` verifies container security standards.
5. **Vulnerability Scanning:** Aqua `trivy` (v0.36.0) scans for OS and package vulnerabilities.
6. **CycloneDX SBOM:** Generated and preserved as an audit artifact.
7. **Container Registry:** Builds and pushes lowercase image tags to GitHub Container Registry (`ghcr.io`).
8. **Keyless AWS SSM Deployment:** Assumes AWS IAM Role via OIDC and triggers a zero-downtime rolling update on EC2 using AWS Systems Manager Run Command (strictly **no SSH keys**).

---

## Required GitHub Actions Variables

To deploy this service from GitHub Actions, configure the following under **Settings** -> **Secrets and variables** -> **Actions** -> **Variables**:

| Variable | Description | Example |
|---|---|---|
| `AWS_ROLE_ARN` | IAM Role ARN with SSM permissions | `arn:aws:iam::<ACCOUNT_ID>:role/GitHubActions-devops-ec2ssm-role` |
| `INSTANCE_ID` | Target EC2 Instance ID | `i-0123456789abcdef0` |
| `AWS_REGION` | AWS Region | `eu-north-1` |

---

## Local Development

```bash
npm install
npm start
```
