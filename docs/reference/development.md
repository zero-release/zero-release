---
title: Development
parent: Reference
nav_order: 5
---

# Development

This repository keeps the release tool itself dependency-light. Documentation source is plain Markdown plus Jekyll configuration for GitHub Pages.

## Run syntax checks

```bash
for file in bin/zero-release bin/semantic-release lib/*.sh plugins/*/plugin; do
  bash -n "$file"
done
```

## Run tests

```bash
bats tests/unit/*.bats tests/integration/*.bats
```

## Work on documentation

Edit the Markdown files under `docs/`.

The `docs-site` workflow mirrors `docs/` into `zero-release/zero-release.github.io`, where GitHub Pages builds the root organization site with Jekyll and the Just the Docs remote theme.

The repository stores:

```text
docs/_config.yml
docs/**/*.md
```

Generated site output is not committed.

## Repository layout

```text
bin/                 CLI entrypoints
lib/                 Bash helper libraries
plugins/             Built-in plugin executables
tests/               Unit and integration tests
docs/                GitHub Pages documentation source
```
