# Roadmap

## Goal

Show the latest status of the servers a Beszel hub monitors inside Redmine, without a second login and without leaking
the hub's credentials.

## Done

- 0.1.0: the macro, the page, the My page block and the partial; placements (welcome page, My page, Overview, top menu, path list) with help; the settings; the cache and the failure cache; the
  credential rules (environment variables named `BESZEL_...`, host binding, https); a fake hub; tests; a demo.

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
