#!/usr/bin/env bash
# Demo 4 (Kubernetes): self-healing, scaling, rolling update, rollback
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
cd "$ROOT/4-orchestration"

ctx=$(kubectl config current-context 2>/dev/null)
if [ "$ctx" != "docker-desktop" ]; then
  warn "kubectl context is '${ctx:-none}', expected 'docker-desktop'."
  echo "Enable Kubernetes: Docker Desktop > Settings > Kubernetes > Enable Kubernetes > Apply & restart."
  echo "Then: kubectl config use-context docker-desktop"
  echo "No Kubernetes? Run ./demo4-swarm.sh instead."
  exit 1
fi
kubectl get nodes >/dev/null 2>&1 || { warn "Kubernetes isn't answering yet. Wait for the green Kubernetes icon in Docker Desktop."; exit 1; }

run "kubectl delete -f k8s/ --ignore-not-found --wait=true"

header "Demo 4: Kubernetes"
step "Desired state: 3 replicas behind a LoadBalancer on 8090." "kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml"
wait_for "deployment ready" 60 "kubectl rollout status deployment/ws-web --timeout=1s"
step "Three pods running." "kubectl get pods -l app=web"
step "Kill one pod." "kubectl delete \$(kubectl get pods -l app=web -o name | head -1)"
step "Kubernetes notices and replaces it (new name)." 'for i in 1 2 3 4; do kubectl get pods -l app=web; echo; sleep 2; done'
step "Scale to 10 with one command." "kubectl scale deployment/ws-web --replicas=10"
wait_for "10 pods" 60 "[ \"\$(kubectl get deploy ws-web -o jsonpath='{.status.readyReplicas}')\" = 10 ]"
step "Ten pods." "kubectl get pods -l app=web"
step "Back to 3 for the update." "kubectl scale deployment/ws-web --replicas=3"
wait_for "3 pods" 60 "[ \"\$(kubectl get pods -l app=web --no-headers | wc -l | tr -d ' ')\" = 3 ]"
step "Rolling update to a new nginx version, zero downtime." "kubectl set image deployment/ws-web nginx=nginx:$NGINX_B"
step "Watch it roll." "kubectl rollout status deployment/ws-web"
step "Oops, bad release. Roll back." "kubectl rollout undo deployment/ws-web"
step "Rolled back." "kubectl rollout status deployment/ws-web"
step "Reach it from the Mac through the LoadBalancer." "curl -s localhost:8090 | head -5"
