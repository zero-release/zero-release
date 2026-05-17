---
title: npm Publishing
parent: Plugins
nav_order: 2
---

# npm Publishing Plugin

The `npm` plugin publishes packages with `npm publish`. It is built for npm Trusted Publishing and OIDC-based authentication.

## Enable it

```bash
zero-release --plugins release-notes,changelog,package-json,git-commit,npm,github-release
```

## GitHub Actions example

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
        with:
          plugins: "release-notes,changelog,package-json,git-commit,npm,github-release"
          branches: "main"
```

## Dist-tags

Stable releases publish with `latest`.

Prereleases publish with the release channel as the dist-tag:

| Channel | npm dist-tag |
|---|---|
| `stable` | `latest` |
| `alpha` | `alpha` |
| `beta` | `beta` |
| `rc` | `rc` |

Override the dist-tag with `ZERO_RELEASE_NPM_TAG`.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `ZERO_RELEASE_NPM_TAG` | `latest` for stable, channel for prerelease | Override the npm dist-tag |
| `ZERO_RELEASE_NPM_ACCESS` | empty | Optional `npm publish --access` value, either `public` or `restricted` |
| `ZERO_RELEASE_NPM_REGISTRY` | empty | Optional `npm publish --registry` value |
| `ZERO_RELEASE_NPM_PACKAGE` | empty | Optional package spec, folder, or tarball to pass to `npm publish` |

## Notes

The plugin does not manage `NPM_TOKEN`. Configure npm Trusted Publishing on npmjs.com and grant the workflow `id-token: write`.

The plugin is skipped in dry-run mode.
