# Blood Bank Management System

> *"Every Drop is Incomparable, Every Life is Priceless."*

A web application that helps users search for available blood, register as blood donors, and
request blood during emergencies. The project aims to simplify blood donation and improve
communication between donors and recipients.

The application itself is graded in the FSD Lab. This repository is graded on how the project is
**versioned, built, tested, packaged, deployed and monitored**.

## Developer

| Roll No. | Name | GitHub Username |
|----------|------|-----------------|
| 24ESKCS042 | Amisha Choudhary | amisha-2403 |

Course: DevOps Practices and Principles (CSUL511), B.Tech CSE Semester V, Session 2026.

## Live URL

**https://skit-devops-2026.github.io/devops-24ESKCS042/**

Deployed from this repository via GitHub Actions to GitHub Pages on every push to `main`.

## Tech Stack

- Frontend: HTML5, CSS3
- Backend: not implemented yet
- Database: not implemented yet
- Web server in the container: Nginx (Alpine)
- CI: GitHub Actions
- CD: GitHub Pages
- Container registry: GitHub Container Registry (GHCR)
- Orchestration: Kubernetes
- Monitoring: Prometheus

## Project Status

The landing page is complete and includes the blood group search form, the blood group
compatibility table, the emergency request section, and the "How BloodBank Works" walkthrough.
Backend and database work has not started.

## Project Structure

```
.
├── index.html                  # Application entry point
├── css/style.css               # Stylesheet
├── tests/test_project.sh       # Automated test suite
├── scripts/hygiene.sh          # Repository hygiene checks (M1)
├── Dockerfile                  # Container image definition
├── .dockerignore               # Keeps build context small
├── docker-compose.yml          # Local container orchestration
├── Jenkinsfile                 # Jenkins pipeline (M4)
├── Makefile                    # install / test / build entry points used by CI
├── k8s/                        # Kubernetes manifests (M7)
│   ├── deployment.yaml
│   └── service.yaml
├── monitoring/                 # Prometheus config and dashboard (M6)
│   ├── prometheus.yml
│   └── dashboard.md
└── docs/                       # Evidence and documentation (M6)
    ├── TESTING.md
    ├── DEPLOYMENT.md
    ├── DEPLOYMENT-SCREENSHOT.md
    └── DOCKER_SCENARIOS.md
```

## Running Locally

### Option 1 — Open directly

Open `index.html` in your browser. No installation required.

### Option 2 — With Docker

```bash
docker build -t bloodbank .
docker run -p 8081:80 --name bloodbank bloodbank
```

Then visit http://localhost:8081

### Option 3 — With Docker Compose

```bash
docker compose up --build
```

Then visit http://localhost:8081

## Testing

```bash
make test
```

The suite checks that the HTML entry point and stylesheet exist, that the document structure is
well formed, that the page is blood-bank specific, and that the stylesheet is linked correctly.
See [docs/TESTING.md](docs/TESTING.md).

The same suite is executed **inside the container image** by the CI pipeline, so the artefact that
ships is the artefact that is tested.

## CI/CD Pipeline

`.github/workflows/ci.yml` runs on every push and pull request and performs:

1. **Repository hygiene** — placeholder, oversized-file, secret and commit-message checks.
2. **Build and test** — `make install`, `make test`, `make build`.
3. **Container build, test and publish** — builds the image, runs the test suite inside the
   container, tags it with the commit SHA, and pushes it to GHCR.

Images are tagged by commit SHA rather than `latest`, so every build is traceable to the exact
code that produced it.

## Container Image

Published at:

```
ghcr.io/skit-devops-2026/bloodbank:<commit-sha>
```

Pull it with:

```bash
docker pull ghcr.io/skit-devops-2026/bloodbank:<commit-sha>
```

## Kubernetes

Manifests live in [`k8s/`](k8s/). A local cluster can be started with `kind` or `k3d` (both run
inside Docker) rather than minikube, since the image is already available locally after M5.

```bash
kind create cluster
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods
```

## Monitoring

[`monitoring/prometheus.yml`](monitoring/prometheus.yml) scrapes the application every 15
seconds. [`monitoring/dashboard.md`](monitoring/dashboard.md) records what is monitored and the
health-check procedure.

## Repository Conventions

- `main` is protected by convention: work lands through a pull request with a written description
  of what changed, rather than by direct push.
- Course reference material (`*.pdf`) is intentionally not tracked.
- Secrets are never committed. `.env.example` documents the expected variables.
