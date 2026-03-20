
# Convert shell:version[@os] token to a safe key for filenames
# e.g. bash:5 -> bash_5, bash:5@linux -> bash_5_linux, local -> local
shellcast_executor_key() {
  printf '%s' "$1" | tr ':' '_' | tr '.' '_' | tr '@' '_'
}

# Extract OS from shell:version@os token (empty string if no @os)
shellcast_executor_os() {
  local token; token="$1"
  case "$token" in
    *@*) printf '%s' "$token" | cut -d'@' -f2 ;;
    *)   printf '' ;;
  esac
}

# Strip @os suffix from token, returning shell:version part
shellcast_executor_base() {
  printf '%s' "$1" | cut -d'@' -f1
}

# Extract shell type from shell:version[@os] (e.g. bash:5@linux -> bash)
shellcast_executor_type() {
  local base; base=$(shellcast_executor_base "$1")
  printf '%s' "$base" | cut -d':' -f1
}

# Extract major version from shell:version[@os] (e.g. bash:5@linux -> 5)
shellcast_executor_major() {
  local base; base=$(shellcast_executor_base "$1")
  local ver; ver=$(printf '%s' "$base" | cut -d':' -f2)
  printf '%s' "$ver" | cut -d'.' -f1
}

# Get local Docker image tag for a shell:version[@os] token.
# @macos tokens use shellcast-macos-<ver> (default: catalina).
shellcast_executor_image_tag() {
  local token; token="$1"
  local os; os=$(shellcast_executor_os "$token")
  if [ "$os" = "macos" ]; then
    local macos_ver; macos_ver="${SHELLCAST_MACOS_VERSION:-catalina}"
    printf 'shellcast-macos-%s' "$macos_ver"
    return 0
  fi
  local type; type=$(shellcast_executor_type "$token")
  local major; major=$(shellcast_executor_major "$token")
  printf 'shellcast-%s-%s' "$type" "$major"
}

# Get shell binary name for use inside the container.
shellcast_executor_bin() {
  case "$1" in
    bash)    printf 'bash'    ;;
    zsh)     printf 'zsh'     ;;
    dash)    printf 'dash'    ;;
    sh)      printf 'sh'      ;;
    ash)     printf 'ash'     ;;
    busybox) printf 'sh'      ;;
    ksh)     printf 'ksh'     ;;
    mksh)    printf 'mksh'    ;;
    posix)   printf 'dash'    ;;
    *)       printf '%s' "$1" ;;
  esac
}

# Resolve Dockerfile path for a shell type and major version.
# Lookup order:
#   1. $PWD/shell/<type>/<major>/Dockerfile             — project-local override
#   2. $HOME/.shellcast/shell/<type>/<major>/Dockerfile — user cache
#   3. Download from GitHub into user cache (only for shells in the registry)
# Prints the resolved file path on stdout; returns 1 on failure.
shellcast_executor_resolve_dockerfile() {
  local type; type="$1"
  local major; major="$2"

  # 1. Project-local override
  local local_df; local_df="${PWD}/shell/${type}/${major}/Dockerfile"
  if [ -f "$local_df" ]; then
    printf '%s' "$local_df"
    return 0
  fi

  # 2. User cache
  local cache_df; cache_df="${HOME}/.shellcast/shell/${type}/${major}/Dockerfile"
  if [ -f "$cache_df" ]; then
    printf '%s' "$cache_df"
    return 0
  fi

  # 3. Download from GitHub — only if the shell is in the registry
  if ! shellcast_registry_is_known "${type}:${major}"; then
    printf 'shellcast: unknown shell %s:%s (not in registry)\n' "$type" "$major" >&2
    return 1
  fi

  local raw_url; raw_url="https://raw.githubusercontent.com/francescobianco/shellcast/main/shell/${type}/${major}/Dockerfile"
  local cache_dir; cache_dir="${HOME}/.shellcast/shell/${type}/${major}"

  printf '[shellcast] fetching Dockerfile for %s:%s from GitHub...\n' "$type" "$major" >&2

  mkdir -p "$cache_dir" || return 1

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$raw_url" -o "$cache_df" 2>/dev/null || {
      rm -f "$cache_df"
      printf 'shellcast: could not fetch Dockerfile for %s:%s from GitHub\n' "$type" "$major" >&2
      return 1
    }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$cache_df" "$raw_url" 2>/dev/null || {
      rm -f "$cache_df"
      printf 'shellcast: could not fetch Dockerfile for %s:%s from GitHub\n' "$type" "$major" >&2
      return 1
    }
  else
    printf 'shellcast: curl or wget required to fetch shell Dockerfiles\n' >&2
    return 1
  fi

  printf '%s' "$cache_df"
}

