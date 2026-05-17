---
title: Getting Started
parent: Guide
nav_order: 1
---

# Getting Started

`zero-release` automates version calculation, release notes, Git tags, and optional publishing plugins from Conventional Commits.

It is designed to run in CI, especially GitHub Actions, but the CLI can also be used locally for previews and diagnostics.

## What zero-release does

For a release-worthy commit range, zero-release can:

1. Read the previous Git tag.
2. Analyze commit messages using Conventional Commits.
3. Calculate the next SemVer version and Git tag.
4. Generate release notes.
5. Update files through prepare plugins, such as `CHANGELOG.md` or `package.json`.
6. Create and push an annotated Git tag.
7. Publish through explicit plugins, such as `github-release` or `npm`.
8. Notify external systems through explicit notification plugins.

## Requirements

The core CLI expects:

| Requirement | Why |
|---|---|
| Bash | Runs the CLI and plugin hooks |
| Git | Reads commits, tags, branches, and creates release tags |
| Standard Unix tools | Used for text processing and shell operations |

The core does not require Node, jq, Python, GitHub CLI, or curl. Some plugins have extra requirements. For example, `github-release` and notification plugins require `curl`, and the `npm` plugin requires the npm CLI.

## Try a dry run

From a checkout of this repository:

```bash
./bin/zero-release --dry-run
```

Or add `bin/` to `PATH`:

```bash
export PATH="$PWD/bin:$PATH"
zero-release --dry-run
```

Dry-run mode analyzes the release that would be produced without creating commits, tags, pushes, network calls, or file modifications.

## Recommended first workflow

For most projects, start with:

```yaml
- uses: zero-release/zero-release@v1
  id: release
  with:
    plugins: "release-notes,changelog,package-json,github-release"
    branches: "main"
```

This setup generates release notes, updates `CHANGELOG.md`, updates a top-level `package.json` version if present, creates and pushes the Git tag, and publishes a GitHub Release.

## Configuration model

Configuration is deliberately explicit:

- CLI flags
- GitHub Action inputs
- environment variables for plugin secrets and overrides

`zero-release` does not load `.releaserc`, `.releaserc.json`, `.releaserc.yml`, or `package.json#release`.

## Next steps

- Configure [GitHub Actions]({{ site.baseurl }}/guide/github-actions/).
- Review [core concepts]({{ site.baseurl }}/guide/concepts/).
- Review [release rules]({{ site.baseurl }}/guide/release-rules/).
- Choose [plugins]({{ site.baseurl }}/plugins/).
- Run [doctor]({{ site.baseurl }}/reference/cli/#doctor).
