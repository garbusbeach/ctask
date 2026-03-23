#!/usr/bin/env bats
CTASK_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/ctask.sh"
REAL_GIT="$(command -v git)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Run ctask inside a zsh subprocess with mocked binaries on PATH.
# Usage: _ctask [--dir <path>] <ctask args...>
_ctask() {
  local dir="$REPO"
  if [[ "$1" == "--dir" ]]; then
    dir="$2"; shift 2
  fi
  run zsh -c "export PATH='${MOCK_BIN}:${PATH}'; source '${CTASK_SH}'; cd '${dir}'; ctask $*"
}

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  # Bare remote — lets real git push succeed
  REMOTE="$(mktemp -d)"
  "$REAL_GIT" init --bare -q "$REMOTE"

  # Working repo — resolve symlinks so pwd matches git worktree list
  # (on macOS /var is a symlink to /private/var)
  REPO="$(mktemp -d)"
  REPO="$(cd "$REPO" && pwd -P)"
  "$REAL_GIT" -C "$REPO" init -b main -q 2>/dev/null \
    || { "$REAL_GIT" -C "$REPO" init -q && "$REAL_GIT" -C "$REPO" checkout -b main -q 2>/dev/null || true; }
  "$REAL_GIT" -C "$REPO" config user.email "test@example.com"
  "$REAL_GIT" -C "$REPO" config user.name "Test"
  "$REAL_GIT" -C "$REPO" remote add origin "file://$REMOTE"
  "$REAL_GIT" -C "$REPO" commit --allow-empty -m "init" -q
  "$REAL_GIT" -C "$REPO" push -u origin main -q

  # Mock binaries
  MOCK_BIN="$(mktemp -d)"

  # code: log the path opened, don't launch VS Code
  printf '#!/bin/sh\nprintf "%%s\n" "$*" >> "%s/code.log"\n' \
    "$MOCK_BIN" > "$MOCK_BIN/code"
  chmod +x "$MOCK_BIN/code"

  # open: log the URL, don't open a browser
  printf '#!/bin/sh\nprintf "%%s\n" "$1" >> "%s/open.log"\n' \
    "$MOCK_BIN" > "$MOCK_BIN/open"
  chmod +x "$MOCK_BIN/open"

  # osascript: no-op (used by ctask clean to close VS Code)
  printf '#!/bin/sh\n' > "$MOCK_BIN/osascript"
  chmod +x "$MOCK_BIN/osascript"

  # git wrapper: swallow push, forward everything else to the real git
  printf '#!/bin/sh\n[ "$1" = "push" ] && { printf "push %%s\n" "$*" >> "%s/git.log"; exit 0; }\nexec "%s" "$@"\n' \
    "$MOCK_BIN" "$REAL_GIT" > "$MOCK_BIN/git"
  chmod +x "$MOCK_BIN/git"

  export REPO REMOTE MOCK_BIN
}

teardown() {
  rm -rf "$REMOTE" "$REPO" "$MOCK_BIN"
}

# ---------------------------------------------------------------------------
# help
# ---------------------------------------------------------------------------

@test "help: shows all commands" {
  _ctask help
  [ "$status" -eq 0 ]
  [[ "$output" == *"ctask new"*   ]]
  [[ "$output" == *"ctask branch"* ]]
  [[ "$output" == *"ctask pr"*    ]]
  [[ "$output" == *"ctask join"*  ]]
  [[ "$output" == *"ctask clean"* ]]
}

@test "help: no args defaults to help" {
  _ctask
  [ "$status" -eq 0 ]
  [[ "$output" == *"ctask"* ]]
}

# ---------------------------------------------------------------------------
# new
# ---------------------------------------------------------------------------

@test "new: creates worktree directory" {
  _ctask new my-feature
  [ "$status" -eq 0 ]
  [ -d "$REPO/.claude/worktrees/my-feature" ]
}

@test "new: creates branch worktree-<name>" {
  _ctask new my-feature
  "$REAL_GIT" -C "$REPO" branch | grep -q "worktree-my-feature"
}

@test "new: .vscode/settings.json is written" {
  _ctask new my-feature
  [ -f "$REPO/.claude/worktrees/my-feature/.vscode/settings.json" ]
}

