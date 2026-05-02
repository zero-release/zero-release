#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
  . "$PROJECT_ROOT/lib/semver.sh"
}

@test "version increment: patch" {
  run zr_bump_version "1.2.3" "patch"
  assert_success
  [ "$output" = "1.2.4" ]
}

@test "version increment: minor" {
  run zr_bump_version "1.2.3" "minor"
  assert_success
  [ "$output" = "1.3.0" ]
}

@test "version increment: major" {
  run zr_bump_version "1.2.3" "major"
  assert_success
  [ "$output" = "2.0.0" ]
}

@test "version increment: prerelease alpha beta rc numbers" {
  make_repo
  commit_file "chore: initial"
  git tag v1.3.0-alpha.1
  git tag v1.3.0-alpha.2
  git tag v1.3.0-beta.1
  git tag v1.3.0-rc.3

  run zr_next_prerelease_number "v%s" "1.3.0" "alpha"
  assert_success
  [ "$output" = "3" ]

  run zr_next_prerelease_number "v%s" "1.3.0" "beta"
  assert_success
  [ "$output" = "2" ]

  run zr_next_prerelease_number "v%s" "1.3.0" "rc"
  assert_success
  [ "$output" = "4" ]
}

@test "validates supported SemVer forms" {
  zr_validate_semver "1.2.3"
  zr_validate_semver "1.2.3-alpha.1"
  zr_validate_semver "1.2.3-beta.1"
  zr_validate_semver "1.2.3-rc.1"
}
