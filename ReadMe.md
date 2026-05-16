# ketchup

> Catch up with what's going on in your world -- open-source edition.

Ketchup is a daily newspaper for the projects you care about.
Every morning a small AI agent scans the repos on your watchlist,
picks out what's actually new (fresh issues, in-flight PRs, releases,
discussions worth knowing about) and writes a single short markdown
report.
Each item is a GitHub-style checkbox, so the report doubles as a
to-do list.
Tick what you've handled and ketchup quietly stops bringing it up.

This is the **starter template**.
It's a working scaffold you can use to publish your own ketchup feed:
a daily report committed to your repo, plus an optional GitHub Pages
site that lets you browse the archive.

If you want to see what a personal ketchup feed looks like in
practice, peek at
[ingydotnet/ketchup](https://github.com/ingydotnet/ketchup).
The engine that drives all of this lives at
[ketchuphub/ketchup-action](https://github.com/ketchuphub/ketchup-action).

## What you get

- A GitHub Action wired to a daily cron that produces
  `report/YYYYMMDD.md` and commits it.
- An [MkDocs](https://www.mkdocs.org/) +
  [Material](https://squidfunk.github.io/mkdocs-material/) site in
  `www/` that publishes your reports at
  `https://<you>.github.io/ketchup/`, with a homepage that
  redirects to today's report.
- A small `Makefile` for running everything locally: generate a
  report, serve the site, push secrets to the Action.
- Sensible defaults you can tweak: which projects to track, how
  far back to look, how aggressively to dedupe.

## Quick start

You need two local files before you start:

- `~/.claude/.credentials.json` -- Claude OAuth creds (the file
  Claude Code maintains).
  Using a Claude Max subscription this way means the daily run does
  not bill API usage.
- `~/.github-tokens/ketchup` -- a fine-grained GitHub PAT.
  See [Secrets](#secrets) for the exact scopes;
  `make update` errors with the same instructions if the file is
  missing.

Then:

1. Click the "**Use this template**" button at the top of this page
   to create your own `<you>/ketchup` repository, then clone it.
2. Edit `ketchup.yaml` with the projects you want to track.
3. Run `make update`.
   It substitutes the `OWNER`/`REPO` placeholders in
   `www/mkdocs.yaml`, pushes both secrets, creates the `gh-pages`
   branch, and enables GitHub Pages.
   Review the change (`git diff www/mkdocs.yaml`), then commit and
   push.
4. Run the command `make run` to create your first ketchup report.
5. Visit `https://<you>.github.io/ketchup/` to see it in the new
   website.
6. Visit it again tomorrow to see the second edition.

## Configure

### `ketchup.yaml`

The list of projects to track and a couple of knobs that control
how aggressively ketchup dedupes items between days.

```yaml
default model: sonnet
lookback days: 30
dedup days: 7

project repos:
- https://github.com/owner/repo-a
- repo: https://github.com/owner/repo-b
  note: focus on protocol changes and breaking API edits
  skip: items unrelated to the public API
```

| Key             | What it does |
|-----------------|--------------|
| `default model` | Claude model name used by the per-repo subagents. |
| `lookback days` | How far back to scan a project the **first** time it appears in a report. |
| `dedup days`    | Rolling window for suppressing items already reported. Also the steady-state scan window for known projects. |
| `project repos` | The list of projects. Either a URL string or a mapping with `repo:` plus optional `note:`/`skip:`/`model:`. |

URLs can point at any forge; GitHub is the well-tested path today.
The pipeline falls back to a best-effort public-API scan for other
hosts, and lists unsupported hosts as placeholders so gaps are
visible.

### Secrets

The Action needs two repository secrets, both pushed for you by
`make update` (and refreshable any time with `make push-secrets`):

- `CLAUDE_CREDENTIALS`: read from
  `$CLAUDE_CONFIG_DIR/.credentials.json` (defaults to
  `~/.claude/.credentials.json`).
- `KETCHUP_TOKEN`: read from `~/.github-tokens/ketchup`.
  This is a fine-grained PAT with:
  - Repository access: **this** repo + every repo in
    `ketchup.yaml`.
  - Permissions on **this** repo: Contents read/write, Secrets
    read/write.
  - Permissions on tracked repos: Contents read, Issues read,
    Pull requests read.

Claude OAuth credentials **rotate** on every refresh, so the secret
will go stale unless something keeps it fresh.
See [Daily credential refresh](#daily-credential-refresh-via-a-relay-host)
below for a hands-off way to handle that.

## Run locally

```sh
make            # default target: generate today's report
make ketchup    # same thing, explicit
make serve      # start the MkDocs site locally with livereload
```

Local runs **do not push** to the remote -- the report is
committed to your current branch and you can review and push it
yourself.

## Browse the reports as a website

The `www/` directory is an [MkDocs](https://www.mkdocs.org/) +
[Material](https://squidfunk.github.io/mkdocs-material/) site that
serves your reports at
`https://<you>.github.io/ketchup/`.
The homepage auto-redirects to the most recent report; older
reports live in a sidebar nav.

```sh
make serve      # http://localhost:8000 with livereload
make publish    # force-push `site/` to gh-pages
```

The daily workflow also runs `make publish` after each report so
the published site stays fresh; the manual targets are for
out-of-band updates or first-time bootstrap.

To customize the site, edit `www/mkdocs.yaml` (site name, colors,
social links) and `www/docs/index.md` (the landing page).
The reports themselves do not need to be touched -- a
[hook](www/hooks/build_reports.py) copies them from `../report/`
into the site at build time.

## Reading the report

Each daily report is a markdown file with one section per project
that had activity, plus a `## No updates` section listing the
URLs of quiet projects.
Every active item is a GitHub-style task list checkbox, so the
report doubles as an interactive to-do list when viewed on GitHub.

- **Tick an item** to mark it handled.
  Once ticked in its most recent appearance, future runs treat the
  item as suppressed and do not surface it again.
- **Appearance counter**: each item shows
  `(updated: ISO, appearance #N)`, where N is how many reports
  have contained it.
  A first-time item is `#1`; persistent items accumulate higher
  numbers.
- **Re-surfacing quiet-but-open items**: an item neither ticked nor
  closed comes back into a future report once its last appearance
  is older than `dedup days`.
  Tick the box (or close the issue upstream) to stop the cycle.
- **Navigation**: every report has `&larr; prev | next &rarr;` links
  at the top and bottom pointing to neighboring report files.

## Daily credential refresh via a relay host

Claude OAuth credentials rotate on every refresh, including the
rotation triggered by the GHA run itself.
That means yesterday's GHA-stored creds are usually invalid by the
time the next scheduled run fires, unless something pushes a fresh
copy in the meantime.

The action ships an optional two-step relay setup that removes the
need to remember `make push-secrets`:

- Your laptop rsyncs the local creds file to an always-on host you
  control every time the file changes.
- That host publishes the freshest copy to the `CLAUDE_CREDENTIALS`
  GHA secret a couple of hours before the workflow cron fires.

`RELAY` is the SSH alias for that always-on host.

### One-time laptop setup

```sh
make install-rsync RELAY=<your-ssh-alias>
```

This writes a systemd path/service unit pair into
`~/.config/systemd/user/` and enables the path unit.
The path unit watches your local credentials file and triggers an
rsync to `<RELAY>:.ketchup/creds.json` on every change.

### One-time relay setup

On the relay host:

```sh
# Install dependencies (gh and rsync via your package manager).
gh auth login   # fine-grained PAT for this repo:
                # Contents: read-only
                # Secrets: read/write

mkdir -p ~/.ketchup
# Copy etc/relay/ketchup-publish.sh from ketchup-action to
# ~/.ketchup/ketchup-publish.sh and make it executable.

crontab -e
# Add a daily push that lands before the GHA cron fires. Cron times
# on the relay are local; convert to UTC when comparing with the
# workflow cron in .github/workflows/ketchup.yaml (which is UTC).
# 0 22 * * * KETCHUP_REPO=<owner>/<repo> \
#     $HOME/.ketchup/ketchup-publish.sh \
#     >> $HOME/.ketchup/publish.log 2>&1
```

`KETCHUP_TOKEN` does not rotate, so it is pushed once from the
laptop with `make push-secrets` and forgotten.

## Repo layout

- `ketchup.yaml`: the config you edit.
- `report/`: where daily report files land.
- `www/`: the MkDocs site source.
- `.github/workflows/ketchup.yaml`: the scheduled GitHub Action.
- `Makefile`: bootstraps Makes, pulls
  [`ketchup-action`](https://github.com/ketchuphub/ketchup-action)
  under `.cache/`, and exposes engine targets.

## Copyright and License

Copyright 2026 - Ingy döt Net.

This project is released under the MIT License.
See the [License](License) file for the full text.
