#!/usr/bin/env bash
# ctask installer
# Usage: curl -fsSL https://raw.githubusercontent.com/garbusbeach/ctask/refs/heads/master/install.sh | bash

set -e

ORANGE='\033[38;2;217;119;87m'
RESET='\033[0m'

CTASK_BASE_URL="https://raw.githubusercontent.com/garbusbeach/ctask/refs/heads/master"
CTASK_URL="$CTASK_BASE_URL/ctask.sh"
VERSION_URL="$CTASK_BASE_URL/VERSION.md"
CTASK_FILE="$HOME/.ctask.sh"
SOURCE_LINE="source \"\$HOME/.ctask.sh\"  # >>> ctask <<<"

# Parse flags
FORCE=0
for arg in "$@"; do
  [[ "$arg" == "--force" ]] && FORCE=1
done

# Detect shell config file
detect_shell_config() {
  if [ -n "$ZSH_VERSION" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    echo "$HOME/.zshrc"
  elif [ -n "$BASH_VERSION" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      echo "$HOME/.bash_profile"
    else
      echo "$HOME/.bashrc"
    fi
  else
    for f in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
      [ -f "$f" ] && echo "$f" && return
    done
    echo "$HOME/.profile"
  fi
}

CONFIG_FILE=$(detect_shell_config)

echo ""
echo -e "${ORANGE}🐿️  ctask installer${RESET}"
echo ""
echo "   ctask file   : $CTASK_FILE"
echo "   shell config : $CONFIG_FILE"
echo ""

# Fetch remote version
echo "   fetching version..."
REMOTE_VERSION=$(curl -fsSL "$VERSION_URL" | tr -d '[:space:]') || {
  echo -e "${ORANGE}Error: failed to fetch version from $VERSION_URL${RESET}"
  exit 1
}
echo "   version      : $REMOTE_VERSION"

# Check installed version
INSTALLED_VERSION=$(grep -m1 '^CTASK_VERSION=' "$CTASK_FILE" 2>/dev/null | cut -d'"' -f2)
if [[ -n "$INSTALLED_VERSION" && "$INSTALLED_VERSION" == "$REMOTE_VERSION" && "$FORCE" -eq 0 ]]; then
  echo ""
  echo -e "${ORANGE}   Already on version ${REMOTE_VERSION}.${RESET}"
  echo -e "${ORANGE}   Use --force to reinstall.${RESET}"
  echo ""
  exit 0
fi

# Download ctask.sh
echo "   fetching ctask.sh..."
CTASK_CONTENT=$(curl -fsSL "$CTASK_URL") || {
  echo -e "${ORANGE}Error: failed to fetch ctask.sh from $CTASK_URL${RESET}"
  exit 1
}

# Inject version and base URL into the script
CTASK_CONTENT=$(printf '%s\n' "$CTASK_CONTENT" \
  | sed "s|CTASK_VERSION=\"\"|CTASK_VERSION=\"${REMOTE_VERSION}\"|" \
  | sed "s|CTASK_BASE_URL=\"\"|CTASK_BASE_URL=\"${CTASK_BASE_URL}\"|")

# Prepend a header so anyone browsing their dotfiles knows what this is
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
_pad() { printf '# ║  %-53s ║\n' "$1"; }
_sep() { printf '# ╠════════════════════════════════════════════════════════╣\n'; }
{
  printf '# ╔════════════════════════════════════════════════════════╗\n'
  _pad "ctask — Claude worktree task launcher"
  _sep
  _pad "Source   : https://github.com/garbus-beach/ctask"
  _pad "Version  : $REMOTE_VERSION"
  _pad "Installed: $INSTALL_DATE"
  _sep
  _pad 'Loaded via : source "$HOME/.ctask.sh"'
  _pad "Update     : ctask update"
  _pad "Remove     : delete this file + remove source line"
  printf '# ╚════════════════════════════════════════════════════════╝\n'
  printf '\n'
  printf '%s\n' "$CTASK_CONTENT"
} > "$CTASK_FILE"
echo "   saved to $CTASK_FILE"

# Add source line to shell config (once)
if grep -qF "$CTASK_FILE" "$CONFIG_FILE" 2>/dev/null; then
  echo "   source line already in $CONFIG_FILE — skipping"
else
  printf '\n%s\n' "$SOURCE_LINE" >> "$CONFIG_FILE"
  echo "   added source line to $CONFIG_FILE"
fi

echo ""
echo "   Activate in your current session:"
echo ""
echo "     source $CTASK_FILE"
echo ""
echo -e "${ORANGE}   Then try: ctask help${RESET}"
echo ""