# Resolve Dockerfile for the macOS BSD userland image.
# macOS versions map to shell/macos/<ver>/Dockerfile (e.g. catalina, monterey).
# Defaults to "catalina" when no version is specified.
shellcast_executor_resolve_macos_dockerfile() {
  local ver; ver="${1:-catalina}"

  local local_df; local_df="${PWD}/shell/macos/${ver}/Dockerfile"
  if [ -f "$local_df" ]; then
    printf '%s' "$local_df"
    return 0
  fi

  local cache_df; cache_df="${HOME}/.shellcast/shell/macos/${ver}/Dockerfile"
  if [ -f "$cache_df" ]; then
    printf '%s' "$cache_df"
    return 0
  fi

  printf 'shellcast: macos Dockerfile not found (expected at %s)\n' "$local_df" >&2
  return 1
}

# Build Docker image for shell:version[@os] if not already present.
# For "local" tokens: no-op.
# For @macos tokens: build shared BSD userland image.
shellcast_executor_ensure_image() {
  local token; token="$1"

  # local target — no Docker needed
  if [ "$token" = "local" ]; then
    return 0
  fi

  local os; os=$(shellcast_executor_os "$token")
  local tag; tag=$(shellcast_executor_image_tag "$token")

  if docker image inspect "$tag" >/dev/null 2>&1; then
    if [ "${SC_VERBOSE:-0}" = "1" ]; then
      printf '[shellcast] image %s already exists\n' "$tag"
    fi
    return 0
  fi

  printf '[shellcast] building image %s...\n' "$tag"

  if [ "$os" = "macos" ]; then
    local macos_ver; macos_ver="${SHELLCAST_MACOS_VERSION:-catalina}"
    local df_path; df_path=""
    df_path=$(shellcast_executor_resolve_macos_dockerfile "$macos_ver") || return 1
    docker build -t "$tag" -f "$df_path" "$(dirname "$df_path")" || {
      printf 'shellcast: failed to build macos image\n' >&2
      return 1
    }
  else
    local type; type=$(shellcast_executor_type "$token")
    local major; major=$(shellcast_executor_major "$token")
    local dockerfile_content; dockerfile_content=""
    dockerfile_content=$(shellcast_executor_resolve_dockerfile "$type" "$major") || return 1
    docker build -t "$tag" -f "$dockerfile_content" "$(dirname "$dockerfile_content")" || {
      printf 'shellcast: failed to build image for %s\n' "$token" >&2
      return 1
    }
  fi

  printf '[shellcast] image %s ready\n' "$tag"
}

# Run script locally (no Docker) for the "local" target.
# Uses the script's shebang line to determine the interpreter.
shellcast_executor_run_local() {
  local script; script="$1"
  local args; args="$2"
  local tmp_dir; tmp_dir="$3"
  local verbose; verbose="${4:-0}"

  local key; key="local"
  local stdout_file; stdout_file="${tmp_dir}/${key}.stdout"
  local stderr_file; stderr_file="${tmp_dir}/${key}.stderr"
  local exit_file; exit_file="${tmp_dir}/${key}.exit"

  if [ "$verbose" = "1" ]; then
    printf '[shellcast] running %s locally (no Docker)\n' "$(basename "$script")"
  fi

  local exit_code; exit_code=0
  # shellcheck disable=SC2086
  sh "$script" $args > "$stdout_file" 2> "$stderr_file" || exit_code=$?

  printf '%d' "$exit_code" > "$exit_file"

  if [ "$verbose" = "1" ]; then
    printf '[shellcast] local exited with code %d\n' "$exit_code"
  fi
}

# Run script inside a container (or locally) for the given token.
# Token forms: shell:version, shell:version@os, local
shellcast_executor_run() {
  local token; token="$1"
  local script; script="$2"
  local args; args="$3"
  local tmp_dir; tmp_dir="$4"
  local verbose; verbose="${5:-0}"

  if [ "$token" = "local" ]; then
    shellcast_executor_run_local "$script" "$args" "$tmp_dir" "$verbose"
    return $?
  fi

  local key; key=$(shellcast_executor_key "$token")
  local type; type=$(shellcast_executor_type "$token")
  local tag; tag=$(shellcast_executor_image_tag "$token")
  local os; os=$(shellcast_executor_os "$token")

  # For @macos, the bin is determined by the script's shebang (run sh by default)
  local bin; bin=""
  if [ "$os" = "macos" ]; then
    bin="sh"
  else
    bin=$(shellcast_executor_bin "$type")
  fi

  local script_abs; script_abs=""
  script_abs=$(realpath "$script")
  local script_dir; script_dir=""
  script_dir=$(dirname "$script_abs")
  local script_base; script_base=""
  script_base=$(basename "$script_abs")

  if [ "$verbose" = "1" ]; then
    printf '[shellcast] running %s on %s\n' "$script_base" "$token"
  fi

  local stdout_file; stdout_file="${tmp_dir}/${key}.stdout"
  local stderr_file; stderr_file="${tmp_dir}/${key}.stderr"
  local exit_file; exit_file="${tmp_dir}/${key}.exit"

  local exit_code; exit_code=0
  # shellcheck disable=SC2086
  docker run --rm \
    -v "${script_dir}:/work:ro" \
    -w /work \
    "$tag" \
    "$bin" "$script_base" $args \
    > "$stdout_file" 2> "$stderr_file" || exit_code=$?

  printf '%d' "$exit_code" > "$exit_file"

  if [ "$verbose" = "1" ]; then
    printf '[shellcast] %s exited with code %d\n' "$token" "$exit_code"
  fi
}

