#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
  . "$PROJECT_ROOT/lib/url.sh"
}

@test "converts GitHub SSH remote to HTTPS" {
  run zr_remote_to_https "git@github.com:user/repo.git"
  assert_success
  [ "$output" = "https://github.com/user/repo" ]
}

@test "removes .git from HTTPS remotes" {
  run zr_remote_to_https "https://github.com/user/repo.git"
  assert_success
  [ "$output" = "https://github.com/user/repo" ]
}

@test "generates GitHub compare URL" {
  run zr_compare_url "https://github.com/user/repo" "v1.0.0" "v1.1.0"
  assert_success
  [ "$output" = "https://github.com/user/repo/compare/v1.0.0...v1.1.0" ]
}

@test "generates GitLab compare URL" {
  run zr_compare_url "https://gitlab.com/user/repo" "v1.0.0" "v1.1.0"
  assert_success
  [ "$output" = "https://gitlab.com/user/repo/-/compare/v1.0.0...v1.1.0" ]
}

@test "generates Bitbucket compare URL" {
  run zr_compare_url "https://bitbucket.org/user/repo" "v1.0.0" "v1.1.0"
  assert_success
  [ "$output" = "https://bitbucket.org/user/repo/branches/compare/v1.1.0%0Dv1.0.0" ]
}

@test "generates Azure DevOps compare URL" {
  run zr_compare_url "https://dev.azure.com/org/project/_git/repo" "v1.0.0" "v1.1.0"
  assert_success
  [ "$output" = "https://dev.azure.com/org/project/_git/repo/branchCompare?baseVersion=GTv1.0.0&targetVersion=GTv1.1.0" ]
}

@test "generates commit URL when possible" {
  run zr_commit_url "https://github.com/user/repo" "abc123"
  assert_success
  [ "$output" = "https://github.com/user/repo/commit/abc123" ]
}
