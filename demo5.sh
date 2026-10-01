#!/usr/bin/env bash
# Demo 5: CI/CD. Push a change to main and watch GitHub Actions run.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
cd "$ROOT"

header "Demo 5: CI/CD"
git rev-parse --verify -q HEAD >/dev/null || {
  warn "No commits yet. Publish the repo first:"
  echo "  git add . && git commit -m 'workshop demos' && git push -u origin main"
  exit 1
}
git checkout -q main || exit 1
step "A tiny change: append a timestamp to VERSION." "date -u '+deployed %Y-%m-%dT%H:%M:%SZ' >> VERSION"
step "Commit it." "git add VERSION && git commit -m 'demo: bump VERSION'"
step "Push to main. That is the trigger." "git push origin main"
step "Watch test, build, scan, push happen." "open $(actions_url)"
