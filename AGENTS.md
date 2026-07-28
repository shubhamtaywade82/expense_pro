# ExpensePro AGENTS.md

## Rule Precedence Hierarchy
When generating, refactoring, or reviewing code in `expense_pro`, always follow this precedence order:
1. **User Explicit Directives**: Specific instructions given by the user in the prompt.
2. **Project Rules (`AGENTS.md` / `CLAUDE.md` / `.cursor/rules`)**: Repository-specific architectural invariants.
3. **Detected Project Profile**: Gemfile.lock realities (Rails version, test runner, DB adapter).
4. **Team Conventions**: Established code styling and folder organization in `app/`.
5. **External Domain Skills**: Patterns from `rails-architecture`, `rails-pattern-advisor`, `GoF`.

---

## Core Architecture Rules

- **Prefer composition over inheritance.**
- **Prefer Rails conventions over custom abstractions.**
- Controllers handle HTTP. Models handle domain/data. Services handle orchestration.
- Do not introduce a design pattern without naming the specific problem it solves.
- If a service object is under 80 lines and has one public method, it does not need a pattern (`NO_PATTERN`).
- New abstractions require specs. No exceptions.
- When uncertain, the answer is `NO_PATTERN`.

---

## Architecture Tools
- `bin/architecture_check <file_path>`: Diagnostic context & pattern advice for a single file.
- `bin/architecture_check --all`: Complete repository architecture audit and hotspot ranking.
- `bundle exec rake architecture:check`: Run Architecture Regression Gate.
