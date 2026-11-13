# DesktopMove.spoon

Move the focused window to an adjacent macOS desktop and follow it with Hammerspoon.

[한국어](README.md)

| Shortcut | Action |
| --- | --- |
| Ctrl + Shift + Left | Move to the previous desktop |
| Ctrl + Shift + Right | Move to the next desktop |

Moves between normal desktops on the window's current display, skipping fullscreen Spaces. It stops at either end and rejects fullscreen windows and windows assigned to all desktops. After confirming the move, it focuses the window. Mission Control is used as a fallback if macOS does not switch desktops when the window is focused.

## Requirements

- macOS and Hammerspoon. The original configuration was used on **macOS 27.2.1 / Hammerspoon 1.1.1**; other versions have not been verified.
- Accessibility permission for Hammerspoon in System Settings → Privacy & Security → Accessibility.
- At least two normal desktops on the same display.
- Xcode or Command Line Tools to build from source.

The native bridge uses private SkyLight APIs, which can change with macOS updates. Unsupported systems show an alert. Screen Recording permission is not required. Notifications currently use Korean; diagnostic logs use English.

## Install

Download `DesktopMove.spoon.zip` from [Releases](https://github.com/jjeabydev/hammerspoon-desktop-move/releases), unzip it, and double-click `DesktopMove.spoon` to install. Alternatively, copy it to `~/.hammerspoon/Spoons/`.

Add this to `~/.hammerspoon/init.lua` and reload Hammerspoon:

```lua
hs.loadSpoon("DesktopMove")
spoon.DesktopMove:start()
```

Stop or remove any previous desktop movement keyboard handler before starting this Spoon to avoid shortcut conflicts.

To build an installable ZIP:

```sh
git clone https://github.com/jjeabydev/hammerspoon-desktop-move.git
cd hammerspoon-desktop-move
sh scripts/package.sh
open dist/DesktopMove.spoon.zip
```

The build produces an arm64 + x86_64 universal module. Intel runtime behavior has not been verified. Set `HAMMERSPOON_APP` if Hammerspoon is installed outside /Applications.

## Configuration and API

```lua
hs.loadSpoon("DesktopMove")
spoon.DesktopMove.modifiers = {"ctrl", "shift"} -- any combination of ctrl, shift, alt, cmd
spoon.DesktopMove:start()                       -- safe to call repeatedly
spoon.DesktopMove:move(-1)                     -- left, focused window
spoon.DesktopMove:move(1, hs.window.focusedWindow())
spoon.DesktopMove:stop()                       -- stop keyboard handling and pending timers
```

Call `:start()` again after changing modifiers. Only the configured arrow key combinations are intercepted. Automatic key repeats are ignored, while up to eight separate arrow presses during a transition are queued for the same window. The `fn` flag macOS may set for arrow keys is ignored. Other keys, mouse input, and trackpad gestures pass through. macOS shortcut and Mission Control settings are not modified.

`lastResult` contains `window`, `source`, `target`, and `complete`. Completion becomes true after the move, destination Space, and focus remain stable for 0.5 seconds. A failed move or Space switch cancels queued input.

## Troubleshooting

- Permission alert: enable Accessibility access and restart Hammerspoon.
- Module load error: install the entire Spoon ZIP or rebuild locally.
- Window assigned to all desktops: remove the assignment using the app's Dock icon → Options → Assign To.
- Desktop switch failure: check the Hammerspoon console. The window may already have moved.

Related Hammerspoon work: [PR #3889](https://github.com/Hammerspoon/hammerspoon/pull/3889), [#3903](https://github.com/Hammerspoon/hammerspoon/issues/3903), [#3897](https://github.com/Hammerspoon/hammerspoon/issues/3897).

## Development

Run `lua tests/desktopmove_test.lua` with Lua 5.4, then `sh scripts/package.sh`. Tests use mocked Hammerspoon APIs and do not perform real window moves. Before release, manually verify movement in both directions, focus restoration, desktop boundaries, and fullscreen exclusion.

MIT licensed. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for native bridge attribution.
