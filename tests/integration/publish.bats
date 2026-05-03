#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup_release_remote() {
  make_repo
  make_bare_origin
  commit_file "chore: initial"
  git push origin main >/dev/null
  git tag v1.0.0
  git push origin v1.0.0 >/dev/null
}

@test "tag is pushed when release happens and push is enabled" {
  setup_release_remote
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins release-notes --branches main
  assert_success
  git --git-dir="$BARE_ORIGIN" rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
}

@test "branch is not pushed when git-commit is not enabled" {
  setup_release_remote
  remote_before="$(git --git-dir="$BARE_ORIGIN" rev-parse refs/heads/main)"
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins release-notes --branches main
  assert_success
  remote_after="$(git --git-dir="$BARE_ORIGIN" rev-parse refs/heads/main)"
  [ "$remote_before" = "$remote_after" ]
}

@test "branch is pushed when git-commit creates a release commit" {
  setup_release_remote
  printf '{ "version": "1.0.0" }\n' > package.json
  git add package.json
  git commit -m "chore: add package" >/dev/null
  git push origin main >/dev/null
  git tag -f v1.0.0 >/dev/null
  git push -f origin v1.0.0 >/dev/null
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins package-json,git-commit --branches main
  assert_success
  remote_branch="$(git --git-dir="$BARE_ORIGIN" rev-parse refs/heads/main)"
  local_branch="$(git rev-parse HEAD)"
  [ "$remote_branch" = "$local_branch" ]
}

@test "nothing is pushed in dry-run" {
  setup_release_remote
  remote_before="$(git --git-dir="$BARE_ORIGIN" rev-parse refs/heads/main)"
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --dry-run --plugins release-notes --branches main
  assert_success
  ! git --git-dir="$BARE_ORIGIN" rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
  remote_after="$(git --git-dir="$BARE_ORIGIN" rev-parse refs/heads/main)"
  [ "$remote_before" = "$remote_after" ]
}

@test "nothing is pushed with --no-push" {
  setup_release_remote
  remote_before="$(git --git-dir="$BARE_ORIGIN" rev-parse refs/heads/main)"
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins release-notes --no-push --branches main
  assert_success
  git rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
  ! git --git-dir="$BARE_ORIGIN" rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
  remote_after="$(git --git-dir="$BARE_ORIGIN" rev-parse refs/heads/main)"
  [ "$remote_before" = "$remote_after" ]
}

@test "no tag is created or pushed with --no-tag" {
  setup_release_remote
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins release-notes --no-tag --branches main
  assert_success
  ! git rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
  ! git --git-dir="$BARE_ORIGIN" rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
}

@test "npm publish plugin runs during the publish phase" {
  setup_release_remote
  commit_file "fix: bug"
  fake_bin="$BATS_TEST_TMPDIR/fake-npm-publish"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nif [ "${1-}" = "--version" ]; then printf "11.5.1\\n"; exit 0; fi\nprintf "%%s\\n" "$*" > "%s/npm-publish-called"\n' "$BATS_TEST_TMPDIR" > "$fake_bin/npm"
  printf '#!/usr/bin/env bash\nprintf "v24.0.0\\n"\n' > "$fake_bin/node"
  chmod +x "$fake_bin/npm"
  chmod +x "$fake_bin/node"

  PATH="$fake_bin:$PATH" run "$ZERO_RELEASE_BIN" --plugins release-notes,npm --branches main
  assert_success
  git --git-dir="$BARE_ORIGIN" rev-parse -q --verify refs/tags/v1.0.1 >/dev/null
  grep '^publish --tag latest$' "$BATS_TEST_TMPDIR/npm-publish-called" >/dev/null
}
