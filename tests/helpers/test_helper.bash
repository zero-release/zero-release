PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
ZERO_RELEASE_BIN="$PROJECT_ROOT/bin/zero-release"

clear_github_actions_env() {
  unset GITHUB_EVENT_NAME
  unset GITHUB_HEAD_REPO_FORK
  unset GITHUB_HEAD_REF
  unset GITHUB_REF_NAME
  unset GITHUB_OUTPUT
}

make_repo() {
  clear_github_actions_env
  TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/zero-release-test.XXXXXX")"
  cd "$TEST_REPO"
  git init -b main >/dev/null 2>&1 || {
    git init >/dev/null
    git checkout -b main >/dev/null
  }
  git config user.email "test@example.com"
  git config user.name "Test User"
  git remote add origin "git@github.com:user/repo.git"
}

make_bare_origin() {
  BARE_ORIGIN="$(mktemp -d "${TMPDIR:-/tmp}/zero-release-origin.XXXXXX")/origin.git"
  git init --bare "$BARE_ORIGIN" >/dev/null
  git remote set-url origin "$BARE_ORIGIN"
}

commit_file() {
  local message="$1"
  local file="${2:-file.txt}"
  printf '%s\n' "$message $(date +%s%N)" >> "$file"
  git add "$file"
  git commit -m "$message" >/dev/null
}

commit_file_with_body() {
  local subject="$1"
  local body="$2"
  local file="${3:-file.txt}"
  printf '%s\n' "$subject $(date +%s%N)" >> "$file"
  git add "$file"
  git commit -m "$subject" -m "$body" >/dev/null
}

assert_success() {
  [ "$status" -eq 0 ] || {
    printf 'expected success, got status %s\n%s\n' "$status" "$output" >&2
    return 1
  }
}

assert_failure() {
  [ "$status" -ne 0 ] || {
    printf 'expected failure, got success\n%s\n' "$output" >&2
    return 1
  }
}

assert_output_contains() {
  local expected="$1"
  case "$output" in
    *"$expected"*) return 0 ;;
    *)
      printf 'expected output to contain: %s\nactual output:\n%s\n' "$expected" "$output" >&2
      return 1
      ;;
  esac
}

assert_json_valid() {
  printf '%s' "$output" | python3 -m json.tool >/dev/null
}

assert_no_jq_in_core() {
  ! grep -R "jq" "$PROJECT_ROOT/bin" "$PROJECT_ROOT/lib" "$PROJECT_ROOT/plugins" >/dev/null
}
