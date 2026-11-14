-- macOS 27: native window moves and WindowManager accessibility, no mouse input.
local M = {
    name = "DesktopMove",
    version = "1.1.1",
    author = "jjeabydev",
    homepage = "https://github.com/jjeabydev/hammerspoon-desktop-move",
    license = "MIT - https://opensource.org/licenses/MIT",
    modifiers = {"ctrl", "shift"},
    busy = false,
    timers = {},
    capturedKeys = {},
    pending = {},
}
local spoonPath = hs.spoons.scriptPath()
local spaces = require("hs.spaces")
local log = hs.logger.new("desktopMove", "info")
local native, loadError

--- DesktopMove:init() -> self
--- Loads the bundled native module. Called by hs.loadSpoon.
function M:init()
    local loader
    loader, loadError = package.loadlib(spoonPath .. "desktopmove_native.so", "luaopen_desktopmove_native")
    if loader then
        local ok, module = pcall(loader)
        if ok then native = module else loadError = module end
    end
    return self
end
local function children(e) return e and e:attributeValue("AXChildren") or {} end
local function child(e, id)
    for _, c in ipairs(children(e)) do
        if c:attributeValue("AXIdentifier") == id then return c end
    end
end
local function displays()
    local app = hs.application.get("com.apple.WindowManager")
    local result = {}
    if app then
        for _, c in ipairs(children(hs.axuielement.applicationElement(app))) do
            if c:attributeValue("AXIdentifier") == "mc.display" then table.insert(result, c) end
        end
    end
    return result
end
local function poll(condition, callback, timeout, interval)
    local start = hs.timer.secondsSinceEpoch()
    local ok, result = pcall(condition)
    if not ok or result then
        callback(ok and result or nil, not ok and result or nil)
        return
    end
    local timer
    timer = hs.timer.doEvery(interval or 0.05, function()
        local ok, result = pcall(condition)
        if not ok or result or hs.timer.secondsSinceEpoch() - start >= timeout then
            timer:stop()
            M.timers[timer] = nil
            callback(ok and result or nil, not ok and result or nil)
        end
    end)
    M.timers[timer] = true
end
local function report(message, detail)
    hs.alert.show(message)
    if detail then log.e(tostring(detail)) end
end
local function onSpace(w, target)
    for _, id in ipairs(spaces.windowSpaces(w) or {}) do if id == target then return true end end
    return false
end
local function closeMissionControl()
    if #displays() > 0 then spaces.toggleMissionControl() end
end
local function switchMissionControl(target, callback)
    local uuid = spaces.spaceDisplay(target)
    local screen, index
    for _, s in ipairs(hs.screen.allScreens()) do if s:getUUID() == uuid then screen = s end end
    if not screen then return callback(nil, "target display disconnected") end
    for i, id in ipairs(spaces.spacesForScreen(screen) or {}) do if id == target then index = i end end
    if not index then return callback(nil, "target space disappeared") end
    if spaces.activeSpaceOnScreen(screen) == target then return callback(true) end
    if #displays() == 0 then spaces.toggleMissionControl() end
    poll(function()
        local frame = screen:fullFrame()
        for _, group in ipairs(displays()) do
            local bounds = group:attributeValue("AXFrame")
            local match = group:attributeValue("AXDisplayID") == screen:id()
            if not match and bounds then
                match = math.abs(bounds.x - frame.x) < 2 and math.abs(bounds.y - frame.y) < 2
                    and math.abs(bounds.w - frame.w) < 2 and math.abs(bounds.h - frame.h) < 2
            end
            if match then
                local list = child(child(group, "mc.spaces"), "mc.spaces.list")
                local buttons = children(list)
                if buttons[index] then return buttons[index] end
            end
        end
    end, function(button, errorMessage)
        if not button then
            closeMissionControl()
            return callback(nil, errorMessage or "Mission Control space button unavailable")
        end
        local pressed, pressError = button:performAction("AXPress")
        if not pressed then closeMissionControl(); return callback(nil, pressError) end
        poll(function()
            return spaces.activeSpaceOnScreen(screen) == target and #displays() == 0
        end, function(active, activeError)
            if not active then closeMissionControl() end
            callback(active, activeError or (not active and "space switch timed out"))
        end, 3)
    end, 3)
end
local drain
local function stableFollow(window, screen, target, callback, timeout)
    local stableSince
    poll(function()
        local focused = hs.window.focusedWindow()
        local ready = spaces.activeSpaceOnScreen(screen) == target
            and onSpace(window, target) and focused and focused:id() == window:id()
        if not ready then stableSince = nil; return false end
        stableSince = stableSince or hs.timer.secondsSinceEpoch()
        return hs.timer.secondsSinceEpoch() - stableSince >= 0.5
    end, callback, timeout)
end
local function finishMove(cancelPending)
    M.busy, M.activeWindow = false, nil
    if cancelPending then M.pending = {} end
    if drain then drain() end
end
local function switchSpace(target, window, callback)
    local uuid = spaces.spaceDisplay(target)
    local screen
    for _, s in ipairs(hs.screen.allScreens()) do if s:getUUID() == uuid then screen = s end end
    if not screen then return callback(nil, "target display disconnected") end
    window:focus()
    stableFollow(window, screen, target, function(active, followError)
        if active then return callback(true) end
        switchMissionControl(target, function(switched, switchError)
            if not switched then return callback(nil, switchError or followError or "space switch failed") end
            window:focus()
            stableFollow(window, screen, target, callback, 2)
        end)
    end, 1.2)
