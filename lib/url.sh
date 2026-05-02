#!/usr/bin/env bash

zr_trim_dot_git() {
  local value="$1"
  value="${value%.git}"
  printf '%s\n' "$value"
}

zr_remote_to_https() {
  local remote="$1"
  local url="$remote"

  if [[ "$remote" =~ ^git@ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/(.+)$ ]]; then
    url="https://dev.azure.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/_git/${BASH_REMATCH[3]}"
  elif [[ "$remote" =~ ^git@([^:]+):(.+)$ ]]; then
    url="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  elif [[ "$remote" =~ ^ssh://git@ssh\.dev\.azure\.com/v3/([^/]+)/([^/]+)/(.+)$ ]]; then
    url="https://dev.azure.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/_git/${BASH_REMATCH[3]}"
  elif [[ "$remote" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    url="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi

  zr_trim_dot_git "$url"
}

zr_get_repository_url() {
  local remote
  remote="$(git remote get-url origin 2>/dev/null || true)"
  if [ -z "$remote" ]; then
    return 1
  fi
  zr_remote_to_https "$remote"
}

zr_detect_provider() {
  local repo_url="$1"

  case "$repo_url" in
    *github.com*) printf 'github\n' ;;
    *gitlab.com*) printf 'gitlab\n' ;;
    *bitbucket.org*) printf 'bitbucket\n' ;;
    *dev.azure.com*|*visualstudio.com*) printf 'azure-devops\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

zr_compare_url() {
  local repo_url="$1"
  local from_tag="$2"
  local to_tag="$3"
  local provider

  [ -n "$repo_url" ] || return 1
  [ -n "$from_tag" ] || return 1
  [ -n "$to_tag" ] || return 1

  provider="$(zr_detect_provider "$repo_url")"
  case "$provider" in
    github) printf '%s/compare/%s...%s\n' "$repo_url" "$from_tag" "$to_tag" ;;
    gitlab) printf '%s/-/compare/%s...%s\n' "$repo_url" "$from_tag" "$to_tag" ;;
    bitbucket) printf '%s/branches/compare/%s%%0D%s\n' "$repo_url" "$to_tag" "$from_tag" ;;
    azure-devops) printf '%s/branchCompare?baseVersion=GT%s&targetVersion=GT%s\n' "$repo_url" "$from_tag" "$to_tag" ;;
    *) printf '%s/compare/%s...%s\n' "$repo_url" "$from_tag" "$to_tag" ;;
  esac
}

zr_commit_url() {
  local repo_url="$1"
  local hash="$2"
  local provider

  [ -n "$repo_url" ] || return 1
  [ -n "$hash" ] || return 1

  provider="$(zr_detect_provider "$repo_url")"
  case "$provider" in
    gitlab) printf '%s/-/commit/%s\n' "$repo_url" "$hash" ;;
    bitbucket) printf '%s/commits/%s\n' "$repo_url" "$hash" ;;
    *) printf '%s/commit/%s\n' "$repo_url" "$hash" ;;
  esac
}
