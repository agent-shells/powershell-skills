# Contributing

Thanks for helping improve `powershell-skills`.

This project is for making AI agents more reliable on Windows and PowerShell. Contributions should improve first-pass command success, failure diagnosis, or adapter coverage without collecting private user context.

## Good Contributions

- Reproducible PowerShell 5.1 or PowerShell 7 compatibility fixes.
- New or improved tests in `core/tests/run-smoke.ps1`.
- Small, reviewed pattern catalog updates under `core/pattern-catalog/`.
- New sanitized failure corpus cases under `core/failure-corpus/cases/`.
- Adapter fixes for Codex, Claude Code, or future agent surfaces.
- Documentation that makes install, trigger, or safety behavior clearer.

## Failure Corpus Rules

Failure cases must be minimized and sanitized before they are submitted.

Do not submit:

- raw terminal logs
- secrets, tokens, cookies, API keys, or credentials
- private repository names
- private file paths that identify a person, customer, project, or company
- proprietary source code
- command history copied from a real user session without reduction

Preferred format:

1. Describe the failure class.
2. Include the smallest command shape that reproduces the issue.
3. Replace private paths with neutral placeholders such as `C:\Workspace\project`.
4. Add the expected safer command shape.
5. Add or update a smoke test when the behavior can be tested.

## Development

Run smoke tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\core\tests\run-smoke.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\core\tests\run-smoke.ps1 -PowerShellExe pwsh
```

Run release verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1 -PowerShellExe pwsh
```

## Pull Request Expectations

- Keep changes focused.
- Explain the failure mode or first-pass-success problem being addressed.
- Include verification output in the PR description.
- Do not add telemetry, automatic upload, or periodic collection behavior.
- Do not weaken destructive-operation validation.

## Scope Boundaries

This project does not bypass agent permissions, shell permissions, OS permissions, GitHub permissions, or workspace restrictions. Helpers and skills should make agent behavior safer and more predictable, not more privileged.
