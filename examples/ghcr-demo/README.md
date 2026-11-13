# GHCR demo (separate from the m³ host installer)

This minimal Go HTTP service is a **CI/CD learning example**, not the Fedora workstation setup itself. It demonstrates multi-architecture container builds and GitHub Container Registry publishing without containerising or changing the host-level m³ installer.

## Run locally

```bash
cd examples/ghcr-demo
go test ./...
go run .
curl -fsS http://localhost:8080/health
```

## Container

```bash
docker build -t m3-ghcr-demo:local .
docker run --rm -p 8080:8080 m3-ghcr-demo:local
```

## Publishing

The workflow at `.github/workflows/ghcr-demo.yml` builds on pushes and pull requests. **Only pushes to `main` or a `demo-v*` tag publish** to GHCR. PRs build without publishing. The workflow uses the repository's `GITHUB_TOKEN` with `packages: write` permission; no personal access token is required.

After a successful publish, inspect the repository's **Packages** section. Package visibility may need to be set to public separately. The package name is `ghcr.io/arndthb/m3-devops-demo`.

## Kubernetes

```bash
kubectl create deployment m3-ghcr-demo --image=ghcr.io/arndthb/m3-devops-demo:main
kubectl expose deployment m3-ghcr-demo --port=8080
kubectl rollout status deployment/m3-ghcr-demo
```

If the image is private, Kubernetes requires image-pull credentials; do not assume public access until verified.
