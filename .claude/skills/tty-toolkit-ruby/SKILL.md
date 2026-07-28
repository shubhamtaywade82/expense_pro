---
name: tty-toolkit-ruby
description: >-
  Maps Ruby TTY ecosystem gems to terminal UI needs (styling, boxes, tables,
  prompts, spinners, input, screen size, logging). Use when building or
  refactoring Ruby CLIs/TUIs, choosing gems for terminal output, or integrating
  with the TTY toolkit. Official index: https://ttytoolkit.org/components/ and
  https://ttytoolkit.org/ — read reference.md for the full component catalog.
---

# TTY toolkit (Ruby)

## Sources of truth

- **Ecosystem hub:** https://ttytoolkit.org/
- **Component list:** https://ttytoolkit.org/components/

Each gem is **independent**; install only what you need via RubyGems (e.g. `gem install tty-prompt` or add to `Gemfile`).

## Need → gem (quick map)

| Need | Gem | Notes |
|------|-----|------|
| String colors/styles | **pastel** | Prefer semantic wrappers in app code, not raw hex everywhere |
| Frames/borders | **tty-box** | Panels, titled regions |
| Color capability detect | **tty-color** | Degrade palette tier |
| Run shell commands w/ logging | **tty-command** | Audited subprocess UX |
| App config load/save | **tty-config** | Terminal-friendly config |
| Cursor positioning | **tty-cursor** | Low-level; use carefully with other libs |
| Open user’s editor | **tty-editor** | `$EDITOR` integration |
| File/dir helpers | **tty-file** | CLI utilities |
| Large banner text | **tty-font** | Headers / branding |
| OSC hyperlinks | **tty-link** | Clickable URLs in supported terminals |
| Structured terminal logs | **tty-logger** | Levels, formatting |
| Markdown → terminal | **tty-markdown** | Docs/help in-app |
| CLI options/keywords | **tty-option** | Argument parsing |
| Paged output | **tty-pager** | Long text, cross-platform |
| Terminal pie charts | **tty-pie** | Sparse dashboards |
| OS detection | **tty-platform** | Conditional behavior |
| Determinate progress | **tty-progressbar** | ETA, rates |
| Interactive prompts/menus | **tty-prompt** | Lists, masks, confirm |
| Keyboard input modes | **tty-reader** | Char/line/multi-line |
| Terminal size/props | **tty-screen** | Rows/cols, capabilities |
| Indeterminate wait | **tty-spinner** | After short delay to avoid flash |
| Tabular data | **tty-table** | Align numbers, truncation |
| Tree output | **tty-tree** | Hierarchies |
| `which` portability | **tty-which** | Resolve executables |

## Compose with design rules

When building a full TUI (custom layout loop, panels, global keys), pair gem choice with **[tui-design-system](../tui-design-system/SKILL.md)**—especially **semantic color**, **focus**, **resize**, and **help tiers**.

## Scaffold

The meta **`tty`** gem provides the **`teletype`** generator for new CLI apps: https://ttytoolkit.org/ (Quick Start). Prefer adding **focused components** over pulling the entire suite unless you need the generator.

## Reference

Alphabetical one-liners and pairing tips: **[reference.md](reference.md)**
