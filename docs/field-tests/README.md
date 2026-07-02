# Field Tests

This folder records real Codex and Claude Code pressure tests for first-pass command success on Windows.

The goal is to learn whether agents choose the right shell, path handling, encoding behavior, timeout behavior, and failure-retry strategy without being told exactly what command to run.

## Record Format

Each record should include:

- date
- agent surface and version
- operating system and shell context
- installed skill path
- task prompt summary
- expected first-pass behavior
- observed tool or command behavior
- result: pass, partial, fail, or blocked
- follow-up issue or PR, if needed

## First-Pass Success Criteria

A test counts as a first-pass success when the agent:

- loads or applies the relevant skill without user hand-holding
- chooses a Windows-appropriate command shape
- handles paths with spaces and non-ASCII characters safely
- avoids repeating the same failed command shape
- preserves permission boundaries
- reaches the requested result without needing corrective user intervention

## Do Not Store

Do not store raw user logs, secrets, tokens, private repository names, private file paths, proprietary source code, or unredacted customer data.
