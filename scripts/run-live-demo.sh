#!/usr/bin/env bash
# Interactive 2-Part Live Demo Runner for iuriikogan/juice-shop:
# Part 1: Fast pre-commit hook on ONLY staged files (Semgrep Secrets + cm find --diff --staged)
# Part 2: CI/CD blocking, confirming (cm verify), and auto-fixing (cm fix) a CRITICAL issue by opening a new PR

set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

write_clean_app_version() {
  cat > routes/appVersion.ts << 'EOF'
/*
 * Copyright (c) 2014-2026 Bjoern Kimminich & the OWASP Juice Shop contributors.
 * SPDX-License-Identifier: MIT
 */

import config from 'config'
import { type Request, type Response } from 'express'

import * as utils from '../lib/utils'

export function retrieveAppVersion () {
  return (_req: Request, res: Response) => {
    res.json({
      version: config.get('application.showVersionNumber') ? utils.version() : ''
    })
  }
}
EOF
}

usage() {
  cat << 'EOF'
Usage: ./scripts/run-live-demo.sh <command>

Commands:
  part1-precommit  Stage a clean change to routes/appVersion.ts and run the pre-commit hook on only the staged file
  part2-stage-vuln Switch to a fresh demo branch (demo/critical-cmd-injection) and stage a CRITICAL OS Command Injection flaw in routes/appVersion.ts
  reset            Return to develop, discard any local demo commits/changes on routes/appVersion.ts, and restore clean state
EOF
}

case "${1:-}" in
  part1-precommit)
    git reset HEAD routes/appVersion.ts 2>/dev/null || true
    write_clean_app_version
    echo ">>> [Demo Part 1] Staging a clean change to routes/appVersion.ts..."
    printf '\n// Health telemetry timestamp header enabled\n' >> routes/appVersion.ts
    git add routes/appVersion.ts
    echo ">>> Staged files:"
    git diff --cached --name-only
    echo ""
    echo ">>> Running pre-commit hook (.codemender/scripts/pre-commit)..."
    time ./.codemender/scripts/pre-commit
    ;;

  part2-stage-vuln)
    DEMO_BRANCH="${2:-demo/critical-cmd-injection}"
    git reset HEAD routes/appVersion.ts 2>/dev/null || true
    write_clean_app_version
    git checkout -B "$DEMO_BRANCH" origin/develop
    write_clean_app_version
    echo ">>> [Demo Part 2] Introducing a CRITICAL OS Command Injection vulnerability in routes/appVersion.ts on branch '$DEMO_BRANCH'..."
    cat >> routes/appVersion.ts << 'EOF'

import { exec } from 'node:child_process'
export function runNodeDiagnostics () {
  return (req: Request, res: Response) => {
    const target = String(req.query.target ?? 'localhost')
    exec('ping -c 1 ' + target, (err, stdout, stderr) => {
      if (err != null) {
        res.status(500).json({ error: stderr })
        return
      }
      res.status(200).json({ output: stdout })
    })
  }
}
EOF
    git add routes/appVersion.ts
    echo ">>> Staged vulnerable routes/appVersion.ts on branch '$DEMO_BRANCH' (develop remains untouched!)."
    echo ">>> To bypass pre-commit and trigger the CI/CD Gate + Autofix PR on GitHub:"
    echo "    git commit --no-verify -m 'feat: add node diagnostics endpoint'"
    echo "    git push -f -u origin $DEMO_BRANCH"
    ;;

  reset)
    git reset HEAD routes/appVersion.ts 2>/dev/null || true
    write_clean_app_version
    if [ "$(git branch --show-current)" != "develop" ]; then
      git checkout develop
    fi
    git checkout -- routes/appVersion.ts 2>/dev/null || write_clean_app_version
    echo ">>> Reset complete: on branch 'develop' with clean 17-line routes/appVersion.ts."
    ;;

  *)
    usage
    exit 1
    ;;
esac
