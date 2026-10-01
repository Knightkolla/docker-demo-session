#!/usr/bin/env bash
# Demo 4 (Swarm fallback): same story as the Kubernetes demo
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
need_docker

run "docker service rm ws-svc"

header "Demo 4: Docker Swarm"
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" = "active" ]; then
  note "Swarm already active, skipping init."
else
  step "Turn this Docker engine into a one-node swarm." "docker swarm init"
fi
step "3 replicas on 8091. (--no-resolve-image so it works offline.)" "docker service create --no-resolve-image --name ws-svc --replicas 3 -p 8091:80 nginx:$NGINX_A"
step "Three tasks running." "docker service ps ws-svc"
step "Kill one container behind swarm's back." "docker rm -f \$(docker ps -q --filter name=ws-svc | head -1)"
step "Swarm replaces it." 'for i in 1 2 3 4; do docker service ps ws-svc --filter desired-state=running; echo; sleep 2; done'
step "Scale to 5." "docker service scale ws-svc=5"
step "Five running." "docker service ps ws-svc --filter desired-state=running"
step "Rolling update." "docker service update --no-resolve-image --image nginx:$NGINX_B ws-svc"
step "Bad release? Roll back." "docker service rollback ws-svc"
step "Reach it from the Mac." "curl -s localhost:8091 | head -5"
step "Clean up the service." "docker service rm ws-svc"
step "Leave the swarm." "docker swarm leave --force"
