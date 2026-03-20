
# Compare reference and target shell outputs.
# Writes diff content to diff_file.
# Returns 0 if identical, 1 if different.
shellcast_comparator_compare() {
  local ref; ref="$1"
  local target; target="$2"
  local tmp_dir; tmp_dir="$3"
  local ignore; ignore="$4"
  local diff_file; diff_file="$5"

  local ref_key; ref_key=$(shellcast_executor_key "$ref")
  local tgt_key; tgt_key=$(shellcast_executor_key "$target")

  local ref_stdout; ref_stdout="${tmp_dir}/${ref_key}.stdout"
  local ref_stderr; ref_stderr="${tmp_dir}/${ref_key}.stderr"
  local ref_exit; ref_exit="${tmp_dir}/${ref_key}.exit"

  local tgt_stdout; tgt_stdout="${tmp_dir}/${tgt_key}.stdout"
  local tgt_stderr; tgt_stderr="${tmp_dir}/${tgt_key}.stderr"
  local tgt_exit; tgt_exit="${tmp_dir}/${tgt_key}.exit"

  local ref_ec; ref_ec=0
  local tgt_ec; tgt_ec=0
  [ -f "$ref_exit" ] && ref_ec=$(cat "$ref_exit")
  [ -f "$tgt_exit" ] && tgt_ec=$(cat "$tgt_exit")

  local any_diff; any_diff=0

  {
    # Exit code mismatch
    if [ "$ref_ec" != "$tgt_ec" ]; then
      printf '[exit_code] expected %s, got %s\n' "$ref_ec" "$tgt_ec"
      any_diff=1
    fi

    # Stdout comparison — optionally filter lines matching ignore pattern
    local ref_out; ref_out="$ref_stdout"
    local tgt_out; tgt_out="$tgt_stdout"

    if [ -n "$ignore" ]; then
      local ref_filtered; ref_filtered="${tmp_dir}/${ref_key}.stdout.filtered"
      local tgt_filtered; tgt_filtered="${tmp_dir}/${tgt_key}.stdout.filtered"
      grep -Ev "$ignore" "$ref_out" > "$ref_filtered" 2>/dev/null || true
      grep -Ev "$ignore" "$tgt_out" > "$tgt_filtered" 2>/dev/null || true
      ref_out="$ref_filtered"
      tgt_out="$tgt_filtered"
    fi

    local stdout_diff; stdout_diff=""
    stdout_diff=$(diff -u "$ref_out" "$tgt_out" 2>/dev/null || true)
    if [ -n "$stdout_diff" ]; then
      printf '[stdout]\n%s\n' "$stdout_diff"
      any_diff=1
    fi

    # Stderr comparison
    local stderr_diff; stderr_diff=""
    stderr_diff=$(diff -u "$ref_stderr" "$tgt_stderr" 2>/dev/null || true)
    if [ -n "$stderr_diff" ]; then
      printf '[stderr]\n%s\n' "$stderr_diff"
      any_diff=1
    fi
  } > "$diff_file"

  return "$any_diff"
}