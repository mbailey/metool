#!/usr/bin/env bats
# Tests for `mt package install` --help/-h and --adopt flags (MT-58)

load test_helper

setup() {
  export TEST_DIR="${BATS_TMPDIR}/metool-adopt-test-$$-${BATS_TEST_NUMBER}"
  export MT_PKG_DIR="${TEST_DIR}/.metool"
  export MT_MODULES_DIR="${MT_PKG_DIR}/modules"
  export MT_PACKAGES_DIR="${MT_PKG_DIR}/packages"
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export HOME="${TEST_DIR}/home"
  export NO_COLOR=1

  mkdir -p "${MT_MODULES_DIR}" "${MT_PACKAGES_DIR}" "${HOME}"

  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/working-set.sh"
  source "${MT_ROOT}/lib/stow.sh"
  source "${MT_ROOT}/lib/package.sh"
  source "${MT_ROOT}/lib/adopt.sh"

  require_command stow git
}

teardown() {
  if [ -n "${TEST_DIR}" ] && [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
  fi
}

# Copy the static fixture into TEST_DIR, init it as a git repo with one commit,
# and add it to the working set. Echoes the package path on stdout.
_install_adopt_fixture() {
  local pkg_path="${TEST_DIR}/adopt-fixture"
  cp -R "${BATS_TEST_DIRNAME}/fixtures/packages/adopt-fixture" "${pkg_path}"
  git -C "${pkg_path}" init -q
  git -C "${pkg_path}" config user.email "test@example.com"
  git -C "${pkg_path}" config user.name "Test User"
  git -C "${pkg_path}" add .
  git -C "${pkg_path}" commit -q -m "initial"
  ln -s "${pkg_path}" "${MT_PACKAGES_DIR}/adopt-fixture"
  echo "${pkg_path}"
}

# --- help / parsing ---

@test "adopt: --help exits 0 and prints Usage" {
  run _mt_package_install --help
  [ $status -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "--adopt" ]]
}

@test "adopt: -h matches --help output" {
  run _mt_package_install --help
  local help_output="$output"
  run _mt_package_install -h
  [ $status -eq 0 ]
  [ "$output" = "$help_output" ]
}

@test "adopt: --bogus errors with Unknown option" {
  run _mt_package_install --bogus
  [ $status -ne 0 ]
  [[ "$output" =~ "Unknown option" ]]
}

# --- adopt behaviour ---

@test "adopt: install without --adopt refuses to clobber pre-existing home file" {
  _install_adopt_fixture >/dev/null
  echo "HOME_DRIFT" > "${HOME}/.fixturerc"

  run _mt_package_install adopt-fixture
  # Stow reports a conflict and does not symlink over the existing file
  [[ "$output" =~ "conflict" ]] || [[ "$output" =~ "--adopt not specified" ]]
  # Home file untouched (still a regular file with its drifted content)
  [ ! -L "${HOME}/.fixturerc" ]
  [ "$(cat "${HOME}/.fixturerc")" = "HOME_DRIFT" ]
}

@test "adopt: --adopt makes home a symlink and source picks up home content" {
  local pkg_path
  pkg_path=$(_install_adopt_fixture)
  echo "HOME_DRIFT" > "${HOME}/.fixturerc"

  run _mt_package_install adopt-fixture --adopt
  [ $status -eq 0 ]

  # Home is now a symlink pointing into the package source
  [ -L "${HOME}/.fixturerc" ]
  local resolved expected
  resolved=$(readlink -f "${HOME}/.fixturerc")
  expected=$(readlink -f "${pkg_path}/config/dot-fixturerc")
  [ "$resolved" = "$expected" ]

  # Source file now contains the home-side content
  [ "$(cat "${pkg_path}/config/dot-fixturerc")" = "HOME_DRIFT" ]
}

@test "adopt: --adopt with identical content removes home file but leaves source unchanged" {
  local pkg_path
  pkg_path=$(_install_adopt_fixture)
  # Pre-populate home with byte-identical content
  cp "${pkg_path}/config/dot-fixturerc" "${HOME}/.fixturerc"
  local before_source_sum
  before_source_sum=$(cksum < "${pkg_path}/config/dot-fixturerc")

  run _mt_package_install adopt-fixture --adopt
  [ $status -eq 0 ]

  # Home is now a symlink (no longer a regular file)
  [ -L "${HOME}/.fixturerc" ]

  # Source content is byte-identical to before
  local after_source_sum
  after_source_sum=$(cksum < "${pkg_path}/config/dot-fixturerc")
  [ "$before_source_sum" = "$after_source_sum" ]
}

@test "adopt: --adopt aborts when package source has uncommitted changes" {
  local pkg_path
  pkg_path=$(_install_adopt_fixture)
  echo "HOME_DRIFT" > "${HOME}/.fixturerc"

  # Dirty the package source on the same path that --adopt would mutate
  echo "DIRTY_LOCAL_EDIT" >> "${pkg_path}/config/dot-fixturerc"

  run _mt_package_install adopt-fixture --adopt
  [ $status -ne 0 ]
  [[ "$output" =~ "uncommitted changes" ]]

  # No mutation: home file still a regular file with its original drifted content
  [ ! -L "${HOME}/.fixturerc" ]
  [ "$(cat "${HOME}/.fixturerc")" = "HOME_DRIFT" ]
  # Source still dirty (unchanged by failed run)
  grep -q "DIRTY_LOCAL_EDIT" "${pkg_path}/config/dot-fixturerc"
}

@test "adopt: --adopt --force overrides the dirty-source guard" {
  local pkg_path
  pkg_path=$(_install_adopt_fixture)
  echo "HOME_DRIFT" > "${HOME}/.fixturerc"
  echo "DIRTY_LOCAL_EDIT" >> "${pkg_path}/config/dot-fixturerc"

  run _mt_package_install adopt-fixture --adopt --force
  [ $status -eq 0 ]

  # Adoption proceeded: home is a symlink
  [ -L "${HOME}/.fixturerc" ]
  # Source now equals the home-side content (single line, no DIRTY tail)
  [ "$(cat "${pkg_path}/config/dot-fixturerc")" = "HOME_DRIFT" ]
}

@test "adopt: running --adopt twice is a no-op on the second run" {
  local pkg_path
  pkg_path=$(_install_adopt_fixture)
  echo "HOME_DRIFT" > "${HOME}/.fixturerc"

  run _mt_package_install adopt-fixture --adopt
  [ $status -eq 0 ]
  local source_after_first
  source_after_first=$(readlink -f "${pkg_path}/config/dot-fixturerc")
  local source_sum_first
  source_sum_first=$(cksum < "${pkg_path}/config/dot-fixturerc")

  run _mt_package_install adopt-fixture --adopt
  [ $status -eq 0 ]
  # No "adopted:" or "linked (no change):" lines on the second run
  [[ ! "$output" =~ "adopted:" ]]
  [[ ! "$output" =~ "linked (no change):" ]]

  # Symlink still resolves to the same source, content unchanged
  [ -L "${HOME}/.fixturerc" ]
  [ "$(readlink -f "${pkg_path}/config/dot-fixturerc")" = "$source_after_first" ]
  [ "$(cksum < "${pkg_path}/config/dot-fixturerc")" = "$source_sum_first" ]
}
