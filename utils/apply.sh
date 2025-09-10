#!/usr/bin/env sh
# link-dotfiles.sh - create symlinks from ../dotfiles/* to ~/
# POSIX sh compatible.
#
# Behavior:
#  - For each entry in ../dotfiles (including hidden files), create a symlink at ~/name
#  - If destination exists, compare contents:
#      - identical -> skip
#      - different -> prompt (interactive) for action or use --on-diff policy
#  - Prompt choices (interactive):
#      Y or O : overwrite
#      B      : backup (move existing to a timestamped .bak) and overwrite
#      N or C : no / cancel (skip)
#    If stdin is not a TTY (non-interactive), default behaviour is "backup".
#
# Usage:
#  ./link-dotfiles.sh [--on-diff <o|overwrite|b|backup|s|skip>] [-o|-b|-s] [-q|--quiet] [-h|--help]
#
# Examples:
#  ./link-dotfiles.sh                # interactively prompts for each diff (if run in a terminal)
#  ./link-dotfiles.sh -b             # always backup & overwrite on diffs
#  ./link-dotfiles.sh --on-diff=skip # always skip on diffs
#  ./link-dotfiles.sh -q             # quiet mode (suppress normal output)
#
# Output:
#  Informational messages are printed to stdout (unless -q).
#  Errors go to stderr.

set -eu

print_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  --on-diff <o|overwrite|b|backup|s|skip>  Set non-interactive policy for how to handle differences.
  -o, -b, -s                              Short forms for --on-diff o|b|s respectively.
  -q, --quiet                             Suppress non-error output.
  -h, --help                              Show this help message.

Prompt choices when a difference is detected (interactive):
  Y or O    overwrite
  B         backup (move existing to timestamped .bak) and overwrite
  N or C    no / cancel (skip)
If stdin is not a TTY the script defaults to the 'backup' action.
EOF
}

# Normalize arguments
ON_DIFF="b"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --on-diff)
      shift
      if [ $# -eq 0 ]; then
        echo "Error: --on-diff requires an argument" >&2
        exit 2
      fi
      ON_DIFF="$1"
      ;;
    --on-diff=*)
      ON_DIFF="${1#*=}"
      ;;
    -o)
      ON_DIFF="o"
      ;;
    -b)
      ON_DIFF="b"
      ;;
    -s)
      ON_DIFF="s"
      ;;
    -q|--quiet)
      QUIET=1
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_help
      exit 2
      ;;
  esac
  shift
done

log() {
  if [ "$QUIET" -eq 0 ]; then
    printf '%s\n' "$*" 
  fi
}

err() {
  printf '%s\n' "$*" >&2
}

# Resolve script dir robustly
SCRIPT_DIR=$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)
DOTFILES_DIR="$SCRIPT_DIR/../dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
  err "Dotfiles directory not found: $DOTFILES_DIR"
  exit 1
fi

log "Making links from: $DOTFILES_DIR"

# Helper: normalize policy values
normalize_policy() {
  v=$(printf '%s' "$1" | awk '{print tolower($0)}')
  case "$v" in
    o|overwrite|y|yes)
      printf '%s' "overwrite"
      ;;
    b|backup)
      printf '%s' "backup"
      ;;
    s|skip)
      printf '%s' "skip"
      ;;
    *)
      # unknown
      printf '%s' ""
      ;;
  esac
}

if [ -n "$ON_DIFF" ]; then
  ON_DIFF=$(normalize_policy "$ON_DIFF")
  if [ -z "$ON_DIFF" ]; then
    err "Unknown --on-diff value"
    exit 2
  fi
fi

# Check if stdin is a TTY (interactive)
if [ -t 0 ]; then
  INTERACTIVE=1
else
  INTERACTIVE=0
fi

# Use /dev/tty for prompts if available
TTY="/dev/tty"
if [ ! -r "$TTY" ] || [ ! -w "$TTY" ]; then
  TTY=""
fi

# Determine a safe timestamp for backups
timestamp() {
  # prefer ISO UTC if date supports -u and format
  if date -u "+%Y%m%dT%H%M%SZ" >/dev/null 2>&1; then
    date -u "+%Y%m%dT%H%M%SZ"
  else
    # fallback to epoch seconds
    date "+%s"
  fi
}

