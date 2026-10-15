#!/bin/bash
# Replaces the LibreAim.app bundle with the latest release, then relaunches it.
# Usage: update_macos.sh <path to LibreAim.app> <game pid> <zip url>
APP="$1"
PID="$2"
URL="$3"

while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

relaunch() { open "$APP"; exit "$1"; }

curl -fsSL -o "$TMP/app.zip" "$URL" || relaunch 1
ditto -x -k "$TMP/app.zip" "$TMP/new" || relaunch 1
[ -d "$TMP/new/LibreAim.app" ] || relaunch 1

mv "$APP" "$TMP/old.app" || relaunch 1
if ! mv "$TMP/new/LibreAim.app" "$APP"; then
	mv "$TMP/old.app" "$APP"
	relaunch 1
fi
relaunch 0
