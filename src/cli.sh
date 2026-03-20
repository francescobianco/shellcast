
shellcast_cli_usage() {
  cat <<'EOF'
Usage: shellcast <command> [options]

Commands:
  run <script>    Run script across multiple shell environments
  shells          List registered shell environments
  versions        Discover real versions of all shells by running inside Docker

Options for 'run':
  --ref <shell:version>   Reference shell for comparison (default: bash:5)
  --on <shells>           Target shells, comma-separated  e.g. bash:5,zsh:5,dash:1
  --on-all                Run against all registered shells
  --args "<args>"         Arguments to pass to the script
  --                      Separator: everything after is passed to the script
  --parallel              Run all shells in parallel
  --report <file>         Save JSON report to file
  --ignore <pattern>      Ignore output lines matching grep pattern
  --verbose               Verbose output

Examples:
  shellcast run script.sh --on bash:5,zsh:5 --ref bash:5
  shellcast run script.sh --on bash:5,bash:4,dash:1 --parallel --report out.json
  shellcast run script.sh --on bash:5,zsh:5 --ignore "^#" --verbose
EOF
}

shellcast_cli_parse_run() {
  SC_SCRIPT=""
  SC_REF=""
  SC_TARGETS=""
  SC_ARGS=""
  SC_PARALLEL=0
  SC_REPORT=""
  SC_IGNORE=""
  SC_VERBOSE=0

  if [ "$#" -eq 0 ]; then
    printf 'shellcast run: script argument required\n' >&2
    shellcast_cli_usage >&2
    return 1
  fi

  SC_SCRIPT="$1"
  shift

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --ref)
        shift
        SC_REF="$1"
        ;;
      --ref=*)
        SC_REF="${1#*=}"
        ;;
      --on)
        shift
        SC_TARGETS="$1"
        ;;
      --on=*)
        SC_TARGETS="${1#*=}"
        ;;
      --on-all)
        # Use all shells from the registry as targets
        SC_TARGETS=$(printf '%s' "$SHELLCAST_REGISTRY" | tr '\n' ',' | sed 's/^,//; s/,$//')
        ;;
      --args)
        shift
        SC_ARGS="$1"
        ;;
      --args=*)
        SC_ARGS="${1#*=}"
        ;;
      --parallel)
        SC_PARALLEL=1
        ;;
      --report)
        shift
        SC_REPORT="$1"
        ;;
      --report=*)
        SC_REPORT="${1#*=}"
        ;;
      --ignore)
        shift
        SC_IGNORE="$1"
        ;;
      --ignore=*)
        SC_IGNORE="${1#*=}"
        ;;
      --verbose|-v)
        SC_VERBOSE=1
        ;;
      --)
        # Everything after -- is passed directly to the script
        shift
        SC_ARGS="$*"
        break
        ;;
      *)
        printf 'shellcast run: unknown option: %s\n' "$1" >&2
        return 1
        ;;
    esac
    shift
  done

  if [ -z "$SC_TARGETS" ]; then
    printf 'shellcast run: --on <shells> or --on-all is required\n' >&2
    return 1
  fi

  # Default reference is always bash:5
  if [ -z "$SC_REF" ]; then
    SC_REF="bash:5"
  fi

  export SC_SCRIPT SC_REF SC_TARGETS SC_ARGS SC_PARALLEL SC_REPORT SC_IGNORE SC_VERBOSE
}