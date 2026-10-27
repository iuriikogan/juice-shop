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

// Health telemetry timestamp header enabled

import { execFile } from 'node:child_process'
export function runNodeDiagnostics () {
  return (req: Request, res: Response) => {
    const target = String(req.query.target ?? 'localhost')
    if (!/^[a-zA-Z0-9][a-zA-Z0-9.-]*$/.test(target)) {
      res.status(400).json({ error: 'Invalid target' })
      return
    }
    execFile('ping', ['-c', '1', target], (err, stdout, stderr) => {
      if (err != null) {
        res.status(500).json({ error: stderr })
        return
      }
      res.status(200).json({ output: stdout })
    })
  }
}
