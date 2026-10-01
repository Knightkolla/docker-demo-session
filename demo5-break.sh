#!/usr/bin/env bash
# Run tonight to get a red pipeline to screenshot. Pushes a branch with a failing test.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
cd "$ROOT"

header "Demo 5: deliberately broken build"
run "git branch -D demo-fail"
git checkout -q -b demo-fail || exit 1
cat >> 1-multistage/main_test.go <<'GO'

func TestDeliberateFailure(t *testing.T) {
	t.Fatal("this build is broken on purpose")
}
GO
git add 1-multistage/main_test.go
git commit -q -m "demo: deliberately failing test"
git push -f -u origin demo-fail
open "$(actions_url)"
git checkout -q main
note "Back on main. The red run is on branch demo-fail."
