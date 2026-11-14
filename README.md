# DesktopMove.spoon

[한국어](#한국어) · [English](#english)

## 한국어

DesktopMove는 현재 포커스된 창을 같은 모니터의 이전·다음 macOS 데스크톱으로 옮기고, 데스크톱 전환과 창 포커스까지 따라가는 Hammerspoon Spoon 플러그인입니다.

Lua Spoon과 macOS 네이티브 브리지로 구성됩니다. Lua 코드가 단축키와 데스크톱 전환을 처리하고, 네이티브 모듈이 창을 다른 데스크톱으로 옮깁니다. 따라서 순수 Lua 플러그인이 아니며, 네이티브 모듈은 macOS의 비공개 SkyLight API에 의존합니다.


| 단축키 | 동작 |
| --- | --- |
| Ctrl + Shift + ← | 현재 창을 왼쪽 데스크톱으로 이동 |
| Ctrl + Shift + → | 현재 창을 오른쪽 데스크톱으로 이동 |

현재 모니터의 일반 데스크톱 사이에서 이동합니다. 전체 화면 데스크톱은 건너뛰고, 맨 끝에서는 멈춥니다. 전체 화면 창과 모든 데스크톱에 할당된 창은 이동하지 않습니다. 창 이동을 확인한 뒤 포커스를 주고, macOS가 화면을 전환하지 않으면 Mission Control로 전환합니다.

### 동작 환경

- **검증한 환경:** Apple Silicon(arm64), macOS 27.2.1, Hammerspoon 1.1.1.
- 배포용 네이티브 모듈은 arm64와 x86_64를 포함하는 universal 바이너리입니다. Intel Mac에서 실행은 검증하지 않았습니다.
- 다른 macOS 및 Hammerspoon 버전은 검증하지 않았으므로 호환성을 보장하지 않습니다. 특히 macOS 업데이트로 비공개 SkyLight API가 바뀌면 네이티브 모듈이 동작하지 않을 수 있습니다.
- 단축키 입력과 창 제어를 위해 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Hammerspoon을 허용해야 합니다. 화면 녹음 권한은 필요하지 않습니다.
- 창이 있는 디스플레이에 일반 데스크톱이 두 개 이상 있어야 합니다. 전체 화면 데스크톱은 건너뛰며, 전체 화면 창과 모든 데스크톱에 할당된 창은 이동하지 않습니다.
- 소스 빌드에는 Xcode 또는 Command Line Tools가 필요합니다.

네이티브 모듈을 불러오지 못하거나 권한이 없으면 Hammerspoon 알림에 오류를 표시합니다.

### 설치

#### ZIP 설치

1. [Releases](https://github.com/jjeabydev/hammerspoon-desktop-move/releases)에서 `DesktopMove.spoon.zip`을 다운로드합니다.
2. ZIP을 풀고 `DesktopMove.spoon`을 더블 클릭해 Hammerspoon으로 설치합니다. 수동으로 `~/.hammerspoon/Spoons/`에 복사해도 됩니다.
3. `~/.hammerspoon/init.lua`에 추가하고 Hammerspoon 설정을 다시 불러옵니다.

```lua
hs.loadSpoon("DesktopMove")
spoon.DesktopMove:start()
```

기존 창 이동 코드가 있다면 해당 코드의 키보드 이벤트 처리를 중지하거나 제거한 뒤 이 Spoon을 시작하세요. 같은 단축키를 두 구현에서 처리하면 충돌할 수 있습니다.

#### 소스에서 설치

```sh
git clone https://github.com/jjeabydev/hammerspoon-desktop-move.git
cd hammerspoon-desktop-move
sh scripts/package.sh
open dist/DesktopMove.spoon.zip
```

빌드는 Apple Silicon과 Intel을 포함하는 universal 모듈을 만듭니다. Intel 런타임 동작은 아직 검증하지 않았습니다. Hammerspoon이 다른 위치에 있으면 `HAMMERSPOON_APP=/path/to/Hammerspoon.app sh scripts/package.sh`를 사용합니다.

### 설정과 API

```lua
hs.loadSpoon("DesktopMove")
spoon.DesktopMove.modifiers = {"ctrl", "shift"} -- ctrl, shift, alt, cmd 조합
spoon.DesktopMove:start()                       -- 여러 번 호출해도 이벤트 탭은 하나

-- 선택 사항: 직접 호출
spoon.DesktopMove:move(-1)                     -- 왼쪽, 현재 포커스 창
spoon.DesktopMove:move(1, hs.window.focusedWindow())
spoon.DesktopMove:stop()                       -- 키보드 처리와 진행 중 타이머 중지
```

`modifiers` 변경 후 `:start()`를 다시 호출합니다. 기본 단축키에서는 키 자동 반복을 무시하지만, 전환 중 별도로 누른 화살표 입력은 같은 창에 최대 8회까지 순서대로 적용합니다. macOS가 화살표 키에 설정하는 `fn` 플래그는 무시합니다. 다른 키 입력과 마우스·트랙패드 이벤트는 그대로 통과시킵니다. macOS 단축키와 Mission Control 설정은 변경하지 않습니다.

이동 결과는 `spoon.DesktopMove.lastResult`의 `window`, `source`, `target`, `complete`에서 확인할 수 있습니다. `complete`는 창 이동과 대상 데스크톱, 포커스가 0.5초 동안 안정된 것을 확인했을 때 true입니다. 이동 또는 화면 전환이 실패하면 대기 중인 입력은 취소합니다.

### 문제 해결

- 권한 알림: 손쉬운 사용 권한을 확인하고 Hammerspoon을 다시 실행하세요.
- 모듈 로드 실패: ZIP 전체를 설치했는지 확인하거나 로컬에서 다시 빌드하세요.
- 모든 데스크톱 할당: Dock의 앱 아이콘 → 옵션 → 할당에서 고정을 해제하세요.
- 화면 전환 실패: Hammerspoon 콘솔 로그를 확인하세요. 창은 이미 목적지로 이동했을 수 있습니다.

호환성 참고: [PR #3889](https://github.com/Hammerspoon/hammerspoon/pull/3889), [#3903](https://github.com/Hammerspoon/hammerspoon/issues/3903), [#3897](https://github.com/Hammerspoon/hammerspoon/issues/3897).

### 개발

```sh
lua tests/desktopmove_test.lua
sh scripts/package.sh
```

테스트는 Lua 5.4에서 모의 Hammerspoon API로 단축키, 이동 대상, 실패 처리와 타이머 정리를 검증합니다. 실제 macOS 창 이동은 대신하지 않습니다. 배포 전에는 두 데스크톱 사이에서 양방향 이동, 포커스 복귀, 끝 경계와 전체 화면 창 제외를 직접 확인하세요.

MIT 라이선스. 네이티브 브리지 출처는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참고하세요.

---

## English

DesktopMove is a Hammerspoon Spoon that moves the focused window to the previous or next macOS desktop on the same display, then follows it by switching desktops and restoring focus.

It combines a Lua Spoon with a native macOS bridge: Lua handles shortcuts and desktop switching, while the native module moves the window between desktops. This is not a pure-Lua plugin. The native module depends on private SkyLight APIs.


| Shortcut | Action |
| --- | --- |
| Ctrl + Shift + Left | Move to the previous desktop |
| Ctrl + Shift + Right | Move to the next desktop |

Moves between normal desktops on the window's current display, skipping fullscreen Spaces. It stops at either end and rejects fullscreen windows and windows assigned to all desktops. After confirming the move, it focuses the window. Mission Control is used as a fallback if macOS does not switch desktops when the window is focused.

### Supported environment

- **Verified on:** Apple Silicon (arm64), macOS 27.2.1, and Hammerspoon 1.1.1.
- The release module is a universal binary containing arm64 and x86_64 slices. Runtime behavior on Intel Macs has not been verified.
- Other macOS and Hammerspoon versions have not been verified, so compatibility is not guaranteed. In particular, macOS updates may change the private SkyLight APIs used by the native module.
- Hammerspoon needs Accessibility permission in System Settings → Privacy & Security → Accessibility to handle shortcuts and control windows. Screen Recording permission is not required.
- The display containing the window needs at least two normal desktops. Fullscreen desktops are skipped; fullscreen windows and windows assigned to all desktops cannot be moved.
- Xcode or Command Line Tools are required to build from source.

If the native module cannot load or permission is unavailable, DesktopMove shows an alert. Notifications are currently in Korean; diagnostic logs are in English.

### Install

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

### Configuration and API

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

### Troubleshooting

- Permission alert: enable Accessibility access and restart Hammerspoon.
- Module load error: install the entire Spoon ZIP or rebuild locally.
- Window assigned to all desktops: remove the assignment using the app's Dock icon → Options → Assign To.
- Desktop switch failure: check the Hammerspoon console. The window may already have moved.

Related Hammerspoon work: [PR #3889](https://github.com/Hammerspoon/hammerspoon/pull/3889), [#3903](https://github.com/Hammerspoon/hammerspoon/issues/3903), [#3897](https://github.com/Hammerspoon/hammerspoon/issues/3897).

### Development

Run `lua tests/desktopmove_test.lua` with Lua 5.4, then `sh scripts/package.sh`. Tests use mocked Hammerspoon APIs and do not perform real window moves. Before release, manually verify movement in both directions, focus restoration, desktop boundaries, and fullscreen exclusion.

MIT licensed. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for native bridge attribution.
