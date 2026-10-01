# Docker workshop demos

Every demo is one script. It prints a "what to say" hint, shows the command, **waits for Enter**, then runs it.
`DEMO_AUTO=1 ./demo1.sh` skips the pauses (for testing). Scripts are idempotent: they remove their own leftovers first.

## Run order

**Tonight (with wifi, once):**
1. `./prep.sh`: pulls images, pre-builds, warms the Trivy cache, prints a PASS/FAIL checklist.
2. `DEMO_AUTO=1 ./demo1.sh` ... `demo4-k8s.sh` to rehearse (optional).
3. `./demo5-break.sh`: pushes a failing branch; screenshot the red run on GitHub.
4. `./cleanup.sh`

**Tomorrow:** `./demo1.sh`, `./demo2.sh`, `./demo3.sh`, `./demo4-k8s.sh` (or `./demo4-swarm.sh`), `./demo5.sh` (needs wifi). Run `./cleanup.sh` between rehearsals.

> Do **not** run `docker system prune` or `docker builder prune` after prep. They delete the build cache, and demos 1 and 2 then need the internet to rebuild.

## Versions used (update your slides)

| Thing | Version |
|---|---|
| Go | **1.27.1** (`golang:1.27.1`, `golang:1.27.1-alpine`) |
| Node (Active LTS "Krypton") | **24.21.0** (`node:24.21.0-alpine`). Node 26 is "Current", not LTS yet. |
| nginx | **1.30.5-alpine** (stable); **1.31.6-alpine** (mainline, the "new version" in updates) |
| Alpine | **3.23** |
| Trivy | **0.74.0** (`aquasec/trivy:0.74.0`) |
| distroless | `gcr.io/distroless/static-debian13:nonroot` (rolling tag, no semver exists) |
| Intentionally unpinned | `node:latest`, in `Dockerfile.bad` only (that's the point) |
| GitHub Actions | checkout v7, setup-buildx v4, login v4, build-push v7, trivy-action v0.36.0 |

Verified 2026-10-01. Express 5 and TypeScript 7 come from `2-security/package-lock.json`.

## Demo 1: multi-stage builds (`demo1.sh`, port 8081)
Same Go app, 1.43 GB fat image vs ~14 MB distroless image with no shell.
`docker exec ... sh` **fails on purpose**.
- *Port in use:* `docker rm -f ws-thin` or `./cleanup.sh`.
- *Name in use:* the script removes `ws-thin` itself; if it still complains, `./cleanup.sh`.
- *Wifi down, build fails:* run `./prep.sh` once with wifi; the build cache covers it.

## Demo 2: container security (`demo2.sh`, ports 8082, 8083)
Bad vs good image: root user, secret in `ENV`, `.env` copied in, Trivy HIGH/CRITICAL counts (≈372 vs ≈7), `--read-only`, `--memory/--cpus`, healthcheck.
`2-security/.env` holds fake values and is created by `prep.sh` (git-ignored).
- *Trivy tries to download the DB:* run `./prep.sh` once. The cache lives in `~/.cache/trivy`.
- *`(healthy)` not showing yet:* wait about 5 seconds and re-run `docker ps`.
- *Port in use:* `./cleanup.sh`.

## Demo 3: restart policy and health (`demo3.sh`)
`--restart=on-failure:5` revives an exiting container; a failing health check only marks it `(unhealthy)`. Docker does nothing about it.
- *Name in use:* `docker rm -f ws-crash ws-sick`.

## Demo 4: orchestration (`demo4-k8s.sh` or `demo4-swarm.sh`, ports 8090 / 8091)
Self-healing, scale to 10, rolling update, rollback.
- *K8s not starting:* Docker Desktop > Settings > Kubernetes > Enable > Apply & restart, wait for the green icon, then `kubectl config use-context docker-desktop`. Still stuck? Use `./demo4-swarm.sh`; same story.
- *Port 8090 in use:* `kubectl delete -f 4-orchestration/k8s`.
- *Swarm "already part of a swarm":* the script detects this and skips init. It leaves the swarm at the end.
- *Swarm updates take about 30 s each* (Docker verifies stability). Talk over it.
- *Offline:* swarm uses `--no-resolve-image`; k8s uses `imagePullPolicy: IfNotPresent`.

## Demo 5: CI/CD (`demo5.sh`, `demo5-break.sh`)
`.github/workflows/docker.yml` runs `go test` inside the builder-stage image, builds the thin image, gates on a Trivy CRITICAL scan, and pushes to `ghcr.io/<owner>/<repo>` (lowercased) **only on main**.
- `demo5.sh` appends to `VERSION`, commits, pushes to main, opens the Actions page.
- `demo5-break.sh` pushes branch `demo-fail` with a failing test, then returns to main.
- *Push rejected / auth:* check `git remote -v` and that you're logged in (`gh auth status`).
- *Needs wifi.* Have the screenshot from tonight as a backup.
- First push of the package to GHCR may need the package set to the repo's visibility in GitHub settings.

## Layout
```
lib.sh  prep.sh  cleanup.sh  demo1.sh demo2.sh demo3.sh demo4-k8s.sh demo4-swarm.sh demo5.sh demo5-break.sh
1-multistage/   Go app, Dockerfile.fat, Dockerfile.thin
2-security/     Express + TypeScript, Dockerfile.bad / .good
4-orchestration/k8s/   deployment.yaml, service.yaml
.github/workflows/docker.yml
```
