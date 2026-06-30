# PowerShell Parser

status: active

## Trigger

Use when generating pipelines, script blocks, logical operators, or inline PowerShell.

## Safe Shape

- Assign statement output to a variable before piping when the parser rejects a direct shape.
- Wrap cmdlet calls in parentheses before using `-and` or `-or`.
- Prefer multi-line `.ps1` files for complex logic.

## Failure Signals

- `An empty pipe element is not allowed`
- `Unexpected token`
- `A positional parameter cannot be found that accepts argument`
