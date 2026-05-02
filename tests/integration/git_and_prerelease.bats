#!/usr/bin/env bats

load "../helpers/test_helper.bash"

@test "detects latest tag and calculates next version" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"
  git tag v1.0.1
  commit_file "feat: next"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"previousTag\": \"v1.0.1\""
  assert_output_contains "\"nextVersion\": \"1.1.0\""
}

@test "works without a previous tag" {
  make_repo
  commit_file "feat: first feature"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"previousVersion\": \"0.0.0\""
  assert_output_contains "\"nextVersion\": \"0.1.0\""
}

@test "does not create a tag in dry-run" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --dry-run --json --branches main
  assert_success
  ! git rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
}

@test "does not push in dry-run" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --dry-run --json --branches main
  assert_success
  assert_output_contains "\"dryRun\": true"
}

@test "validates allowed branch" {
  make_repo
  commit_file "feat: first"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"currentBranch\": \"main\""
}

@test "main branch creates a stable release with default prerelease config" {
  make_repo
  commit_file "chore: initial"
  git tag v1.2.0
  commit_file "feat: stable feature"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_success
  assert_output_contains "\"nextVersion\": \"1.3.0\""
  assert_output_contains "\"channel\": \"stable\""
}

@test "blocks disallowed branches" {
  make_repo
  git checkout -b feature/test >/dev/null
  commit_file "feat: first"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main
  assert_failure
  assert_output_contains "is not allowed"
}

@test "alpha beta and rc do not create prereleases by default" {
  for branch in alpha beta rc; do
    make_repo
    git checkout -b "$branch" >/dev/null
    commit_file "chore: initial"
    git tag v1.2.0
    commit_file "feat: prerelease candidate"

    run "$ZERO_RELEASE_BIN" analyze --json --branches main
    assert_failure
    assert_output_contains "is not allowed"
  done
}

@test "creates alpha prerelease based on branch channel" {
  make_repo
  git checkout -b alpha >/dev/null
  commit_file "chore: initial"
  git tag v1.2.0
  commit_file "feat: upcoming"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main --prerelease-branches alpha
  assert_success
  assert_output_contains "\"nextVersion\": \"1.3.0-alpha.1\""
  assert_output_contains "\"channel\": \"alpha\""
}

@test "increments beta prerelease number from existing tags" {
  make_repo
  git checkout -b beta >/dev/null
  commit_file "chore: initial"
  git tag v1.2.0
  commit_file "feat: beta one"
  git tag v1.3.0-beta.1
  commit_file "fix: beta two"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main --prerelease-branches alpha,beta,rc
  assert_success
  assert_output_contains "\"previousTag\": \"v1.3.0-beta.1\""
  assert_output_contains "\"nextVersion\": \"1.3.0-beta.2\""
}

@test "creates rc prerelease using mapped branch" {
  make_repo
  git checkout -b next >/dev/null
  commit_file "chore: initial"
  git tag v2.0.0
  commit_file "fix: release candidate"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main --prerelease-branches next:rc
  assert_success
  assert_output_contains "\"nextVersion\": \"2.0.1-rc.1\""
  assert_output_contains "\"channel\": \"rc\""
}

@test "creates beta prerelease using mapped next branch" {
  make_repo
  git checkout -b next >/dev/null
  commit_file "chore: initial"
  git tag v1.2.0
  commit_file "feat: beta channel"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main --prerelease-branches next:beta
  assert_success
  assert_output_contains "\"nextVersion\": \"1.3.0-beta.1\""
  assert_output_contains "\"channel\": \"beta\""
}

@test "dry-run shows explicit prerelease without creating tags or modifying files" {
  make_repo
  git checkout -b alpha >/dev/null
  commit_file "chore: initial"
  git tag v1.2.0
  commit_file "feat: upcoming"

  run "$ZERO_RELEASE_BIN" --dry-run --branches main --prerelease-branches alpha
  assert_success
  assert_output_contains "Next version: 1.3.0-alpha.1"
  assert_output_contains "Next tag: v1.3.0-alpha.1"
  ! git rev-parse -q --verify refs/tags/v1.3.0-alpha.1 >/dev/null
  [ -z "$(git status --short)" ]
}

@test "manual --prerelease is not accepted" {
  make_repo
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" analyze --json --branches main --prerelease
  assert_failure
  assert_output_contains "Unknown option: --prerelease"
}

@test "help does not mention manual --prerelease" {
  run "$ZERO_RELEASE_BIN" --help
  assert_success
  [[ "$output" != *"--prerelease"$'\n'* ]]
  [[ "$output" == *"--prerelease-branches alpha,beta,rc"* ]]
  [[ "$output" == *"--prerelease-branch next:beta"* ]]
}
