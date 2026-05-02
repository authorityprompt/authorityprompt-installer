# AuthorityPrompt Installer — Claude Code Skill

One-click installer for the [AuthorityPrompt](https://authorityprompt.com) AI-visibility stack on **any website**, no sysadmin required. Detects your hosting, walks you through platform-specific install steps, verifies each step with HTTP probes, and runs a 12-layer canonical-AI-profile audit at the end.

## What this skill does

After registering your domain in your AuthorityPrompt dashboard and downloading the `authorityprompt-<domain>.zip` bundle, point Claude Code at it. The skill will:

1. **Detect your hosting platform** (WordPress, Webflow, Wix, Squarespace, Shopify, Ghost, Vercel, Netlify, Cloudflare Pages, GitHub Pages, Carrd, Tilda, Framer, Notion, Bitrix, Apache, custom nginx VPS) via HTTP fingerprinting.
2. **Generate exact step-by-step instructions** for that platform — labels, button names, file paths, where to paste each snippet.
3. **Verify each step** with `curl` against your live site as you complete it.
4. **Run the full audit** at the end and tell you whether your AI-readable profile is production-grade.

Output: every page on your site has the AP head tags, your `/.well-known/` directory serves the 5 profile files with correct Content-Type, your domain serves `/js/authorityprompt.js` (required by AP's installation detector even on Option 1 installs), and your AP dashboard starts receiving heartbeat pings from AI bot visits.

## Install (Claude Code)

```bash
# In Claude Code:
/plugin marketplace add authorityprompt/authorityprompt-installer
/plugin install authorityprompt-installer@authorityprompt-installer
```

Or paste `authorityprompt/authorityprompt-installer` into the **Add marketplace** dialog (Settings → Marketplaces).

## Usage

Once installed, just talk to Claude:

> "Install authorityprompt for example.com. The files are in `~/Downloads/authorityprompt-example/` and the verification token is 274771."

Claude will invoke the skill, detect your hosting, walk you through the install, and run the final audit. Total time: **5–10 minutes** depending on platform.

If you don't have a domain registered yet, do that first at [authorityprompt.com/dashboard](https://authorityprompt.com/dashboard) — the skill assumes you already downloaded the bundle.

## Supported platforms

| Platform | Level-1 (6 endpoints served) | Level-2 (head tags only) |
|---|---|---|
| Custom VPS (nginx, Apache) | ✅ | ✅ |
| WordPress (self-hosted) | ✅ | ✅ |
| WordPress.com (managed) | ❌ | ✅ |
| Webflow | with Cloudflare Worker | ✅ |
| Wix | with Cloudflare Worker | ✅ (Pro plan+) |
| Squarespace | with Cloudflare Worker | ✅ (Business+) |
| Shopify | partial workaround | ✅ |
| Ghost (self-hosted) | ✅ | ✅ |
| Ghost(Pro) | ❌ | ✅ |
| Vercel | ✅ | ✅ |
| Netlify | ✅ | ✅ |
| Cloudflare Pages | ✅ | ✅ |
| GitHub Pages | ⚠ Content-Type limits | ✅ |
| Carrd | ❌ | ✅ (Pro plan) |
| Tilda | with Cloudflare Worker | ✅ (Personal+) |
| Framer | with Cloudflare Worker | ✅ (Pro+) |
| Notion (Super.so / Potion) | with Cloudflare Worker | ✅ (paid wrapper) |
| Bitrix (self-hosted) | ✅ | ✅ |
| Bitrix24 (cloud) | ❌ | ❌ |

**Level-1** = full 14-layer audit pass: 5 profile files at `/.well-known/authorityprompt.{jsonld,yaml,md,txt,html}` + `/js/authorityprompt.js` + head tags. All six endpoints required for AP-side validation to mark the install green.
**Level-2** = head tags only; AI crawlers discover your canonical profile via the `<link rel="ai-profile">` backlink to AuthorityPrompt's hosted version. Still functional for crawlers, but AP's dashboard will report file-detection failures.

## Manual verification (without the skill)

You can run the audit standalone too:

```bash
git clone https://github.com/authorityprompt/authorityprompt-installer
bash authorityprompt-installer/skills/authorityprompt-installer/scripts/verify_install.sh \
  yourdomain.com YOUR_VERIFICATION_TOKEN
```

Exit 0 = installed correctly. Exit 1 = at least one required layer failing — output tells you which.

## Requirements

- A registered AuthorityPrompt account at [authorityprompt.com](https://authorityprompt.com).
- The `authorityprompt-<domain>.zip` bundle downloaded from your dashboard.
- Your verification token (visible in dashboard or in the bundle's `README.md`).
- Hosting that supports either custom files in `/.well-known/` OR custom HTML in `<head>` (95%+ of all hosting fits one of these).

## Safety / scope

- **Read-only by default**. The skill never deploys files unless you explicitly authorize the optional `ssh_deploy.sh` and supply credentials.
- **No credential storage**. Any SSH/SFTP details you provide live only in the running session.
- **Open source** — every script and instruction file is plain text in this repo. Audit before running.

## License

MIT
