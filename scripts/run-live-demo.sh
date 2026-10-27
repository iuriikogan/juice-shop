#!/usr/bin/env bash
# Interactive 2-Part Live Demo Runner for iuriikogan/juice-shop:
# Part 1: Fast pre-commit hook on ONLY staged files (Semgrep Secrets + cm find --diff --staged --diff-depth=0)
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
  part1-precommit  Stage a clean change to routes/appVersion.ts and run `git commit` -> Shows Semgrep + `cm find --diff --staged --diff-depth=0` passing fast on only the staged file
  part2-stage-vuln Stage a CRITICAL OS Command Injection flaw in routes/appVersion.ts (ready to commit with `--no-verify` and open a PR for CI/CD autofix)
  reset            Restore routes/appVersion.ts to clean state
EOF
}

case "${1:-}" in
  part1-precommit)
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
    write_clean_app_version
    echo ">>> [Demo Part 2] Introducing a CRITICAL OS Command Injection vulnerability in routes/appVersion.ts..."
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
    echo ">>> Staged vulnerable routes/appVersion.ts."
    echo ">>> To bypass pre-commit and trigger the CI/CD Gate + Autofix PR on GitHub:"
    echo "    git checkout -b demo/critical-cmd-injection"
    echo "    git commit --no-verify -m 'feat: add node diagnostics endpoint'"
    echo "    git push -u origin demo/critical-cmd-injection"
    ;;

  reset)
    git reset HEAD routes/appVersion.ts 2>/dev/null || true
    write_clean_app_version
    echo ">>> Reset routes/appVersion.ts to clean state."
    ;;

  *)
    usage
    exit 1
    ;;
esac
