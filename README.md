# EduPulse Auth Service (`edupulse-auth-service`)

Authentication and Session Management Microservice for the EduPulse System.

## Architecture

* **Runtime:** Node.js 22 (runs non-root on port `4000`).
* **Session Store:** Redis 7 (stores ephemeral sessions with TTL).
* **Security Controls:**
  - Brute-force rate limiting and lockout counters.
  - HttpOnly secure session cookies.
  - Verification endpoint `/auth/verify` consumed by Nginx reverse proxy `auth_request`.
* **Event Publishing:** Emits audit and login telemetry to RabbitMQ.
* **Health Check:** `GET /health` returns `200 OK`.

## DevSecOps Pipeline

1. **Secret Scanning:** `gitleaks` checks for hardcoded tokens and credentials.
2. **SCA & Dependency Vulnerability Gate:** `npm audit --omit=dev --audit-level=high` fails on high-risk dependencies.
3. **SAST Syntax & Linting:** `node --check` validates JavaScript files.
4. **Dockerfile Linting:** `hadolint` verifies container security standards.
5. **Vulnerability Scanning:** Aqua `trivy` scans for OS and package vulnerabilities.
6. **CycloneDX SBOM:** Generated and preserved as an audit artifact.
7. **Container Signing:** Signed with Sigstore `cosign` using GitHub OIDC.
8. **Deployment:** Pushes to Amazon ECR and updates the ECS Fargate `auth-service`.

## Required Environment Variables

| Variable | Description |
|---|---|
| `REDIS_URL` | Redis connection URL (`redis://...:6379`) |
| `REDIS_PASSWORD` | Injected via AWS Secrets Manager |
| `RABBITMQ_URL` | AMQP URL with credentials |
| `ADMIN_USER` | Administrator username |
| `ADMIN_PASSWORD` | Injected via AWS Secrets Manager |
| `STUDENT_USER` | Student username |
| `STUDENT_PASSWORD` | Injected via AWS Secrets Manager |
| `COOKIE_SECURE` | Set to `true` in production (HTTPS) |

## Local Development

```bash
npm install
npm start
```
