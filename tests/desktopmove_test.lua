-- Standalone Lua 5.4 tests. No actual macOS windows or settings are touched.
local originalLoadlib = package.loadlib
local passed = 0
local function check(value, message)
    assert(value, message)
end

local function fixture(options)
    options = options or {}
    local state = {membership = {10}, active = 10, moves = 0, alerts = {}, timers = {}, now = 0, mc = false}
    local window = {}
    function window:id() return 42 end
    function window:isStandard() return not options.nonstandard end
    function window:isFullScreen() return options.fullscreen end
    function window:focus()
        state.focused = self
        if not options.fallback then state.active = state.membership[1] end
    end
    local screen = {}
    function screen:getUUID() return "display" end
    function screen:id() return 1 end
    function screen:fullFrame() return {x = 0, y = 0, w = 100, h = 100} end
    local function element(attrs)
        return {attributeValue = function(_, key) return attrs[key] end}
    end
    local buttons = {}
    for _, id in ipairs({10, 99, 20, 30}) do
        local button = element({})
        function button:performAction()
            if options.pressError then return nil, "press failed" end
            state.active, state.mc = id, false
            return true
        end
        buttons[#buttons + 1] = button
    end
    local list = element({AXIdentifier = "mc.spaces.list", AXChildren = buttons})
    local spacesGroup = element({AXIdentifier = "mc.spaces", AXChildren = {list}})
    local display = element({AXIdentifier = "mc.display", AXDisplayID = 1, AXChildren = {spacesGroup}})
    local root = {attributeValue = function(_, key)
        if key == "AXChildren" then return state.mc and {display} or {} end
    end}
    local spaces = {
        windowSpaces = function() return state.membership end,
        spaceDisplay = function() return "display" end,
        spacesForScreen = function() return {10, 99, 20, 30} end,
        spaceType = function(id) return id == 99 and "fullscreen" or "user" end,
        activeSpaceOnScreen = function() return state.active end,
        toggleMissionControl = function() state.mc = not state.mc end,
    }
    package.loaded["hs.spaces"] = spaces
    package.loadlib = function(path, symbol)
        check(path == "/spoon/desktopmove_native.so", "module must load from Spoon directory")
        check(symbol == "luaopen_desktopmove_native", "wrong native entry point")
        if options.loadError then return nil, "load failed" end
        return function()
            return {
                available = function() return not options.unavailable end,
                move = function(_, target)
                    state.moves = state.moves + 1
                    if options.moveError then return nil, "move failed" end
                    if not options.pending then state.membership = {target} end
                    return true
                end,
            }
        end
    end
    hs = {
        spoons = {scriptPath = function() return "/spoon/" end},
        logger = {new = function() return {e = function() end, i = function() end} end},
        alert = {show = function(message) state.alerts[#state.alerts + 1] = message end},
        accessibilityState = function() return not options.noAccessibility end,
        window = {focusedWindow = function() return state.focused end},
        screen = {allScreens = function() return {screen} end},
        application = {get = function() return {} end},
        axuielement = {applicationElement = function() return root end},
        timer = {
            secondsSinceEpoch = function() return state.now end,
            doEvery = function(_, callback)
                local timer = {callback = callback, stopped = false}
                function timer:stop() self.stopped = true end
                state.timers[#state.timers + 1] = timer
                return timer
            end,
        },
        eventtap = {
            event = {types = {keyDown = 1, keyUp = 2}, properties = {keyboardEventAutorepeat = 1}},
            new = function(_, callback)
                local tap = {callback = callback}
                function tap:start() self.started = true; return self end
                function tap:stop() self.started = false end
                function tap:isEnabled() return self.started end
                return tap
            end,
        },
    }
    state.focused = window
    function state:tick(seconds)
        local deadline = self.now + seconds
        while self.now < deadline do
            self.now = math.min(deadline, self.now + 0.05)
            local pending = {table.unpack(self.timers)}
            for _, timer in ipairs(pending) do if not timer.stopped then timer.callback() end end
        end
    end
    function state:key(code, kind, flags, repeated)
        return {
            getKeyCode = function() return code end,
            getType = function() return kind end,
            getFlags = function() return flags or {ctrl = true, shift = true} end,
            getProperty = function() return repeated and 1 or 0 end,
        }
    end
    local spoon = dofile("Source/DesktopMove.spoon/init.lua")
    check(spoon.keyboard == nil, "loading a Spoon must not start keyboard handling")
    spoon:init()
    return spoon, state, window
end

local function test(name, run)
    run()
    passed = passed + 1
    print("ok - " .. name)
end

test("move right skips fullscreen Space and follows window", function()
    local spoon, state = fixture()
    spoon:move(1)
    state:tick(0.6)
    check(state.moves == 1 and state.active == 20, "wrong target")
    check(spoon.lastResult.complete and not spoon.busy, "move did not complete")
end)

test("move left uses window membership and explicit window", function()
    local spoon, state, window = fixture()
    state.membership, state.focused = {20}, nil
    spoon:move(-1, window)
    state:tick(0.6)
    check(state.active == 10 and spoon.lastResult.complete, "left move failed")
end)

test("desktop boundaries do not wrap", function()
    local spoon, state = fixture()
    spoon:move(-1)
    state.membership = {30}
    spoon:move(1)
    check(state.moves == 0 and #state.alerts == 2, "boundary should alert")
end)

test("reject unsupported windows and missing permissions or module", function()
    for _, options in ipairs({{nonstandard = true}, {fullscreen = true}, {noAccessibility = true},
        {loadError = true}, {unavailable = true}}) do
        local spoon, state = fixture(options)
        spoon:move(1)
        check(state.moves == 0 and #state.alerts == 1 and not spoon.busy, "invalid move was accepted")
    end
    local spoon, state = fixture()
    state.membership = {10, 20}
    spoon:move(1)
    state.membership = {}
    spoon:move(1)
    state.focused = nil
    spoon:move(1)
    check(state.moves == 0 and #state.alerts == 3, "pinned or missing window accepted")
end)

test("invalid directions are rejected", function()
    local spoon = fixture()
    check(not pcall(function() spoon:move(0) end), "zero direction accepted")
    check(not pcall(function() spoon:move(2) end), "invalid direction accepted")
end)

test("native submission failure clears busy state", function()
    local spoon, state = fixture({moveError = true})
    spoon:move(1)
    check(not spoon.busy and not spoon.lastResult.complete and #state.alerts == 1, "failure stuck")
end)

test("pending move blocks reentry and times out", function()
    local spoon, state = fixture({pending = true})
    spoon:move(1)
    spoon:move(1)
    check(spoon.busy and state.moves == 1, "reentrant move")
    state:tick(4)
    check(not spoon.busy and not spoon.lastResult.complete and #state.alerts == 1, "timeout stuck")
    check(next(spoon.timers) == nil, "timeout leaked timer")
end)

test("Mission Control fallback selects correct desktop including fullscreen index", function()
    local spoon, state = fixture({fallback = true})
    spoon:move(1)
    state:tick(2)
    check(state.active == 20 and not state.mc and spoon.lastResult.complete, "fallback failed")
end)

test("arrow presses during a transition queue for the same window", function()
    local spoon, state, window = fixture()
    spoon:move(1)
    spoon:move(1)
    check(state.moves == 1 and #spoon.pending == 1, "second key press was not queued")
    state:tick(2)
    check(state.moves == 2 and state.membership[1] == 30 and spoon.lastResult.complete,
        "queued move did not complete for the same window")
end)

test("Mission Control press failure leaves move incomplete and closes UI", function()
    local spoon, state = fixture({fallback = true, pressError = true})
    spoon:move(1)
    state:tick(2)
    check(not state.mc and not spoon.busy and not spoon.lastResult.complete, "fallback failure stuck")
    check(state.membership[1] == 20 and #state.alerts == 1, "moved window should remain at target")
end)

test("keyboard handles only configured keys and ignores repeat", function()
    local spoon, state = fixture()
    spoon:start()
    local callback = spoon.keyboard.callback
    check(not callback(state:key(0, 1)), "unrelated key swallowed")
    check(not callback(state:key(124, 1, {ctrl = true})), "wrong modifiers swallowed")
    check(not callback(state:key(124, 1, {ctrl = true, shift = true, cmd = true})), "extra modifier swallowed")
    check(not callback(state:key(124, 2)), "unhandled keyup swallowed")
    check(callback(state:key(124, 1)), "shortcut not captured")
    check(callback(state:key(124, 1, nil, true)) and state.moves == 1, "repeat moved window")
    check(callback(state:key(124, 2, {})), "captured keyup should be swallowed even after modifier release")
    check(not callback(state:key(124, 2)), "keyup should only be swallowed once")
end)

test("start replaces event tap and supports custom modifiers", function()
    local spoon, state = fixture()
    spoon:start()
    local old = spoon.keyboard
    spoon.modifiers = {"cmd", "alt"}
    spoon:start()
    check(not old.started and spoon.keyboard.started, "duplicate tap")
    check(not spoon.keyboard.callback(state:key(124, 1)), "old modifiers captured")
    check(spoon.keyboard.callback(state:key(124, 1, {cmd = true, alt = true})), "custom modifiers failed")
end)

test("stop cancels pending timers and releases keyboard state", function()
    local spoon, state = fixture({pending = true})
    spoon:start()
    spoon.keyboard.callback(state:key(124, 1))
    check(spoon.busy, "expected pending move")
    spoon:stop()
    state:tick(5)
    check(not spoon.keyboard.started and not spoon.busy, "stop failed")
    check(next(spoon.timers) == nil and next(spoon.capturedKeys) == nil, "state leaked")
    check(#state.alerts == 1 and not spoon.lastResult.complete, "stop produced an unexpected alert or ran a cancelled callback")
end)

package.loadlib = originalLoadlib
print(string.format("%d tests passed", passed))
