<div align="center">

# 0️⃣🚀 zero-release

**Zero-runtime-dependency semantic release automation for GitHub Actions, written in Bash and based on Conventional Commits.**

[![tests](https://github.com/zero-release/zero-release/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/zero-release/zero-release/actions/workflows/tests.yml)
![Bash](https://img.shields.io/badge/bash-CLI-4EAA25?logo=gnubash&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-composite%20action-2088FF?logo=githubactions&logoColor=white)
![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-FE5196?logo=conventionalcommits&logoColor=white)
![runtime dependencies](https://img.shields.io/badge/runtime%20dependencies-zero-brightgreen)
![jq](https://img.shields.io/badge/jq-not%20required-lightgrey)

</div>

`zero-release` analyzes Conventional Commits, calculates the next SemVer version, creates Git tags, generates release notes, and runs explicit publish/notify plugins. It is built for repositories that want release automation in CI without installing Node packages, `jq`, Python, `gh`, or a runtime dependency tree.

It is semantic-release inspired, not semantic-release compatible. Configuration is explicit through CLI flags, action inputs, and environment variables; `.releaserc` and package-manager installs are intentionally out of scope for the core.

### [Read the docs ->](https://zero-release.github.io/)

## Install

Run it directly from this repository:

```bash
./bin/zero-release --dry-run
```

Or add `bin/` to `PATH`:

```bash
export PATH="$PWD/bin:$PATH"
zero-release --dry-run
```

You'll get the next release decision from your Git history and Conventional Commit messages. Use `--json` for machine-readable output, or `doctor` to check whether the repository is ready to release.

```bash
zero-release analyze --json
zero-release doctor --json
```

An optional compatibility wrapper exists at `bin/semantic-release`, but new documentation and workflows should use `zero-release`.

## GitHub Actions

A composite action ships with this repository. Drop it into `.github/workflows/release.yml`:

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

`fetch-depth: 0` gives `zero-release` the tags and commit history it needs. `contents: write` allows it to push the new tag, and lets the `github-release` plugin create a GitHub Release when enabled.

For stricter reproducibility, pin a full version tag:

```yaml
- uses: zero-release/zero-release@v1.0.0
```

**Inputs:** `dry-run`, `plugins`, `branches`, `prerelease-branches`, `tag-format`, `changelog-file`, `package-json`, `debug`. See [`action.yml`](https://github.com/zero-release/zero-release/blob/main/action.yml) for full descriptions.

**Outputs:** `released`, `version`, `tag`, `bump`, `previous-version`, `previous-tag`, `channel`.

## PR Previews

On `pull_request` events, `zero-release` defaults to dry-run. The workflow can show which release would be produced without changing files, creating tags, pushing branches, or calling network plugins.

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

Use a follow-up step when you want to comment, annotate, or gate on the action outputs.

```yaml
- run: |
    echo "release=${{ steps.release.outputs.released }}"
    echo "version=${{ steps.release.outputs.version }}"
    echo "tag=${{ steps.release.outputs.tag }}"
```

## Release Modes

Pick the mode that matches the repository.

**Release notes only** creates a tag and generated notes without mutating project files:

```yaml
- uses: zero-release/zero-release@v1
  with:
    plugins: "release-notes,github-release"
```

**Commit release assets** updates files such as `CHANGELOG.md` or `package.json`, then commits them before tagging:

```yaml
- run: |
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

- uses: zero-release/zero-release@v1
  with:
    plugins: "release-notes,changelog,package-json,git-commit,github-release"
```

**npm trusted publishing** uses npm OIDC. It does not require or manage `NPM_TOKEN`; configure the trusted publisher on npmjs.com and grant `id-token: write` in the workflow.

```yaml
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

Trusted publishing currently requires npm CLI `11.5.1` or later and Node.js `22.14.0` or later.

## Prereleases

Prereleases are opt-in. Stable releases only run from branches configured with `--branches`.

```yaml
- uses: zero-release/zero-release@v1
  with:
    branches: "main"
    prerelease-branches: "alpha,beta,rc,next:beta"
    plugins: "release-notes,changelog,package-json,github-release"
```

The prerelease identifier defaults to the branch name unless mapped:

```text
1.3.0-alpha.1
1.3.0-alpha.2
1.3.0-beta.1
```

Branch/channel prerelease support is intentionally simple. More advanced semantic-release branch ranges and channel promotion are roadmap items.

## Configuration

There is no project config file loader. No `.releaserc`, `.releaserc.json`, `.releaserc.yml`, or `package.json#release` is read or executed.

Configure the CLI with flags:

```bash
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
```

Or configure the composite action with `with:` inputs:

```yaml
- uses: zero-release/zero-release@v1
  with:
    dry-run: "false"
    branches: "main"
    plugins: "release-notes,changelog,package-json,github-release"
    tag-format: "v%s"
    changelog-file: "CHANGELOG.md"
    package-json: "package.json"
```

## Release Rules

Default release rules follow Conventional Commits:

| Commit pattern | Release type |
|---|---|
| `feat:` / `feat(scope):` | `minor` |
| `fix:` / `fix(scope):` | `patch` |
| `perf:` / `perf(scope):` | `patch` |
| `type!:` / `type(scope)!:` | `major` |
| `BREAKING CHANGE` / `BREAKING-CHANGE` | `major` |
| `chore:` / `docs:` / `test:` | no release |
| `major:` | no release by default |

Breaking changes are detected from footer markers and bang syntax:

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

## Plugins

Built-in plugins are explicit. Network behavior only happens when a network plugin is enabled, and network plugins are skipped in dry-run.

| Plugin | Lifecycle | Changes files? | Network? | Purpose |
|---|---|---:|---:|---|
| `release-notes` | `generate-notes` | No | No | Generates release notes |
| `changelog` | `prepare` | Yes | No | Updates `CHANGELOG.md` or `--changelog-file` |
| `package-json` | `prepare` | Yes | No | Updates the top-level `version` field in `package.json` |
| `git-commit` | `prepare` | Yes | No | Commits changed release assets when explicitly enabled |
| `npm` | `publish` | No | Yes | Publishes with `npm publish` using npm Trusted Publishing/OIDC |
| `github-release` | `publish` | No | Yes | Creates a GitHub Release with generated Markdown notes |
| `slack` | `notify` | No | Yes | Sends a Slack webhook notification |
| `webhook` | `notify` | No | Yes | Sends a generic webhook notification |
| `gchat` | `notify` | No | Yes | Sends a Google Chat webhook notification |

Plugin execution order is deterministic and based on lifecycle responsibility, not on the order passed to `--plugins`.

```text
prepare: changelog -> package-json -> git-commit
publish: npm -> github-release
notify:  webhook -> slack -> gchat
```

The core always produces a release notes file before `prepare` and `publish`. Enabling `release-notes` makes that generation explicit and leaves room for alternate notes plugins, but `changelog`, annotated Git tags, and `github-release` can still consume generated notes when `release-notes` is not listed.

## Publishing

Publishing is deliberately explicit:

| Action | Behavior |
|---|---|
| Create tag | Done locally unless `--no-tag` or `--dry-run` |
| Push tag | Done with `git push origin "$tag"` unless `--no-push`, `--no-tag`, or `--dry-run` |
| Push branch | Done only when the `git-commit` plugin created a release commit |
| npm package | Done with `npm publish` when the `npm` plugin is enabled; stable releases use `latest`, prereleases use the channel as the dist-tag |
| GitHub Release | Done with the GitHub Releases API when the `github-release` plugin is enabled |
| Dry-run | Never creates commits, tags, pushes, or network calls |

The `github-release` plugin supports:

| Variable | Default | Description |
|---|---|---|
| `ZERO_RELEASE_GITHUB_TOKEN` | `GITHUB_TOKEN` or `GH_TOKEN` | Token used to create the GitHub Release |
| `ZERO_RELEASE_GITHUB_RELEASE_NAME` | Next tag | Release title |
| `GITHUB_REPOSITORY` | parsed from `origin` when possible | Repository in `owner/name` form |
| `GITHUB_API_URL` | `https://api.github.com` | GitHub API base URL, useful for GitHub Enterprise |

The `npm` plugin supports:

| Variable | Default | Description |
|---|---|---|
| `ZERO_RELEASE_NPM_TAG` | `latest` for stable, channel for prerelease | Override the npm dist-tag |
| `ZERO_RELEASE_NPM_ACCESS` | empty | Optional `npm publish --access` value, either `public` or `restricted` |
| `ZERO_RELEASE_NPM_REGISTRY` | empty | Optional `npm publish --registry` value |
| `ZERO_RELEASE_NPM_PACKAGE` | empty | Optional package spec, folder, or tarball to pass to `npm publish` |

## CLI Reference

```text
Usage:
  zero-release [options]
  zero-release analyze [options]
  zero-release doctor [options]

Options:
  --dry-run
  --json
  --debug
  --no-push
  --no-tag
  --branches main,master
  --plugins release-notes,changelog,package-json,github-release,npm
  --tag-format "v%s"
  --changelog-file CHANGELOG.md
  --package-json package.json
  --prerelease-branches alpha,beta,rc
  --prerelease-branch next:beta
```

The default command performs the full release flow. `analyze` calculates the release result and exits before mutations. `doctor` checks the environment and configuration.

### JSON output

`--json` output is generated by Bash helpers and escaped without `jq`.

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

### Doctor

```bash
zero-release doctor
zero-release doctor --json
```

Doctor checks Bash, Git, repository state, tag availability, branch detection, branch allowlists, remote/provider detection, plugin names, optional network plugin requirements and secrets, GitHub pull request safety, and whether dry-run would be defaulted.

Doctor does not perform release actions.

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

Core analysis and publishing are handled by the CLI. Plugins are executable hook adapters and receive release context through `ZERO_RELEASE_*` environment variables.

## Security Model

`zero-release` keeps the core small and avoids executing project-owned configuration.

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

The roadmap is tracked in GitHub issues so planned work stays discussable and current.

- [Design an external plugin API](https://github.com/zero-release/zero-release/issues/3)
- [Add a safe configuration file](https://github.com/zero-release/zero-release/issues/4)
- [Support custom release rules](https://github.com/zero-release/zero-release/issues/5)
- [Expand branch and channel support](https://github.com/zero-release/zero-release/issues/6)
- [Support assets in GitHub Releases](https://github.com/zero-release/zero-release/issues/7)
- [Make release commits configurable](https://github.com/zero-release/zero-release/issues/8)
- [Add release notes templates](https://github.com/zero-release/zero-release/issues/9)
- [Add a GitLab Release plugin](https://github.com/zero-release/zero-release/issues/10)
- [Define a plugin distribution strategy](https://github.com/zero-release/zero-release/issues/11)

See the [open issues](https://github.com/zero-release/zero-release/issues) for the current list.

## Resources & Contributing

Documentation source lives in [`docs/`](docs/) and is published to [zero-release.github.io](https://zero-release.github.io/).

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

Find a bug or want to propose a feature? Open an issue or pull request in this repository.
