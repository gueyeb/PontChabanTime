# PontChabanTime

Shows upcoming lift times for the [Pont Jacques-Chaban-Delmas](https://en.wikipedia.org/wiki/Pont_Jacques-Chaban-Delmas)
in Bordeaux, France. The bridge's central span lifts to let tall ships pass
underneath on the Garonne, closing the road while it does; this app's
homepage shows when that's scheduled to happen next.

## How it works

`app/models/bridge_lift.rb` fetches the schedule live from Bordeaux
Métropole's open data portal
([`previsions_pont_chaban`](https://opendata.bordeaux-metropole.fr/explore/dataset/previsions_pont_chaban/))
over HTTP, paging through the feed as needed. Nothing is persisted to this
app's own database — the portal is the authority on the schedule, so each
request just re-reads it (through a 15-minute `Rails.cache` cache, so we're
not hammering their API on every page view).

A few things worth knowing about the data:

* Closures that straddle midnight (e.g. closes 23:00, reopens 05:00 the
  next day) are handled explicitly — see the "rolls the reopening time"
  test in `test/models/bridge_lift_test.rb`.
* `MAINTENANCE` entries aren't a real ship; `BridgeLift#maintenance?` and
  the `HomeHelper#vessel_label` helper turn that into "Travaux de
  maintenance" in the UI instead of showing the raw feed value.
* Multiple vessels can share one closure window (the feed joins their
  names with " - "); `BridgeLift#vessels` splits that back out.
* If the feed can't be reached, `BridgeLift.upcoming` returns `nil` rather
  than an empty array, so `HomeController` can tell "nothing scheduled"
  apart from "data temporarily unavailable" and the homepage shows the
  right message for each case instead of silently claiming there's
  nothing planned.

The homepage (`app/controllers/home_controller.rb`,
`app/views/home/index.html.erb`) highlights the single next closure and
lists the ones after it in a table. `config.time_zone` is set to
`Europe/Paris` since the feed's times are local, unqualified `HH:MM`
values.

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
Since the bridge data comes from a live external API, a deployed instance
just needs normal outbound internet access — no extra credentials or
network allowlisting.

## Background jobs, cache, and WebSockets

Solid Queue, Solid Cache, and Solid Cable are configured for production,
backed by SQLite databases in `storage/`. No Redis or other external
service is required. Run the job worker in production with:

```bash
bin/jobs
```
