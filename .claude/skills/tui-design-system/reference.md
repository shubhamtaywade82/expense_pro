# TUI design system — reference

Expanded patterns, examples, and checklists. Keep **SKILL.md** as the default; open this file when implementing details.

## Persistent multi-panel (concept)

```
┌─ Status ──┬─────────── Detail ──────────┐
├─ Files ───┤                              │
│ > file.rs │  diff content here...        │
│   main.rs │                              │
├─ Branches ┤                              │
│ * main    │                              │
└───────────┴──────────────────────────────┘
  [q]uit [c]ommit [p]ush [?]help
```

Use when users need **simultaneous context** (git, containers, trading dashboards). **Never** swap panel roles between runs without explicit user action.

## Miller columns (concept)

Parent | current | preview. Preview content **adapts to selection type** (text vs tree vs metadata).

## Drill-down stack

Enter descends, Esc ascends. Always show **breadcrumbs** or path. Offer **command mode** (`:`) for jumps.

## Widget dashboard

Independent titled widgets; often **sparklines**, bars, gauges. Each widget owns its title and refresh cadence.

## IDE three-panel

Sidebar (toggle), main/tabs, bottom output/detail. Bottom may expand.

## Overlay / popup

Shell augmentation: bounded height, **return selection to caller**, avoid trashing scrollback.

## Header + scrollable list

Fixed header (stats/filters), scrollable body, footer keys. Sort by the **most actionable** dimension by default.

## Search and filtering

- `/` opens search; **Esc** dismisses.
- **n / N** next/prev match when applicable.
- Prefer **fuzzy** default; document exact-match prefix if supported.
- Highlight matches; keep preview in sync with selection.

## Dialogs and confirmations

| Severity | Pattern |
|----------|---------|
| Reversible | Act + status/toast |
| Moderate | Inline y/n |
| Severe | Modal + explicit confirm (typed name, etc.) |
| Batch irreversible | `--dry-run` + explicit confirm |

Modals: dim background, trap focus. Toasts: short TTL, no required interaction.

## Data visualization (character building blocks)

| Element | Characters | Use |
|---------|------------|-----|
| Fine bars | █▉▊▋▌▍▎▏ | Progress, micro charts |
| Shades | ░▒▓█ | Heat/density |
| Braille | U+2800–28FF | Higher-res spark/line |
| Sparkline | ▁▂▃▄▅▆▇█ | Inline series |

**Spinners:** use for **indeterminate** work; **progress bars** for determinate. Delay spinner ~200ms to avoid flash.

## Animation rules

- **Never** delay or queue user input behind transitions—**cancel** animation and handle the key.
- Panel resize: **reflow immediately** (0ms “animation”).
- Dashboard charts: optional smooth value change (short window), capped refresh rate.

## Seven principles (compact)

1. **Keyboard-first**, mouse optional.
2. **Spatial consistency** — stable landmarks.
3. **Progressive disclosure** — footer → `?` → docs.
4. **Async** — background work + cancel.
5. **Semantic color** — meaning, not decoration.
6. **Contextual intelligence** — footers/bindings match mode/panel.
7. **Design in layers** — monochrome → 16-color → truecolor; each tier must stand alone.

## Anti-pattern checklist (ranked)

| # | Pitfall | Mitigation |
|---|---------|------------|
| 1 | Colors break across terminals | 16-color baseline; test multiple emulators/themes |
| 2 | Flicker / full redraw | Buffer/diff/batch writes where applicable |
| 3 | Hidden bindings | Context footer + `?` + optional which-key style |
| 4 | Windows/WSL issues | Test Windows Terminal; cautious Unicode |
| 5 | Unicode inconsistency | Prefer box-drawing + blocks; limit emoji |
| 6 | Multiplexer breakage | Test tmux/zellij; mouse vs selection |
| 7 | Accessibility | NO_COLOR, no color-only meaning |
| 8 | Blocking UI | Feedback <100ms; async + progress |
| 9 | Modal confusion | Status shows mode; cursor/style hints |
| 10 | Over-chrome | Borders/color serve content |

## Compatibility checklist (before ship)

- [ ] Works at minimum size (often 80×24)
- [ ] Resize-safe (no crash)
- [ ] Dark **and** light themes acceptable
- [ ] Respects `NO_COLOR`
- [ ] tmux / zellij / screen sanity
- [ ] SSH-safe (no local-only assumptions)
- [ ] Mouse does not break selection (e.g. Shift+click)
- [ ] Fully keyboard-accessible
- [ ] No escape leaks when piped/non-TTY
- [ ] Clean exit restores terminal (Ctrl+C/SIGINT)

## Related

- Ruby gem mapping: [tty-toolkit-ruby](../tty-toolkit-ruby/SKILL.md)
- TTY component index: https://ttytoolkit.org/components/
