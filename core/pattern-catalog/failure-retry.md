# Failure Retry

status: active

## Trigger

Use after one command failure or before retrying a similar command.

## Safe Shape

- Classify the failure before retrying.
- Change the command shape after a parser, quoting, path, or encoding failure.
- Stop after the second failed shape and report the blocker.

## Failure Signals

- same command text is retried unchanged
- shell mismatch persists after the first error
- missing tool is called repeatedly
