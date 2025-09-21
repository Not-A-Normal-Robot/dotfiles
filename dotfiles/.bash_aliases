#!/usr/bin/env bash
alias mysqlstart='sudo systemctl start mysql'
alias smklogin='~/Code/Scripts/wifilogin.sh'
alias autologin='~/Code/Scripts/autologin.sh'
alias ping1='ping 1.1.1.1'
alias ping8='ping 8.8.8.8'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias .......='cd ../../../../../..'
alias ........='cd ../../../../../../..'
alias techmino='git -C ~/Games/Blockstackers/Techmino checkout upstream/main && love ~/Games/Blockstackers/Techmino'
alias time-curl='time curl -v --trace-time -H "Cache-Control: no-cache" -s -o /dev/null'
alias cls=clear
alias dusort='du -had1 | sort -rh'
lysrc() {
    lynx "https://lite.duckduckgo.com/lite/search?q=${*// /+}"
}
function cl() {
    cd "$@" && ls
}
function zl() {
    z "$@" && ls
}
function rob() {
    if [ $# -eq 0 ]; then
        echo "rob: Usage: rob <command> [args...]" >&2
        return 1
    fi

    local delay=1
    local attempt=1

    while true; do
        if "$@"; then
             echo "rob: command succeeded on attempt $attempt" >&2
             return 0
        fi

        echo "rob: attempt $attempt failed, retrying" >&2
        sleep "$delay"

        ((attempt++))
    done
}
# shellcheck disable=SC2154
alias pullall='for d in */.git; do (cd "${d%/.git}" && echo "Updating $PWD" && git pull --ff-only); done'
await-fin() {
  if [ $# -lt 1 ]; then
    echo "Usage: await-fin <PID> [--ignore-failure] [command...]" >&2
    return 1
  fi

  local pid=$1
  shift

  local ignore_failure=0
  if [ "$1" = "--ignore-failure" ]; then
    ignore_failure=1
    shift
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Error: Process $pid does not exist" >&2
    return 1
  fi

  local proc_name
  proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "(unknown)")

  local start_time
  start_time=$(date +%s)

  echo "awaiting end of process '$proc_name' (PID $pid)" >&2
  echo "start timestamp: $(date -u '+%Y-%m-%d %H:%M:%S')" >&2

  while kill -0 "$pid" 2>/dev/null; do
    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    echo -ne "\rawaiting... ${elapsed}s" >&2
    sleep 1
  done
  echo >&2  # New line after the counter

  wait "$pid" 2>/dev/null
  local status=$?

  if [ $status -eq 0 ]; then
    echo "await finished at $(date -u '+%Y-%m-%d %H:%M:%S')" >&2
    if [ $# -gt 0 ]; then
      "$@"
    fi
    return 0
  else
    if [ $status -gt 128 ]; then
      local signal=$((status - 128))
      echo "process ended with signal $signal" >&2
    else
      echo "process ended with code $status" >&2
    fi

    if [ $ignore_failure -eq 1 ] && [ $# -gt 0 ]; then
      "$@"
      return $?
    fi
    return $status
  fi
}
alias canon='cd $(realpath .)'
