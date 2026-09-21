# Airlock for Homebrew

[Airlock](https://useairlock.app) lives in your Mac's notch: clipboard history,
a shelf for files, sound, meetings, and approvals for Claude Code and Codex.

```bash
brew install --cask gdelolmo7/tap/airlock
```

Needs a Mac with a notch running macOS 26 or later. 14 days free, then a
subscription; see [useairlock.app](https://useairlock.app).

## Updates

Airlock updates itself, so `brew upgrade` leaves it alone unless you pass
`--greedy`. This tap follows every release on its own: a few times a day it
checks for a new version and only moves to it once the download is notarized
by Apple and signed by Airlock's developer certificate.

## Uninstalling

```bash
brew uninstall --cask airlock          # removes the app
brew uninstall --cask --zap airlock    # also removes its settings and history
```

Neither touches `~/Airlock` (your shelf and agent workspace) or `~/.airlock`
(your approval rules). To disconnect Claude Code and Codex first, use
Airlock's Settings before uninstalling.

Questions: hello@useairlock.app
