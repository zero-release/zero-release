#!/usr/bin/env bats

load "helpers/test_helper.bash"

@test "unit and integration test suites pass" {
  run bats "$BATS_TEST_DIRNAME"/unit/*.bats "$BATS_TEST_DIRNAME"/integration/*.bats
  assert_success
}
