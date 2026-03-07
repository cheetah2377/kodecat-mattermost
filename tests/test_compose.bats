#!/usr/bin/env bats

PROJECT_DIR="${BATS_TEST_DIRNAME}/.."

@test "docker-compose.prod.yml is valid YAML" {
  python3 -c "import yaml; yaml.safe_load(open('${PROJECT_DIR}/docker-compose.prod.yml'))"
}

@test ".env.example exists" {
  [ -f "${PROJECT_DIR}/.env.example" ]
  [ -s "${PROJECT_DIR}/.env.example" ]
}

@test "Dockerfile exists" {
  [ -f "${PROJECT_DIR}/Dockerfile" ]
}

@test "backup directory exists" {
  [ -d "${PROJECT_DIR}/backup" ]
}
