# Python Scripts in Metool Packages

Conventions for Python scripts in metool packages.

## Package Manager

Use **uv** as the package manager for Python scripts.

## Inline Script Metadata (PEP 723)

Use inline script metadata to declare dependencies:

```python
#!/usr/bin/env python
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests", "click"]
# ///

import requests
import click

@click.command()
def main():
    # Script implementation
    pass

if __name__ == "__main__":
    main()
```

## File Naming

Scripts in `bin/` should have **no `.py` extension**:

```
package-name/
└── bin/
    ├── my-tool           # ✓ Correct
    └── my-tool.py        # ✗ Avoid
```

This keeps commands clean:
```bash
my-tool --help    # ✓ Clean
my-tool.py --help # ✗ Awkward
```

## Running Scripts

With uv, scripts run directly:

```bash
# uv handles dependency installation automatically
./bin/my-tool

# Or with explicit uv
uv run bin/my-tool
```

## Virtual Environments

For packages with many Python scripts sharing dependencies, consider a `pyproject.toml`:

```
package-name/
├── pyproject.toml
├── bin/
│   ├── tool-one
│   └── tool-two
└── src/
    └── package_name/
        └── __init__.py
```

## See Also

- [creation.md](creation.md) - Creating packages
- [structure.md](structure.md) - Package structure conventions
