# docs-governance-platform

Central platform for docs governance: reusable workflows + composite actions.

## Usage

### docs-checks (PR validation)

```yaml
# .github/workflows/docs-checks.yml
name: docs-checks
on:
  pull_request:
    paths: ['docs/**', 'work/**', 'src/**']
jobs:
  checks:
    uses: Royyyylin/docs-governance-platform/.github/workflows/docs-checks.yml@main
    with:
      code_impact_patterns: 'src/*|lib/*|Makefile'
      docs_not_needed_label: 'docs-not-needed'
```

### docs-staleness (weekly archive)

```yaml
name: docs-staleness
on:
  schedule:
    - cron: '0 9 * * 1'
  workflow_dispatch: {}
jobs:
  archive:
    uses: Royyyylin/docs-governance-platform/.github/workflows/docs-staleness.yml@main
```

### docs-index-update (auto-index on merge)

```yaml
name: docs-index-update
on:
  push:
    branches: [main]
    paths: ['docs/current/**', 'docs/adr/**', 'docs/domain/**']
jobs:
  update:
    uses: Royyyylin/docs-governance-platform/.github/workflows/docs-index-update.yml@main
```

## Composite Actions

| Action | Description |
|--------|-------------|
| `actions/frontmatter-check` | Validate YAML frontmatter in docs |
| `actions/impact-check` | Ensure code changes update docs |
| `actions/index-gen` | Regenerate docs/index.md |

## Architecture

```
Caller repo                    This repo (platform)
─────────                      ────────────────────
.github/workflows/             .github/workflows/
  docs-checks.yml ──uses──→      docs-checks.yml (reusable)
  docs-staleness.yml ──uses──→   docs-staleness.yml (reusable)
  docs-index-update.yml ──uses→  docs-index-update.yml (reusable)

                               actions/
                                 frontmatter-check/  (composite)
                                 impact-check/       (composite)
                                 index-gen/          (composite)
```
