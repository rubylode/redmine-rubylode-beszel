// README screenshots from the demo Redmine (ruby bin/demo up), in its default theme, with the fake hub's made-up data.
//   npm install && npm run screenshots
import { mkdirSync } from "node:fs"
import { baseUrl, launch, signedInPage } from "./browser.mjs"

const out = new URL("../docs/screenshots/", import.meta.url).pathname
mkdirSync(out, { recursive: true })
const hubPort = process.env.DEMO_HUB_PORT || "9113"

async function scenario(name) {
  const response = await fetch(`http://localhost:${hubPort}/__scenario/${name}`, { method: "POST" })
  if (!response.ok) throw new Error(`scenario ${name} refused`)
  await new Promise((resolve) => setTimeout(resolve, 6000)) // the demo caches the hub's answer for 5 seconds
}

async function shoot(page, name, path, selector, extra = {}) {
  await page.goto(`${baseUrl}${path}`, { waitUntil: "load" })
  await page.waitForSelector(selector)
  await page.screenshot({ path: `${out}${name}.png`, ...extra })
  console.log("saved", `${name}.png`)
}

const browser = await launch()
const page = await signedInPage(browser, "sam.rivera", "demo-password-1", { width: 1280, height: 640 })

await scenario("all_up")
await shoot(page, "status-all-up", "/beszel_status", ".rubylode-beszel-table")

await scenario("one_down")
await shoot(page, "status-one-down", "/beszel_status", ".rubylode-beszel-table")
await shoot(page, "wiki-macro", "/projects/operations/wiki/Servers", ".wiki .rubylode-beszel-table")

await shoot(page, "welcome-page", "/", ".rubylode-beszel")
await shoot(page, "issues-page-compact", "/issues", ".rubylode-beszel.is-compact")

await scenario("unavailable")
await shoot(page, "status-unavailable", "/beszel_status", ".rubylode-beszel-summary.is-unavailable")

await scenario("all_up")
await browser.close()
