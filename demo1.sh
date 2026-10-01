#!/usr/bin/env bash
# Demo 1: multi-stage builds (fat vs thin Go image)
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
need_docker
cd "$ROOT/1-multistage"

run "docker rm -f ws-thin"
run "docker rmi -f ws-fat ws-thin"

header "Demo 1: multi-stage build"
step "Single stage: the compiler ships to production." "cat Dockerfile.fat"
step "Two stages: build in one, ship only the binary." "cat Dockerfile.thin"
step "Build the fat one." "docker build -f Dockerfile.fat -t ws-fat ."
step "Build the thin one." "docker build -f Dockerfile.thin -t ws-thin ."
step "Same app, look at the sizes." "docker images --filter reference=ws-fat --filter reference=ws-thin"
step "Run the thin one on 8081." "docker run -d --name ws-thin -p 8081:8080 ws-thin"
wait_for "ws-thin" 15 "curl -fs localhost:8081"
step "It works in the browser." "open http://localhost:8081"
step "Try to get a shell. There is none: no attack surface." "docker exec -it ws-thin sh"
note "^ That failure is EXPECTED: distroless has no shell."
step "Layer by layer: the fat one." "docker history ws-fat"
step "Layer by layer: the thin one." "docker history ws-thin"
