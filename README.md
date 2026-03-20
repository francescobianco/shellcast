# ShellCast

> Cast your script to multiple shells. Verify compatibility. Catch surprises early.

**ShellCast** is a CLI tool for CI/CD pipelines that runs a shell script across multiple shell environments (Bash, Zsh, Dash, POSIX sh, and more) inside isolated Docker containers, compares the output against a reference, and reports any differences.

Supported platforms and shells:

| Platforms | Shells |
|-----------|--------|
| Linux · macOS · BSD · Solaris · AIX · BusyBox | `sh` `bash` `dash` `ksh` `mksh` `yash` `zsh` `posix` |

> Windows support is planned — contributions welcome.

---

## Features

- Run a script simultaneously on multiple shell environments
- Compare stdout, stderr, and exit codes against a reference shell
- Parallel execution for fast CI runs
- JSON report output for CI/CD integration
- Auto-discovery of real shell versions via Docker introspection (`shellcast versions`)
- Automatic Dockerfile download from the shellcast registry when missing locally

---

## Quick Start

```bash
# Build
mush build --release

# Run a script on bash:5 (reference) and dash:1
shellcast run myscript.sh --ref bash:5 --on bash:5,dash:1,posix:1

# Run in parallel with JSON report
shellcast run myscript.sh \
  --ref bash:5 \
  --on bash:5,bash:4,dash:1,zsh:5,posix:1 \
  --parallel \
  --report report.json
```

---

## Commands

| Command            | Description                                                   |
| ------------------ | ------------------------------------------------------------- |
| `run <script>`     | Run script across multiple shell environments                 |
| `shells`           | List all registered shell environments                        |
| `versions`         | Introspect real shell versions by running inside Docker       |
| `--version`        | Print shellcast version                                       |
| `--help`           | Print usage                                                   |

### `run` Options

| Option                  | Description                                           |
| ----------------------- | ----------------------------------------------------- |
| `--ref <shell:version>` | Reference shell (default: first in `--on` list)       |
| `--on <shells>`         | Target shells, comma-separated                        |
| `--args "<args>"`       | Arguments passed to the script                        |
| `--parallel`            | Run all shells in parallel                            |
| `--report <file>`       | Save results as JSON to file                          |
| `--ignore <pattern>`    | Ignore output lines matching grep regex pattern       |
| `--verbose`             | Show detailed execution log                           |

---

## Supported Shell Environments

| Shell       | Tag       | Base Image             | Notes                         |
| ----------- | --------- | ---------------------- | ----------------------------- |
| `bash:5`    | bash 5.x  | `bash:5` (official)    | Modern Bash                   |
| `bash:4`    | bash 4.x  | `bash:4` (official)    | Older Bash (macOS default)    |
| `zsh:5`     | zsh 5.x   | Alpine 3.19 + zsh      | Z shell                       |
| `dash:1`    | dash 1.x  | Debian bookworm-slim   | Lightweight POSIX shell       |
| `sh:1`      | sh (ash)  | Alpine 3.19            | BusyBox sh (Alpine default)   |
| `ash:1`     | ash       | Alpine 3.19            | BusyBox ash                   |
| `busybox:1` | busybox   | `busybox:1` (official) | Full BusyBox environment      |
| `ksh:1`     | ksh       | Debian bookworm-slim   | KornShell                     |
| `mksh:1`    | mksh      | Debian bookworm-slim   | MirBSD KornShell              |
| `posix:1`   | POSIX sh  | Debian bookworm-slim   | Strict POSIX (via dash)       |

> **Custom shells**: add a `Dockerfile` at `./shell/<type>/<major>/Dockerfile` in your project,
> or at `~/.shellcast/shell/<type>/<major>/Dockerfile` for user-wide availability.
> When not found locally, ShellCast fetches Dockerfiles from the
> [shellcast GitHub registry](https://github.com/francescobianco/shellcast/tree/main/shell/).

---

## CI/CD Integration

ShellCast exits `0` if all shells match the reference, `1` if any differ.

### GitHub Actions example

```yaml
- name: Check shell compatibility
  run: |
    shellcast run myscript.sh \
      --ref bash:5 \
      --on bash:5,bash:4,dash:1,posix:1 \
      --parallel \
      --report shellcast-report.json

- name: Upload report
  uses: actions/upload-artifact@v4
  with:
    name: shellcast-report
    path: shellcast-report.json
```

### JSON Report format

```json
{
  "script": "myscript.sh",
  "reference": "bash:5",
  "results": [
    { "shell": "bash:5",  "exit_code": 0, "pass": true,  "diff": null },
    { "shell": "dash:1",  "exit_code": 0, "pass": false, "diff": "[stdout]\n..." },
    { "shell": "posix:1", "exit_code": 1, "pass": false, "diff": "[exit_code] expected 0, got 1\n..." }
  ]
}
```

---

## Version Introspection

```bash
shellcast versions
```

Builds all registered Docker images and runs the shell's `--version` command inside each container, showing the real installed version:

```
SHELL:VERSION        IMAGE                          REAL VERSION
bash:5               shellcast-bash-5               GNU bash, version 5.2.37(1)-release ...
dash:1               shellcast-dash-1               ...
posix:1              shellcast-posix-1              ...
```

---

## Project Structure

```
Manifest.toml             # Mush package manifest
src/
  main.sh                 # Entry point
  cli.sh                  # CLI argument parsing
  registry.sh             # Hardcoded list of supported shells
  executor.sh             # Docker image management and script execution
  comparator.sh           # Output diff comparison
  reporter.sh             # Human-readable and JSON reporting
shell/
  bash/5/Dockerfile       # Shell environment definitions
  bash/4/Dockerfile
  zsh/5/Dockerfile
  dash/1/Dockerfile
  sh/1/Dockerfile
  ash/1/Dockerfile
  busybox/1/Dockerfile
  ksh/1/Dockerfile
  mksh/1/Dockerfile
  posix/1/Dockerfile
tests/
  fixtures/               # Sample scripts for testing
    hello.sh              # Portable: PASS on all shells
    arithmetic.sh         # Portable: POSIX arithmetic, PASS on all shells
    arrays.sh             # Bash-only: FAIL on dash/sh/posix
    string_ops.sh         # Bash-only: case conversion, FAIL on POSIX shells
    process_substitution.sh  # Bash/Zsh-only: FAIL on dash/sh/posix
    local_assignment.sh   # POSIX-correct local variable style
    exit_code.sh          # Exit code propagation test
  test_hello.sh           # Test runner: portability check
  test_bash_only.sh       # Test runner: bash-only features
  test_arithmetic.sh      # Test runner: POSIX arithmetic
  test_parallel.sh        # Test runner: parallel execution + JSON report
target/
  release/shellcast       # Compiled binary (mush build --release)
```

---

## Built with [Mush](https://mush.javanile.org)

ShellCast is a [Mush](https://mush.javanile.org) project — a shell package manager inspired by Cargo/Rust that brings structured modules, a manifest, and a build pipeline to shell scripting.

```bash
mush build           # debug build → target/debug/shellcast
mush build --release # release build → target/release/shellcast
mush run             # build and run
```
