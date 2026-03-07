#!/usr/bin/env bats

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../scripts"

@test "all scripts have valid syntax" {
  for script in "${SCRIPTS_DIR}"/*.sh; do
    run bash -n "$script"
    [ "$status" -eq 0 ]
  done
}

@test "library scripts have valid syntax" {
  for script in "${SCRIPTS_DIR}"/lib/*.sh; do
    if [ -f "$script" ]; then
      run bash -n "$script"
      [ "$status" -eq 0 ]
    fi
  done
}

@test "scripts start with proper shebang" {
  for script in "${SCRIPTS_DIR}"/*.sh; do
    run bash -c "head -1 '$script' | grep -qE '^#!/'"
    [ "$status" -eq 0 ]
  done
}
