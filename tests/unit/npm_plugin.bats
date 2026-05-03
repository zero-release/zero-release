#!/usr/bin/env bats

load "../helpers/test_helper.bash"

make_fake_npm() {
  local fake_bin="$1"
  local log_file="$2"

  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nif [ "${1-}" = "--version" ]; then printf "11.5.1\\n"; exit 0; fi\nprintf "%%s\\n" "$*" > "%s"\n' "$log_file" > "$fake_bin/npm"
  printf '#!/usr/bin/env bash\nprintf "v24.0.0\\n"\n' > "$fake_bin/node"
  chmod +x "$fake_bin/npm"
  chmod +x "$fake_bin/node"
}

@test "npm plugin publishes stable releases with latest dist-tag" {
  fake_bin="$BATS_TEST_TMPDIR/fake-npm-stable"
  log_file="$BATS_TEST_TMPDIR/npm-stable.log"
  make_fake_npm "$fake_bin" "$log_file"

  PATH="$fake_bin:$PATH" \
    ZERO_RELEASE_RELEASED="true" \
    ZERO_RELEASE_DRY_RUN="false" \
    ZERO_RELEASE_CHANNEL="stable" \
    run "$PROJECT_ROOT/plugins/npm/plugin" publish

  assert_success
  assert_output_contains "npm: publishing with dist-tag latest"
  grep '^publish --tag latest$' "$log_file" >/dev/null
}

@test "npm plugin publishes prereleases with the release channel as dist-tag" {
  fake_bin="$BATS_TEST_TMPDIR/fake-npm-prerelease"
  log_file="$BATS_TEST_TMPDIR/npm-prerelease.log"
  make_fake_npm "$fake_bin" "$log_file"

  PATH="$fake_bin:$PATH" \
    ZERO_RELEASE_RELEASED="true" \
    ZERO_RELEASE_DRY_RUN="false" \
    ZERO_RELEASE_CHANNEL="beta" \
    ZERO_RELEASE_NPM_ACCESS="public" \
    ZERO_RELEASE_NPM_REGISTRY="https://registry.npmjs.org" \
    ZERO_RELEASE_NPM_PACKAGE="./pkg" \
    run "$PROJECT_ROOT/plugins/npm/plugin" publish

  assert_success
  assert_output_contains "npm: publishing with dist-tag beta"
  grep '^publish --tag beta --access public --registry https://registry.npmjs.org ./pkg$' "$log_file" >/dev/null
}

@test "npm plugin does not call npm during dry-run" {
  fake_bin="$BATS_TEST_TMPDIR/fake-npm-dry-run"
  log_file="$BATS_TEST_TMPDIR/npm-dry-run.log"
  make_fake_npm "$fake_bin" "$log_file"

  PATH="$fake_bin:$PATH" \
    ZERO_RELEASE_RELEASED="true" \
    ZERO_RELEASE_DRY_RUN="true" \
    ZERO_RELEASE_CHANNEL="stable" \
    run "$PROJECT_ROOT/plugins/npm/plugin" publish

  assert_success
  [ ! -f "$log_file" ]
}

@test "npm plugin verify requires npm for real releases" {
  fake_bin="$BATS_TEST_TMPDIR/no-npm-bin"
  mkdir -p "$fake_bin"
  ln -s "$(command -v bash)" "$fake_bin/bash"

  PATH="$fake_bin" \
    ZERO_RELEASE_RELEASED="true" \
    ZERO_RELEASE_DRY_RUN="false" \
    run "$PROJECT_ROOT/plugins/npm/plugin" verify

  assert_failure
  assert_output_contains "npm CLI is required"
}

@test "npm plugin verify requires trusted publishing capable npm" {
  fake_bin="$BATS_TEST_TMPDIR/old-npm-bin"
  log_file="$BATS_TEST_TMPDIR/old-npm.log"
  make_fake_npm "$fake_bin" "$log_file"
  printf '#!/usr/bin/env bash\nprintf "11.4.0\\n"\n' > "$fake_bin/npm"
  chmod +x "$fake_bin/npm"

  PATH="$fake_bin:$PATH" \
    ZERO_RELEASE_RELEASED="true" \
    ZERO_RELEASE_DRY_RUN="false" \
    run "$PROJECT_ROOT/plugins/npm/plugin" verify

  assert_failure
  assert_output_contains "npm CLI 11.5.1 or later is required"
}

@test "npm plugin verify requires trusted publishing capable Node.js" {
  fake_bin="$BATS_TEST_TMPDIR/old-node-bin"
  log_file="$BATS_TEST_TMPDIR/old-node.log"
  make_fake_npm "$fake_bin" "$log_file"
  printf '#!/usr/bin/env bash\nprintf "v22.13.0\\n"\n' > "$fake_bin/node"
  chmod +x "$fake_bin/node"

  PATH="$fake_bin:$PATH" \
    ZERO_RELEASE_RELEASED="true" \
    ZERO_RELEASE_DRY_RUN="false" \
    run "$PROJECT_ROOT/plugins/npm/plugin" verify

  assert_failure
  assert_output_contains "Node.js 22.14.0 or later is required"
}

@test "npm plugin rejects invalid access values" {
  fake_bin="$BATS_TEST_TMPDIR/fake-npm-invalid-access"
  log_file="$BATS_TEST_TMPDIR/npm-invalid-access.log"
  make_fake_npm "$fake_bin" "$log_file"

  PATH="$fake_bin:$PATH" \
    ZERO_RELEASE_RELEASED="true" \
    ZERO_RELEASE_DRY_RUN="false" \
    ZERO_RELEASE_NPM_ACCESS="private" \
    run "$PROJECT_ROOT/plugins/npm/plugin" verify

  assert_failure
  assert_output_contains "ZERO_RELEASE_NPM_ACCESS must be public or restricted"
}
