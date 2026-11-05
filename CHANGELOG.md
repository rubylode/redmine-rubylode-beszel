# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.0] - 2026-11-04

The settings and the page path follow the Rubylode plugin standard, and the block can show on the Rubylode Status page.

### Added

- Register a "Servers" widget with Rubylode Status when that plugin is installed. The widget gives the Status page a state, a summary such as "2 of 3 servers up" and one item per server.
- Serve the page at `/status/beszel`, with or without Rubylode Status.
- Say on the settings page and on the plugin's page whether Rubylode Status is installed.
- A migration (`db/migrate/001_rename_beszel_settings_for_version_two.rb`) that moves saved settings to the new keys, and moves them back when reverted. It writes nothing when no settings were saved.

### Changed

- Rename the setting `hub_url` to `base_url`, labeled "Beszel address". The migration moves the saved value.
- Rename the setting `show_on_paths` to `matching_page_paths`, and add `show_on_matching_pages`. The paths only count when "Pages matching these paths" is checked; the migration checks it when paths were saved.
- Make "My page" add the block to the default My page, for people who have not arranged their own. It used to draw a small version at the top of every My page. People who added the block themselves keep it.
- Reword the settings: "Email variable", "Password variable", "Allowed hosts" (was "Other allowed hosts"), "Servers to show" (was "Servers"), "Show in the top menu" (was "Top menu link"), and a hint for every setting. The placements are under "Show the block on", each with a visible "Column" select where it has one.
- Name the block "Servers" everywhere. "Server status" is gone from the My page block list and the page title.
- Show "n/a" instead of an en dash where the hub gives no reading.
- Rename the Ruby modules to `RubylodeBeszel`, with one `RubylodeBeszel::Settings` reader (was `RedmineRubylodeBeszel::Defaults` and `RubylodeBeszel::Configuration`), and move the translations under one `rubylode_beszel` root.
- Hide the plugin's top menu item, and the "Show in the top menu" setting, when Rubylode Status is installed. The item is the Status plugin's then.
- Spell the documentation in en-US, and describe the current plugin in the README, the listing notes and the roadmap.
- Make `*` in a path stand for anything inside one path segment, and `**` for anything including slashes. Saved patterns keep their meaning because each `*` became `**` in the migration (and back on revert).

### Moved

- The page is now `/status/beszel`. `/beszel_status` redirects there (301) for this release and goes in the next one. The macro is still `{{beszel_status}}`.

### Upgrading from 1.x

1. Put the new version in place and run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`, then restart Redmine.
2. Change links to `/beszel_status` (wiki text, themes, bookmarks) to `/status/beszel`.
3. If "My page" was checked, look at it again: it now sets the default My page. A small block on every My page is gone; to keep it on a page, use "Pages matching these paths" with `/my/page`.
4. If you wrote code that reads `RubylodeBeszel::Configuration` or `RedmineRubylodeBeszel::Defaults`, use `RubylodeBeszel::Settings`.

## [1.1.1] - 2026-11-04

### Changed

- Require Redmine 5.1 or newer instead of 5.0. Redmine 5.0 cannot be tested in CI (the sqlite3 gem it pins does not build
  there), and this plugin only claims what CI verifies. No code changed.

## [1.1.0] - 2026-11-04

### Changed

- Run on Redmine 5.0 and newer. The plugin's own tests pass unchanged on those versions; no code changed.

## [1.0.1] - 2026-11-03

### Added

- Show a Rubylode thumbnail at the top of the README.

### Changed

- Make the README plainer and add a license section.
- Write the checksum file inside the build step of the release job.

## [1.0.0] - 2026-11-02

First stable release.

### Changed

- Show the project address on Administration, Plugins.
- Set the name, author and version to match the listing on redmine.org.

## [0.1.1] - 2026-11-02

### Fixed

- Log a warning instead of failing the page when the cache cannot be read or written (for example a cache file owned by another user). The block is built from a fresh request to the hub, or shows "Status unavailable".

## [0.1.0] - 2026-11-01

First version.

### Added

- The latest status of the servers a [Beszel](https://beszel.dev) hub monitors: up or down, when each was last seen, and CPU, memory and disk usage as bars (amber from 80 percent, red from 90).
- A `{{beszel_status}}` wiki macro, a page at `/beszel_status`, an optional My page block and a partial (`rubylode_beszel/status`) for other plugins.
- Down servers first, and a summary line ("All servers up" or "N of M down"). When the hub cannot be asked the block says "Status unavailable" and the page keeps rendering.
- Settings: hub URL, the names of the environment variables that hold the sign-in email and password, an optional list of servers with friendly names (`Name | system name in Beszel | Description`), cache seconds (60), failure cache seconds (30), timeout seconds (2), block title, who may see it, plain http and other allowed hosts.
- Credentials from environment variables named `BESZEL_...`. They go only to the host of the hub URL, over https unless the host is loopback or plain http is allowed, and are never saved, shown or logged. A redirect to another host is not followed.
- Placements switched in the settings: the welcome page (left or right column), My page, the project Overview page (left or right column), a top menu link and a list of path patterns. Patterns use a `*` wildcard, ignore query strings, and never match the admin, settings or sign-in pages unless listed. They draw a compact variant. Every placement honors the permission setting and shares the cache.
- Help on the settings page and in the README: a table of where, how and which setting, with copy-paste snippets for the macro, the My page block, the path list, the partial and the page.
- A fake Beszel hub in `test/support` for the demo and the tests, a throwaway Redmine on port 3013 (`bin/demo`), unit and integration tests, CI and screenshots.

[2.0.0]: https://github.com/rubylode/redmine-rubylode-beszel/compare/v1.1.1...v2.0.0
[1.1.1]: https://github.com/rubylode/redmine-rubylode-beszel/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/rubylode/redmine-rubylode-beszel/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/rubylode/redmine-rubylode-beszel/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/rubylode/redmine-rubylode-beszel/compare/v0.1.1...v1.0.0
[0.1.1]: https://github.com/rubylode/redmine-rubylode-beszel/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/rubylode/redmine-rubylode-beszel/releases/tag/v0.1.0
