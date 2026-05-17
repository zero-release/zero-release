---
title: GitHub Pages
parent: Deployment
nav_order: 1
---

# GitHub Pages

The documentation site is designed to publish from Markdown source without committing generated HTML or JavaScript build artifacts.

GitHub Pages is the recommended host for this project because it has built-in Jekyll support. The repository stores Markdown and `_config.yml`; GitHub Pages runs Jekyll and publishes the static site.

## Repository files

The repository stores:

```text
docs/
  _config.yml
  index.md
  guide/
  plugins/
  reference/
  deployment/
```

The repository does not store:

```text
docs/_site/
```

## Recommended settings

Use these GitHub Pages settings:

| Setting | Value |
|---|---|
| Source | Deploy from a branch |
| Branch | `main` |
| Folder | `/docs` |

The project site will be published at:

```text
https://zero-release.github.io/zero-release/
```

## Theme

The docs use Just the Docs through Jekyll remote themes:

```yaml
remote_theme: just-the-docs/just-the-docs
plugins:
  - jekyll-remote-theme
```

This keeps the documentation source lightweight while still providing documentation-oriented navigation and search.

## Custom domains

If the docs later move to a custom domain, update `url` and `baseurl` in `docs/_config.yml`.

For a root custom domain such as `https://zero-release.dev`, use:

```yaml
url: "https://zero-release.dev"
baseurl: ""
```

For a subpath deployment, keep `baseurl` set to the path prefix.
