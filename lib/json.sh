#!/usr/bin/env bash

zr_json_escape() {
  local value="${1-}"
  printf '%s' "$value" | awk '
    BEGIN { ORS = "" }
    {
      gsub(/\\/,"\\\\")
      gsub(/"/,"\\\"")
      gsub(/\t/,"\\t")
      gsub(/\r/,"\\r")
      if (NR > 1) {
        printf "\\n"
      }
      printf "%s", $0
    }
  '
}

zr_json_string() {
  printf '"%s"' "$(zr_json_escape "${1-}")"
}

zr_json_bool() {
  case "${1-}" in
    true) printf 'true' ;;
    *) printf 'false' ;;
  esac
}

zr_json_string_array() {
  local first="true"
  local item

  printf '['
  for item in "$@"; do
    if [ "$first" = "true" ]; then
      first="false"
    else
      printf ', '
    fi
    zr_json_string "$item"
  done
  printf ']'
}
