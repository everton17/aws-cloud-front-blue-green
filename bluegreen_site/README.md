# edge-switch — Blue/Green CloudFront demo site

A single-page static site built to demonstrate fast deploys and rollbacks
using the CloudFront + S3 (blue/green) pipeline you already built in
Terraform.

## Structure

```
bluegreen-site/
├── package.json
├── README.md
└── src/
    └── index.html      <- the entire site (inline HTML + CSS + JS, no build dependencies)
```

There's no bundler, framework, or node_modules — it's a single self-contained
HTML file (fonts loaded from the Google Fonts CDN). This is intentional:
the simpler the build, the faster the deploy/rollback demo cycle.

## How to edit the headline (the only thing you need to touch)

Open `src/index.html` and look for the block in the `<head>`, near the top
of the file:

```html
<script>
  window.SITE_CONFIG = {
    headline: "Ship it.\nBreak it.\nSwitch back.",
    badge: "v1.0.0 — deployed just now"
  };
</script>
```

- **`headline`**: the large hero text. Use `\n` to break onto a new line
  (each line automatically gets a different color — black, blue, green —
  and repeats the pattern if you add more than 3 lines).
- **`badge`**: the text in the pill badge right above the headline, also
  shown in the footer — handy for displaying the version/commit currently
  live.

Example for your next demo deploy:

```html
window.SITE_CONFIG = {
  headline: "Now live.\nVersion two.\nNo downtime.",
  badge: "v1.1.0 — deployed via GitHub Actions"
};
```

Save, run the build (below), and ship the contents of `dist/` — that's it.

## Build

Prerequisite: Node.js installed (any recent version; the build script
doesn't use any dependency beyond shell commands).

```bash
cd bluegreen-site
npm run build
```

This runs `rm -rf dist && mkdir -p dist && cp -r src/* dist/` — i.e. it
just copies `src/` into `dist/`. There's no transpiling, minifying, or
bundling, since the site is already a single small HTML file (~12 KB).

**Output folder:** `dist/`

```
dist/
└── index.html
```

The contents of `dist/` are what should be synced to the main S3 bucket in
the GitHub Actions workflows we already created (`aws s3 sync ./dist
s3://<bucket> --delete`) — adjust `build_output_dir = "./dist"` in the
Terraform module variable, since the default was `./build`.

## Local preview (optional)

```bash
npm run preview
```

Spins up a static server at `http://localhost:5050` using `npx serve`
(downloads the package on demand, nothing to install beforehand).

Or, without npm:

```bash
cd dist && python3 -m http.server 5050
```

## Suggested demo flow

1. Edit `headline` in `src/index.html`.
2. `npm run build`.
3. Commit + push (or trigger `workflow_dispatch`) to fire off `deploy.yml`.
4. Watch the CloudFront invalidation step finish in Actions.
5. Refresh the published page — the new headline is live.
6. To demo a rollback: trigger the `rollback.yml` workflow (or
   `rollback-and-restore.yml`, depending on the option chosen in the
   module) and refresh the page again — it's back to the previous version.