end
local function runMove(direction, selectedWindow)
    if not hs.accessibilityState() then return report("Hammerspoon의 손쉬운 사용 권한이 꺼져 있습니다.") end
    if not native or not native.available() then return report("창 이동 모듈을 불러올 수 없습니다.", loadError) end
    local w = selectedWindow or hs.window.focusedWindow()
    if not w or not w:isStandard() then return report("이동할 일반 창을 선택해 주세요.") end
    if w:isFullScreen() then return report("전체 화면을 해제한 다음 창을 이동해 주세요.") end
    local memberships = spaces.windowSpaces(w)
    if not memberships or #memberships == 0 then return report("선택한 창의 데스크톱을 찾을 수 없습니다.") end
    if #memberships > 1 then return report("이 앱이 모든 데스크탑에 할당되어 있습니다. Dock의 할당 옵션을 해제해 주세요.") end
    local current, index = memberships[1], nil
    local desktops = {}
    for _, id in ipairs(spaces.spacesForScreen(spaces.spaceDisplay(current)) or {}) do
        if spaces.spaceType(id) == "user" then
            table.insert(desktops, id)
            if id == current then index = #desktops end
        end
    end
    local target = index and desktops[index + direction]
    if not target then return report(direction < 0 and "왼쪽에 데스크톱이 없습니다." or "오른쪽에 데스크톱이 없습니다.") end
    M.busy, M.activeWindow = true, w
    local result = {window = w:id(), source = current, target = target, complete = false}
    M.lastResult = result
    local submitted, moveError = native.move(w:id(), target)
    if not submitted then
        report("창 이동 요청에 실패했습니다.", moveError)
        finishMove(true)
        return false
    end
    poll(function() return onSpace(w, target) end, function(moved, errorMessage)
        if not moved then
            report("창이 이동하지 않았습니다. Hammerspoon 콘솔을 확인해 주세요.", errorMessage or "window move timed out")
            return finishMove(true)
        end
        switchSpace(target, w, function(switched, switchError)
            if not switched then
                report("창은 이동했지만 화면 전환이 실패했습니다.", switchError)
                return finishMove(true)
            end
            local focused = hs.window.focusedWindow()
            if not focused or focused:id() ~= w:id() then w:focus() end
            result.complete = onSpace(w, target)
            log.i(string.format("Window %d: Space %d → %d", w:id(), current, target))
            finishMove(false)
        end)
    end, 3, 0.01)
    return true
end
--- DesktopMove:move(direction[, window])
--- Moves a standard window to the adjacent user desktop and follows it.
--- direction must be -1 (left) or 1 (right).
function M:move(direction, selectedWindow)
    if direction ~= -1 and direction ~= 1 then error("direction must be -1 or 1", 2) end
    if M.busy then
        if #M.pending >= 8 then
            log.e("DesktopMove input queue is full; dropping key press")
            return
        end
        table.insert(M.pending, {direction = direction, window = M.activeWindow or selectedWindow or hs.window.focusedWindow()})
        return
    end
    runMove(direction, selectedWindow)
    if not M.busy and drain then drain() end
end
drain = function()
    if M.busy or M.drainTimer or #M.pending == 0 then return end
    local timer
    timer = hs.timer.doEvery(0.05, function()
        timer:stop()
        M.timers[timer], M.drainTimer = nil, nil
        local request = table.remove(M.pending, 1)
        if request then M:move(request.direction, request.window) end
    end)
    M.drainTimer = timer
    M.timers[timer] = true
end
--- DesktopMove:stop() -> self
--- Stops keyboard interception and cancels pending polling timers.
function M:stop()
    for timer in pairs(M.timers) do timer:stop() end
    M.timers = {}
    if M.keyboard then M.keyboard:stop() end
    M.capturedKeys, M.pending = {}, {}
    M.activeWindow, M.drainTimer = nil, nil
    M.busy = false
    return self
end
-- Handle only keyboard events. Leave macOS symbolic hotkeys and gestures alone.
--- DesktopMove:start() -> self
--- Starts Ctrl+Shift+Left/Right by default. Set modifiers before starting.
function M:start()
    self:stop()
    local wanted = {}
    for _, modifier in ipairs(self.modifiers) do
        assert(modifier == "ctrl" or modifier == "shift" or modifier == "cmd" or modifier == "alt", "unsupported modifier")
        wanted[modifier] = true
    end
    assert(next(wanted), "at least one modifier is required")
    M.keyboard = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp}, function(event)
        local code = event:getKeyCode()
        if code ~= 123 and code ~= 124 then return false end
        if event:getType() == hs.eventtap.event.types.keyUp then
            if M.capturedKeys[code] then M.capturedKeys[code] = nil; return true end
            return false
        end
        local flags = event:getFlags()
        for _, modifier in ipairs({"ctrl", "shift", "cmd", "alt"}) do
            if (not not flags[modifier]) ~= (not not wanted[modifier]) then return false end
        end
        M.capturedKeys[code] = true
        if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 0 then
            M:move(code == 123 and -1 or 1)
        end
        return true
    end):start()
    if not M.keyboard:isEnabled() then
        report("키보드 감지가 시작되지 않았습니다. Hammerspoon의 손쉬운 사용 권한을 확인해 주세요.")
        return self
    end
    hs.alert.show("창 이동 준비됨: Ctrl+Shift+←/→", 2)
    log.i("Ready: Ctrl+Shift+Left/Right")
    return self
end

return M