# List registered shell environments
shellcast_executor_list_shells() {
  printf 'Registered shell environments:\n'
  shellcast_registry_list
  printf '\nSpecial targets:\n'
  printf '  local   — run directly on this machine (no Docker)\n'
  printf '\nCustom shells: place a Dockerfile at:\n'
  printf '  %s/shell/<type>/<major>/Dockerfile\n' "$PWD"
  printf '  %s/.shellcast/shell/<type>/<major>/Dockerfile\n' "$HOME"
}

# Get the shell command to run inside a container to extract its real version.
shellcast_executor_version_cmd() {
  local type; type="$1"
  case "$type" in
    bash)
      printf 'bash --version 2>&1 | head -1'
      ;;
    zsh)
      printf 'zsh --version 2>&1 | head -1'
      ;;
    dash|posix)
      printf 'dpkg-query -W dash 2>/dev/null | awk '"'"'{print "dash " $2}'"'"' || echo "dash (version unknown)"'
      ;;
    sh|ash)
      printf 'apk info busybox 2>/dev/null | head -1 | cut -d" " -f1 || echo "sh/ash (version unknown)"'
      ;;
    busybox)
      printf 'busybox 2>&1 | head -1'
      ;;
    ksh)
      printf 'ksh --version 2>&1 | head -1 | sed '"'"'s/^[[:space:]]*//'"'"
      ;;
    mksh)
      printf "mksh -c 'echo mksh \$KSH_VERSION' 2>/dev/null || dpkg-query -W mksh 2>/dev/null | awk '{print \"mksh \" \$2}'"
      ;;
    yash)
      printf 'yash --version 2>&1 | head -1'
      ;;
    *)
      printf '%s --version 2>&1 | head -1 || %s -version 2>&1 | head -1 || echo "%s (version unknown)"' \
        "$type" "$type" "$type"
      ;;
  esac
}

# Show local machine shell versions (for the "local" entry in versions output)
shellcast_executor_local_versions() {
  local versions; versions=""
  local v; v=""
  if command -v bash >/dev/null 2>&1; then
    v=$(bash --version 2>&1 | head -1)
    versions="${versions}  bash: ${v}\n"
  fi
  if command -v zsh >/dev/null 2>&1; then
    v=$(zsh --version 2>&1 | head -1)
    versions="${versions}  zsh: ${v}\n"
  fi
  if command -v dash >/dev/null 2>&1; then
    v=$(dash --version 2>&1 | head -1 || dpkg-query -W dash 2>/dev/null | awk '{print "dash " $2}' || printf 'dash (version unknown)')
    versions="${versions}  dash: ${v}\n"
  fi
  if command -v sh >/dev/null 2>&1; then
    v=$(sh --version 2>&1 | head -1 || printf 'sh (version unknown)')
    versions="${versions}  sh: ${v}\n"
  fi
  printf '%b' "$versions"
}

# Run version-introspection inside each registered shell container + local.
shellcast_executor_discover_versions() {
  local line; line=""
  printf '%-22s %-30s %s\n' "SHELL:VERSION" "IMAGE" "REAL VERSION"
  printf '%s\n' "---------------------- ------------------------------ ------------------------------"

  # Show local entry first
  printf '%-22s %-30s %s\n' "local" "(host)" "$(uname -s) $(uname -r)"
  shellcast_executor_local_versions | while IFS= read -r vline; do
    printf '  %s\n' "$vline"
  done

  for line in $SHELLCAST_REGISTRY; do
    local type; type=$(shellcast_executor_type "$line")
    local tag; tag=$(shellcast_executor_image_tag "$line")

    shellcast_executor_ensure_image "$line" >/dev/null 2>&1 || {
      printf '%-22s %-30s %s\n' "$line" "$tag" "[image build failed]"
      continue
    }

    local ver_line; ver_line=""
    ver_line=$(docker run --rm "$tag" shell-version 2>/dev/null) || true

    if [ -z "$ver_line" ]; then
      local ver_cmd; ver_cmd=""
      ver_cmd=$(shellcast_executor_version_cmd "$type")
      ver_line=$(docker run --rm "$tag" sh -c "$ver_cmd" 2>/dev/null) || true
    fi

    if [ -z "$ver_line" ]; then
      ver_line="[version unavailable]"
    fi

    ver_line=$(printf '%s' "$ver_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    printf '%-22s %-30s %s\n' "$line" "$tag" "$ver_line"
  done
}
