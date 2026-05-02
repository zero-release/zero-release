#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
  . "$PROJECT_ROOT/lib/json.sh"
}

@test "escapes JSON strings with quotes, backslashes, and newlines" {
  value=$'quote " slash \\ newline\nnext'
  run zr_json_string "$value"
  assert_success
  printf '%s' "$output" | python3 -m json.tool >/dev/null
  [[ "$output" == *'\"'* ]]
  [[ "$output" == *'\\'* ]]
  [[ "$output" == *'\n'* ]]
}

@test "core JSON generation does not require jq" {
  assert_no_jq_in_core
}