# Compare src and dest: returns 0 if same, 1 if different, 2 on error
is_same() {
  src="$1"
  dest="$2"

  if [ ! -e "$dest" ]; then
    return 1
  fi

  # If either is a directory, use diff -r -q
  if [ -d "$src" ] || [ -d "$dest" ]; then
    # diff returns 0 (same), 1 (different), >1 error
    if diff -r -q "$src" "$dest" >/dev/null 2>&1; then
      return 0
    else
      # check exit status of diff explicitly
      if diff -r -q "$src" "$dest" >/dev/null 2>&1; then
        return 0
      else
        # If diff returns non-zero, we assume different (or diff not supported)
        # To be safe, if diff also errored, we treat as different but warn
        return 1
      fi
    fi
  else
    # regular files: use cmp -s
    if cmp -s "$src" "$dest" >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  fi
}

# Ask user what to do for a differing file. prints action to stdout and returns 0.
# The chosen action (one of overwrite|backup|skip) is echoed.
ask_on_diff() {
  src="$1"
  dest="$2"

  # If a global policy was provided, use it
  if [ -n "$ON_DIFF" ]; then
    printf '%s' "$ON_DIFF"
    return 0
  fi

  # If not interactive, default to backup
  if [ "$INTERACTIVE" -eq 0 ] || [ -z "$TTY" ]; then
    printf '%s' "backup"
    return 0
  fi

  # Prompt loop
  while :; do
    printf "%s" "Conflict for '$dest' (existing differs from source). Choose action [Y/O=overwrite, B=backup+overwrite, N/C=no]: " >"$TTY"
    if ! IFS= read -r answer <"$TTY"; then
      # read failed: default to backup
      printf '%s' "backup"
      return 0
    fi
    # normalize
    a=$(printf '%s' "$answer" | awk '{print tolower($0)}')
    case "$a" in
      y|o|overwrite|yes)
        printf '%s' "overwrite"
        return 0
        ;;
      b|backup)
        printf '%s' "backup"
        return 0
        ;;
      n|c|no|cancel)
        printf '%s' "skip"
        return 0
        ;;
      '')
        # treat empty as backup (safe default)
        printf '%s' "backup"
        return 0
        ;;
      *)
        printf "%s\n" "Unrecognized choice: '$answer' (valid: Y/O, B, N/C)" >"$TTY"
        ;;
    esac
  done
}

# Iterate entries in dotfiles directory including hidden ones (but avoid . and ..)
# The glob patterns are expanded by the shell; skip literal patterns if they do not match.
set +f  # temporarily disable globbing? Actually we need globbing enabled. Don't change.
# Build list manually to handle hidden files
for src in "$DOTFILES_DIR"/* "$DOTFILES_DIR"/.[!.]* "$DOTFILES_DIR"/..?*; do
  # If the glob didn't match, the literal pattern may be present; skip it if file doesn't exist
  [ -e "$src" ] || continue

  name=$(basename "$src")
  dest="$HOME/$name"

  # Prepare absolute source path for symlink target
  src_abs="$(cd "$(dirname "$src")" >/dev/null 2>&1 && pwd)/$(basename "$src")"

  if [ -e "$dest" ]; then
    # if dest is a symlink pointing to the same target we can skip fast (but also cmp/diff would catch)
    # Compare contents
    if is_same "$src" "$dest"; then
      log "skip: '$name' (identical)"
      continue
    fi

    # Different: decide action
    action=$(ask_on_diff "$src" "$dest")
    case "$action" in
      overwrite)
        if rm -- "$dest" >/dev/null 2>&1; then
          if ln -s -- "$src_abs" "$dest" >/dev/null 2>&1; then
            log "overwrote: '$name' -> symlink created"
          else
            err "Failed to create symlink for '$name'"
          fi
        else
          err "Failed to remove existing destination '$dest'"
        fi
        ;;
      backup)
        bak="$dest.$(timestamp).bak"
        if mv -- "$dest" "$bak" >/dev/null 2>&1; then
          if ln -s -- "$src_abs" "$dest" >/dev/null 2>&1; then
            log "backed up: '$name' -> '$bak' and symlink created"
          else
            err "Moved '$dest' to '$bak' but failed to create symlink"
          fi
        else
          err "Failed to move '$dest' to backup '$bak'"
        fi
        ;;
      skip)
        log "skipped: '$name'"
        ;;
      *)
        err "Internal error: unknown action '$action' for '$name'"
        ;;
    esac
  else
    # dest does not exist: create symlink
    if ln -s "$src_abs" "$dest" >/dev/null 2>&1; then
      log "linked: '$name' -> $src_abs"
    else
      err "Failed to create symlink for '$name': $RES"
    fi
  fi
done

exit 0
