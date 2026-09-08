#!/usr/bin/env bash
# Help & Usage Guide for AAPP CLI
cat <<EOF
Usage: aapp <command> [options]

Asymmetric Agent Planning Protocol (AAPP v${AAPP_VERSION:-1.0.0})
A deterministic protocol decoupling planning, agent behavioral rules,
and git hooks from application source code using isolated Git worktrees.

Commands:
  init       Initialize or update AAPP in the current git repository
  upgrade    Upgrade global AAPP binaries & templates from upstream
  status     Display the 4-pillar context recovery briefing
  install    Install AAPP globally into ~/.local/bin and configure PATH
  uninstall  Remove global AAPP binaries and share files from system
  version    Show installed AAPP version (-v, --version)
  help       Show this help message (-h, --help)

Examples:
  aapp init              # Set up or sync worktrees in current repository
  aapp status            # Print Shipped, Issues, Plans, and Pickup briefing
  aapp upgrade           # Pull latest upstream release into ~/.local/share
  aapp install           # Install aapp globally into ~/.local/bin
  aapp uninstall         # Remove global installation

For documentation, see: https://github.com/aapp-protocol/aapp-kit
EOF
