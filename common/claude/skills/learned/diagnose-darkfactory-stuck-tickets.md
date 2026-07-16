# Diagnosing stuck dark-factory (dmtools) Jira tickets via GitHub Actions logs

**Extracted:** 2026-05-25
**Context:** A dmtools/dark-factory pipeline (SM orchestrator + `ai-teammate` workflow) drives Jira tickets through stages. A ticket "hangs" in a column for days. You have `gh` CLI access to the host repo but NO direct Jira access.

## Problem
Tickets sit in one Jira status indefinitely. The `ai-teammate` runs show `success`, so nothing looks broken — yet nothing moves. You need the root cause without Jira credentials.

## Solution
Reconstruct the whole pipeline state from GitHub Actions logs:

1. **Map runs → tickets via artifact name.** Each `ai-teammate` run uploads an artifact `ai-teammate-BBP-<N>`. List recent runs and resolve the ticket each handled:
   ```bash
   for id in $(gh run list --repo OWNER/REPO --workflow ai-teammate --status completed --limit 25 --json databaseId --jq '.[].databaseId'); do
     echo "$id -> $(gh api repos/OWNER/REPO/actions/runs/$id/artifacts --jq '.artifacts[0].name')"
   done
   ```
   **Signal:** the SAME ticket reappearing in every batch = it never advances → it's looping (stuck), not progressing.

2. **Read the SM orchestrator log to see the rule set + verdicts.** SM logs every JQL it scans (the exact set of statuses it handles) and, for `localExecution` rules, the decision inline:
   ```bash
   gh run view <SM_RUN_ID> --repo OWNER/REPO --log | sed -E 's/^[a-z-]*\t[^\t]*\t[0-9T:.-]*Z //' \
     | grep -iE "status in|══|done check|not.*done|waiting|→|skip|releasing lock"
   ```
   - If a ticket's status has NO matching JQL rule → it's orphaned (no handler). (Grep the WHOLE log — rules span many lines; a truncated grep can falsely "miss" a rule.)
   - Container `Task` tickets use `task_done_check` → `checkTaskStoriesDone.js`: a Task only leaves `In Progress`/`In Development` once ALL linked Stories/Bugs are `Done`. Look for `Stories/Bugs not yet Done: X / Y` → the parent is just *waiting on children*, not broken. The lock is released each cycle (`jira_remove_label sm_task_done_check_triggered`) — that's healthy.

3. **Read an `ai-teammate` run log to find the stage + blocker.** The dispatched stage is in the run's `CONFIG_FILE` / `ENCODED_CFG` (e.g. `pr_test_automation_rework.json`). Grep the tail for the verdict (PR created, tests passed/failed, error):
   ```bash
   gh run view <RUN_ID> --repo OWNER/REPO --log | sed -E 's/^[a-z-]*\t[^\t]*\t[0-9T:.-]*Z //' \
     | grep -iE "CONFIG_FILE|response\.md|Pull request|PR #|Passed|Failed|playwright test failed|rework|::error|transition" \
     | grep -viE "DEBUG|Exposed MCP|Converting|Final args"
   ```

## Example: the actual root cause found
Chain: `Task (BBP-2/4/6) waits for children → Stories/Bugs wait for Test Cases → Test Cases run Playwright E2E → E2E fails`. The `ai-teammate` PR body said it plainly: *"Expo web bundle requires `EXPO_PUBLIC_SUPABASE_URL`/`ANON_KEY` at startup — not available as CI secrets."* So Test Cases never reach `Passed` → infinite `pr_test_automation_rework` loop (the agent "fixes" test code, but the real problem is missing CI env). Fix = add the secrets AND wire them into the workflow `env:` block (a secret alone isn't visible to the step).

## When to Use
- A Jira ticket in a dmtools/dark-factory project hasn't moved for a long time.
- `ai-teammate` runs are green but tickets don't advance, or the same tickets reappear in every scheduled batch.
- You need to diagnose pipeline state and have `gh` (read) access but no Jira access.
- Key mental model: **parents wait on children; the real blocker is usually at the deepest stage (test automation / E2E / merge), and a green run can still mean "no progress".** Also: a missing CI secret causes endless rework, not a hard failure.
