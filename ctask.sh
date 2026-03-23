# Claude worktree task launcher
# Usage:
#   ctask new <name>    — create worktree + open VS Code
#   ctask branch        — push current worktree branch to remote
#   ctask pr            — push + open GitHub PR in browser
#   ctask join          — merge worktree into main + cleanup
#   ctask version       — print installed version
#   ctask update        — update to latest version

# Injected by installer — do not edit manually
CTASK_VERSION=""
CTASK_BASE_URL=""

ctask() {
  local ORANGE='\033[38;2;217;119;87m'
  local RESET='\033[0m'

  _ctask_require_git() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
      echo "${ORANGE}Error: not inside a git repository${RESET}"
      return 1
    fi
  }

  _ctask_current_branch() {
    git branch --show-current
  }

  _ctask_main_worktree() {
    git worktree list | head -1 | awk '{print $1}'
  }

  _ctask_forge_pr_url() {
    local branch="$1" main_branch="$2"
    local remote host repo_path forge base_url

    remote=$(git remote get-url origin 2>/dev/null) || {
      echo "${ORANGE}Error: no remote 'origin' found${RESET}" >&2; return 1
    }

    # Parse SSH:   git@host:org/repo.git
    if [[ "$remote" == git@* ]]; then
      host="${remote#git@}"; host="${host%%:*}"
      repo_path="${remote#*:}"
    # Parse HTTPS: https://host/org/repo.git
    elif [[ "$remote" == http* ]]; then
      local stripped="${remote#*://}"
      host="${stripped%%/*}"
      repo_path="${stripped#*/}"
    else
      echo "${ORANGE}Error: unrecognized remote format: ${remote}${RESET}" >&2; return 1
    fi

    repo_path="${repo_path%.git}"
    base_url="https://${host}/${repo_path}"

    case "$host" in
      *github*)    forge="github" ;;
      *gitlab*)    forge="gitlab" ;;
      *bitbucket*) forge="bitbucket" ;;
      *)           forge="github" ;;
    esac

    case "$forge" in
      github)
        echo "${base_url}/compare/${main_branch}...${branch}?expand=1" ;;
      gitlab)
        echo "${base_url}/-/merge_requests/new?merge_request[source_branch]=${branch}&merge_request[target_branch]=${main_branch}" ;;
      bitbucket)
        echo "${base_url}/pull-requests/new?source=${branch}&dest=${main_branch}" ;;
      *)
        echo "${base_url}/compare/${main_branch}...${branch}?expand=1" ;;
    esac
  }

  case "$1" in

    new)
      # Parse: ctask new <name> [--color [#RRGGBB]]
      #   no --color flag   → Claude orange (#D97757)
      #   --color           → random color
      #   --color #RRGGBB   → specific color
      local CLAUDE_ORANGE="#D97757"
      local name="" custom_color="" use_random=0 skip_next=0
      local i=2
      while [[ $i -le $# ]]; do
        local arg="${@[$i]}"
        if (( skip_next )); then
          skip_next=0
        elif [[ "$arg" == "--color" ]]; then
          local next="${@[$((i+1))]}"
          if [[ "$next" == \#* ]]; then
            custom_color="$next"
            skip_next=1
          else
            use_random=1
          fi
        elif [[ -z "$name" ]]; then
          name="$arg"
        fi
        i=$(( i + 1 ))
      done
      [[ -z "$name" ]] && name="task-$(date +%s)"

      local root="$(git rev-parse --show-toplevel 2>/dev/null)"
      if [ -z "$root" ]; then echo "${ORANGE}Error: not inside a git repository${RESET}"; return 1; fi

      local worktree_path="$root/.claude/worktrees/$name"
      local branch="worktree-$name"

      git worktree prune 2>/dev/null
      git worktree add "$worktree_path" -b "$branch" 2>/dev/null || {
        echo "${ORANGE}Branch '$branch' exists, reusing...${RESET}"
        git worktree add "$worktree_path" "$branch"
      }

      # Resolve r, g, b — three modes
      local r g b bar_color
      if [[ -n "$custom_color" ]]; then
        bar_color="$custom_color"
        r=$(( 16#${custom_color:1:2} ))
        g=$(( 16#${custom_color:3:2} ))
        b=$(( 16#${custom_color:5:2} ))
      elif (( use_random )); then
        r=$(( RANDOM % 180 + 40 ))
        g=$(( RANDOM % 180 + 40 ))
        b=$(( RANDOM % 180 + 40 ))
        bar_color=$(printf '#%02X%02X%02X' $r $g $b)
      else
        bar_color="$CLAUDE_ORANGE"
        r=$(( 16#${CLAUDE_ORANGE:1:2} ))
        g=$(( 16#${CLAUDE_ORANGE:3:2} ))
        b=$(( 16#${CLAUDE_ORANGE:5:2} ))
      fi

      # Foreground: dark on light bg, light on dark bg
      local lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
      local fg_color fg_alpha
      if (( lum > 128 )); then
        fg_color="#15202b"
        fg_alpha="#15202b99"
      else
        fg_color="#e7e7e7"
        fg_alpha="#e7e7e799"
      fi

      # Hover: slightly darker
      local hover_color=$(printf '#%02X%02X%02X' \
        $(( r - 20 < 0   ? 0   : r - 20 )) \
        $(( g - 20 < 0   ? 0   : g - 20 )) \
        $(( b - 20 < 0   ? 0   : b - 20 )))

      # Sash: slightly lighter
      local sash_color=$(printf '#%02X%02X%02X' \
        $(( r + 30 > 255 ? 255 : r + 30 )) \
        $(( g + 30 > 255 ? 255 : g + 30 )) \
        $(( b + 30 > 255 ? 255 : b + 30 )))

      # Inactive: base + 99 alpha suffix
      local inactive_bg="${bar_color}99"

      mkdir -p "$worktree_path/.vscode"
      cat > "$worktree_path/.vscode/settings.json" << EOF
{
  "workbench.colorCustomizations": {
    "commandCenter.border": "${fg_alpha}",
    "sash.hoverBorder": "${sash_color}",
    "statusBar.background": "${bar_color}",
    "statusBar.foreground": "${fg_color}",
    "statusBarItem.hoverBackground": "${hover_color}",
    "statusBarItem.remoteBackground": "${bar_color}",
    "statusBarItem.remoteForeground": "${fg_color}",
    "titleBar.activeBackground": "${bar_color}",
    "titleBar.activeForeground": "${fg_color}",
    "titleBar.inactiveBackground": "${inactive_bg}",
    "titleBar.inactiveForeground": "${fg_alpha}"
  },
  "peacock.color": "${bar_color}"
}
EOF

      code "$worktree_path"

      echo "${ORANGE}🐿️  ctask '${name}' is ready!${RESET}"
      echo "${ORANGE}   branch : ${branch}${RESET}"
      echo "${ORANGE}   path   : ${worktree_path}${RESET}"
      echo "${ORANGE}   color  : ${bar_color}${RESET}"
      ;;

    branch)
      _ctask_require_git || return 1
      local branch=$(_ctask_current_branch)
      echo "${ORANGE}🐿️  Pushing branch '${branch}'...${RESET}"
      git push -u origin "$branch"
      echo "${ORANGE}   done — branch is on remote${RESET}"
      ;;

    pr)
      _ctask_require_git || return 1
      local branch=$(_ctask_current_branch)
      local main_branch=$(git -C "$(_ctask_main_worktree)" symbolic-ref --short HEAD 2>/dev/null || echo "main")

      echo "${ORANGE}🐿️  Pushing '${branch}' and opening PR...${RESET}"
      git push -u origin "$branch"

      local pr_url=$(_ctask_forge_pr_url "$branch" "$main_branch") || return 1
      open "$pr_url"

      echo "${ORANGE}   PR opened in browser${RESET}"
      echo "${ORANGE}   ${pr_url}${RESET}"
      ;;

    join)
      _ctask_require_git || return 1
      local branch=$(_ctask_current_branch)
      local worktree_path=$(pwd)
      local main_path=$(_ctask_main_worktree)

      if [ "$worktree_path" = "$main_path" ]; then
        echo "${ORANGE}Error: run 'ctask join' from inside the worktree, not main${RESET}"
        return 1
      fi

      echo "${ORANGE}🐿️  Merging '${branch}' into main...${RESET}"
      local main_branch=$(git -C "$main_path" symbolic-ref --short HEAD 2>/dev/null || echo "main")
      git -C "$main_path" checkout "$main_branch"
      git -C "$main_path" merge "$branch"

      cd "$main_path"
      git worktree remove "$worktree_path" --force
      git branch -d "$branch"

      echo "${ORANGE}   merged + worktree cleaned up${RESET}"
      echo "${ORANGE}   you are now on: $(pwd)${RESET}"
      ;;

    clean)
      _ctask_require_git || return 1
      local main_path=$(_ctask_main_worktree)
      local root="$(git -C "$main_path" rev-parse --show-toplevel)"

      # resolve target: named or current
      local worktree_path branch
      if [[ -n "$2" ]]; then
        local name="$2"
        worktree_path="$root/.claude/worktrees/$name"
        branch="worktree-$name"
      else
        worktree_path=$(pwd)
        branch=$(_ctask_current_branch)
        if [ "$worktree_path" = "$main_path" ]; then
          echo "${ORANGE}Error: run 'ctask clean' from inside a worktree, or pass a name${RESET}"
          return 1
        fi
      fi

      echo "${ORANGE}🐿️  Cleaning worktree '${branch}'...${RESET}"

      # prune stale entries in case dir was manually deleted
      git -C "$main_path" worktree prune 2>/dev/null

      cd "$main_path"
      git worktree remove "$worktree_path" --force
      git branch -D "$branch" 2>/dev/null || true

      echo "${ORANGE}   worktree removed${RESET}"
      echo "${ORANGE}   branch '${branch}' deleted${RESET}"
      ;;

    version)
      echo "${ORANGE}🐿️  ctask ${CTASK_VERSION}${RESET}"
      ;;

    update)
      if [[ -z "$CTASK_BASE_URL" ]]; then
        echo "${ORANGE}Error: CTASK_BASE_URL not set — re-run the installer${RESET}"
        return 1
      fi

      local remote_version
      remote_version=$(curl -fsSL "${CTASK_BASE_URL}/VERSION.md" 2>/dev/null | tr -d '[:space:]') || {
        echo "${ORANGE}Error: could not reach ${CTASK_BASE_URL}/VERSION.md${RESET}"
        return 1
      }

      if [[ "$remote_version" == "$CTASK_VERSION" ]]; then
        echo "${ORANGE}🐿️  Already up to date (${CTASK_VERSION})${RESET}"
        return 0
      fi

      echo "${ORANGE}🐿️  Updating ${CTASK_VERSION} → ${remote_version}...${RESET}"
      bash <(curl -fsSL "${CTASK_BASE_URL}/install.sh") --force
      echo "${ORANGE}   Updated! Run: source ~/.ctask.sh${RESET}"
      ;;

    help|*)
      echo ""
      echo "${ORANGE}🐿️  ctask — Claude worktree task launcher${RESET}"
      echo ""
      echo "  ${ORANGE}ctask new <name>${RESET}              create worktree (Claude orange)"
      echo "  ${ORANGE}ctask new <name> --color${RESET}      create worktree (random color)"
      echo "  ${ORANGE}ctask new <name> --color #RRGGBB${RESET} create worktree (custom color)"
      echo "  ${ORANGE}ctask branch${RESET}       push current worktree branch to remote"
      echo "  ${ORANGE}ctask pr${RESET}           push branch + open GitHub PR in browser"
      echo "  ${ORANGE}ctask join${RESET}         merge worktree into main + cleanup"
      echo "  ${ORANGE}ctask clean [name]${RESET} remove worktree + close VS Code window"
      echo "  ${ORANGE}ctask version${RESET}      show installed version"
      echo "  ${ORANGE}ctask update${RESET}       update to latest version"
      echo "  ${ORANGE}ctask help${RESET}         show this help"
      echo ""
      ;;
  esac
}