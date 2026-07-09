# CloudFront Blue/Green — Static Site Stack with Instant Rollback

> 🌐 **Languages:** **English** · [Português (Brasil)](./docs/pt-br/README.md)

A Terraform stack for hosting static sites on **Amazon CloudFront + S3**, built around a
**blue/green deployment** pattern: when a release goes wrong, you roll back to the previous
version **instantly — with one click and no new build**.

Instead of re-deploying an old artifact or restoring files by hand, you flip a single switch
(an SSM Parameter Store value) and a **Lambda@Edge** function transparently re-points
CloudFront to the previous version, which was kept warm in a second S3 bucket. You can also
keep an archive of **every** build and restore any historical version on demand.

It also provisions — all optional — Route 53 records, ACM certificates for custom domains,
public **or** private buckets, and a complete **GitHub Actions CI/CD pipeline** authenticated
via **OIDC (no long-lived access keys)**.

---

## 📚 Documentation map

This README is the middle ground: enough to understand the project and get going. From here,
two paths:

| If you want to… | Go to |
|---|---|
| **Just use it, fast** | ⚡ Quickstart — [English](./docs/en/quickstart.md) · [Português](./docs/pt-br/quickstart.md) |
| **See all configuration examples** (9 ready-to-use .tfvars files) | 📋 [Test Examples & Scenarios](./docs/TEST_EXAMPLES.md) — Simple, Rollback, Versioning |
| **Understand every detail** (variables, OAC vs website, OIDC, gotchas) | 📖 Complete guide — [English](./docs/en/full-guide.md) · [Português](./docs/pt-br/full-guide.md) |
| **See the architecture with AWS logos** | 🎨 [`docs/architecture.drawio`](./docs/architecture.drawio) (open in [draw.io](https://app.diagrams.net) or the VS Code *Draw.io* extension) |
| **A demo site to test the whole flow** | 🧪 [`bluegreen_site/`](./bluegreen_site/README.md) |

---

## How it works

The core is a **Lambda@Edge function on CloudFront's `origin-request` event**. On each request
to the origin, it:

1. Reads an SSM parameter (default `/Lambda/CF/Rollback`), value `"true"` or `"false"`
   (cached in the Lambda for ~60s to avoid an SSM call per request).
2. Picks the origin: `"false"` → **main** bucket (current version); `"true"` → **rollback**
   bucket (previous version); anything unexpected → falls back to main.
3. Rewrites the request origin to that bucket — an **S3 origin** (private/OAC) or a **custom
   HTTP origin** (public/website).

```mermaid
flowchart LR
    User([Viewer]) --> CF[CloudFront]
    CF -- origin-request --> L["Lambda@Edge<br/>(reads SSM, ~60s cache)"]
    L --> P{{"SSM: rollback?"}}
    P -- "false (current)" --> Main[("S3 main = GREEN")]
    P -- "true (previous)" --> Roll[("S3 rollback = BLUE")]
    Main --> CF --> User
    Roll --> CF
```

**Deploy** keeps the buckets in sync: it copies the current main bucket into the rollback
bucket (preserving the previous version), builds, uploads the new version to main, ensures
the toggle is `false`, and invalidates the cache.

**Rollback** is then a single click: the rollback workflow flips the toggle to `"true"` and
invalidates — within the Lambda cache TTL (~60s) CloudFront serves the preserved previous
version. No build, no re-upload.

> 🎨 Prefer the version with AWS service logos? See [`docs/architecture.drawio`](./docs/architecture.drawio).

---

## Deployment modalities

Selected with `gha_gen_workflows.workflow_option`. It decides both the AWS resources you
provision and the GitHub Actions workflows that get generated.

| Modality | What it provisions | Rollback | Restore by commit | Generated workflows |
|---|---|:---:|:---:|---|
| **`simple-deploy`** | CloudFront + 1 bucket | — | — | `deploy.yml` |
| **`deploy-and-rollback`** | + rollback bucket + Lambda@Edge + SSM | ✅ instant | — | `deploy.yml`, `rollback.yml` |
| **`deploy-rollback-and-restore`** | + versions bucket (`.tar.gz` per commit) | ✅ instant | ✅ any version | `deploy.yml`, `rollback-and-restore.yml` |

The third modality archives every build as `<commit-sha>.tar.gz`, so you can restore **any**
historical version by its commit hash — not only the immediately previous one. Full details
and per-modality `tfvars` examples are in the
[complete guide](./docs/en/full-guide.md#the-three-deployment-modalities).

---

## Key features

- 🟦🟩 **Instant, one-click blue/green rollback** (Lambda@Edge + SSM toggle, no rebuild).
- 🗄️ **Version archive & restore** of any build, by commit hash (optional third bucket).
- 🔒 **Public or private origins**: S3 website hosting **or** CloudFront OAC — the Lambda is
  rendered from the matching template automatically.
- 🌍 **Custom domain ready**: optional Route 53 records + ACM certificate (single or wildcard).
- 🤖 **Auto-generated GitHub Actions workflows** tailored to the chosen modality.
- 🔑 **Keyless CI/CD via OIDC**: a GitHub↔AWS trust relationship replaces static keys, with a
  least-privilege policy scoped to exactly your buckets, parameter, and distribution.

---

## Using it

The fast path lives in the **[Quickstart](./docs/en/quickstart.md)**. In short:

1. **Create a `terraform.tfvars`** describing your buckets, CloudFront, Lambda mode, domain
   and GitHub repo. (Ready-made examples per modality:
   [complete guide → examples](./docs/en/full-guide.md#configuration-examples-tfvars).)
2. **Provision:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
   This creates the AWS resources **and** writes the workflows into `.github/workflows`.
3. **Commit the generated workflows** to your repository.
4. **Trigger a deploy** — push to the deploy branch (default `main`) or run the **Deploy**
   workflow manually. It assumes the IAM role via OIDC, builds, uploads to S3, invalidates.
5. **Roll back anytime** by running the **Rollback** workflow (one click).

> 🧪 Want to validate end-to-end first? The [`bluegreen_site/`](./bluegreen_site/README.md)
> demo is a single self-contained HTML page; the
> [Quickstart](./docs/en/quickstart.md#testing-the-full-flow-with-the-demo) walks through a
> deploy → deploy → rollback → restore cycle with it.

### Requirements

- **Terraform ≥ 1.5**, **AWS provider ~> 6.33**.
- An **AWS account**, with the stack deployed in **`us-east-1`** (required by CloudFront's
  ACM certificate and Lambda@Edge).
- A **GitHub repository** for the generated CI/CD; a **Route 53 hosted zone** for custom domains.

---

## Repository structure

```text
.
├── README.md               # You are here — the main, middle-ground doc
├── *.tf                     # Root stack: S3, CloudFront, Lambda@Edge, ACM, Route 53, outputs
├── lambda/                  # Lambda@Edge templates: oac/ (private) and s3_website/ (public)
├── modules/gha_gen_workflows/  # OIDC + IAM + GitHub Actions workflow generator
├── bluegreen_site/          # Self-contained demo static site
└── docs/
    ├── architecture.drawio  # Architecture diagram with AWS logos (draw.io)
    ├── en/  {quickstart.md, full-guide.md}
    └── pt-br/  {README.md, quickstart.md, full-guide.md}
```

A file-by-file breakdown is in the
[complete guide → repository structure](./docs/en/full-guide.md#repository-structure).

---

## Good to know

A few constraints worth keeping in mind (the
[complete guide](./docs/en/full-guide.md#conventions-constraints--gotchas) explains each):

- **Deploy in `us-east-1`** (CloudFront ACM + Lambda@Edge requirement).
- **Exactly one production bucket** (`main_bucket = true`, `versions_bucket = false`) — its
  name can be anything; a validation enforces this.
- A bucket is **either** public (`website = true`) **or** private (`origin_access_control = true`),
  never both, and `lambda_edge.cf_access_bucket_mode` must match.
- For a **custom domain**, use ACM (`acm.create = true`) and set the CloudFront default
  certificate to `false`.
- Rollback propagation ≈ Lambda cache TTL (~60s) + invalidation time — fast, not literally instant.

---

## Use cases

- **Marketing / landing / docs sites** that must never stay "stuck broken".
- **SPAs** (React/Vue/Angular) wanting safe, frequent deploys with a fast escape hatch.
- **Teams adopting keyless CI/CD** (OIDC) instead of managing AWS access keys.
- **Audited environments** that benefit from an immutable archive of every build and exact
  per-commit restores.

---

> 📖 Dig deeper in the complete guide ([EN](./docs/en/full-guide.md) ·
> [PT](./docs/pt-br/full-guide.md)) · ⚡ or get going with the quickstart
> ([EN](./docs/en/quickstart.md) · [PT](./docs/pt-br/quickstart.md)).
