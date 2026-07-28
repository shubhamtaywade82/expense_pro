---
name: pine-paths
description: Use when any pine-* skill (pine-developer, pine-visualizer, pine-debugger, pine-backtester, pine-optimizer, pine-manager, pine-publisher) references paths like /docs, /projects, /templates, or /examples. Resolves those relative roots to the absolute pinescript-agents install and points to the indicators/strategies collection in the parent repo.
---

# Pine Script Path Anchor

Sibling pine-* skills use repo-relative paths (`/docs/...`, `/projects/...`, `/templates/...`, `/examples/...`). Resolve them as:

## Absolute roots

- **pinescript-agents root**: `/home/nemesis/project/trading-workspace/pinescript/pinescripts-collections/pinescript-agents`
- **collections repo root**: `/home/nemesis/project/trading-workspace/pinescript/pinescripts-collections`

## Path mapping

| Skill reference | Absolute path |
|---|---|
| `/docs/...` | `<agents>/docs/...` |
| `/projects/...` | `<agents>/projects/...` |
| `/templates/...` | `<agents>/templates/...` |
| `/examples/...` | `<agents>/examples/...` |
| `blank.pine` | `<agents>/projects/blank.pine` |
| analyzer output | `<agents>/projects/analysis/` |

Where `<agents>` = pinescript-agents root above.

## Collection layout (parent repo)

Reference, not scratch space:

- `<repo>/indicators/<domain>/*.pine` — published indicators (whales, smc, trendlines, htf-volume, utilities)
- `<repo>/strategies/<domain>/*.pine` — strategies
- `<repo>/CLAUDE.md` — repo-specific hard rules (Pine v6 line-continuation, no `plot()` in local scope, engine limits)

## Rules

- WIP / scratch goes to `<agents>/projects/`, never `indicators/` or `strategies/`.
- Edits to existing collection files stay in their original location.
- YouTube ingestion: `python3 <agents>/tools/video-analyzer.py "<url>"`.
- Read `<repo>/CLAUDE.md` first when working in this repo — it overrides upstream onboarding directives.

## Verify before recommending

Symlinks point at the live repo. If the user has moved or deleted the repo, `ls <agents>` will fail — surface that instead of guessing.
