# GitHub Pages

Git-based, full Level-1 supported (with one Jekyll quirk).

## Step A — `/.well-known/*` + `/js/` files

1. Clone the repo locally.
2. Create `.well-known/` at repo root (or inside `docs/` if Pages is set to "docs/" folder).
3. Copy the 5 profile files (`authorityprompt.{jsonld,yaml,md,txt,html}`) in.
4. **Also required** — create `js/` at the same level (repo root or `docs/`) and copy `authorityprompt.js` to `js/authorityprompt.js`. AP's installation detector probes `<your-domain>/js/authorityprompt.js` independently of how the script tag is loaded in `<head>`.

## Jekyll quirk — directories starting with `.`

Jekyll's default config **excludes directories starting with `.`** from site output. To include `.well-known/`, add to `_config.yml`:

```yaml
include:
  - .well-known
```

If the repo has no `_config.yml`, GitHub Pages still uses Jekyll by default. Either add `_config.yml` with the above, or create a `.nojekyll` file at repo root to disable Jekyll entirely (then files in `.well-known/` ship verbatim).

## Step B — Content-Type

GitHub Pages serves with limited MIME flexibility. `.txt` and `.html` will be correct; `.jsonld`, `.yaml`, `.md` will likely be served as `text/plain`. AI crawlers are tolerant — they parse by content, not just MIME — so this typically still works. If you need strict Content-Type, put Cloudflare in front and use `cloudflare-worker.md`.

## Step C — head tags

Edit your site templates:

- **Jekyll**: `_includes/head.html` or `_layouts/default.html`.
- **Plain HTML site**: every page's `<head>`.
- **Hugo / mkdocs / 11ty / Astro etc.**: their respective layout file.

Paste the snippet from `templates/head-snippet.html`.

## Step D — commit + push

```bash
git add .well-known _config.yml <head-modified-files>
git commit -m "feat: install AuthorityPrompt"
git push
```

GitHub Pages rebuilds within 1-2 minutes.

## Step E — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect L1 may show `text/plain` for `.jsonld`/`.yaml`/`.md` — this is a soft fail. AI parsers tolerate it. For strict 100% pass, add Cloudflare in front (see `cloudflare-worker.md`).
