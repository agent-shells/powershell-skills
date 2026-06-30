# Encoding

status: active

## Trigger

Use when output, paths, or inline code may contain non-ASCII text.

## Safe Shape

- For Python output, set `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1`.
- Prefer UTF-8 output where the tool supports it.
- Keep tests for Chinese output and paths.

## Failure Signals

- mojibake
- Unicode encode or decode exceptions
- non-ASCII output disappears or is replaced
