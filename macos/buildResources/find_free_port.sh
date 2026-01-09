#!/bin/sh

# Find first free TCP port starting at $PORT (default 19119)
PORT=${1:-19119}
MAX_PORT=65535

# Helper to identify free port
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

is_listening_lsof(){
  # -t prints only PIDs
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t >/dev/null 2>/dev/null
}

# Use lsof port checker helper if available
checker_available=true
if have_cmd lsof; then
  checker=is_listening_lsof
else
  checker_available=false
fi

if [ "$checker_available" = false ]; then
  echo "lsof is not available."
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