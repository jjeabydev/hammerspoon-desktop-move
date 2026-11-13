#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$task_root/scripts/build.sh"
task_stage=$(mktemp -d)
trap 'rm -rf "$task_stage"' EXIT HUP INT TERM
mkdir -p "$task_stage/DesktopMove.spoon" "$task_root/dist"
cp "$task_root/Source/DesktopMove.spoon/init.lua" \
    "$task_root/Source/DesktopMove.spoon/desktopmove_native.so" \
    "$task_root/LICENSE" "$task_root/THIRD_PARTY_NOTICES.md" \
    "$task_stage/DesktopMove.spoon/"
cp "$task_root/licenses/Hammerspoon-LICENSE" "$task_stage/DesktopMove.spoon/Hammerspoon-LICENSE"
rm -f "$task_root/dist/DesktopMove.spoon.zip"
(cd "$task_stage" && zip -q -r "$task_root/dist/DesktopMove.spoon.zip" DesktopMove.spoon)
echo "Packaged $task_root/dist/DesktopMove.spoon.zip"
