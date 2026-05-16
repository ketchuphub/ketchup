# Ketchup Website

Source for the MkDocs site that publishes your daily ketchup
reports at `https://<owner>.github.io/<repo>/`.

The reports themselves live in `../report/YYYYMMDD.md` and are
written by the ketchup pipeline.
A hook (`hooks/build_reports.py`) copies them into `docs/reports/`
at build time, so the source markdown stays untouched.

## Local Development

From the repo root:

```sh
make serve
```

Or from this directory:

```sh
make serve
```

Either auto-installs Python via Makes, creates a venv, installs
MkDocs + Material, and starts a livereload server at
`http://localhost:8000`.
The root URL redirects to the most recent report.

## Building

```sh
make build
```

Output goes in `site/`.

## Publishing

From the repo root:

```sh
make publish
```

Force-pushes the built `site/` to the `gh-pages` branch of
whatever URL `git remote get-url origin` returns (override with
`REPO=...`).
GitHub Pages serves from that branch.

The daily GitHub Actions workflow runs the same `make publish`
after each ketchup report, so this only needs to be invoked
manually for out-of-band updates or first-time bootstrap.
