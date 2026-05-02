#!/usr/bin/env bats

load "../helpers/test_helper.bash"

@test "--json returns valid JSON for a release" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file "feat: add JSON output"

  run "$ZERO_RELEASE_BIN" --dry-run --json --branches main
  assert_success
  assert_json_valid
  assert_output_contains "\"released\": true"
  assert_output_contains "\"nextVersion\": \"1.3.0\""
}

@test "--json returns valid JSON for no release" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file "docs: update docs"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_json_valid
  assert_output_contains "\"released\": false"
}

@test "messages with quotes and newlines do not break JSON output" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.3
  commit_file_with_body "fix: handle \"quoted\" value" $'Body line one\nBody with \\ slash and "quote"'

  run "$ZERO_RELEASE_BIN" --dry-run --json --branches main
  assert_success
  assert_json_valid
  assert_output_contains "\"nextVersion\": \"1.2.4\""
}
