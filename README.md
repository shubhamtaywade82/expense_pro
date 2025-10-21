# ExpensePro (Rails 8)

ExpensePro is currently a clean Rails 8.0.3 scaffold running on Ruby 3.3.4. Use this baseline to rebuild the application with the latest framework features while keeping the original finance tracking goals in mind.

## Prerequisites
- Ruby 3.3.4 (see `.ruby-version`; install via RVM, asdf, or ruby-install).
- Node.js 22.14.0 and Yarn 1.22.x for asset builds.
- PostgreSQL 13+.
- Redis is optional; enable it when you add background workers or caching.

Install gem and JavaScript dependencies:
```bash
bundle install
yarn install
```

## Local Development
1. Copy secrets: `cp config/master.key.example config/master.key` (or generate new credentials with `bin/rails credentials:edit`).
2. Configure `config/database.yml` (or export `DATABASE_URL`).
3. Prepare the database: `bin/rails db:prepare`.
4. Start the dev server with JS/CSS watchers: `bin/dev` then visit `http://localhost:3000`.

### Testing & Quality
- Run the test suite: `bin/rails test` (add `test:system` once you create system specs).
- Run RuboCop and Brakeman via CI or locally (`bin/rubocop`, `bin/brakeman`).

## Docker Workflow
Build the production image and run it against PostgreSQL (local or managed):
```bash
docker build -t expense_pro:latest .
docker run --rm \
  -p 3000:80 \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e DATABASE_URL=postgres://postgres:password@host.docker.internal:5432/expense_pro_production \
  expense_pro:latest
```
Adjust `DATABASE_URL` for your environment and supply any additional settings (e.g., `RAILS_LOG_TO_STDOUT=1`). The image starts via `./bin/thrust ./bin/rails server` and runs `db:prepare` automatically on boot.

For a compose-based workflow, pair this container with a `postgres:16` service and share the master key via `.env` or Docker secrets.

## Next Steps
Recreate domain models, controllers, and views as needed. Keep the provided headings in `AGENTS.md` up to date so contributors know where new modules belong and how to work with the refreshed toolchain.
