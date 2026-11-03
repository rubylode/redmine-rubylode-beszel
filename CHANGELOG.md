# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.1] - 2026-11-03

### Added

- Show a Rubylode thumbnail at the top of the README.

### Changed

- Make the README plainer and add a licence section.
- Word the changelog entries more plainly.
- Write the checksum file inside the build step of the release job.

## [1.0.0] - 2026-11-02

First stable release.

### Changed

- Show the project address on Administration, Plugins.
- Set the name, author and version to match the listing on redmine.org.

## [0.1.1] - 2026-11-02

### Fixed

- Log a warning instead of failing the page when the cache cannot be read or written (for example a cache file owned by another user). The block is built from a live fetch, or shows "Status unavailable".

## [0.1.0] - 2026-11-01

First version.

### Added

- The latest status of the servers a [Beszel](https://beszel.dev) hub monitors: up or down, when each was last seen, and CPU, memory and disk usage as bars (amber from 80 percent, red from 90).
- A `{{beszel_status}}` wiki macro, a page at `/beszel_status`, an optional My page block and a partial (`rubylode_beszel/status`) for other plugins.
- Down servers first, and a summary line ("All servers up" or "N of M down"). When the hub cannot be asked the block says "Status unavailable" and the page keeps rendering.
- Settings: hub URL, the names of the environment variables that hold the sign-in email and password, an optional list of servers with friendly names (`Name | system name in Beszel | Description`), cache seconds (60), failure cache seconds (30), timeout seconds (2), block title, who may see it, plain http and other allowed hosts.
- The credentials come from environment variables named `BESZEL_...`. They go only to the host of the hub URL, over https unless the host is loopback or plain http is allowed, and are never saved, shown or logged. A redirect to another host is not followed.
- Placements switched in the settings: the welcome page (left or right column), My page, the project Overview page (left or right column), a top menu link and a list of path patterns. Patterns use a `*` wildcard and ignore query strings, and never match the admin, settings or sign-in pages unless listed. They draw a compact variant. Every placement honours the permission setting and shares the cache.
- Help on the settings page and in the README: a place, how and setting table, with copy-paste snippets for the macro, the My page block, the path list, the partial and the page.
- A fake Beszel hub in `test/support` for the demo and the tests, a throwaway Redmine on port 3013 (`bin/demo`), unit and integration tests, CI and screenshots.
