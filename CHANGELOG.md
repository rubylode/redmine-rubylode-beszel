# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-11-01

First version.

### Added

- The latest status of the servers a [Beszel](https://beszel.dev) hub monitors: up or down, when each was last seen, and
  CPU, memory and disk usage as simple bars (amber from 80 percent, red from 90).
- Four ways to show it: the wiki macro `{{beszel_status}}`, the page `/beszel_status`, an optional My page block and a
  partial (`rubylode_beszel/status`) other plugins can render.
- Down servers first, a summary line ("All servers up" or "N of M down"), and "Status unavailable" while the page
  keeps rendering when the hub cannot be asked.
- Plugin settings: hub URL, the names of the environment variables that hold the sign-in email and password, an optional
  list of servers with friendly names (`Name | system name in Beszel | Description`), cache seconds (60), failure cache
  seconds (30), timeout seconds (2), block title, who may see it, plain http and other allowed hosts.
- The credentials are never saved, shown or logged: they come from environment variables named `BESZEL_...`, are sent only to
  the host of the hub URL, over https unless the host is loopback or plain http is allowed, and never follow a redirect to
  another host.
- Where the block shows is a setting: the welcome page (left or right column), My page, the project Overview page (left or
  right column), a top menu link, and a list of path patterns (`*` wildcard, query strings ignored, never the admin, settings
  or sign-in pages unless listed) drawn as a compact variant. All of them honour the permission setting and share the cache.
- Help on the settings page and in the README: a place, how, needs-a-setting table with copy-paste snippets for the macro in
  wiki pages, news, descriptions and the welcome text, the My page block, the path list, the partial and the standalone page.
- A fake Beszel hub in `test/support` for the demo and the tests, a throwaway Redmine on port 3013 (`bin/demo`), unit and
  integration tests, CI and screenshots.
