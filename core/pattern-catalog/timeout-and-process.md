# Timeout And Process

status: active

## Trigger

Use for commands that may hang, spawn child processes, or produce large output.

## Safe Shape

- Set an explicit timeout for helper-managed execution.
- Capture stdout, stderr, exit code, and duration.
- Classify timeout separately from command failure.

## Failure Signals

- command never returns
- stdout and stderr are lost
- exit code is not available
