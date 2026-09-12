-- Run from the repository root with Lua 5.4. No macOS permissions required.
local tasks, timers, canvases, alerts = {}, {}, {}, {}
local eventTap, decoded, modifiers, secure, failStart
local focusedID = 3
local key = { tab = 48, h = 4, j = 38, k = 40, l = 37, escape = 53,
    left = 123, right = 124, down = 125, up = 126, a = 0 }
hs = {
    screenRecordingState = function() return true end,
    keycodes = { map = key },
    fs = { attributes = function() return "file" end },
    logger = { new = function() return { w = function() end } end },
    alert = { show = function(message) alerts[#alerts + 1] = message end },
    json = { decode = function(value)
        if value == "invalid" then error("invalid JSON") end
        return decoded
    end },
    screen = { mainScreen = function() return { frame = function()
        return { x = -1600, y = 0, w = 1600, h = 1000 }
    end } end },
    window = {
        focusedWindow = function()
            if not focusedID then return nil end
            return { id = function() return focusedID end,
                screen = function() return hs.screen.mainScreen() end }
        end,
        snapshotForID = function() return nil end, -- Denied screen recording.
    },
}
hs.timer = {}
local function timer(callback)
    local t = { callback = callback, stopped = false }
    function t:stop() self.stopped = true end
    timers[#timers + 1] = t
    return t
end
hs.timer.doAfter = function(_, callback) return timer(callback) end
hs.timer.doEvery = function(_, callback) return timer(callback) end
hs.task = { new = function(_, callback, arguments)
    local t = { callback = callback, arguments = arguments }
    function t:start() return not failStart and self end
    function t:terminate() self.terminated = true end
    tasks[#tasks + 1] = t
    return t
end }
hs.canvas = { new = function(frame)
    local c = { frame = frame }
    function c:level() return self end
    function c:behaviorAsLabels() return self end
    function c:replaceElements(...) self.elements = { ... }; return self end
    function c:show() self.visible = true; return self end
    function c:delete() self.visible = false; self.deleted = true end
    canvases[#canvases + 1] = c
    return c
end }
hs.eventtap = {
    event = { types = { keyDown = 1, keyUp = 2, flagsChanged = 3 } },
    new = function(_, callback)
        eventTap = { callback = callback }
        function eventTap:start() self.enabled = true; return self end
        function eventTap:stop() self.enabled = false end
        function eventTap:isEnabled() return self.enabled end
        return eventTap
    end,
    checkKeyboardModifiers = function() return modifiers end,
    isSecureInputEnabled = function() return secure end,
}
local grid = dofile("config/hammerspoon/aerospace-window-grid.lua")
local function event(kind, code, flags)
    modifiers = flags or { alt = true }
    return eventTap.callback({
        getType = function() return hs.eventtap.event.types[kind] end,
        getKeyCode = function() return key[code] or 0 end,
        getFlags = function() return modifiers end,
    })
end
local function down(code, flags) return event("keyDown", code, flags) end
local function up(code, flags) return event("keyUp", code, flags) end
local function reply(task, count, status, stdout)
    decoded = {}
    for id = count or 1, 1, -1 do
        decoded[#decoded + 1] = { ["window-id"] = id, ["app-name"] = "App",
            ["window-title"] = "日本語 title " .. id, workspace = "W" }
    end
    task.callback(status or 0, stdout or "json", "error")
end
local function start()
    modifiers, secure, failStart = { alt = true }, false, false
    tasks, timers, canvases, alerts = {}, {}, {}, {}
    focusedID = 3
    return grid.start()
end
local function query()
    assert(down("tab"))
    local t = tasks[#tasks]
    assert(t.arguments[1] == "list-windows" and t.arguments[3] == "focused")
    return t
end
local function focusIs(id)
    local t = tasks[#tasks]
    assert(t.arguments[1] == "focus" and t.arguments[3] == tostring(id))
end

local c = start()
assert(not down("a", {}))
assert(not down("tab", { cmd = true }))
assert(not down("tab", { alt = true, shift = true }))
reply(query(), 8)
assert(canvases[1].visible and canvases[1].frame.x < 0)
assert(down("tab")) -- Autorepeat must not start another query.
assert(#tasks == 1)
down("j"); up("j") -- 3 -> 7
down("h"); up("h") -- 7 -> 6
down("k"); up("k") -- 6 -> 2
down("l") -- 2 -> 3; leave held across confirmation.
assert(up("tab"))
assert(canvases[1].visible and #tasks == 1) -- Tab release must not commit.
event("flagsChanged", nil, {})
focusIs(3)
assert(canvases[1].deleted)
assert(down("l") and up("l")) -- Drain repeat and key-up.
assert(not down("l", {}))
c.stop()

c = start()
reply(query(), 8)
down("h"); up("h")
event("flagsChanged", nil, {})
focusIs(2)
assert(down("tab", {}) and up("tab", {}))
assert(#tasks == 2)
c.stop()

c = start()
local stale = query()
up("tab")
event("flagsChanged", nil, {}) -- Option release before list completion cancels.
reply(stale, 8)
assert(#tasks == 1 and #canvases == 0)
local old = query()
down("escape"); up("escape"); up("tab")
local current = query()
reply(old, 8)
assert(#canvases == 0)
reply(current, 8)
down("escape"); up("escape"); up("tab")
assert(canvases[1].deleted and #tasks == 3)
c.stop()

c = start()
local pending = query()
assert(up("tab")) -- Even before the list arrives, Tab release keeps it open.
reply(pending, 8)
assert(canvases[1].visible and #tasks == 1)
down("h"); up("h") -- Navigation remains active with only Option held.
assert(down("tab") and up("tab")) -- Re-tapping Tab must not restart or confirm.
assert(canvases[1].visible and #tasks == 1)
event("flagsChanged", nil, {})
focusIs(2)
c.stop()

c = start()
reply(query(), 27)
for _ = 1, 25 do down("l"); up("l") end
assert(canvases[1].elements[4].text == "3/3")
down("j"); up("j"); up("tab")
event("flagsChanged", nil, {})
focusIs(27) -- Incomplete last row and page boundary.
c.stop()

for _, failure in ipairs({ "empty", "invalid", "offline", "timeout", "start" }) do
    c = start()
    if failure == "start" then failStart = true end
    local t = query()
    if failure == "empty" then reply(t, 0)
    elseif failure == "invalid" then reply(t, 1, 0, "invalid")
    elseif failure == "offline" then reply(t, 1, 1)
    elseif failure == "timeout" then timers[#timers].callback() end
    up("tab")
    assert(#canvases == 0 and #tasks == 1, failure)
    c.stop()
end

c = start()
focusedID = nil
reply(query(), 1)
timers[#timers].callback() -- Nil snapshot still leaves a selectable card.
up("tab")
event("flagsChanged", nil, {})
focusIs(1)
c.stop()

c = start()
reply(query(), 8)
secure = true
timers[1].callback() -- Secure Input cancels; no delayed focus.
assert(canvases[1].deleted and #tasks == 1)
c.stop()

c = start()
reply(query(), 8)
eventTap.enabled = false
timers[1].callback()
assert(canvases[1].deleted and eventTap.enabled and #tasks == 1)
c.stop()
assert(not eventTap.enabled)

c = start()
hs.screenRecordingState = function() return false end
reply(query(), 1)
assert(canvases[1].visible)
up("tab")
event("flagsChanged", nil, {})
focusIs(1)
c.stop()
print("aerospace-window-grid: all tests passed")
