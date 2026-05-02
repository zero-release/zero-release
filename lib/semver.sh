#!/usr/bin/env bash

zr_validate_semver() {
  [[ "${1-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z-]*\.[0-9]+)?$ ]]
}

zr_validate_stable_semver() {
  [[ "${1-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

zr_validate_prerelease_identifier() {
  [[ "${1-}" =~ ^[0-9A-Za-z][0-9A-Za-z-]*$ ]]
}

zr_bump_version() {
  local version="$1"
  local bump="$2"
  local base major minor patch

  base="${version%%-*}"
  IFS='.' read -r major minor patch <<EOF
$base
EOF

  case "$bump" in
    major) printf '%s.0.0\n' "$((major + 1))" ;;
    minor) printf '%s.%s.0\n' "$major" "$((minor + 1))" ;;
    patch) printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))" ;;
    *) printf '%s\n' "$base" ;;
  esac
}

zr_compare_stable_versions() {
  local left="$1"
  local right="$2"
  local l_major l_minor l_patch r_major r_minor r_patch

  IFS='.' read -r l_major l_minor l_patch <<EOF
$left
EOF
  IFS='.' read -r r_major r_minor r_patch <<EOF
$right
EOF

  if [ "$l_major" -gt "$r_major" ]; then
    printf '1\n'
  elif [ "$l_major" -lt "$r_major" ]; then
    printf -- '-1\n'
  elif [ "$l_minor" -gt "$r_minor" ]; then
    printf '1\n'
  elif [ "$l_minor" -lt "$r_minor" ]; then
    printf -- '-1\n'
  elif [ "$l_patch" -gt "$r_patch" ]; then
    printf '1\n'
  elif [ "$l_patch" -lt "$r_patch" ]; then
    printf -- '-1\n'
  else
    printf '0\n'
  fi
}

zr_validate_tag_format() {
  local format="$1"
  local without_placeholder

  case "$format" in
    *'%s'*) ;;
    *) return 1 ;;
  esac

  without_placeholder="${format//%s/}"
  case "$without_placeholder" in
    *%*) return 1 ;;
  esac

  [[ "$format" =~ ^[A-Za-z0-9._/%-]*%s[A-Za-z0-9._/%-]*$ ]]
}

zr_tag_prefix() {
  local format="$1"
  printf '%s\n' "${format%%\%s*}"
}

zr_tag_suffix() {
  local format="$1"
  printf '%s\n' "${format#*\%s}"
}

zr_format_tag() {
  local format="$1"
  local version="$2"

  printf '%s\n' "${format//%s/$version}"
}

zr_extract_version_from_tag() {
  local format="$1"
  local tag="$2"
  local prefix suffix value

  prefix="$(zr_tag_prefix "$format")"
  suffix="$(zr_tag_suffix "$format")"
  value="$tag"

  if [ -n "$prefix" ]; then
    case "$value" in
      "$prefix"*) value="${value#"$prefix"}" ;;
      *) return 1 ;;
    esac
  fi

  if [ -n "$suffix" ]; then
    case "$value" in
      *"$suffix") value="${value%"$suffix"}" ;;
      *) return 1 ;;
    esac
  fi

  printf '%s\n' "$value"
}

zr_validate_tag_name() {
  local tag="$1"

  [ -n "$tag" ] || return 1
  case "$tag" in
    -*|*' '*|*$'\n'*|*$'\t'*|*'..'*|*'~'*|*'^'*|*':'*|*'?'*|*'['*|*'\\'*)
      return 1
      ;;
  esac
  git check-ref-format "refs/tags/$tag" >/dev/null 2>&1
}

zr_find_latest_stable_tag() {
  local format="$1"
  local prefix suffix pattern tag version
  local best_version="0.0.0"
  local best_tag=""

  prefix="$(zr_tag_prefix "$format")"
  suffix="$(zr_tag_suffix "$format")"
  pattern="${prefix}*${suffix}"

  while IFS= read -r tag; do
    version="$(zr_extract_version_from_tag "$format" "$tag" 2>/dev/null || true)"
    if zr_validate_stable_semver "$version"; then
      if [ "$(zr_compare_stable_versions "$version" "$best_version")" = "1" ]; then
        best_version="$version"
        best_tag="$tag"
      fi
    fi
  done < <(git tag --list "$pattern" 2>/dev/null || true)

  printf '%s\t%s\n' "$best_version" "$best_tag"
}

zr_next_prerelease_number() {
  local format="$1"
  local base_version="$2"
  local identifier="$3"
  local prefix suffix pattern tag version number
  local max=0

  prefix="$(zr_tag_prefix "$format")"
  suffix="$(zr_tag_suffix "$format")"
  pattern="${prefix}${base_version}-${identifier}.*${suffix}"

  while IFS= read -r tag; do
    version="$(zr_extract_version_from_tag "$format" "$tag" 2>/dev/null || true)"
    case "$version" in
      "$base_version-$identifier."*)
        number="${version##*.}"
        if [[ "$number" =~ ^[0-9]+$ ]] && [ "$number" -gt "$max" ]; then
          max="$number"
        fi
        ;;
    esac
  done < <(git tag --list "$pattern" 2>/dev/null || true)

  printf '%s\n' "$((max + 1))"
}

zr_find_latest_prerelease_tag() {
  local format="$1"
  local identifier="$2"
  local prefix suffix pattern tag version base suffix_part number
  local best_version=""
  local best_tag=""
  local best_base="0.0.0"
  local best_number=0
  local compare_result

  prefix="$(zr_tag_prefix "$format")"
  suffix="$(zr_tag_suffix "$format")"
  pattern="${prefix}*-${identifier}.*${suffix}"

  while IFS= read -r tag; do
    version="$(zr_extract_version_from_tag "$format" "$tag" 2>/dev/null || true)"
    case "$version" in
      *-"$identifier".*)
        base="${version%%-*}"
        suffix_part="${version#*-}"
        number="${suffix_part##*.}"
        if ! zr_validate_stable_semver "$base"; then
          continue
        fi
        if ! [[ "$number" =~ ^[0-9]+$ ]]; then
          continue
        fi
        compare_result="$(zr_compare_stable_versions "$base" "$best_base")"
        if [ "$compare_result" = "1" ] || { [ "$compare_result" = "0" ] && [ "$number" -gt "$best_number" ]; }; then
          best_version="$version"
          best_tag="$tag"
          best_base="$base"
          best_number="$number"
        fi
        ;;
    esac
  done < <(git tag --list "$pattern" 2>/dev/null || true)

  printf '%s\t%s\n' "$best_version" "$best_tag"
}
