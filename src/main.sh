
module cli
module registry
module executor
module comparator
module reporter

SHELLCAST_VERSION="0.1.0"

main() {
  if [ -z "$SHELLCAST_HOME" ]; then
    SHELLCAST_HOME="$(cd "$(dirname "$0")" && pwd)"
    export SHELLCAST_HOME
  fi

  if [ "$#" -eq 0 ]; then
    shellcast_cli_usage
    return 1
  fi

  local cmd; cmd="$1"
  shift

  case "$cmd" in
    run)
      shellcast_main_cmd_run "$@"
      ;;
    shells)
      shellcast_main_cmd_shells
      ;;
    versions)
      shellcast_executor_discover_versions
      ;;
    --version|-V)
      printf 'shellcast %s\n' "$SHELLCAST_VERSION"
      ;;
    --help|-h)
      shellcast_cli_usage
      ;;
    *)
      printf 'shellcast: unknown command: %s\n' "$cmd" >&2
      shellcast_cli_usage >&2
      return 1
      ;;
  esac
}

# Expand a comma-separated list of shell:version tokens across OS values.
# "local" tokens are never OS-expanded (they always refer to the current machine).
# Example: shells="bash:5,local"  oses="linux,macos"
#       => "bash:5@linux,bash:5@macos,local"
shellcast_main_expand_os() {
  local shells; shells="$1"
  local oses; oses="$2"
  local result; result=""
  local s; s=""
  local os; os=""
  local token; token=""

  for s in $(printf '%s' "$shells" | tr ',' '\n'); do
    if [ "$s" = "local" ]; then
      case ",$result," in
        *",local,"*) ;;
        *) result="${result},local" ;;
      esac
    else
      for os in $(printf '%s' "$oses" | tr ',' '\n'); do
        token="${s}@${os}"
        case ",$result," in
          *",$token,"*) ;;
          *) result="${result},${token}" ;;
        esac
      done
    fi
  done

  printf '%s' "$result" | sed 's/^,//'
}

shellcast_main_cmd_run() {
  shellcast_cli_parse_run "$@" || return 1

  if [ ! -f "$SC_SCRIPT" ]; then
    printf 'shellcast: script not found: %s\n' "$SC_SCRIPT" >&2
    return 1
  fi

  # Expand shells × OS if --os was specified
  local targets; targets="$SC_TARGETS"
  local ref; ref="$SC_REF"
  if [ -n "$SC_OS" ]; then
    targets=$(shellcast_main_expand_os "$SC_TARGETS" "$SC_OS")
    # Ref gets the first OS in the list (unless it is "local")
    if [ "$SC_REF" != "local" ]; then
      local ref_os; ref_os=$(printf '%s' "$SC_OS" | cut -d',' -f1)
      ref="${SC_REF}@${ref_os}"
    fi
  fi

  # Build deduplicated execution set: ref + all targets
  local all_shells; all_shells="$ref"
  local s; s=""
  for s in $(printf '%s' "$targets" | tr ',' '\n'); do
    case ",$all_shells," in
      *",$s,"*) ;;
      *) all_shells="${all_shells},${s}" ;;
    esac
  done

  # Ensure all images / local runners are ready
  for s in $(printf '%s' "$all_shells" | tr ',' '\n'); do
    shellcast_executor_ensure_image "$s" || return 1
  done

  # Create temp directory for per-shell results
  local tmp_dir; tmp_dir=""
  tmp_dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT INT TERM

  shellcast_reporter_print_header "$SC_SCRIPT" "$ref"

  # Execute script on each shell (sequential or parallel)
  local pids; pids=""
  local pid; pid=""
  for s in $(printf '%s' "$all_shells" | tr ',' '\n'); do
    if [ "$SC_PARALLEL" = "1" ]; then
      shellcast_executor_run "$s" "$SC_SCRIPT" "$SC_ARGS" "$tmp_dir" "$SC_VERBOSE" &
      pid=$!
      pids="${pids}${pid} "
    else
      shellcast_executor_run "$s" "$SC_SCRIPT" "$SC_ARGS" "$tmp_dir" "$SC_VERBOSE"
    fi
  done

  if [ "$SC_PARALLEL" = "1" ] && [ -n "$pids" ]; then
    # shellcheck disable=SC2086
    wait $pids 2>/dev/null || true
  fi

  # Compare each target against reference
  local overall; overall=0
  local key; key=""
  local diff_file; diff_file=""
  local pass; pass=0
  for s in $(printf '%s' "$targets" | tr ',' '\n'); do
    key=$(shellcast_executor_key "$s")
    diff_file="${tmp_dir}/${key}.diff"
    if shellcast_comparator_compare "$ref" "$s" "$tmp_dir" "$SC_IGNORE" "$diff_file"; then
      pass=0
    else
      pass=1
      overall=1
    fi
    shellcast_reporter_print_result "$s" "$pass" "$diff_file"
  done

  shellcast_reporter_print_summary "$overall"

  if [ -n "$SC_REPORT" ]; then
    shellcast_reporter_write_json \
      "$SC_SCRIPT" "$ref" "$targets" "$tmp_dir" "$SC_REPORT"
    printf 'Report saved to: %s\n' "$SC_REPORT"
  fi

  return "$overall"
}

shellcast_main_cmd_shells() {
  shellcast_executor_list_shells
}
