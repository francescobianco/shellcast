
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

# Get shell binary name for use inside the container.
# Uses unqualified names so the container's PATH resolves them correctly
# (e.g. official bash:5 image has bash at /usr/local/bin/bash, not /bin/bash).
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

# Get Dockerfile content for a shell type and major version.
# Tries to resolve from disk/GitHub first, then falls back to built-in templates.
shellcast_executor_dockerfile() {
  local type; type="$1"
  local major; major="$2"

  local df_path; df_path=""
  if df_path=$(shellcast_executor_resolve_dockerfile "$type" "$major" 2>/dev/null); then
    cat "$df_path"
    return 0
  fi

  # Built-in fallback templates
  if [ "${SC_VERBOSE:-0}" = "1" ]; then
    printf '[shellcast] using built-in Dockerfile template for %s:%s\n' "$type" "$major" >&2
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
    if [ "${SC_VERBOSE:-0}" = "1" ]; then
      printf '[shellcast] image %s already exists\n' "$tag"
    fi
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

  if [ "$verbose" = "1" ]; then
    printf '[shellcast] running %s on %s\n' "$script_base" "$shell_ver"
  fi

  local stdout_file; stdout_file="${tmp_dir}/${key}.stdout"
  local stderr_file; stderr_file="${tmp_dir}/${key}.stderr"
  local exit_file; exit_file="${tmp_dir}/${key}.exit"

  # Mount the script's directory read-only; run from /work inside container.
  # Use || to prevent set -e from triggering on non-zero script exit codes.
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
    printf '[shellcast] %s exited with code %d\n' "$shell_ver" "$exit_code"
  fi
}

# List registered shell environments
shellcast_executor_list_shells() {
  printf 'Registered shell environments:\n'
  shellcast_registry_list
  printf '\nCustom shells: place a Dockerfile at:\n'
  printf '  %s/shell/<type>/<major>/Dockerfile\n' "$PWD"
  printf '  %s/.shellcast/shell/<type>/<major>/Dockerfile\n' "$HOME"
}

# Get the shell command to run inside a container to extract its real version.
# Each shell type needs a different approach because not all support --version.
# Get the shell command to run inside a container to extract its real version.
# The command runs via: docker run --rm <tag> sh -c "<version_cmd>"
# IMPORTANT: do NOT use $VAR shell syntax in the returned string — it will be
# expanded by the outer shell when passed to docker. Use /usr/local/bin/shellcast-version
# (a label-embedded script) or package-manager queries that avoid format strings.
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
      # dash has no --version; use dpkg-query without format variables
      # dpkg-query -W outputs: "dash\t0.5.12-2" — cut the version field
      printf 'dpkg-query -W dash 2>/dev/null | awk '"'"'{print "dash " $2}'"'"' || echo "dash (version unknown)"'
      ;;
    sh|ash)
      # Alpine sh/ash is BusyBox; query apk and take first token (e.g. busybox-1.36.1-r20)
      printf 'apk info busybox 2>/dev/null | head -1 | cut -d" " -f1 || echo "sh/ash (version unknown)"'
      ;;
    busybox)
      # First line of busybox output: "BusyBox v1.37.0 (...)"
      printf 'busybox 2>&1 | head -1'
      ;;
    ksh)
      # AT&T ksh --version has leading spaces; strip them
      printf 'ksh --version 2>&1 | head -1 | sed '"'"'s/^[[:space:]]*//'"'"
      ;;
    mksh)
      # mksh exposes version via KSH_VERSION, readable without variable expansion issues
      # because we run it as a literal arg to -c, not through our outer shell
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

# Run version-introspection inside each registered shell container.
# Builds images that are missing, then queries the real shell version.
shellcast_executor_discover_versions() {
  local line; line=""
  printf '%-20s %-30s %s\n' "SHELL:VERSION" "IMAGE" "REAL VERSION"
  printf '%s\n' "-------------------- ------------------------------ ------------------------------"

  for line in $SHELLCAST_REGISTRY; do
    local type; type=$(shellcast_executor_type "$line")
    local tag; tag=$(shellcast_executor_image_tag "$line")

    # Ensure image is ready, suppress build output unless it fails
    shellcast_executor_ensure_image "$line" >/dev/null 2>&1 || {
      printf '%-20s %-30s %s\n' "$line" "$tag" "[image build failed]"
      continue
    }

    # Prefer the embedded /usr/local/bin/shellcast-version script in the image,
    # fall back to the shell-specific version command.
    local ver_line; ver_line=""
    ver_line=$(docker run --rm "$tag" shellcast-version 2>/dev/null) || true

    if [ -z "$ver_line" ]; then
      local ver_cmd; ver_cmd=""
      ver_cmd=$(shellcast_executor_version_cmd "$type")
      ver_line=$(docker run --rm "$tag" sh -c "$ver_cmd" 2>/dev/null) || true
    fi

    if [ -z "$ver_line" ]; then
      ver_line="[version unavailable]"
    fi

    # Trim leading/trailing whitespace
    ver_line=$(printf '%s' "$ver_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    printf '%-20s %-30s %s\n' "$line" "$tag" "$ver_line"
  done
}