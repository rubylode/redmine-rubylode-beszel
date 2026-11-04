# Rubylode Beszel for Redmine

<p><img src="docs/thumbnail.png" alt="Rubylode Beszel plugin" width="160"></p>

[![tests](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-beszel/tests.yml?branch=main&label=tests)](https://github.com/rubylode/redmine-rubylode-beszel/actions/workflows/tests.yml)
[![security](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-beszel/security.yml?branch=main&label=security)](https://github.com/rubylode/redmine-rubylode-beszel/actions/workflows/security.yml)
[![version](https://img.shields.io/github/v/tag/rubylode/redmine-rubylode-beszel?sort=semver&label=version)](https://github.com/rubylode/redmine-rubylode-beszel/tags)
[![license](https://img.shields.io/github/license/rubylode/redmine-rubylode-beszel)](https://github.com/rubylode/redmine-rubylode-beszel/blob/main/LICENSE)
![Redmine](https://img.shields.io/badge/Redmine-5.1%20%7C%206.0%20%7C%206.1%20%7C%207.0-b22222)
![Ruby](https://img.shields.io/badge/Ruby-3.2%20%7C%203.3%20%7C%203.4%20%7C%204.0-cc342d)

TL;DR: this plugin shows the latest status of the servers a [Beszel](https://beszel.dev) hub monitors inside
[Redmine](https://www.redmine.org): up or down, when each was last seen, and CPU, memory and disk usage as bars. It comes
as a wiki macro, a page, a My page block and a partial, and it puts its block on the [Rubylode Status](https://github.com/rubylode/redmine-rubylode-status) page when that plugin is installed.

The hub's login stays in environment variables and the plugin only reads. Version 2.0.0, needs Redmine 5.1 or newer, tested
against a fake hub. `docs/roadmap/ROADMAP.md` lists what is not done. Upgrading from 1.x: read the 2.0.0 entry in `CHANGELOG.md`.

![The status page, one server down](docs/screenshots/status-one-down.png)

Contents:

- [What it does](#what-it-does)
- [Install](#install)
- [Settings](#settings)
- [Where it shows](#where-it-shows)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Tests](#tests)
- [License](#license)

## What it does

Asks your Beszel hub which systems it monitors and shows them in a table: name, description, status (up, down, paused),
how long ago the hub last heard from the server, and bars for CPU, memory and disk. A bar turns amber from 80 percent and
red from 90, so a nearly full disk stands out. Down servers come first. A summary line says "All servers up" or "2 of 5 down".

If the hub cannot be reached the block says "Status unavailable" (administrators also see why) and the page around it still
renders. The hub's answer is cached for 60 seconds by default, and for 30 after a failure.

| All up, one disk nearly full | Hub unavailable |
|---|---|
| ![](docs/screenshots/status-all-up.png) | ![](docs/screenshots/status-unavailable.png) |

All screenshots show the made-up data of the fake hub in `test/support/fake_beszel_hub.rb`.

## Install

Needs Redmine 5.1 or newer, and a Beszel hub (a PocketBase app) that Redmine can reach.

1. Put the plugin folder in Redmine's `plugins/` directory, named `redmine_rubylode_beszel`:

       cd /path/to/redmine/plugins
       git clone https://github.com/rubylode/redmine-rubylode-beszel.git redmine_rubylode_beszel

2. Run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`.
3. In Beszel, make a user for Redmine (a regular user is enough, it only reads). Set its email and password in two
   environment variables where Redmine runs, for example `BESZEL_EMAIL` and `BESZEL_PASSWORD`, then restart Redmine
   ([Passenger](https://www.phusionpassenger.com), [Puma](https://puma.io), whatever serves it).
4. In Administration, Plugins, open Rubylode Beszel and choose Configure. Enter the Beszel address.

To remove it, delete the folder and restart. The settings stay in the database as one `plugin_redmine_rubylode_beszel`
row, which you can delete.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| Beszel address | empty | For example `https://beszel.example.com`. Empty: the block is shown to administrators only, with a hint. |
| Email variable, Password variable | `BESZEL_EMAIL`, `BESZEL_PASSWORD` | The NAMES of the environment variables that hold the credentials. They must start with `BESZEL_`. The settings page tells you whether each is set. |
| Allowed hosts | empty | Hosts that may receive the credentials besides the Beszel address, separated by spaces or commas. |
| Allow plain http | off | See [Security](#security). |
| Servers to show | empty | One per line: `Name | system name in Beszel | Description`. The last two may be empty (an empty system name means the same as Name). Lines starting with `#` are ignored. Empty: every system the hub has is shown. |
| Cache seconds, Failure cache seconds, Timeout seconds | 60, 30, 2 | The hub is asked at most once per cache window. After a failed answer it is left alone for the failure window. A request is given up after the timeout. |
| Block title | Servers | The heading of the block and the name of the top menu link. |
| Who may see the block | Everyone who is signed in | Or administrators only. Anonymous visitors never see it. |
| Show the block on | all off | Welcome page, My page, Project Overview page, Pages matching these paths, and Show in the top menu. See below. |

Example servers list:

    Web | web-1 | The public site
    Database | db-1 | Primary database
    Backups | backup-1 |

## Where it shows

- Wiki macro: `{{beszel_status}}`, or `{{beszel_status(title=Our servers)}}`. People who may not see it get nothing where it
  stands.
- Page: `/status/beszel`.
- My page block: "Servers" in the list of blocks you can add to My page.
- Partial, for other plugins and themes: `render partial: "rubylode_beszel/status"` (locals `title` and `show_title`).

![The macro in a wiki page](docs/screenshots/wiki-macro.png)

### Status page

With [Rubylode Status](https://github.com/rubylode/redmine-rubylode-status) installed, the block also shows on its Status page,
and this plugin drops its own top menu item and hides "Show in the top menu" on the settings page. Without it, nothing else
changes and the settings page says where to get it. The old page path `/beszel_status` redirects to `/status/beszel` in 2.0.0.

### Other pages

The same block, with the same permission setting and the same cache, can be put in many places. The settings page carries
this table and these snippets too.

| Where | How | Needs a setting |
|---|---|---|
| Wiki pages | the macro `{{beszel_status}}` | no |
| News, issue descriptions and comments | the macro | no |
| Project descriptions (so the project's Overview page) | the macro | no |
| The welcome text (Administration, Settings, General) | the macro | no |
| My page, as a block you can move | pick "Servers" in the Add list | no |
| Welcome page, left or right column | check "Welcome page" | Welcome page |
| The default My page | check "My page" | My page |
| Project Overview page, left or right column | check "Project Overview page" | Project Overview page |
| Any other page, such as the issue list | check "Pages matching these paths" and list the path | Pages matching these paths |
| Its own page | open `/status/beszel` | no |
| The top menu | check "Show in the top menu" | Show in the top menu |
| A theme or another plugin | render the partial | no |

"My page" adds the block to the default My page, the one people get until they arrange their own. Everyone can still add it
from the block list.

The macro works in anything Redmine formats with its wiki syntax, the welcome text included.

    {{beszel_status}}
    {{beszel_status(title=Our servers)}}

The path list takes one pattern per line, drawn as a small version of the block at the top of each matching page:

    /issues
    /projects/*/issues
    /wiki*

`*` stands for anything inside one path segment, `**` for anything including slashes. A query string (`?status_id=o`) and a trailing `/` are ignored, so `/issues`
matches `/issues?set_filter=1`. A pattern must start with `/` and be at most 200 characters, with no `http://` or host
name; the settings page refuses anything else and names the line. Pages under `/admin`, `/settings`, `/login`, `/logout`
and `/account` never match a wildcard such as `/*`; to put the block there anyway, list a pattern that itself starts with
that prefix (`/admin/*`). A page that already shows the block (the macro, the page itself, the My page block) is not given
a second one.

For a theme or another plugin's view, the partial draws nothing for people who may not see the block:

    <%= render partial: "rubylode_beszel/status" %>
    <%= render partial: "rubylode_beszel/status", locals: { compact: true, title: "Servers", show_title: false } %>

Locals, all optional: `title` replaces the block title, `show_title: false` hides it, `compact: true` gives the small variant
without the description and last seen columns.

Link to the page from any wiki text with `"Servers":/status/beszel`. Check "Show in the top menu" for a link in Redmine's top
menu, named like the block title. Only people who may see the block get it.

![The small block on the issue list, from the path list](docs/screenshots/issues-page-compact.png)

### Restyling it

Every color, size and gap is a CSS custom property on `.rubylode-beszel` (`--rubylode-beszel-up-color`,
`--rubylode-beszel-down-color`, `--rubylode-beszel-warning-color`, `--rubylode-beszel-bar-width` and so on, listed at the top
of `assets/stylesheets/rubylode_beszel.css`). A theme restyles the block by setting them. The defaults switch to dark colors
in the system's dark mode. There is no JavaScript of its own.

## Security

The hub's email and password are never saved in Redmine's database, never shown on a page, never written to the log and never
part of an error message (errors name the problem, not the credential). They are read from environment variables when a
request is made.

- Only `BESZEL_...` variables are read. The settings accept a variable name only if it matches `BESZEL_[A-Z0-9_]*`, and
  the check is made again every time the credentials are read. A name like `SECRET_KEY_BASE` or `DATABASE_PASSWORD` is
  refused when you save the settings, and if it is somehow in the database anyway it is ignored: the credential counts as
  missing and nothing is sent. Otherwise an administrator could point the plugin at one of Redmine's own secrets and an
  address of their choosing.
- The credentials go to one host. They are sent only to the host of the saved Beszel address. A redirect is followed only to
  that host or to a host listed under "Allowed hosts", at most three times; a redirect anywhere else stops the request
  before the credentials are sent again, and the block says "Status unavailable".
- https is required, unless the host is loopback. A Beszel address that starts with `http://` is refused when you save it, and
  the credentials are not sent at runtime, unless the host is `localhost`, `127.0.0.1` or `::1`, or you check "Allow plain http".
  Check it only when the hub is on a network you trust (Docker's internal network, a private LAN), because anyone who can
  watch that traffic can read the password.
- The plugin asks the hub only for the fields it shows (name, status, last update, and the usage numbers), so a server's
  address never leaves the hub.
- Give Redmine its own Beszel user, so you can revoke it without touching anyone else's login.

## Troubleshooting

- The block says "Status unavailable": administrators see the reason under it. Common ones are credentials not set (the settings
  page says whether each variable is set), a refused sign-in, and a redirect to a host that is not in "Allowed hosts".
- The block does not show: "Who may see the block" decides, and anonymous visitors never see it. With an empty Beszel address
  only administrators see a hint.
- If the cache store cannot be read or written (a cache file owned by another user, a full disk), the plugin logs a warning with
  the error class and message and asks the hub directly. The page still renders.
- The top menu link is missing: with Rubylode Status installed the link is the Status plugin's.

## Tests

    bin/test                                         all unit and integration tests
    bin/test test/unit/system_status_test.rb         one file

They run in a Redmine 7 image with its test gems (`docker/test.Dockerfile`) against the fake hub in
`test/support/fake_beszel_hub.rb`, a small Ruby script that answers the two calls the plugin makes with the JSON shapes
PocketBase uses. It can run on its own: `FAKE_BESZEL_EMAIL=a@example.com FAKE_BESZEL_PASSWORD=x ruby test/support/fake_beszel_hub.rb`.
The Status plugin is not in that image, so the tests use a stand-in for its registry.

Pull Requests are welcome!

### Try it

A throwaway Redmine 7 and a fake Beszel hub run from this folder, with the repository mounted as the plugin:

    ruby bin/demo up                 start both and load the demo data; Redmine is on http://localhost:3013
    ruby bin/demo scenario one_down  make the fake hub report one server down (all_up, one_down, unavailable)
    ruby bin/demo restart            pick up a change to the plugin (it runs in production mode)
    ruby bin/demo down               stop it, keep the data
    ruby bin/demo reset              stop it and wipe the data

Placements are switched on for the welcome page, the project Overview page, `/issues` and the top menu. Sign in as admin / admin, or as `sam.rivera` with the password `demo-password-1`. The fake hub is at http://localhost:9113
and accepts the made-up credentials in `docker-compose.yml`. The wiki page is Operations, Servers. The data is throwaway;
never point the seed script at a real tracker.

`npm install && npm run screenshots` retakes the screenshots in `docs/screenshots` from the running demo.

### Releasing

Push a `vX.Y.Z` tag whose version matches `version` in `init.rb` and has an entry in `CHANGELOG.md`. CI runs the tests, builds `redmine_rubylode_beszel-X.Y.Z.zip` and publishes the GitHub release with the changelog entry as its notes. To build a release for a tag that already exists, use Actions, release, Run workflow.

The text to paste when listing the plugin on www.redmine.org, and how to read the result of Check for updates, is in [docs/redmine-org-listing.md](docs/redmine-org-listing.md).

## License

GNU General Public License, version 2 or (at your option) any later version, the same as Redmine. See `LICENSE`.

Copyright (C) 2026  Nick Gorbikoff

No warranty, as the GPL says. The plugin only reads from your hub, but it holds a login for it, so read the Security section and try it on a copy of your tracker first. I tested it in CI with the Rubylode plugins' own test suites on Redmine 7.0, 6.1, 6.0 and 5.1, against a fake hub that follows the PocketBase API and Beszel's documented fields, not against every Beszel release.
