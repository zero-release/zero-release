#!/usr/bin/env bats

load "../helpers/test_helper.bash"

@test "writes GitHub Actions outputs to GITHUB_OUTPUT" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"
  output_file="$BATS_TEST_TMPDIR/github-output"

  GITHUB_OUTPUT="$output_file" run "$ZERO_RELEASE_BIN" --dry-run --json --branches main
  assert_success
  grep '^released=true$' "$output_file" >/dev/null
  grep '^version=1.0.1$' "$output_file" >/dev/null
  grep '^tag=v1.0.1$' "$output_file" >/dev/null
  grep '^bump=patch$' "$output_file" >/dev/null
  grep '^previous-version=1.0.0$' "$output_file" >/dev/null
  grep '^previous-tag=v1.0.0$' "$output_file" >/dev/null
  grep '^channel=stable$' "$output_file" >/dev/null
}

@test "GitHub Action prerelease-branches input defaults to empty" {
  grep -A 4 '^  prerelease-branches:' "$PROJECT_ROOT/action.yml" | grep 'default: ""' >/dev/null
}

@test "defaults to dry-run for pull_request events" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  GITHUB_EVENT_NAME="pull_request" run "$ZERO_RELEASE_BIN" --json --branches main
  assert_success
  assert_output_contains "\"dryRun\": true"
  ! git rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
}

@test "does not publish from fork pull requests" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  GITHUB_EVENT_NAME="pull_request" GITHUB_HEAD_REPO_FORK="true" run "$ZERO_RELEASE_BIN" --plugins release-notes,webhook --json --branches main
  assert_success
  assert_output_contains "\"dryRun\": true"
  ! git rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
}

@test "doctor reports environment checks" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0

  run "$ZERO_RELEASE_BIN" doctor --branches main
  assert_success
  assert_output_contains "zero-release doctor"
  assert_output_contains "git repository"
  assert_output_contains "branch allowed"
}

@test "doctor --json returns valid JSON" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0

  run "$ZERO_RELEASE_BIN" doctor --json --branches main
  assert_success
  assert_json_valid
  assert_output_contains "\"gitRepository\""
}

@test "doctor reports missing optional curl for network plugins" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  fake_bin="$BATS_TEST_TMPDIR/minimal-bin"
  mkdir -p "$fake_bin"
  for tool in bash git awk sed grep cut tr sort date mktemp dirname pwd; do
    tool_path="$(command -v "$tool")"
    if [ -n "$tool_path" ] && [ -f "$tool_path" ]; then
      ln -s "$tool_path" "$fake_bin/$tool"
    fi
  done

  PATH="$fake_bin" run "$ZERO_RELEASE_BIN" doctor --json --plugins slack --branches main
  assert_success
  assert_json_valid
  assert_output_contains "\"networkPluginRequirements\": { \"ok\": false"
}

@test "doctor reports missing npm for npm plugin" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  fake_bin="$BATS_TEST_TMPDIR/minimal-bin-no-npm"
  mkdir -p "$fake_bin"
  for tool in bash git awk sed grep cut tr sort date mktemp dirname pwd; do
    tool_path="$(command -v "$tool")"
    if [ -n "$tool_path" ] && [ -f "$tool_path" ]; then
      ln -s "$tool_path" "$fake_bin/$tool"
    fi
  done

  PATH="$fake_bin" run "$ZERO_RELEASE_BIN" doctor --json --plugins npm --branches main
  assert_success
  assert_json_valid
  assert_output_contains "\"networkPluginRequirements\": { \"ok\": false"
  assert_output_contains "npm CLI is required"
}

@test "doctor does not perform release actions" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" doctor --branches main
  assert_success
  ! git rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
}
