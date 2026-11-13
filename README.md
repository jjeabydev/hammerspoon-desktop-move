# DesktopMove.spoon

현재 창을 옆 macOS 데스크톱으로 이동하고 해당 창을 따라가는 Hammerspoon Spoon 플러그인입니다.

[English documentation](README.en.md)

| 단축키 | 동작 |
| --- | --- |
| Ctrl + Shift + ← | 현재 창을 왼쪽 데스크톱으로 이동 |
| Ctrl + Shift + → | 현재 창을 오른쪽 데스크톱으로 이동 |

현재 모니터의 일반 데스크톱 사이에서 이동합니다. 전체 화면 데스크톱은 건너뛰고, 맨 끝에서는 멈춥니다. 전체 화면 창과 모든 데스크톱에 할당된 창은 이동하지 않습니다. 창 이동을 확인한 뒤 포커스를 주고, macOS가 화면을 전환하지 않으면 Mission Control로 전환합니다.

## 요구 사항

- macOS와 Hammerspoon. 기존 구현의 사용 환경: **macOS 27.2.1 / Hammerspoon 1.1.1**. 다른 버전은 검증하지 않았습니다.
- 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Hammerspoon 허용.
- 같은 모니터에 일반 데스크톱이 두 개 이상 있어야 합니다.
- 소스 빌드에는 Xcode 또는 Command Line Tools가 필요합니다.

네이티브 모듈은 macOS의 비공개 SkyLight API를 사용합니다. OS 업데이트로 호환성이 달라질 수 있으며 모듈이 지원되지 않으면 알림을 표시합니다. 화면 녹음 권한은 필요하지 않습니다.

## 설치

### ZIP 설치

1. [Releases](https://github.com/jjeabydev/hammerspoon-desktop-move/releases)에서 `DesktopMove.spoon.zip`을 다운로드합니다.
2. ZIP을 풀고 `DesktopMove.spoon`을 더블 클릭해 Hammerspoon으로 설치합니다. 수동으로 `~/.hammerspoon/Spoons/`에 복사해도 됩니다.
3. `~/.hammerspoon/init.lua`에 추가하고 Hammerspoon 설정을 다시 불러옵니다.

```lua
hs.loadSpoon("DesktopMove")
spoon.DesktopMove:start()
```

기존 창 이동 코드가 있다면 해당 코드의 키보드 이벤트 처리를 중지하거나 제거한 뒤 이 Spoon을 시작하세요. 같은 단축키를 두 구현에서 처리하면 충돌할 수 있습니다.

### 소스에서 설치

```sh
git clone https://github.com/jjeabydev/hammerspoon-desktop-move.git
cd hammerspoon-desktop-move
sh scripts/package.sh
open dist/DesktopMove.spoon.zip
```

빌드는 Apple Silicon과 Intel을 포함하는 universal 모듈을 만듭니다. Intel 런타임 동작은 아직 검증하지 않았습니다. Hammerspoon이 다른 위치에 있으면 `HAMMERSPOON_APP=/path/to/Hammerspoon.app sh scripts/package.sh`를 사용합니다.

## 설정과 API

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

## 문제 해결

- 권한 알림: 손쉬운 사용 권한을 확인하고 Hammerspoon을 다시 실행하세요.
- 모듈 로드 실패: ZIP 전체를 설치했는지 확인하거나 로컬에서 다시 빌드하세요.
- 모든 데스크톱 할당: Dock의 앱 아이콘 → 옵션 → 할당에서 고정을 해제하세요.
- 화면 전환 실패: Hammerspoon 콘솔 로그를 확인하세요. 창은 이미 목적지로 이동했을 수 있습니다.

호환성 참고: [PR #3889](https://github.com/Hammerspoon/hammerspoon/pull/3889), [#3903](https://github.com/Hammerspoon/hammerspoon/issues/3903), [#3897](https://github.com/Hammerspoon/hammerspoon/issues/3897).

## 개발

```sh
lua tests/desktopmove_test.lua
sh scripts/package.sh
```

테스트는 Lua 5.4에서 모의 Hammerspoon API로 단축키, 이동 대상, 실패 처리와 타이머 정리를 검증합니다. 실제 macOS 창 이동은 대신하지 않습니다. 배포 전에는 두 데스크톱 사이에서 양방향 이동, 포커스 복귀, 끝 경계와 전체 화면 창 제외를 직접 확인하세요.

MIT 라이선스. 네이티브 브리지 출처는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참고하세요.
