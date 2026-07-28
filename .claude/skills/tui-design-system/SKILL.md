---
name: tui-design-system
description: >-
  Provides framework-agnostic patterns for keyboard-centric terminal UIs—layouts,
  resize behavior, focus, keybindings, semantic color tiers, data density, and
  shipping checklists. Use when designing TUIs, terminal dashboards, panel
  layouts, split panes, color themes, keybinding design, Ratatui, Ink, Textual,
  Bubbletea, Ruby TTY, modal flows, footers/help layers, or terminal
  accessibility. Read reference.md for full tables, ASCII examples, and
  anti-patterns.
---

# TUI design system

## Philosophy

TUIs earn trust through **spatial consistency**, **keyboard fluency**, and **information density** that respects attention. Design for expert speed without hiding the path for beginners.

Official Ruby terminal building blocks (when stack is Ruby): see [tty-toolkit-ruby](../tty-toolkit-ruby/SKILL.md) and https://ttytoolkit.org/components/

## Design process

1. **What are you building?** — Pick the primary user job (browse, monitor, edit, review logs).
2. **Layout paradigm** — Match paradigm to the job (see below).
3. **Interaction model** — Focus rules, modes (if any), search, help tiers.
4. **Visual system** — Semantic color slots, typography hierarchy, NO_COLOR path.
5. **Validate** — Run the anti-pattern and compatibility checklists in [reference.md](reference.md).

## Layout paradigm selector

| App type | Paradigm | Examples |
|----------|-----------|----------|
| File manager | Miller columns | yazi, ranger |
| Git / DevOps | Persistent multi-panel | lazygit, lazydocker |
| System monitor | Widget dashboard | btop, bottom |
| K8s / deep hierarchy | Drill-down stack | k9s |
| SQL / HTTP client | IDE three-panel | harlequin-style |
| Shell augmentation | Overlay / popup | fzf, atuin |
| Logs / events | Header + scrollable list | htop, tig |

**Rules:** Panels keep **fixed positions** across sessions unless the user changes layout. Multi-panel tools rely on spatial memory—do not reshuffle casually.

## Responsive terminals

- Prefer **proportional splits** (ratios), **min/max constraints**, not hard-coded absolute layout.
- Define a **minimum size** (often 80×24); below usable threshold, show a clear “terminal too small” message instead of corrupting UI.
- **Never crash on resize**; handle `SIGWINCH` (or framework equivalent).
- Test at **80×24**, **120×40**, **200×60**; verify **tmux/zellij** if users run there.

## Interaction model

### Keybinding layers (progressive disclosure)

| Layer | Keys | Shown where |
|-------|------|-------------|
| L0 Universal | arrows, Enter, Esc, q | Footer always |
| L1 Vim-style | hjkl, /, ?, :, g/G | Footer or contextual help |
| L2 Actions | mnemonics (d, c, p, …) | Context help (`?`) |
| L3 Power | compositions, macros | Docs only |

**Lingua franca:** `j/k` down/up, `h/l` left/right or collapse/expand, `/` search, `?` help, `:` command mode, `q` quit or back, `Tab` focus, `Space` toggle, `g/G` top/bottom.

**Avoid stealing:** Ctrl+C (interrupt), Ctrl+Z (suspend), Ctrl+\ (quit signal)—these belong to the shell.

### Focus

- One focused widget receives keys; **Tab** / **Shift+Tab** cycle.
- **Visible focus**: border, color, or cursor—unfocused panels may dim.
- **Modals** trap focus; background does not receive input until dismissed.

### Help tiers

1. **Footer** — 3–5 actionable shortcuts for the current context.
2. **`?` overlay** — Full bindings for this view/mode.
3. **`--help` / man** — Complete reference.

## Color system

### Capability tiers (detect, degrade gracefully)

1. **16 ANSI** — Must remain usable; theme controls look.
2. **256** — Extended palette; fixed indices may clash with themes.
3. **True color** — Only when `COLORTERM` / terminal supports it; never required for hierarchy.

Respect **`NO_COLOR`**. If color is removed, meaning must survive via **labels, symbols, position, weight**.

### Semantic slots (name by role, not hex in widgets)

Examples: `fg.default`, `fg.muted`, `fg.emphasis`, `bg.base`, `bg.surface`, `bg.overlay`, `bg.selection`, `accent.primary`, `accent.secondary`, `status.error|warning|success|info`.

**Never use color alone** for state—pair with text or symbols. Prefer **reverse video** for selection when you need universal contrast.

## Motion and refresh

- **Selection moves** — instant (do not animate).
- **Dashboards** — cap refresh (~15–30 FPS), prefer **diffed** updates to reduce flicker.
- **Do not block** the UI on I/O; show spinner/progress **after ~200ms** if still pending.
- Prefer **double-buffering / batched writes** when implementing raw rendering.

## When to read more

- Full ASCII layout sketches, data-viz character sets, expanded anti-pattern list, and ship checklist: **[reference.md](reference.md)**

## Attribution

Design structure synthesizes common TUI UX practice and community “TUI design system” style guidance; adapted for local agent use. Ruby component mapping lives in the sibling **tty-toolkit-ruby** skill.
