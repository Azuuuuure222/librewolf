#!/usr/bin/env bash
# Source this file from the build step so Sway stays alive for the full xbps-src run.
# PGO uses a headless Wayland session because the final package is Wayland-only.

pgo_runtime_cleanup() {
  local status=$?
  trap - EXIT

  if [[ -n "${PGO_SWAY_PID:-}" ]]; then
    kill "$PGO_SWAY_PID" >/dev/null 2>&1 || true
    wait "$PGO_SWAY_PID" >/dev/null 2>&1 || true
  fi

  if [[ "$status" -ne 0 && -s "${PGO_SWAY_LOG:-}" ]]; then
    echo "Sway log (PGO compositor startup/runtime):" >&2
    cat "$PGO_SWAY_LOG" >&2
  fi

  if [[ -n "${PGO_RUNTIME_DIR:-}" ]]; then
    rm -rf -- "$PGO_RUNTIME_DIR"
  fi
  exit "$status"
}

pgo_runtime_start() {
  : "${PGO_RUNTIME_DIR:?PGO_RUNTIME_DIR must be set before starting PGO runtime}"

  rm -rf -- "$PGO_RUNTIME_DIR"
  mkdir -p -- "$PGO_RUNTIME_DIR"
  chmod 700 "$PGO_RUNTIME_DIR"

  PGO_SWAY_PID=""
  PGO_SWAY_LOG="$PGO_RUNTIME_DIR/sway.log"
  trap pgo_runtime_cleanup EXIT

  printf '%s\n' \
    'output * mode 1366x768' \
    'default_border none' \
    'default_floating_border none' \
    >"$PGO_RUNTIME_DIR/sway.conf"

  # Weston 13's headless backend does not create a wl_seat by default.
  # Sway/wlroots provides a Wayland seat with no physical devices; Pixman makes
  # rendering deterministic on hosted runners without a usable GPU render node.
  export XDG_RUNTIME_DIR="$PGO_RUNTIME_DIR"
  export WAYLAND_DISPLAY=wayland-1
  export XDG_CURRENT_DESKTOP=sway
  export XDG_SESSION_TYPE=wayland
  export WLR_BACKENDS=headless
  export WLR_RENDERER=pixman
  export WLR_LIBINPUT_NO_DEVICES=1
  export WLR_HEADLESS_OUTPUTS=1
  export WLR_NO_HARDWARE_CURSORS=1
  unset DISPLAY

  sway --config "$PGO_RUNTIME_DIR/sway.conf" --verbose \
    >"$PGO_SWAY_LOG" 2>&1 &
  PGO_SWAY_PID=$!

  # Wait for the Wayland display socket itself. swaymsg speaks Sway's separate
  # IPC protocol and must not be pointed at the Wayland display socket.
  for _ in {1..100}; do
    if ! kill -0 "$PGO_SWAY_PID" 2>/dev/null; then
      echo "Sway exited before its Wayland socket became ready." >&2
      return 1
    fi
    if [[ -S "$PGO_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
      break
    fi
    sleep 0.1
  done

  if [[ ! -S "$PGO_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    echo "Timed out waiting for the PGO Wayland socket." >&2
    return 1
  fi

  # Ensure the compositor survives beyond socket creation before starting a
  # multi-hour instrumented build.
  sleep 1
  if ! kill -0 "$PGO_SWAY_PID" 2>/dev/null; then
    echo "Sway exited immediately after creating its Wayland socket." >&2
    return 1
  fi

  : >"$PGO_RUNTIME_DIR/wayland-required"
}
