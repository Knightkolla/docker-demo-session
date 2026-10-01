#!/usr/bin/env bash
# Run once tonight, with wifi. Pulls and pre-builds everything so the demos work offline.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
cd "$ROOT"
declare -a RESULTS

record() { # record "name" exit_code
  if [ "$2" -eq 0 ]; then RESULTS+=("${C_OK}PASS${C_RESET}  $1"); else RESULTS+=("${C_BAD}FAIL${C_RESET}  $1"); fi
}

header "Docker"
need_docker
docker version --format 'Docker engine {{.Server.Version}} ({{.Server.Arch}})'
docker compose version 2>/dev/null | head -1
kubectl version --client 2>/dev/null | head -1
echo "Free disk: $(df -h / | awk 'NR==2{print $4}')  (expect ~3GB of images)"

header "Pulling images"
IMAGES="golang:$GO_VERSION golang:$GO_VERSION-alpine $DISTROLESS
node:$NODE_VERSION-alpine $NODE_LATEST
alpine:$ALPINE_VERSION nginx:$NGINX_A nginx:$NGINX_B
aquasec/trivy:$TRIVY_VERSION"
PULL_FAIL=0
for img in $IMAGES; do
  echo "pull $img"
  docker pull -q "$img" >/dev/null || { warn "  FAILED: $img"; PULL_FAIL=1; }
done
record "all images pulled" $PULL_FAIL

header "Demo 2 fake secrets"
make_env && note "created 2-security/.env"

header "Pre-building images (fills the build cache so demos build offline)"
(cd 1-multistage && docker build -q -f Dockerfile.fat -t ws-fat . >/dev/null && docker build -q -f Dockerfile.thin -t ws-thin . >/dev/null)
D1=$?
(cd 2-security && docker build -q -f Dockerfile.bad -t ws-bad . >/dev/null && docker build -q -f Dockerfile.good -t ws-good . >/dev/null)
D2B=$?

header "Warming the Trivy cache ($TRIVY_CACHE)"
mkdir -p "$TRIVY_CACHE"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$TRIVY_CACHE":/root/.cache/ \
  aquasec/trivy:$TRIVY_VERSION image --scanners vuln --severity HIGH,CRITICAL --quiet --format json ws-good >/dev/null
TRIVY_WARM=$?
# prove it now works with updates disabled, exactly as on stage
eval "$TRIVY_RUN --severity HIGH,CRITICAL --format json ws-good" >/dev/null 2>&1
TRIVY_OFFLINE=$?

header "Kubernetes"
K8S=1
if [ "$(kubectl config current-context 2>/dev/null)" = "docker-desktop" ] && kubectl get nodes >/dev/null 2>&1; then
  K8S=0; note "Kubernetes on docker-desktop is up."
else
  warn "Kubernetes is not enabled/ready. To enable it:"
  echo "  Docker Desktop > Settings > Kubernetes > Enable Kubernetes > Apply & restart"
  echo "  then: kubectl config use-context docker-desktop"
  echo "  (or just use ./demo4-swarm.sh)"
fi

img() { docker image inspect "$@" >/dev/null 2>&1; }
record "demo1  multistage (images built)"        $D1
record "demo2  security (images, trivy offline)" $(( D2B + TRIVY_WARM + TRIVY_OFFLINE ))
img alpine:$ALPINE_VERSION nginx:$NGINX_A; record "demo3  health (alpine + nginx present)" $?
img nginx:$NGINX_A nginx:$NGINX_B;        record "demo4  swarm (nginx images present)" $?
record "demo4  kubernetes (docker-desktop ready)" $K8S

header "Checklist"
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
echo "Reminder: don't run 'docker system prune' or 'docker builder prune' before the talk; they wipe the offline cache."
echo "Demo 5 needs wifi + git push access to GitHub."
