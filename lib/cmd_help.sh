#!/usr/bin/env bash
# Help & Usage Guide for AAPP CLI
cat <<EOF
Usage: aapp <command> [options]

Asymmetric Agent Planning Protocol (AAPP v${AAPP_VERSION:-1.0.0})
A deterministic protocol decoupling planning, agent behavioral rules,
and git hooks from application source code using isolated Git worktrees.

Commands:
  init         Initialize or update AAPP in the current git repository
  develop      Link development repository into global paths via symlinks
  upgrade      Upgrade global AAPP binaries & templates from upstream
  status       Display the 4-pillar context recovery briefing
  active       Display or manage active execution plan buffer (swap, clear)
  pause        Engage project emergency brake; quarantine code per-worktree into stashes
  resume       Disengage brake, verify drift, and restore quarantined stashes
  push         Push active AAPP worktrees (.plans, .agents, .githooks) to remote
  pull         Pull updates for active AAPP worktrees from remote (--ff-only)
  sync         Bi-directional sync: pull updates followed by push
  plan-status  Inspect plan lane matrix or specific blueprint (read-only)
  plan         Display educational planning switchboard
  freeze-start Atomically freeze blueprint, transition to In Development, bind buffer
  start        Transition frozen blueprint to In Development and bind buffer
  ai-status    Display current AI attribution mode and pending notes
  ai-commit    Switch to public, emailless semantic trailer mode
  ai-notes     Switch to local-first / private git notes attribution
  ai-off       Disable AI attribution (pure human authoring)
  ai-credits   Generate or update AI Contributors block in README.md
  ai-note      Pre-stage customizable note buffer for next commit (--stage)
  install      Install AAPP globally into ~/.local/bin and configure PATH
  uninstall    Remove global AAPP binaries and share files from system
  version      Show installed AAPP version (-v, --version)
  help         Show this help message (-h, --help)

Examples:
  aapp init              # Set up or sync worktrees in current repository
  aapp develop           # Link local development clone globally (live editable)
  aapp status            # Print Shipped, Issues, Plans, and Pickup briefing
  aapp push              # Push all active worktrees (.plans, .agents, .githooks)
  aapp pull              # Pull remote changes with --ff-only
  aapp sync              # Pull then push active worktrees
  aapp sync origin hook  # Sync delegating transport to on-sync hook
  aapp pause "away"      # Engage emergency brake and quarantine in-flight changes
  aapp resume            # Disengage brake, verify drift, and restore stashed work
  aapp active P-20       # Designate P-20 as active execution plan buffer
  aapp plan-status       # Inspect current plan lane matrix
  aapp plan              # Display educational planning switchboard
  aapp ai-commit         # Enable public emailless trailers (AI-Agent:)
  aapp ai-notes          # Enable local git notes attribution
  aapp ai-off            # Disable AI attribution (pure human commits)
  aapp ai-credits        # Update AI Contributors block in README.md
  aapp ai-note --stage   # Pre-stage customizable note buffer for next commit
  aapp upgrade           # Pull latest upstream release into ~/.local/share
  aapp install           # Install aapp globally into ~/.local/bin
  aapp uninstall         # Remove global installation

For documentation, see: https://github.com/aapp-protocol/aapp-kit
EOF
