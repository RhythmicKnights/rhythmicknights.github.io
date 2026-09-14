# Charlie Samsung bridge prototype

This branch contains a prototype bridge for the Samsung A53 Ubuntu/Termux Codex setup.

## Goal

Use a private GitHub repository as a task mailbox:

1. ChatGPT/Charlie creates an issue whose title begins with `[CHARLIE]`.
2. The Samsung bridge notices the issue.
3. The Samsung runs the issue body through `codex exec`.
4. The bridge posts Codex's final response back to the issue and closes it.
5. ChatGPT/Charlie can read the result through the connected GitHub account.

## Important security constraint

The task mailbox must be **private**. The bridge refuses to run against a public repo unless `ALLOW_PUBLIC_REPO=1` is deliberately set.

The Samsung A53 PRoot environment currently prevents Codex's normal Linux sandbox from working reliably. For unattended jobs, the prototype therefore uses Codex's explicit `--dangerously-bypass-approvals-and-sandbox` mode. This should only be enabled in a dedicated workspace with no sensitive files mounted into it. Do not expose Android shared storage, passwords, bank data, or unrelated personal files to this workspace.

## One-time Samsung requirements

- Ubuntu under Termux/PRoot
- Codex CLI already signed in
- GitHub CLI (`gh`) installed and signed in
- A private GitHub repo dedicated to the bridge
- `CHARLIE_REPO` set to that private repo
- Bridge script copied to the Samsung and started

Later hardening should include a dedicated non-root Linux user, restricted workspace permissions, Android battery-exemption/wakelock handling, startup automation, and logging/health checks.
