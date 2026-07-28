# TTY toolkit — component reference

Canonical upstream list: https://ttytoolkit.org/components/  
Toolkit home: https://ttytoolkit.org/

Install gems independently via RubyGems. Names below match published components.

| Gem | Role |
|-----|------|
| **pastel** | Terminal string styling API |
| **tty-box** | Frames and boxes |
| **tty-color** | Terminal color capability detection |
| **tty-command** | Shell commands with structured logging |
| **tty-config** | Read/write configuration for terminal apps |
| **tty-cursor** | Cursor movement/control |
| **tty-editor** | Open buffer/path in user editor |
| **tty-file** | File/directory helpers |
| **tty-font** | Large stylized terminal text |
| **tty-link** | Hyperlinks (OSC) |
| **tty-logger** | Structured terminal logging |
| **tty-markdown** | Markdown → terminal rendering |
| **tty-option** | CLI arguments/keywords/options |
| **tty-pager** | Cross-platform paging |
| **tty-pie** | Terminal pie charts |
| **tty-platform** | OS/platform detection |
| **tty-progressbar** | Progress bars (rates, ETA) |
| **tty-prompt** | Interactive prompts, lists, confirm |
| **tty-reader** | Keyboard input (char/line/multiline) |
| **tty-screen** | Terminal dimensions/properties |
| **tty-spinner** | Indeterminate activity indicator |
| **tty-table** | Columnar tables |
| **tty-tree** | Tree-structured printing |
| **tty-which** | Portable executable lookup |

## Composition notes

- **pastel** + **tty-box** + **tty-table** cover many “dashboard” static layouts; animation/diffing may still be custom.
- **tty-prompt** + **tty-reader** overlap with interactive flows—pick one primary input story per screen.
- **tty-screen** early in startup to enforce minimum size and choose layout breakpoints (see [tui-design-system](../tui-design-system/SKILL.md)).
- **tty-logger** suits service-style output; in-app “event log” panes may still need custom truncation/scrolling.

## Meta gem

**tty** — includes **`teletype`** project generator (see toolkit home Quick Start). Use when bootstrapping a new CLI; for existing apps, prefer direct component gems.
