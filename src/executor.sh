
# Convert shell:version to a safe key for filenames (e.g. bash:5.2 -> bash_5_2)
shellcast_executor_key() {
  printf '%s' "$1" | tr ':' '_' | tr '.' '_'
}

# Extract shell type from shell:version (e.g. bash:5.2 -> bash)
shellcast_executor_type() {
  printf '%s' "$1" | cut -d':' -f1
}

# Extract major version from shell:version (e.g. bash:5.2 -> 5, zsh:5 -> 5)
shellcast_executor_major() {
  local ver; ver=""
  ver=$(printf '%s' "$1" | cut -d':' -f2)
  printf '%s' "$ver" | cut -d'.' -f1
}

# Get local Docker image tag for a shell:version
shellcast_executor_image_tag() {
  local type; type=$(shellcast_executor_type "$1")
  local major; major=$(shellcast_executor_major "$1")
  printf 'shellcast-%s-%s' "$type" "$major"
}

# Get shell binary path inside container
shellcast_executor_bin() {
  case "$1" in
    bash) printf '/bin/bash' ;;
    zsh)  printf '/bin/zsh'  ;;
    dash) printf '/bin/dash' ;;
    sh)   printf '/bin/sh'   ;;
    ksh)  printf '/bin/ksh'  ;;
    *)    printf '/bin/%s' "$1" ;;
  esac
}

# Get Dockerfile content for a shell type and major version.
# Checks $SHELLCAST_HOME/shell/<type>/<major>/Dockerfile first,
# then falls back to built-in templates.
shellcast_executor_dockerfile() {
  local type; type="$1"
  local major; major="$2"

  local df_path; df_path="${SHELLCAST_HOME}/shell/${type}/${major}/Dockerfile"
  if [ -f "$df_path" ]; then
    cat "$df_path"
    return 0
  fi

  case "$type" in
    bash)
      printf 'FROM bash:%s\n' "$major"
      printf 'LABEL shellcast.shell="bash" shellcast.version="%s"\n' "$major"
      ;;
    zsh)
      printf 'FROM alpine:3.19\n'
      printf 'RUN apk add --no-cache zsh\n'
      printf 'LABEL shellcast.shell="zsh" shellcast.version="%s"\n' "$major"
      ;;
    dash)
      printf 'FROM debian:bookworm-slim\n'
      printf 'RUN apt-get update && apt-get install -y --no-install-recommends dash \\\n'
      printf '    && rm -rf /var/lib/apt/lists/*\n'
      printf 'LABEL shellcast.shell="dash" shellcast.version="%s"\n' "$major"
      ;;
    sh)
      printf 'FROM alpine:3.19\n'
      printf 'LABEL shellcast.shell="sh" shellcast.version="%s"\n' "$major"
      ;;
    ksh)
      printf 'FROM debian:bookworm-slim\n'
      printf 'RUN apt-get update && apt-get install -y --no-install-recommends ksh \\\n'
      printf '    && rm -rf /var/lib/apt/lists/*\n'
      printf 'LABEL shellcast.shell="ksh" shellcast.version="%s"\n' "$major"
      ;;
    *)
      printf 'shellcast: unsupported shell type: %s\n' "$type" >&2
      return 1
      ;;
  esac
}

# Build Docker image for shell:version if not already present
shellcast_executor_ensure_image() {
  local shell_ver; shell_ver="$1"
  local type; type=$(shellcast_executor_type "$shell_ver")
  local major; major=$(shellcast_executor_major "$shell_ver")
  local tag; tag=$(shellcast_executor_image_tag "$shell_ver")

  if docker image inspect "$tag" >/dev/null 2>&1; then
    [ "${SC_VERBOSE:-0}" = "1" ] && printf '[shellcast] image %s already exists\n' "$tag"
    return 0
  fi

  printf '[shellcast] building image %s...\n' "$tag"

  local dockerfile_content; dockerfile_content=""
  dockerfile_content=$(shellcast_executor_dockerfile "$type" "$major") || return 1

  printf '%s\n' "$dockerfile_content" | docker build -t "$tag" - || {
    printf 'shellcast: failed to build image for %s\n' "$shell_ver" >&2
    return 1
  }

  printf '[shellcast] image %s ready\n' "$tag"
}

# Run script inside a container for the given shell:version.
# Outputs are saved to $tmp_dir/<key>.stdout, .stderr, .exit
shellcast_executor_run() {
  local shell_ver; shell_ver="$1"
  local script; script="$2"
  local args; args="$3"
  local tmp_dir; tmp_dir="$4"
  local verbose; verbose="${5:-0}"

  local key; key=$(shellcast_executor_key "$shell_ver")
  local type; type=$(shellcast_executor_type "$shell_ver")
  local tag; tag=$(shellcast_executor_image_tag "$shell_ver")
  local bin; bin=$(shellcast_executor_bin "$type")

  local script_abs; script_abs=""
  script_abs=$(realpath "$script")
  local script_dir; script_dir=""
  script_dir=$(dirname "$script_abs")
  local script_base; script_base=""
  script_base=$(basename "$script_abs")

  [ "$verbose" = "1" ] && printf '[shellcast] running %s on %s\n' "$script_base" "$shell_ver"

  local stdout_file; stdout_file="${tmp_dir}/${key}.stdout"
  local stderr_file; stderr_file="${tmp_dir}/${key}.stderr"
  local exit_file; exit_file="${tmp_dir}/${key}.exit"

  # Mount the script's directory read-only; run from /work inside container
  # shellcheck disable=SC2086
  docker run --rm \
    -v "${script_dir}:/work:ro" \
    -w /work \
    "$tag" \
    "$bin" "$script_base" $args \
    > "$stdout_file" 2> "$stderr_file"

  local exit_code; exit_code=$?
  printf '%d' "$exit_code" > "$exit_file"

  [ "$verbose" = "1" ] && printf '[shellcast] %s exited with code %d\n' "$shell_ver" "$exit_code"
}

# List built-in supported shell environments
shellcast_executor_list_shells() {
  printf 'Built-in shell environments:\n'
  printf '  bash:4    GNU Bash 4.x\n'
  printf '  bash:5    GNU Bash 5.x\n'
  printf '  zsh:5     Zsh 5.x (Alpine)\n'
  printf '  dash:1    Dash 1.x (Debian)\n'
  printf '  sh:1      POSIX sh / BusyBox (Alpine)\n'
  printf '  ksh:1     KornShell (Debian)\n'
  printf '\nCustom shells: place a Dockerfile at:\n'
  printf '  $SHELLCAST_HOME/shell/<type>/<major>/Dockerfile\n'
}