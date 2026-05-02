#!/usr/bin/env bash

zr_commit_is_breaking() {
  local subject="$1"
  local body="$2"
  local breaking_header_re='^[A-Za-z0-9][A-Za-z0-9-]*(\([^)]+\))?!:'

  if [[ "$subject" =~ $breaking_header_re ]]; then
    return 0
  fi

  case "$subject"$'\n'"$body" in
    *"BREAKING CHANGE"*|*"BREAKING-CHANGE"*) return 0 ;;
    *) return 1 ;;
  esac
}

zr_commit_type() {
  local subject="$1"
  local type_re='^([A-Za-z0-9][A-Za-z0-9-]*)(\([^)]+\))?!?:'

  if [[ "$subject" =~ $type_re ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '\n'
  fi
}

zr_commit_scope() {
  local subject="$1"
  local scope_re='^[A-Za-z0-9][A-Za-z0-9-]*\(([^)]+)\)'

  if [[ "$subject" =~ $scope_re ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '\n'
  fi
}

zr_commit_description() {
  local subject="$1"
  local description="$subject"

  case "$subject" in
    *': '*) description="${subject#*: }" ;;
    *':') description="" ;;
    *:*) description="${subject#*:}" ;;
  esac

  printf '%s\n' "$description"
}

zr_breaking_description() {
  local subject="$1"
  local body="$2"
  local line rest
  local breaking_header_re='^[A-Za-z0-9][A-Za-z0-9-]*(\([^)]+\))?!:'

  if [[ "$subject" =~ $breaking_header_re ]]; then
    zr_commit_description "$subject"
    return 0
  fi

  while IFS= read -r line; do
    case "$line" in
      *"BREAKING CHANGE:"*)
        rest="${line#*BREAKING CHANGE:}"
        printf '%s\n' "${rest# }"
        return 0
        ;;
      *"BREAKING-CHANGE:"*)
        rest="${line#*BREAKING-CHANGE:}"
        printf '%s\n' "${rest# }"
        return 0
        ;;
      *"BREAKING CHANGE"*)
        printf '%s\n' "$line"
        return 0
        ;;
      *"BREAKING-CHANGE"*)
        printf '%s\n' "$line"
        return 0
        ;;
    esac
  done <<EOF
$subject
$body
EOF

  zr_commit_description "$subject"
}

zr_analyze_commits() {
  local previous_tag="${1-}"
  local range=()
  local hash subject body type

  ZR_COMMIT_TOTAL=0
  ZR_COMMIT_FEATURES=0
  ZR_COMMIT_FIXES=0
  ZR_COMMIT_PERFORMANCE=0
  ZR_COMMIT_BREAKING=0
  ZR_COMMIT_OTHER=0
  ZR_ANALYSIS_BUMP=""

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$previous_tag" ]; then
    range=("${previous_tag}..HEAD")
  else
    range=("HEAD")
  fi

  while IFS=$'\037' read -r -d $'\036' hash subject body; do
    [ -n "$hash" ] || continue
    ZR_COMMIT_TOTAL=$((ZR_COMMIT_TOTAL + 1))

    if zr_commit_is_breaking "$subject" "$body"; then
      ZR_COMMIT_BREAKING=$((ZR_COMMIT_BREAKING + 1))
      ZR_ANALYSIS_BUMP="major"
      continue
    fi

    type="$(zr_commit_type "$subject")"
    case "$type" in
      feat)
        ZR_COMMIT_FEATURES=$((ZR_COMMIT_FEATURES + 1))
        if [ "$ZR_ANALYSIS_BUMP" != "major" ]; then
          ZR_ANALYSIS_BUMP="minor"
        fi
        ;;
      fix)
        ZR_COMMIT_FIXES=$((ZR_COMMIT_FIXES + 1))
        if [ -z "$ZR_ANALYSIS_BUMP" ]; then
          ZR_ANALYSIS_BUMP="patch"
        fi
        ;;
      perf)
        ZR_COMMIT_PERFORMANCE=$((ZR_COMMIT_PERFORMANCE + 1))
        if [ -z "$ZR_ANALYSIS_BUMP" ]; then
          ZR_ANALYSIS_BUMP="patch"
        fi
        ;;
      *)
        ZR_COMMIT_OTHER=$((ZR_COMMIT_OTHER + 1))
        ;;
    esac
  done < <(git log --format='%H%x1f%s%x1f%b%x1e' "${range[@]}" 2>/dev/null || true)
}

zr_generate_release_notes_file() {
  local output_file="$1"
  local version="$2"
  local previous_tag="$3"
  local next_tag="$4"
  local repository_url="${5-}"
  local compare_url="${6-}"
  local range=()
  local hash subject body short_hash type description scope commit_url link
  local breaking="" features="" fixes="" performance="" other=""

  if [ -n "$previous_tag" ]; then
    range=("${previous_tag}..HEAD")
  else
    range=("HEAD")
  fi

  while IFS=$'\037' read -r -d $'\036' hash subject body; do
    [ -n "$hash" ] || continue
    short_hash="${hash:0:7}"
    if [ -n "$repository_url" ]; then
      commit_url="$(zr_commit_url "$repository_url" "$hash" 2>/dev/null || true)"
    else
      commit_url=""
    fi
    if [ -n "$commit_url" ]; then
      link="([${short_hash}](${commit_url}))"
    else
      link="(${short_hash})"
    fi

    if zr_commit_is_breaking "$subject" "$body"; then
      description="$(zr_breaking_description "$subject" "$body")"
      breaking="${breaking}- **BREAKING CHANGE**: ${description} ${link}"$'\n'
      continue
    fi

    type="$(zr_commit_type "$subject")"
    description="$(zr_commit_description "$subject")"
    scope="$(zr_commit_scope "$subject")"
    if [ -n "$scope" ]; then
      description="**${scope}**: ${description}"
    fi

    case "$type" in
      feat) features="${features}- ${description} ${link}"$'\n' ;;
      fix) fixes="${fixes}- ${description} ${link}"$'\n' ;;
      perf) performance="${performance}- ${description} ${link}"$'\n' ;;
      *) other="${other}- ${subject} ${link}"$'\n' ;;
    esac
  done < <(git log --format='%H%x1f%s%x1f%b%x1e' "${range[@]}" 2>/dev/null || true)

  : > "$output_file"
  printf '## %s\n\n' "$next_tag" >> "$output_file"
  printf 'Released on %s.\n\n' "$(date +%Y-%m-%d)" >> "$output_file"

  if [ -n "$breaking" ]; then
    printf '### Breaking Changes\n\n%s\n' "$breaking" >> "$output_file"
  fi
  if [ -n "$features" ]; then
    printf '### Features\n\n%s\n' "$features" >> "$output_file"
  fi
  if [ -n "$fixes" ]; then
    printf '### Bug Fixes\n\n%s\n' "$fixes" >> "$output_file"
  fi
  if [ -n "$performance" ]; then
    printf '### Performance\n\n%s\n' "$performance" >> "$output_file"
  fi
  if [ -n "$other" ]; then
    printf '### Other Changes\n\n%s\n' "$other" >> "$output_file"
  fi
  if [ -n "$compare_url" ]; then
    printf '[Compare changes](%s)\n' "$compare_url" >> "$output_file"
  fi

  [ -n "$version" ]
}
