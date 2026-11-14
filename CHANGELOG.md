# Changelog

## 1.1.1

- Align regression tests with stable move completion and the startup readiness alert.

## 1.1.0

- Queue up to eight separate arrow presses during a move and keep them bound to the original window.
- Confirm the destination Space and window focus remain stable before reporting completion.
- Accept the `fn` flag macOS may set for arrow keys, report when the keyboard event tap is disabled, and show a ready alert when it starts.

## 1.0.0

- Package the existing desktop window movement configuration as DesktopMove.spoon.
- Move and follow windows with Ctrl+Shift+Left/Right; keep native focus switching and Mission Control fallback.
- Provide configurable modifiers and start, stop, and move methods.
- Include a universal native bridge, source build scripts, Korean/English documentation, and automated tests.
