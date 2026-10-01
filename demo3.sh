#!/usr/bin/env bash
# Demo 3: restart policies and health checks
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
need_docker

run "docker rm -f ws-crash ws-sick"

header "Demo 3: restart policy"
step "A container that crashes after 3s, with a restart policy of 5 retries." \
  "docker run -d --name ws-crash --restart=on-failure:5 alpine:$ALPINE_VERSION sh -c 'sleep 3; exit 1'"
step "Watch RestartCount climb. Docker revives it, but only because it EXITED." \
  'for i in 1 2 3 4 5 6; do docker inspect -f "RestartCount={{.RestartCount}}  status={{.State.Status}}" ws-crash; sleep 3; done'

header "Demo 3: Up is not the same as healthy"
step "nginx is running fine, but we tell Docker its health check always fails." \
  "docker run -d --name ws-sick --health-cmd='exit 1' --health-interval=3s --health-retries=2 nginx:$NGINX_A"
step "Poll until Docker flags it." \
  'for i in 1 2 3 4 5 6 7 8 9 10; do docker ps --filter name=ws-sick --format "{{.Names}}  {{.Status}}"; docker ps --filter name=ws-sick --filter health=unhealthy | grep -q ws-sick && break; sleep 3; done'
note "Docker knows it's sick and does nothing."
say "Plain Docker only restarts on exit. An orchestrator acts on health: that's the next demo."
