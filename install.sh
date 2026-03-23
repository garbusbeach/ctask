#!/usr/bin/env bash
# ctask installer
# Usage: curl -fsSL https://raw.githubusercontent.com/garbus-beach/ctask/main/install.sh | bash

set -e

ORANGE='\033[38;2;217;119;87m'
RESET='\033[0m'

CTASK_URL="https://raw.githubusercontent.com/garbus-beach/ctask/main/ctask.sh"
CTASK_FILE="$HOME/.ctask.sh"
SOURCE_LINE="source \"\$HOME/.ctask.sh\"  # >>> ctask <<<"

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

# Download ctask.sh to ~/.ctask.sh
echo "   fetching ctask.sh..."
CTASK_CONTENT=$(curl -fsSL "$CTASK_URL") || {
  echo -e "${ORANGE}Error: failed to fetch ctask.sh from $CTASK_URL${RESET}"
  exit 1
}

# Prepend a header so anyone browsing their dotfiles knows what this is
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
_pad() { printf '# ║  %-53s ║\n' "$1"; }
_sep() { printf '# ╠════════════════════════════════════════════════════════╣\n'; }
{
  printf '# ╔════════════════════════════════════════════════════════╗\n'
  _pad "ctask — Claude worktree task launcher"
  _sep
  _pad "Source   : https://github.com/garbus-beach/ctask"
  _pad "Installed: $INSTALL_DATE"
  _sep
  _pad 'Loaded via : source "$HOME/.ctask.sh"'
  _pad "Update     : re-run the install one-liner"
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
echo -e "${ORANGE}   To update later: re-run the install command${RESET}"
echo -e "${ORANGE}   Then try: ctask help${RESET}"
echo ""
