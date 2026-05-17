---
title: GitHub Release
parent: Plugins
nav_order: 1
---

# GitHub Release Plugin

The `github-release` plugin creates a GitHub Release after zero-release creates and pushes the Git tag.

It does not replace Git tags. The tag is still the Git-native version marker. The GitHub Release is platform metadata attached to that tag, with title, notes, and release state.

## Enable it

```bash
zero-release --plugins release-notes,changelog,package-json,github-release
```

In GitHub Actions:

```yaml
- uses: zero-release/zero-release@v1
  with:
    plugins: "release-notes,changelog,package-json,github-release"
    branches: "main"
```

## Requirements

For real releases, the plugin requires:

| Requirement | Notes |
|---|---|
| `curl` | Used to call the GitHub REST API |
| Token | `ZERO_RELEASE_GITHUB_TOKEN`, `GITHUB_TOKEN`, or `GH_TOKEN` |
| Repository | `GITHUB_REPOSITORY` or a parseable GitHub remote URL |
| Tag push | The Git tag must exist on GitHub |

The published composite action passes the workflow `github.token` as `GITHUB_TOKEN` automatically.

## Behavior

The plugin runs during `publish`, after the core creates and pushes the tag.

It sends a `POST` request to:

```text
https://api.github.com/repos/OWNER/REPO/releases
```

The payload contains:

| Field | Source |
|---|---|
| `tag_name` | `ZERO_RELEASE_NEXT_TAG` |
| `name` | `ZERO_RELEASE_GITHUB_RELEASE_NAME` or the next tag |
| `body` | Generated release notes file |
| `draft` | `false` |
| `prerelease` | `true` when the channel is not `stable` |

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `ZERO_RELEASE_GITHUB_TOKEN` | `GITHUB_TOKEN` or `GH_TOKEN` | Token used to create the GitHub Release |
| `ZERO_RELEASE_GITHUB_RELEASE_NAME` | Next tag | Release title |
| `GITHUB_REPOSITORY` | Parsed from `origin` when possible | Repository in `owner/name` form |
| `GITHUB_API_URL` | `https://api.github.com` | GitHub API base URL, useful for GitHub Enterprise |

## Guardrails

The plugin fails clearly when:

- a real release is running without a token;
- the repository cannot be determined;
- `curl` is missing;
- `--no-tag` is enabled;
- `--no-push` is enabled.

`--no-tag` and `--no-push` are incompatible because the GitHub Release should point to a tag that already exists on GitHub.

In dry-run mode, the plugin is skipped and no network call is made.
