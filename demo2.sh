#!/usr/bin/env bash
# Demo 2: container security, bad vs good image
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
need_docker
cd "$ROOT/2-security"
[ -f .env ] || make_env

run "docker rm -f ws-good ws-limited"
run "docker rmi -f ws-bad ws-good"

header "Demo 2: container security"
step "Two Dockerfiles, same app. One is full of mistakes." "cat Dockerfile.bad"
step "The good one." "cat Dockerfile.good"

header "1. Build both"
step "Build the bad image." "docker build -f Dockerfile.bad -t ws-bad ."
step "Build the good image." "docker build -f Dockerfile.good -t ws-good ."

header "Issue 1: running as root"
step "Bad: root. If the app is compromised, so is the container." "docker run --rm ws-bad whoami"
step "Good: the unprivileged node user." "docker run --rm ws-good whoami"

header "Issue 2: secret baked into the image"
step "Anyone with the image can read ENV lines from its history." "docker history --no-trunc ws-bad | grep DB_PASSWORD"

header "Issue 3: .env copied into the image"
step "Bad: COPY . . dragged the .env file in." "docker run --rm ws-bad cat .env"
step "Good: .dockerignore kept it out (this fails, as intended)." "docker run --rm ws-good cat .env"

header "Issue 4: vulnerability scan (HIGH and CRITICAL only)"
step "Trivy, run as a container with a warm local cache. Bad image count:" "$TRIVY_RUN --severity HIGH,CRITICAL --format json ws-bad | grep -cE '\"Severity\": \"(HIGH|CRITICAL)\"' | sed 's/^/ws-bad  HIGH+CRITICAL findings: /'"
step "Good image count:" "$TRIVY_RUN --severity HIGH,CRITICAL --format json ws-good | grep -cE '\"Severity\": \"(HIGH|CRITICAL)\"' | sed 's/^/ws-good HIGH+CRITICAL findings: /'"

header "Issue 5: writable filesystem"
step "Normally a process can write anywhere." "docker run --rm ws-good touch /tmp/hack && echo 'write succeeded'"
step "Read-only root filesystem: the write is blocked." "docker run --rm --read-only ws-good touch /tmp/hack"
step "Read-only, but with a scratch tmpfs for /tmp: works again." "docker run --rm --read-only --tmpfs /tmp ws-good touch /tmp/hack && echo 'write succeeded'"

header "Issue 6: no resource limits"
step "Cap memory and CPU so one container cannot starve the host." "docker run -d --name ws-limited --memory=512m --cpus=1 -p 8083:3000 ws-good"
wait_for "ws-limited" 15 "curl -fs localhost:8083"
step "Note the 512MiB limit." "docker stats --no-stream ws-limited"

header "Run the good image for real"
step "Healthcheck from the Dockerfile marks it healthy." "docker run -d --name ws-good -p 8082:3000 ws-good"
wait_for "ws-good healthy" 40 "docker ps --filter name=ws-good --filter health=healthy | grep -q ws-good"
step "Look for (healthy)." "docker ps --filter name=ws-good"
