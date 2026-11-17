# PontChabanTime

A Ruby on Rails application. The project is currently a fresh Rails skeleton — no
application-specific models, controllers, or views have been written yet.

## Tech stack

* Ruby 3.3.6 (see `.ruby-version`)
* Rails 8.1
* SQLite (via the `storage/` directory, including separate databases for
  Solid Cache, Solid Queue, and Solid Cable)
* Hotwire (Turbo + Stimulus) with import maps for JavaScript — no Node/Yarn
  build step required
* Propshaft for the asset pipeline

## Getting started

```bash
bin/setup
```

This installs gems, prepares the database, and clears logs/tmp files. Then
start the app with:

```bash
bin/rails server
```

and visit `http://localhost:3000`.

## Running tests

```bash
bin/rails test            # unit/integration tests
bin/rails test:system     # browser-driven system tests
```

## Code quality & security checks

The same checks run in CI (see `.github/workflows/ci.yml`):

```bash
bin/rubocop               # style (Omakase Rails style)
bin/brakeman               # static security analysis
bin/bundler-audit          # known CVEs in Ruby gems
bin/importmap audit        # known CVEs in pinned JS packages
```

Dependabot (`.github/dependabot.yml`) checks weekly for outdated gems and
GitHub Actions and opens PRs automatically.

## Deployment

The app ships with a [Kamal](https://kamal-deploy.org) configuration
(`config/deploy.yml`, `.kamal/`) for deploying as a Docker container to any
server. Update the placeholder server/registry details before using it.

## Background jobs, cache, and WebSockets

Solid Queue, Solid Cache, and Solid Cable are configured for production,
backed by SQLite databases in `storage/`. No Redis or other external
service is required. Run the job worker in production with:

```bash
bin/jobs
```
