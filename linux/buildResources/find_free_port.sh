#!/bin/sh

# This script is intended for linux, not macos.
#   ss is not present on macOS by default, so that test isn't so useful there.
#   The macOS netstat response is different, and has so far been elusive.
#   The lsof test on the other hand, is a good MacOS test and does works the same there.

# This linux script works as follows:
#   If ss (fastest) is available it listens there until it finds an available port.
#     An open port found by ss will then be reconfirmed as open via lsof (if available) otherwise via netstat (if available)
#   If ss is not available but lsof is, then lsof will be used.
#   If neither ss nor lsof are available but netstat is, then netstat will be used.
#   In the event none of these methods are available the default port will be used without confirmation that it is available.

# Why the double check on ss?
#  ss false negatives (ports false reported as not in use) could stem from visibility, parsing, permissions, and tool/version quirks.
#  lsof false negatives are possible but uncommon.
#  netstat false negatives stem from visibility/namespace/permission limits, differing output formats across implementations, filtering flags, IPv6/address-format quirks, race conditions, and parsing bugs. 

# Find first free TCP port starting at $PORT (default 19119)
PORT=${1:-19119}
MAX_PORT=65535

# Helper to identify free port
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

is_listening_ss(){
  ss --numeric --no-header -ltn 2>/dev/null | awk -v p=":$PORT$" '
    { for (i=1;i<=NF;i++) if ($i ~ p) exit 0 }
    END { exit 1 }
  '
}

is_listening_lsof(){
  # -t prints only PIDs
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t >/dev/null 2>/dev/null
}

is_listening_netstat() {
  [ -n "$PORT" ] || return 1
  netstat -ltn 2>/dev/null | {
    skip=2
    found=1
    while IFS= read -r line; do
      if [ "$skip" -gt 0 ]; then skip=$((skip-1)); continue; fi
      addr=
      for token in $line; do
        case $token in
          *:[0-9]*) addr=$token; break;;
        esac
      done
      [ -z "$addr" ] && continue
      addr=${addr#"["}; addr=${addr%"]"}
      port_part=$addr
      # leave only last segment after last colon
      while case $port_part in *:*) true;; *) false;; esac; do
        port_part=${port_part#*:}
      done
      [ "$port_part" = "$PORT" ] && { found=0; break; }
    done
    exit $found
    # 0 = port is listening (occupied)
    # 1 = port not listening (free)
    # We are treating "caller error (PORT unset)" as occupied.
  }
}

# prefer ss then lsof then netstat
checker_available=true
if have_cmd ss; then
  checker=is_listening_ss
elif have_cmd lsof; then
  checker=is_listening_lsof
elif have_cmd netstat; then
  checker=is_listening_netstat
else
  checker_available=false
fi

if [ "$checker_available" = false ]; then
  echo "Neither ss nor lsof nor netstat are available."
  echo "Will use the default port and hope it is not already in use."
else
  # find first free port
  found=false
  tries=0
  while [ "$PORT" -le "$MAX_PORT" ] && [ "$tries" -le 65536 ]; do
    if ! $checker; then
      if [ "$checker" = "is_listening_ss" ]; then
        if have_cmd lsof; then
          if is_listening_lsof; then
            PORT=$((PORT+1)); tries=$((tries+1)); continue
          else
            found=true; break
          fi
        elif have_cmd netstat; then
          if is_listening_netstat; then
            PORT=$((PORT+1)); tries=$((tries+1)); continue
          else
            found=true; break
          fi
        else
          found=true; break
        fi
      else
        found=true; break
      fi
    else
      PORT=$((PORT+1)); tries=$((tries+1)); continue
    fi
  done

  if [ "$found" = false ]; then
    echo "No free TCP port found up to $MAX_PORT"
    exit 1
  fi
fi

# set port environment variables
export ROCKET_PORT=$PORT
