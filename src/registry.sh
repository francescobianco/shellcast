
# Hardcoded registry of supported shell environments.
# Format: "<type>:<major>" one per line.
# When a new shell image is added, update this list and add its Dockerfile
# under src/shell/<type>/<major>/Dockerfile.
SHELLCAST_REGISTRY="
bash:4
bash:5
zsh:5
dash:1
sh:1
ash:1
busybox:1
ksh:1
mksh:1
posix:1
"

# Check if a shell:version is in the registry.
# Returns 0 if known, 1 if unknown.
shellcast_registry_is_known() {
  local shell_ver; shell_ver="$1"
  local type; type=$(shellcast_executor_type "$shell_ver")
  local major; major=$(shellcast_executor_major "$shell_ver")
  local entry; entry="${type}:${major}"

  local line; line=""
  for line in $SHELLCAST_REGISTRY; do
    if [ "$line" = "$entry" ]; then
      return 0
    fi
  done
  return 1
}

# Print all registered shells
shellcast_registry_list() {
  local line; line=""
  for line in $SHELLCAST_REGISTRY; do
    printf '  %s\n' "$line"
  done
}
