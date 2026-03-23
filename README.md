<p align="center">
  <img src="img/claude.svg" width="72" alt="Claude"/>
  <img src="img/vscode.svg" width="72" alt="VS-Code"/>
</p>

# ctask 🐿️

[![Tests](https://github.com/garbusbeach/ctask/actions/workflows/test.yml/badge.svg)](https://github.com/garbusbeach/ctask/actions/workflows/test.yml)

🐿️ Claude worktree task launcher. Spins up isolated git worktrees for parallel Claude Code tasks, each with a color-coded VS Code status bar and title bar so you always know which window you're in.

## Install

### One-liner (recommended)

```sh
curl -fsSL https://garbusbeach.com/ctask.sh | bash
```

And that's all.


The installer (`install.sh`) downloads `ctask.sh` to `~/.ctask.sh` and adds one line to your shell config:

```sh
source "$HOME/.ctask.sh"  # >>> ctask <<<
```

Activate in your current session: (after install)

```sh
source ~/.ctask.sh
```

To update ctask later, just re-run the install command — it overwrites `~/.ctask.sh` without touching your shell config again.

### Manual

```sh
curl -fsSL https://raw.githubusercontent.com/garbusbeach/ctask/refs/heads/master/ctask.sh -o ~/.ctask.sh
echo 'source "$HOME/.ctask.sh"  # >>> ctask <<<' >> ~/.zshrc
source ~/.ctask.sh
```

## Usage

```
ctask new <name>                  create worktree — Claude orange status bar
ctask new <name> --color          create worktree — random color
ctask new <name> --color #RRGGBB  create worktree — specific hex color

ctask branch                      push current worktree branch to remote
ctask pr                          push branch + open GitHub PR in browser
ctask join                        merge worktree into main + cleanup
ctask clean [name]                remove worktree + close VS Code window
ctask version                     show installed version
ctask update                      update to latest version
ctask help                        show help
```

## Workflow

```sh
# 1. From any repo, spin up a new isolated task (Claude orange by default)
ctask new fix-auth

# 2. Or use a specific color to tell worktrees apart at a glance
ctask new redesign --color
ctask new hotfix --color #C084FC

# 3. Claude works in the worktree — VS Code opens with a colored status bar + title bar

# 4. Push the branch when ready
ctask branch

# 5. Open a PR directly in the browser
ctask pr

# 6. Or merge directly into main and clean up
ctask join

# 7. Or just discard the worktree without merging
ctask clean fix-auth
```

Worktrees are created at `<repo-root>/.claude/worktrees/<name>` on branch `worktree-<name>`.

## Color behavior

| Flag | Color |
|------|-------|
| *(none)* | Claude orange <span style="background:#D97757; color: #fff; padding: 2px 4px; border-radius: 2px;">#D97757</span> |
| `--color` | Random color |
| `--color #RRGGBB` | Your hex value |

Foreground text (light/dark) is chosen automatically based on the background luminance. Works with the [Peacock](https://marketplace.visualstudio.com/items?itemName=johnpapa.vscode-peacock) extension too.

## Requirements

- git
- VS Code (`code` CLI in PATH)
- GitHub remote (for `ctask pr`)
- macOS (for `ctask clean` VS Code window auto-close via AppleScript)
