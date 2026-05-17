<div align="center">

# 0️⃣🚀 zero-release

**Zero-runtime-dependency semantic release automation for GitHub Actions, written in Bash and based on Conventional Commits.**

[![tests](https://github.com/zero-release/zero-release/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/zero-release/zero-release/actions/workflows/tests.yml) ![Bash](https://img.shields.io/badge/bash-CLI-4EAA25?logo=gnubash&logoColor=white) ![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-composite%20action-2088FF?logo=githubactions&logoColor=white) ![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-FE5196?logo=conventionalcommits&logoColor=white) ![runtime dependencies](https://img.shields.io/badge/runtime%20dependencies-zero-brightgreen) ![jq](https://img.shields.io/badge/jq-not%20required-lightgrey)

</div>

`zero-release` is a zero-runtime-dependency semantic release automation tool for GitHub Actions, written in Bash and based on Conventional Commits.

It is semantic-release inspired, not semantic-release compatible. The current version intentionally does not implement `.releaserc`, `.releaserc.json`, package-manager installs, or JavaScript runtime dependencies.

The documentation site source lives in `docs/` as plain Markdown plus Jekyll configuration for GitHub Pages. It is published to `https://zero-release.github.io/` by mirroring `docs/` into `zero-release/zero-release.github.io`; generated HTML is not committed.

## At a glance

| Area | zero-release |
|---|---|
| Runtime | Bash |
| Core dependencies | Bash, Git, and standard Unix tools |
| Commit convention | Conventional Commits |
| Configuration | CLI flags and environment variables |
| GitHub Actions | Composite action |
| Network calls | Explicit plugins only |
| `.releaserc` | Not supported |
| Compatibility | semantic-release inspired, not compatible |

## Why

`zero-release` exists for repositories that want a small release automation path in CI:

| Goal | How zero-release handles it |
|---|---|
| Reduce runtime dependencies | Bash core with no Node, jq, Python, gh, or curl |
| Avoid package-manager setup | No required package installation for the core CLI |
| Automate SemVer | Conventional Commit analysis and Git tag calculation |
| Work well in GitHub Actions | Composite action and `$GITHUB_OUTPUT` |
| Keep PRs safe | `pull_request` events default to dry-run |
| Isolate network access | Network calls only happen in explicit plugins |

This gives a smaller supply-chain surface by design: no runtime JS dependencies and no package installation required.

## Install

Use the executable directly from this repository:

```bash
./bin/zero-release --dry-run
```

Or add `bin/` to `PATH`:

```bash
export PATH="$PWD/bin:$PATH"
zero-release --dry-run
```

For GitHub Actions, prefer using the composite action shown below.

An optional compatibility wrapper exists at `bin/semantic-release`, but documentation and new workflows should use `zero-release`.

## Local Usage

```bash
zero-release
zero-release --dry-run
zero-release --json
zero-release --debug
zero-release --no-push
zero-release --no-tag
zero-release --branches main,master
zero-release --plugins release-notes,changelog,package-json,github-release,npm
zero-release --tag-format "v%s"
zero-release --changelog-file CHANGELOG.md
zero-release --package-json package.json
zero-release --branches main --prerelease-branches alpha,beta,rc
zero-release analyze --json
zero-release doctor --json
```

Configuration is only through CLI flags and environment variables. `.releaserc` is deliberately not loaded.

## GitHub Actions

Use `actions/checkout` with full history and tags, and grant write access to repository contents so `zero-release` can create and push tags. Add the `github-release` plugin when you want GitHub to render the generated Markdown as a release body.

### Using the published action

```yaml
name: release

on:
  push:
    branches:
      - main

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: zero-release/zero-release@v1
        id: release
        with:
          plugins: "release-notes,changelog,package-json,github-release"
          branches: "main"
```

For a fully pinned version, use a specific tag:

```yaml
- uses: zero-release/zero-release@v1.0.0
```

### npm trusted publishing

The `npm` plugin is built for npm Trusted Publishing. It does not require or manage `NPM_TOKEN`; the npm CLI authenticates through OIDC when the package has a trusted publisher configured on npmjs.com and the workflow has `id-token: write`.

```yaml
name: release

on:
  push:
    branches:
      - main

permissions:
  contents: write
  id-token: write

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: "24"
          registry-url: "https://registry.npmjs.org"

      - run: npm ci
      - run: npm test
      - run: npm run build --if-present

      - run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

      - uses: zero-release/zero-release@v1
        id: release
        with:
          plugins: "release-notes,changelog,package-json,git-commit,npm,github-release"
          branches: "main"
```

Trusted publishing currently requires npm CLI `11.5.1` or later and Node.js `22.14.0` or later. For GitHub Actions and GitLab CI/CD, npm generates provenance automatically for supported public package publishes.

### Using the action from the same repository

When developing or testing `zero-release` itself, use the local action path:

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0

- uses: ./
  id: release
  with:
    dry-run: "false"
    plugins: "release-notes,changelog,package-json,github-release"
    branches: "main"
```

### Pull requests

In GitHub Actions, `pull_request` events default to dry-run. This means pull request workflows can analyze the release that would be produced without creating commits, tags, pushes, or network notifications.

```yaml
name: release-preview

on:
  pull_request:

jobs:
  preview:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: zero-release/zero-release@v1
        id: release
        with:
          plugins: "release-notes,changelog,package-json,github-release"
          branches: "main"
```

### Prerelease branches

Prereleases are opt-in. Configure prerelease branches explicitly:

```yaml
- uses: zero-release/zero-release@v1
  id: release
  with:
    branches: "main"
    prerelease-branches: "alpha,beta,rc,next:beta"
    plugins: "release-notes,changelog,package-json,github-release"
```

When `$GITHUB_OUTPUT` exists, the CLI writes these outputs directly:

| Output | Description |
|---|---|
| `released` | Whether a release was produced |
| `version` | The next version |
| `tag` | The next Git tag |
| `bump` | `major`, `minor`, or `patch` |
| `previous-version` | The previous version |
| `previous-tag` | The previous Git tag |
| `channel` | `stable` or the prerelease channel |

## Flags

| Flag | Default | Description |
|---|---|---|
| `--dry-run` | auto in PRs | Analyze, calculate, and preview without modifying files, creating tags, pushing, committing, or calling network plugins |
| `--json` | `false` | Print stable JSON output generated by zero-release without requiring `jq` |
| `--debug` | `false` | Print debug logs to stderr |
| `--no-push` | `false` | Create local release work but do not push Git tags or branches |
| `--no-tag` | `false` | Do not create a tag |
| `--branches` | `main,master` | Comma-separated stable branches |
| `--plugins` | `release-notes` | Comma-separated plugins |
| `--tag-format` | `v%s` | Tag format with one `%s` placeholder |
| `--changelog-file` | `CHANGELOG.md` | Changelog file path |
| `--package-json` | `package.json` | Package file path |
| `--prerelease-branches` | empty | Comma-separated prerelease branches. Entries may be `branch` or `branch:channel` |
| `--prerelease-branch` | empty | Repeatable single prerelease branch mapping |

## Lifecycle

The CLI is structured around semantic-release-like lifecycle names:

```text
verify
analyze
verify-release
generate-notes
prepare
publish
notify
success
fail
```

Core analysis and publishing are handled by the CLI. Plugins are executable hook adapters and receive context through `ZERO_RELEASE_*` environment variables.

```mermaid
flowchart TD
  A[Start zero-release] --> B[Verify environment]
  B --> C[Read Git tags and commits]
  C --> D[Analyze Conventional Commits]
  D --> E{Release needed?}
  E -- No --> F[Print no-release result]
  E -- Yes --> G[Calculate next version and tag]
  G --> H[Generate release notes]
  H --> I[Prepare files via plugins]
  I --> J{Dry-run?}
  J -- Yes --> K[Preview only]
  J -- No --> L[Create tag]
  L --> M[Push tag]
  M --> N[Run publish plugins]
  N --> O[Notify via explicit plugins]
```

Plugin execution order is deterministic and based on lifecycle responsibility, not on the order passed to `--plugins`. In `prepare`, asset-changing plugins run before `git-commit`:

```text
changelog
package-json
git-commit
```

Notify plugins run in this order when enabled:

```text
webhook
slack
gchat
```

Publish plugins run in this order when enabled:

```text
npm
github-release
```

## Release Rules

Default rules:

| Commit pattern | Release type |
|---|---|
| `feat:` / `feat(scope):` | `minor` |
| `fix:` / `fix(scope):` | `patch` |
| `perf:` / `perf(scope):` | `patch` |
| `type!:` / `type(scope)!:` | `major` |
| `BREAKING CHANGE` / `BREAKING-CHANGE` | `major` |
| `chore:` / `docs:` / `test:` | no release |
| `major:` | no release by default |

Breaking changes are detected from:

```text
BREAKING CHANGE
BREAKING-CHANGE
feat!: message
feat(scope)!: message
fix!: message
fix(scope)!: message
perf!: message
perf(scope)!: message
refactor(core)!: message
```

`major:` does not create a major release by default.

## Prerelease Branches

Prereleases are opt-in. By default, `zero-release` only releases from stable branches configured with `--branches`.

To enable prereleases, configure prerelease branches explicitly:

```bash
zero-release --branches main --prerelease-branches alpha,beta,rc
zero-release --branches main --prerelease-branches alpha:alpha,next:beta
```

The prerelease identifier defaults to the branch name unless mapped. Existing prerelease tags are used to increment the number:

```text
1.3.0-alpha.1
1.3.0-alpha.2
1.3.0-beta.1
```

This is intentionally simple branch/channel prerelease support. More advanced semantic-release branch ranges and channel promotion are roadmap items.

## Plugins

Built-in plugins:

| Plugin | Lifecycle hook | Changes files? | Network? | Purpose |
|---|---|---:|---:|---|
| `release-notes` | `generate-notes` | No | No | Generates release notes |
| `changelog` | `prepare` | Yes | No | Updates `CHANGELOG.md` or `--changelog-file` |
| `package-json` | `prepare` | Yes | No | Updates the top-level `version` field in `package.json`; fails instead of modifying a nested or ambiguous field |
| `git-commit` | `prepare` | Yes | No | Commits changed release assets when explicitly enabled |
| `npm` | `publish` | No | Yes | Publishes with `npm publish` using npm Trusted Publishing/OIDC |
| `github-release` | `publish` | No | Yes | Creates a GitHub Release with the generated Markdown notes |
| `slack` | `notify` | No | Yes | Sends a Slack webhook notification |
| `webhook` | `notify` | No | Yes | Sends a generic webhook notification |
| `gchat` | `notify` | No | Yes | Sends a Google Chat webhook notification |

The core always produces a release notes file before `prepare` and `publish`. Enabling `release-notes` makes that generation explicit and leaves room for alternate notes plugins, but `changelog`, annotated Git tags, and `github-release` can still consume the generated notes when `release-notes` is not listed.

Network plugins are never run in `--dry-run` and must be enabled explicitly. GitHub release creation and notification plugins require `curl`. The `github-release` plugin requires `GITHUB_TOKEN`, `GH_TOKEN`, or `ZERO_RELEASE_GITHUB_TOKEN`; the published composite action passes the workflow `github.token` automatically. The `npm` plugin requires the npm CLI and a trusted publisher configured in the npm package settings. Webhook secrets are not required for dry-run or no-release runs, but they are required for real releases that reach `notify`.

```mermaid
flowchart LR
  Core[zero-release core<br/>Bash + Git + standard Unix tools] --> Notes[release-notes]
  Core --> Changelog[changelog]
  Core --> Package[package-json]
  Core --> Commit[git-commit]
  Core --> Npm[npm<br/>uses npm CLI + OIDC]
  Core --> GitHubRelease[github-release<br/>uses GitHub REST API]
  Core --> Notify[notify plugins]

  Notify --> Slack[slack<br/>uses curl]
  Notify --> Webhook[webhook<br/>uses curl]
  Notify --> GChat[gchat<br/>uses curl]
```

## Publishing

Publishing is explicit:

| Action | Behavior |
|---|---|
| Create tag | Done locally unless `--no-tag` or `--dry-run` |
| Push tag | Done with `git push origin "$tag"` unless `--no-push`, `--no-tag`, or `--dry-run` |
| Push branch | Done only when the `git-commit` plugin created a release commit |
| npm package | Done with `npm publish` when the `npm` plugin is enabled; stable releases use `latest`, prereleases use the channel as the dist-tag |
| GitHub Release | Done with the GitHub Releases API when the `github-release` plugin is enabled |
| Dry-run | Never creates commits, tags, pushes, or network calls |

The `github-release` plugin supports these environment variables:

| Variable | Default | Description |
|---|---|---|
| `ZERO_RELEASE_GITHUB_TOKEN` | `GITHUB_TOKEN` or `GH_TOKEN` | Token used to create the GitHub Release |
| `ZERO_RELEASE_GITHUB_RELEASE_NAME` | Next tag | Release title |
| `GITHUB_REPOSITORY` | parsed from `origin` when possible | Repository in `owner/name` form |
| `GITHUB_API_URL` | `https://api.github.com` | GitHub API base URL, useful for GitHub Enterprise |

The `npm` plugin supports these environment variables:

| Variable | Default | Description |
|---|---|---|
| `ZERO_RELEASE_NPM_TAG` | `latest` for stable, channel for prerelease | Override the npm dist-tag |
| `ZERO_RELEASE_NPM_ACCESS` | empty | Optional `npm publish --access` value, either `public` or `restricted` |
| `ZERO_RELEASE_NPM_REGISTRY` | empty | Optional `npm publish --registry` value |
| `ZERO_RELEASE_NPM_PACKAGE` | empty | Optional package spec, folder, or tarball to pass to `npm publish` |

## JSON Output

`--json` output is generated by Bash helpers and escaped without `jq`.

Example release:

```json
{
  "released": true,
  "previousVersion": "1.2.3",
  "nextVersion": "1.3.0",
  "previousTag": "v1.2.3",
  "nextTag": "v1.3.0",
  "bump": "minor",
  "channel": "stable",
  "dryRun": true,
  "currentBranch": "main"
}
```

## Doctor

```bash
zero-release doctor
zero-release doctor --json
```

Doctor checks Bash, Git, repository state, tag availability, branch detection, branch allowlists, remote/provider detection, plugin names, optional network plugin requirements and secrets, GitHub pull request safety, and whether dry-run would be defaulted.

Doctor does not perform release actions.

## Security

`zero-release` follows these rules:

| Rule | Why it matters |
|---|---|
| No `eval` | Avoids command injection from untrusted input |
| No project config is sourced | Avoids executing repository-provided configuration |
| No `.releaserc` support | Keeps configuration explicit through flags/env |
| No `jq` | Keeps the core free of non-standard runtime dependencies |
| No improvised JSON/YAML config parser | Avoids fragile config parsing behavior |
| No network calls in the core | Keeps network behavior isolated to explicit plugins |
| Network plugins are skipped in dry-run | Keeps PR and preview workflows safe |
| Pull request events default to dry-run | Prevents publishing from PR workflows |
| Releases only run on allowed branches | Avoids accidental releases from arbitrary branches |
| Tags, versions, branch names, and plugin names are validated | Reduces unsafe input handling |
| Commits and commit messages are treated as untrusted input | Prevents release metadata from becoming executable behavior |

## Git Providers

Remote URL helpers support common HTTPS URLs and SSH conversion such as:

```text
git@github.com:user/repo.git
https://github.com/user/repo.git
```

Compare and commit URLs are generated for GitHub, GitLab, Bitbucket, and Azure DevOps when possible.

## Current Limitations

| Limitation | Notes |
|---|---|
| No config files | No `.releaserc`, `.releaserc.json`, `.releaserc.yml`, or `package.json#release` |
| No compatibility layer | semantic-release compatibility may be explored later |
| No custom release rules | Default Conventional Commit rules only |
| No GitLab release plugin yet | GitLab release creation is not implemented yet |
| Minimal `package-json` update | Updates the top-level `"version"` field using a minimal text-based strategy; complex JSON rewriting is out of scope |
| Simple prerelease support | Branch/channel prereleases are intentionally limited |

## Roadmap

- Optional config loader plugins:
  - `.releaserc`
  - `.releaserc.json`
  - `.releaserc.yml`
  - `package.json#release`
- Semantic-release compatibility layer.
- GitLab Release plugin.
- MCP server/wrapper.
- Optional Docker image for generic CI systems.
- Custom release rules.
- Custom changelog templates.

## Development

Run syntax checks:

```bash
for file in bin/zero-release bin/semantic-release lib/*.sh plugins/*/plugin; do
  bash -n "$file"
done
```

Run tests:

```bash
bats tests/unit/*.bats tests/integration/*.bats
```

Documentation source lives in `docs/` and is published with GitHub Pages at `https://zero-release.github.io/`.
