#!/usr/bin/env bash
# Help & Usage Guide for AAPP CLI
cat <<EOF
Usage: aapp <command> [options]

Asymmetric Agent Planning Protocol (AAPP v${AAPP_VERSION:-1.0.0})
A deterministic protocol decoupling planning, agent behavioral rules,
and git hooks from application source code using isolated Git worktrees.

Commands:
  init        Initialize or update AAPP in the current git repository
  develop     Link development repository into global paths via symlinks
  upgrade     Upgrade global AAPP binaries & templates from upstream
  status      Display the 4-pillar context recovery briefing
  ai-status   Display current AI attribution mode and pending notes
  ai-commit   Switch to public, emailless semantic trailer mode
  ai-notes    Switch to local-first / private git notes attribution
  ai-off      Disable AI attribution (pure human authoring)
  ai-credits  Generate or update AI Contributors block in README.md
  ai-note     Pre-stage customizable note buffer for next commit (--stage)
  install     Install AAPP globally into ~/.local/bin and configure PATH
  uninstall   Remove global AAPP binaries and share files from system
  version     Show installed AAPP version (-v, --version)
  help        Show this help message (-h, --help)

Examples:
  aapp init              # Set up or sync worktrees in current repository
  aapp develop           # Link local development clone globally (live editable)
  aapp status            # Print Shipped, Issues, Plans, and Pickup briefing
  aapp ai-commit         # Enable public emailless trailers (AI-Agent:)
  aapp ai-notes          # Enable local git notes attribution
  aapp ai-off            # Disable AI attribution (pure human commits)
  aapp ai-credits        # Update AI Contributors block in README.md
  aapp ai-note --stage   # Pre-stage customizable note buffer for next commit
  aapp upgrade           # Pull latest upstream release into ~/.local/share
  aapp install           # Install aapp globally into ~/.local/bin
  aapp install --keep    # Install globally without self-consuming clone folder
  aapp init --keep       # Initialize repository preserving drop-in clone
  aapp uninstall         # Remove global installation

For documentation, see: https://github.com/aapp-protocol/aapp-kit
EOF