@test "new: default color is Claude orange #D97757" {
  _ctask new my-feature
  grep -qi "D97757" "$REPO/.claude/worktrees/my-feature/.vscode/settings.json"
}

@test "new: --color flag produces a random color (not orange)" {
  _ctask "new my-feature --color"
  [ "$status" -eq 0 ]
  # settings.json must exist
  [ -f "$REPO/.claude/worktrees/my-feature/.vscode/settings.json" ]
}

@test "new: --color #RRGGBB uses the given hex value" {
  _ctask "new my-feature --color '#FF0000'"
  grep -qi "FF0000" "$REPO/.claude/worktrees/my-feature/.vscode/settings.json"
}

@test "new: fails outside a git repo" {
  TMPDIR="$(mktemp -d)"
  run zsh -c "export PATH='${MOCK_BIN}:${PATH}'; source '${CTASK_SH}'; cd '${TMPDIR}'; ctask new foo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not inside a git repository"* ]]
  rm -rf "$TMPDIR"
}

@test "new: opens VS Code in the worktree path" {
  _ctask new my-feature
  [ -f "$MOCK_BIN/code.log" ]
  grep -q "my-feature" "$MOCK_BIN/code.log"
}

# ---------------------------------------------------------------------------
# branch
# ---------------------------------------------------------------------------

@test "branch: records a git push call" {
  # Create a worktree first, then push from it
  _ctask new push-test
  _ctask --dir "$REPO/.claude/worktrees/push-test" branch
  [ "$status" -eq 0 ]
  [ -f "$MOCK_BIN/git.log" ]
  grep -q "push" "$MOCK_BIN/git.log"
}

# ---------------------------------------------------------------------------
# pr
# ---------------------------------------------------------------------------

@test "pr: opens a GitHub compare URL" {
  # Set a fake GitHub remote so URL is deterministic
  "$REAL_GIT" -C "$REPO" remote set-url origin "https://github.com/acme/myrepo.git"
  _ctask new pr-gh
  _ctask --dir "$REPO/.claude/worktrees/pr-gh" pr
  [ "$status" -eq 0 ]
  grep -q "github.com/acme/myrepo/compare" "$MOCK_BIN/open.log"
}

@test "pr: opens a GitLab merge_request URL" {
  "$REAL_GIT" -C "$REPO" remote set-url origin "https://gitlab.example.com/acme/myrepo.git"
  _ctask new pr-gl
  _ctask --dir "$REPO/.claude/worktrees/pr-gl" pr
  [ "$status" -eq 0 ]
  grep -q "merge_requests" "$MOCK_BIN/open.log"
}

@test "pr: parses SSH remote (git@github.com:...)" {
  "$REAL_GIT" -C "$REPO" remote set-url origin "git@github.com:acme/myrepo.git"
  _ctask new pr-ssh
  _ctask --dir "$REPO/.claude/worktrees/pr-ssh" pr
  [ "$status" -eq 0 ]
  grep -q "github.com/acme/myrepo/compare" "$MOCK_BIN/open.log"
}

# ---------------------------------------------------------------------------
# join
# ---------------------------------------------------------------------------

@test "join: merges branch into main and removes worktree" {
  _ctask new join-test
  _ctask --dir "$REPO/.claude/worktrees/join-test" join
  [ "$status" -eq 0 ]
  # Worktree directory should be gone
  [ ! -d "$REPO/.claude/worktrees/join-test" ]
  # Branch should be deleted
  ! "$REAL_GIT" -C "$REPO" branch | grep -q "worktree-join-test"
}

@test "join: fails when called from main repo" {
  _ctask join
  [ "$status" -ne 0 ]
  [[ "$output" == *"from inside the worktree"* ]]
}

# ---------------------------------------------------------------------------
# clean
# ---------------------------------------------------------------------------

@test "clean: removes named worktree without merging" {
  _ctask new clean-test
  _ctask clean clean-test
  [ "$status" -eq 0 ]
  [ ! -d "$REPO/.claude/worktrees/clean-test" ]
}

@test "clean: fails when called from main with no name" {
  _ctask clean
  [ "$status" -ne 0 ]
  [[ "$output" == *"pass a name"* ]]
}
