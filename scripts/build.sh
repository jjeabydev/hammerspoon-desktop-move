#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task_app=${HAMMERSPOON_APP:-/Applications/Hammerspoon.app}
task_headers="$task_app/Contents/Frameworks/LuaSkin.framework/Headers"
task_source="$task_root/Source/DesktopMove.spoon"
if [ ! -f "$task_headers/lua.h" ]; then
    echo "Install Hammerspoon or set HAMMERSPOON_APP to its .app path." >&2
    exit 1
fi
xcrun clang -Wall -Wextra -Werror -fobjc-arc -bundle -undefined dynamic_lookup \
    -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -framework Cocoa \
    -I "$task_headers" "$task_source/desktopmove_native.m" \
    -o "$task_source/desktopmove_native.so.new"
mv "$task_source/desktopmove_native.so.new" "$task_source/desktopmove_native.so"
echo "Built $task_source/desktopmove_native.so (arm64 + x86_64)"
