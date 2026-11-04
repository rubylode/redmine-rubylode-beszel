# Roadmap

## Goal

Show the latest status of the servers a Beszel hub monitors inside Redmine, without a second login and without leaking
the hub's credentials.

## Done

- 2.0.0: settings and the page path follow the Rubylode plugin standard; the block shows on the Rubylode Status page.
- 1.1.1: needs Redmine 5.1 or newer.
- 1.0.0: stable release, with the project address and author on the Plugins page.
- 0.1.1: a cache that cannot be read or written no longer fails the page.
- 0.1.0: the macro, the page, the My page block and the partial.
- 0.1.0: placements (welcome page, My page, Overview, top menu, path list) with help on the settings page.
- 0.1.0: the settings, the cache and the failure cache.
- 0.1.0: the credential rules (environment variables named `BESZEL_...`, host binding, https).
- 0.1.0: a fake hub, tests and a demo.

## Ideas

- Show the hub's alerts, or the load average and temperature that Beszel reports, next to the bars.
- Let the amber and red thresholds (80 and 90 percent) be settings.
- Show uptime ("up for 12 days") from the system's `info.u`.
- Translations beyond English.
- A hub API token instead of an email and password, if Beszel offers one that can read the `systems` collection.

## Facts to check against your hub

The plugin asks the PocketBase API of the hub: `POST /api/collections/users/auth-with-password`, then
`GET /api/collections/systems/records` with the returned token in the `Authorization` header. It reads each record's `name`,
`status` (`up`, `down`, `paused`, `pending`), `updated` (when the hub last heard from the agent) and `info.cpu`, `info.mp`
(memory) and `info.dp` (disk), all in percent. Those names match Beszel's source and docs for the 0.1x releases; a future Beszel
release could rename them.
