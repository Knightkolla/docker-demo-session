#!/usr/bin/env bash
# Remove everything the demos create. Keeps pulled base images, build cache and the Trivy
# cache so tomorrow still works offline. Pass --deep to also drop the pulled base images.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
need_docker

note "Containers..."
run "docker rm -f ws-thin ws-bad ws-good ws-limited ws-crash ws-sick"
run "docker rm -f \$(docker ps -aq --filter name=ws-)"

note "Swarm..."
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" = "active" ]; then
  run "docker service rm ws-svc"
  run "docker swarm leave --force"
fi

note "Kubernetes..."
if [ "$(kubectl config current-context 2>/dev/null)" = "docker-desktop" ]; then
  run "kubectl delete -f '$ROOT/4-orchestration/k8s' --ignore-not-found"
fi

note "Images..."
run "docker rmi -f ws-fat ws-thin ws-bad ws-good"

if [ "$1" = "--deep" ]; then
  note "Base images (--deep)..."
  run "docker rmi -f golang:$GO_VERSION golang:$GO_VERSION-alpine $DISTROLESS node:$NODE_VERSION-alpine $NODE_LATEST alpine:$ALPINE_VERSION nginx:$NGINX_A nginx:$NGINX_B aquasec/trivy:$TRIVY_VERSION"
fi

run "rm -f '$ROOT/2-security/.env'"
note "Clean. (Local branch demo-fail and VERSION commits are git history; not touched.)"
