
SHELLCAST_COLOR_GREEN='\033[0;32m'
SHELLCAST_COLOR_RED='\033[0;31m'
SHELLCAST_COLOR_CYAN='\033[0;36m'
SHELLCAST_COLOR_BOLD='\033[1m'
SHELLCAST_COLOR_RESET='\033[0m'

shellcast_reporter_print_header() {
  local script; script="$1"
  local ref; ref="$2"
  printf "${SHELLCAST_COLOR_BOLD}shellcast${SHELLCAST_COLOR_RESET}  script: %s  ref: %s\n\n" \
    "$script" "$ref"
}

shellcast_reporter_print_result() {
  local shell_ver; shell_ver="$1"
  local pass; pass="$2"
  local diff_file; diff_file="$3"

  if [ "$pass" = "0" ]; then
    printf "  ${SHELLCAST_COLOR_GREEN}PASS${SHELLCAST_COLOR_RESET}  %s\n" "$shell_ver"
  else
    printf "  ${SHELLCAST_COLOR_RED}FAIL${SHELLCAST_COLOR_RESET}  %s\n" "$shell_ver"
    if [ -f "$diff_file" ] && [ -s "$diff_file" ]; then
      printf "${SHELLCAST_COLOR_CYAN}"
      sed 's/^/        /' "$diff_file"
      printf "${SHELLCAST_COLOR_RESET}"
    fi
  fi
}

shellcast_reporter_print_summary() {
  local overall; overall="$1"
  printf '\n'
  if [ "$overall" = "0" ]; then
    printf "${SHELLCAST_COLOR_GREEN}${SHELLCAST_COLOR_BOLD}All shells match reference.${SHELLCAST_COLOR_RESET}\n"
  else
    printf "${SHELLCAST_COLOR_RED}${SHELLCAST_COLOR_BOLD}Some shells differ from reference.${SHELLCAST_COLOR_RESET}\n"
  fi
}

# Minimal JSON string escaping
shellcast_reporter_json_escape() {
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g' \
    | awk '{ printf "%s\\n", $0 }' \
    | sed 's/\\n$//'
}

# Write full JSON report to output file
shellcast_reporter_write_json() {
  local script; script="$1"
  local ref; ref="$2"
  local targets; targets="$3"
  local tmp_dir; tmp_dir="$4"
  local out_file; out_file="$5"

  local script_esc; script_esc=$(shellcast_reporter_json_escape "$script")
  local ref_esc; ref_esc=$(shellcast_reporter_json_escape "$ref")

  {
    printf '{\n'
    printf '  "script": "%s",\n' "$script_esc"
    printf '  "reference": "%s",\n' "$ref_esc"
    printf '  "results": [\n'

    local first; first=1
    local s; s=""
    for s in $(printf '%s' "$targets" | tr ',' '\n'); do
      local key; key=$(shellcast_executor_key "$s")
      local exit_file; exit_file="${tmp_dir}/${key}.exit"
      local diff_file; diff_file="${tmp_dir}/${key}.diff"

      local exit_code; exit_code=0
      [ -f "$exit_file" ] && exit_code=$(cat "$exit_file")

      local has_diff; has_diff=0
      local diff_esc; diff_esc=""
      if [ -f "$diff_file" ] && [ -s "$diff_file" ]; then
        has_diff=1
        diff_esc=$(shellcast_reporter_json_escape "$(cat "$diff_file")")
      fi

      local s_esc; s_esc=$(shellcast_reporter_json_escape "$s")

      [ "$first" = "0" ] && printf ',\n'
      printf '    {\n'
      printf '      "shell": "%s",\n' "$s_esc"
      printf '      "exit_code": %d,\n' "$exit_code"
      if [ "$has_diff" = "0" ]; then
        printf '      "pass": true,\n'
        printf '      "diff": null\n'
      else
        printf '      "pass": false,\n'
        printf '      "diff": "%s"\n' "$diff_esc"
      fi
      printf '    }'
      first=0
    done

    printf '\n  ]\n'
    printf '}\n'
  } > "$out_file"
}