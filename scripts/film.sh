#!/bin/bash
# Plays a hands-free brightness routine to film: after a countdown the screen
# fades down to black and back up while kbsync takes the keyboard with it.
# The display goes back to where it was at the end, even on Ctrl-C.
set -euo pipefail
cd "$(dirname "$0")/.."

display=.build/set-display-brightness
if ! pgrep -qf "kbsync run"; then
    echo "kbsync isn't running. Start it first (kbsync run, or kbsync install)." >&2
    exit 1
fi

start=$($display)
trap '$display "$start"' EXIT

echo "Start the camera. The routine runs in 5 seconds and takes about 20."
echo "Don't touch the Mac until it finishes."
for count in 5 4 3 2 1; do
    printf '%s ' "$count"
    sleep 1
done
echo

$display 0.6 1.5    # settle at an everyday level
sleep 1.5
$display 0 4        # all the way down: both go dark
sleep 2
$display 1 4        # all the way up
sleep 1.5
$display 0.6 2      # and back
sleep 1.5
echo "done"
