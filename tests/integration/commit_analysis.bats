#!/usr/bin/env bats

load "../helpers/test_helper.bash"

assert_commit_bump() {
  local subject="$1"
  local expected_bump="$2"
  local expected_version="$3"

  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file "$subject"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_json_valid
  assert_output_contains "\"bump\": \"$expected_bump\""
  assert_output_contains "\"nextVersion\": \"$expected_version\""
}

@test "fix: creates patch" {
  assert_commit_bump "fix: repair bug" "patch" "1.2.4"
}

@test "fix(scope): creates patch" {
  assert_commit_bump "fix(api): repair bug" "patch" "1.2.4"
}

@test "perf: creates patch" {
  assert_commit_bump "perf: speed up path" "patch" "1.2.4"
}

@test "feat: creates minor" {
  assert_commit_bump "feat: add feature" "minor" "1.3.0"
}

@test "feat(scope): creates minor" {
  assert_commit_bump "feat(ui): add feature" "minor" "1.3.0"
}

@test "feat!: creates major" {
  assert_commit_bump "feat!: remove old API" "major" "2.0.0"
}

@test "feat(scope)!: creates major" {
  assert_commit_bump "feat(api)!: remove old API" "major" "2.0.0"
}

@test "fix!: creates major" {
  assert_commit_bump "fix!: change default behavior" "major" "2.0.0"
}

@test "refactor(core)!: creates major" {
  assert_commit_bump "refactor(core)!: remove deprecated method" "major" "2.0.0"
}

@test "BREAKING CHANGE creates major" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file_with_body "refactor: change API" "BREAKING CHANGE: API changed"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"bump\": \"major\""
  assert_output_contains "\"nextVersion\": \"2.0.0\""
}

@test "BREAKING-CHANGE creates major" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file_with_body "refactor: change API" "BREAKING-CHANGE: API changed"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"bump\": \"major\""
  assert_output_contains "\"nextVersion\": \"2.0.0\""
}

@test "major: does not create major by default" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file "major: old opt-in style"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"released\": false"
}

@test "chore docs and test do not create a release" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file "chore: clean"
  commit_file "docs: update readme"
  commit_file "test: add coverage"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"released\": false"
}
