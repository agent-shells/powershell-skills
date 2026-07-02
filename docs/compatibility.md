# Compatibility and Verification

`powershell-skills` treats Windows PowerShell 5.1 and PowerShell 7 as first-class targets.

## Matrix

| Surface | Host | Status |
| --- | --- | --- |
| Windows PowerShell 5.1 | `powershell.exe` | Tested in GitHub Actions |
| PowerShell 7 | `pwsh` | Tested in GitHub Actions |
| npm CLI | Node.js 18+ | Smoke-tested locally and in release verification |
| Codex adapter | user skill path | Installed and verified by release checks |
| Claude Code adapter | personal skill path | Installed and verified by release checks |

## Design Rules

- Helper scripts avoid PowerShell 7-only syntax unless a host-specific path is explicitly tested.
- JSON handling must be checked on both 5.1 and 7.
- Path operations prefer `-LiteralPath` when handling user or workspace paths.
- External process invocation must account for Windows `.cmd` shims.
- Encoding-sensitive output should be captured as UTF-8 where the host allows it.

## Local Verification

Run the npm smoke test:

```powershell
npm test
```

Run release verification on Windows PowerShell 5.1:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1
```

Run release verification on PowerShell 7:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1 -PowerShellExe pwsh
```

Run a package dry run:

```powershell
npm pack --dry-run
```

## CI

GitHub Actions runs the verification suite on `windows-latest` with both:

- `powershell.exe`
- `pwsh`

Compatibility is not considered complete unless the matrix passes.
