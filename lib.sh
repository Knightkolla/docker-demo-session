#!/usr/bin/env bash
# Shared helpers for the workshop demos. Source this: . "$(dirname "$0")/lib.sh"
# DEMO_AUTO=1 skips every "press Enter" pause (used for testing end to end).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pinned versions (keep in sync with README.md and the Dockerfiles)
GO_VERSION=1.27.1
NODE_VERSION=24.21.0
ALPINE_VERSION=3.23
NGINX_A=1.30.5-alpine      # stable
NGINX_B=1.31.6-alpine      # mainline, used as the "new version" in rolling updates
TRIVY_VERSION=0.74.0
DISTROLESS=gcr.io/distroless/static-debian13:nonroot
NODE_LATEST=node:latest    # deliberately unpinned: it is the "bad" example

C_RESET=$'\033[0m'; C_HDR=$'\033[1;35m'; C_SAY=$'\033[0;33m'; C_CMD=$'\033[1;36m'
C_OK=$'\033[0;32m'; C_BAD=$'\033[0;31m'; C_DIM=$'\033[2m'

# In auto mode never launch a browser
if [ -n "$DEMO_AUTO" ]; then
  open() { echo "${C_DIM}(auto mode: would open $*)${C_RESET}"; }
fi

header() { printf '\n%s━━━━━━━━━━ %s ━━━━━━━━━━%s\n' "$C_HDR" "$*" "$C_RESET"; }
say()    { printf '%s💬 %s%s\n' "$C_SAY" "$*" "$C_RESET"; }
note()   { printf '%s%s%s\n' "$C_OK" "$*" "$C_RESET"; }
warn()   { printf '%s%s%s\n' "$C_BAD" "$*" "$C_RESET"; }

pause() { [ -n "$DEMO_AUTO" ] || { read -r _ </dev/tty; }; }

# step "what to say" "command"
# Prints the hint, shows the command, waits for Enter, runs it.
# Never aborts the script: a failing command is often the point. Returns its exit code.
step() {
  local hint="$1" cmd="$2" run="$2"
  [ -n "$hint" ] && say "$hint"
  printf '%s$ %s%s' "$C_CMD" "$cmd" "$C_RESET"
  if [ -n "$DEMO_AUTO" ]; then echo; else printf '  %s[Enter]%s' "$C_DIM" "$C_RESET"; pause; fi
  # no terminal (automated run): -it would fail for the wrong reason
  [ -t 0 ] || run="${run// -it / -i }"
  eval "$run"
  local rc=$?
  return $rc
}

# run "command" : quiet setup/cleanup, no pause, output hidden, never fails
run() { eval "$1" >/dev/null 2>&1 || true; }

# wait_for "description" tries "command" : poll once a second (no `timeout` on macOS)
wait_for() {
  local desc="$1" tries="$2" cmd="$3" i
  for ((i=0; i<tries; i++)); do eval "$cmd" >/dev/null 2>&1 && return 0; sleep 1; done
  warn "gave up waiting for: $desc"; return 1
}

need_docker() {
  docker info >/dev/null 2>&1 || { warn "Docker Desktop is not running. Start it and retry."; exit 1; }
}

# https URL of the repo's Actions page, from the git remote (handles ssh and https remotes)
actions_url() {
  local u; u=$(git -C "$ROOT" remote get-url origin 2>/dev/null) || return 1
  u="${u%.git}"; u="${u/git@github.com:/https://github.com/}"
  echo "$u/actions"
}

# Trivy through docker: socket mounted, persistent cache so nothing downloads on stage
TRIVY_CACHE="$HOME/.cache/trivy"
TRIVY_RUN='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/.cache/trivy:/root/.cache/ aquasec/trivy:'"$TRIVY_VERSION"' image --scanners vuln --skip-db-update --skip-java-db-update --quiet'

# Fake secrets for demo 2. Same content every time so the Docker build cache stays valid.
make_env() { printf 'DB_PASSWORD=supersecret123\nAPI_KEY=fake-key-not-real\n' > "$ROOT/2-security/.env"; }
