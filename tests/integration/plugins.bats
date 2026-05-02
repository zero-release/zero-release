#!/usr/bin/env bats

load "../helpers/test_helper.bash"

@test "package-json updates only version and does not commit" {
  make_repo
  printf '{\n  "name": "demo",\n  "version": "1.0.0",\n  "description": "version should stay in this string"\n}\n' > package.json
  git add package.json
  git commit -m "chore: initial" >/dev/null
  git tag v1.0.0
  commit_file "fix: bug"
  before_count="$(git rev-list --count HEAD)"

  run "$ZERO_RELEASE_BIN" --plugins package-json --no-tag --no-push --branches main
  assert_success
  after_count="$(git rev-list --count HEAD)"
  [ "$before_count" = "$after_count" ]
  grep '"version": "1.0.1"' package.json >/dev/null
  grep '"description": "version should stay in this string"' package.json >/dev/null
}

@test "package-json does not update nested version fields" {
  make_repo
  cat > package.json <<'JSON'
{
  "nested": {
    "version": "0.0.1"
  },
  "name": "demo",
  "version": "1.0.0"
}
JSON
  git add package.json
  git commit -m "chore: initial" >/dev/null
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins package-json --no-tag --no-push --branches main
  assert_success
  grep '"version": "0.0.1"' package.json >/dev/null
  grep '"version": "1.0.1"' package.json >/dev/null
}

@test "package-json fails if only nested version exists" {
  make_repo
  printf '{ "nested": { "version": "0.0.1" } }\n' > package.json
  git add package.json
  git commit -m "chore: initial" >/dev/null
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins package-json --no-tag --no-push --branches main
  assert_failure
  assert_output_contains 'no top-level "version" field found'
  grep '"version": "0.0.1"' package.json >/dev/null
}

@test "package-json fails if multiple top-level version fields exist" {
  make_repo
  printf '{ "version": "1.0.0", "name": "demo", "version": "1.0.0" }\n' > package.json
  git add package.json
  git commit -m "chore: initial" >/dev/null
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins package-json --no-tag --no-push --branches main
  assert_failure
  assert_output_contains 'multiple top-level "version" fields found'
}

@test "package-json does not change files in dry-run" {
  make_repo
  printf '{ "version": "1.0.0", "name": "demo" }\n' > package.json
  git add package.json
  git commit -m "chore: initial" >/dev/null
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --dry-run --plugins package-json --branches main
  assert_success
  grep '"version": "1.0.0"' package.json >/dev/null
  [ -z "$(git status --short)" ]
}

@test "git-commit commits only when explicitly enabled" {
  make_repo
  printf '{ "version": "1.0.0" }\n' > package.json
  git add package.json
  git commit -m "chore: initial" >/dev/null
  git tag v1.0.0
  commit_file "fix: bug"
  before_count="$(git rev-list --count HEAD)"

  run "$ZERO_RELEASE_BIN" --plugins package-json --no-tag --no-push --branches main
  assert_success
  without_count="$(git rev-list --count HEAD)"
  [ "$before_count" = "$without_count" ]

  git checkout -- package.json
  run "$ZERO_RELEASE_BIN" --plugins package-json,git-commit --no-tag --no-push --branches main
  assert_success
  with_count="$(git rev-list --count HEAD)"
  [ "$with_count" -eq "$((before_count + 1))" ]
}

@test "git-commit runs after changelog and package-json regardless of user plugin order" {
  make_repo
  printf '{ "version": "1.0.0" }\n' > package.json
  git add package.json
  git commit -m "chore: initial" >/dev/null
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins git-commit,package-json,changelog,release-notes --no-tag --no-push --branches main
  assert_success
  [ -z "$(git status --short)" ]
  git show --name-only --format="" HEAD | grep '^CHANGELOG.md$' >/dev/null
  git show --name-only --format="" HEAD | grep '^package.json$' >/dev/null
}

@test "changelog respects --changelog-file" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "feat: new thing"

  run "$ZERO_RELEASE_BIN" --plugins release-notes,changelog --changelog-file NEWS.md --no-tag --no-push --branches main
  assert_success
  [ -f NEWS.md ]
  grep "v1.1.0" NEWS.md >/dev/null
  [ ! -f CHANGELOG.md ]
}

@test "release-notes generates notes without changing files in dry-run" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --dry-run --plugins release-notes --branches main
  assert_success
  assert_output_contains "Release notes preview"
  [ -z "$(git status --short)" ]
}

@test "slack is skipped in dry-run and does not call curl" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nprintf called > "%s/curl-called"\nexit 9\n' "$BATS_TEST_TMPDIR" > "$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  PATH="$fake_bin:$PATH" run "$ZERO_RELEASE_BIN" --dry-run --plugins release-notes,slack --branches main
  assert_success
  [ ! -f "$BATS_TEST_TMPDIR/curl-called" ]
}

@test "slack does not require webhook when there is no release" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "docs: no release"

  run "$ZERO_RELEASE_BIN" --plugins release-notes,slack --branches main
  assert_success
  assert_output_contains "No release-worthy commits found"
}

@test "slack fails clearly for real release without webhook" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins release-notes,slack --no-push --branches main
  assert_failure
  assert_output_contains "SLACK_WEBHOOK_URL is required"
}

@test "slack reaches notify phase for real release with webhook" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"
  fake_bin="$BATS_TEST_TMPDIR/fake-bin-slack-notify"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nprintf called > "%s/slack-curl-called"\nexit 0\n' "$BATS_TEST_TMPDIR" > "$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  PATH="$fake_bin:$PATH" SLACK_WEBHOOK_URL="https://example.invalid" run "$ZERO_RELEASE_BIN" --plugins release-notes,slack --no-push --branches main
  assert_success
  [ -f "$BATS_TEST_TMPDIR/slack-curl-called" ]
}

@test "webhook is skipped in dry-run and does not call curl" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"
  fake_bin="$BATS_TEST_TMPDIR/fake-bin-webhook"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nprintf called > "%s/webhook-curl-called"\nexit 9\n' "$BATS_TEST_TMPDIR" > "$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  PATH="$fake_bin:$PATH" ZERO_RELEASE_WEBHOOK_URL="https://example.invalid" run "$ZERO_RELEASE_BIN" --dry-run --plugins release-notes,webhook --branches main
  assert_success
  [ ! -f "$BATS_TEST_TMPDIR/webhook-curl-called" ]
}

@test "webhook and gchat do not require secrets when there is no release" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "docs: no release"

  run "$ZERO_RELEASE_BIN" --plugins release-notes,webhook,gchat --branches main
  assert_success
  assert_output_contains "No release-worthy commits found"
}

@test "webhook and gchat fail clearly for real release without secrets" {
  make_repo
  commit_file "chore: initial"
  git tag v1.0.0
  commit_file "fix: bug"

  run "$ZERO_RELEASE_BIN" --plugins release-notes,webhook --no-push --branches main
  assert_failure
  assert_output_contains "ZERO_RELEASE_WEBHOOK_URL is required"

  run "$ZERO_RELEASE_BIN" --plugins release-notes,gchat --no-push --branches main
  assert_failure
  assert_output_contains "GCHAT_WEBHOOK_URL is required"
}

@test "slack plugin has no generate-notes hook" {
  ZERO_RELEASE_ROOT_DIR="$PROJECT_ROOT" run "$PROJECT_ROOT/plugins/slack/plugin" generate-notes
  assert_success
}
