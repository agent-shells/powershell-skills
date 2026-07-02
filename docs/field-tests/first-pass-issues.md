# First-Pass Command Success Issues

Track real cases where an agent did not choose the right command shape on the first try.

## Open

| ID | Surface | Scenario | Result | Follow-up |
| --- | --- | --- | --- | --- |
| FPS-001 | Codex desktop | Fresh-session automatic skill trigger after restart | Pending | Run after Codex desktop restart |
| FPS-002 | Claude Code | `--bare` mode slash command `/powershell-command-runner` | Known limit | Do not treat `--bare` as v0.3 acceptance path |

## Closed

| ID | Surface | Scenario | Result | Fixed or Verified In |
| --- | --- | --- | --- | --- |
| FPS-000 | Claude Code | Normal mode Windows path with space and Chinese characters | Pass | v0.3 |
