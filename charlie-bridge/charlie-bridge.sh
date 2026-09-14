#!/usr/bin/env bash
set -euo pipefail

# Charlie Samsung bridge prototype.
# Polls a GitHub repo for open issues whose titles start with [CHARLIE],
# runs each issue body through Codex, posts the final response back to the issue,
# then closes the issue.
#
# SECURITY: By default this bridge refuses to use a public repository.
# Set CHARLIE_REPO to a PRIVATE repo, e.g. owner/charlie-samsung-bridge.

: "${CHARLIE_REPO:?Set CHARLIE_REPO to owner/repo for the PRIVATE task repo}"
: "${CHARLIE_WORKSPACE:=$HOME/charlie-workspace}"
: "${POLL_SECONDS:=60}"

mkdir -p "$CHARLIE_WORKSPACE"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is not installed." >&2
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: Codex CLI is not on PATH." >&2
  exit 1
fi

visibility="$(gh repo view "$CHARLIE_REPO" --json visibility --jq '.visibility')"
if [[ "$visibility" != "PRIVATE" && "${ALLOW_PUBLIC_REPO:-0}" != "1" ]]; then
  echo "ERROR: $CHARLIE_REPO is $visibility. Refusing to use a public repo as a task mailbox." >&2
  exit 1
fi

echo "Charlie bridge watching $CHARLIE_REPO every ${POLL_SECONDS}s"
echo "Workspace: $CHARLIE_WORKSPACE"

while true; do
  issue_number="$(gh issue list \
    --repo "$CHARLIE_REPO" \
    --state open \
    --search 'in:title "[CHARLIE]"' \
    --limit 1 \
    --json number \
    --jq '.[0].number // empty')"

  if [[ -n "$issue_number" ]]; then
    workdir="$CHARLIE_WORKSPACE/job-$issue_number"
    mkdir -p "$workdir"
    prompt_file="$workdir/prompt.txt"
    result_file="$workdir/result.txt"
    log_file="$workdir/codex.log"

    gh issue view "$issue_number" --repo "$CHARLIE_REPO" --json body --jq '.body' > "$prompt_file"

    # Mark the issue as picked up before starting.
    gh issue comment "$issue_number" --repo "$CHARLIE_REPO" \
      --body "Samsung bridge picked up this task and is running Codex." >/dev/null

    set +e
    (
      cd "$CHARLIE_WORKSPACE"
      # PRoot/Android currently prevents Codex's normal Linux sandbox from working reliably.
      # Therefore unattended execution requires the explicit danger-full-access bypass.
      # This is constrained operationally by running in a dedicated Linux workspace.
      codex exec \
        --skip-git-repo-check \
        --dangerously-bypass-approvals-and-sandbox \
        --output-last-message "$result_file" \
        - < "$prompt_file" > "$log_file" 2>&1
    )
    status=$?
    set -e

    if [[ $status -eq 0 && -s "$result_file" ]]; then
      gh issue comment "$issue_number" --repo "$CHARLIE_REPO" --body-file "$result_file" >/dev/null
      gh issue close "$issue_number" --repo "$CHARLIE_REPO" --reason completed >/dev/null
      echo "Completed task #$issue_number"
    else
      {
        echo "Samsung bridge failed to complete this task."
        echo
        echo "Exit code: $status"
        echo
        echo '```text'
        tail -n 80 "$log_file" 2>/dev/null || true
        echo '```'
      } > "$workdir/failure-comment.txt"
      gh issue comment "$issue_number" --repo "$CHARLIE_REPO" --body-file "$workdir/failure-comment.txt" >/dev/null
      echo "Task #$issue_number failed; left open for inspection."
    fi
  fi

  sleep "$POLL_SECONDS"
done
