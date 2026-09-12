-- Run from the repository root with Lua 5.4. No macOS permissions required.
local tasks, timers, canvases, alerts = {}, {}, {}, {}
local eventTap, decoded, modifiers, secure, failStart
local focusedID = 3
local screenFrame = { x = -1600, y = 0, w = 1600, h = 1000 }
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
        return screenFrame
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
    assert(t.arguments[1] == "list-windows" and t.arguments[2] == "--all")
    return t
end
local function focusIs(id)
    local t = tasks[#tasks]
    assert(t.arguments[1] == "focus" and t.arguments[3] == tostring(id))
end

local function visibleCards()
    local result = {}
    for _, element in ipairs(canvases[#canvases].elements) do
        if element.id and element.id:match("^window%-") then
            result[tonumber(element.id:match("%d+$"))] = element
        end
    end
    return result
end

local function selectedID()
    for id, element in pairs(visibleCards()) do
        if element.strokeWidth == 3 then return id end
    end
    error("no selected visible card")
end

local c = start()
assert(not down("a", {}))
assert(not down("tab", { cmd = true }))
assert(not down("tab", { alt = true, shift = true }))
reply(query(), 8)
assert(canvases[1].visible and canvases[1].frame.x < 0)
assert(down("tab")) -- Autorepeat must not start another query.
assert(#tasks == 1)
down("j"); up("j") -- One workspace: down stays in the same row.
down("h"); up("h") -- 3 -> 2
down("k"); up("k") -- One workspace: up stays in the same row.
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
local cards = visibleCards()
assert(cards[24] and cards[27] and not cards[23])
down("j"); up("j"); up("tab")
event("flagsChanged", nil, {})
focusIs(27) -- End of a horizontally scrolled workspace; no row wrapping.
c.stop()

-- Eight nonempty workspaces, each with six windows; no rows for empty 8 or 9.
local function manyWorkspaces(task)
    decoded = {}
    for _, name in ipairs({ "10", "7", "6", "5", "4", "3", "2", "1" }) do
        for index = 6, 1, -1 do
            local id = tonumber(name) * 100 + index
            decoded[#decoded + 1] = { ["window-id"] = id, ["app-name"] = "App " .. name,
                ["window-title"] = "Window " .. id, workspace = name }
        end
    end
    task.callback(0, "json", "")
end

c = start()
focusedID = 103
manyWorkspaces(query())
cards = visibleCards()
local count = 0
for _ in pairs(cards) do count = count + 1 end
assert(count == 24 and cards[101] and cards[604] and not cards[105] and not cards[701])
assert(selectedID() == 103)
local otherX, otherY = cards[201].frame.x, cards[201].frame.y
for _ = 1, 3 do down("l"); up("l") end
cards = visibleCards()
assert(selectedID() == 106 and cards[103] and not cards[102])
assert(cards[201].frame.x == otherX and cards[201].frame.y == otherY and not cards[205])
down("j"); up("j")
assert(selectedID() == 201) -- Enter another row at its own remembered selection.
for _ = 1, 4 do down("l"); up("l") end
cards = visibleCards()
assert(selectedID() == 205 and cards[202] and not cards[201])
assert(cards[103] and cards[106] and not cards[102])
down("k"); up("k")
assert(selectedID() == 106)
for _ = 1, 6 do down("j"); up("j") end
cards = visibleCards()
assert(selectedID() == 701 and not cards[103] and cards[202] and cards[704])
down("j"); up("j")
cards = visibleCards()
assert(selectedID() == 1001 and cards[301] and not cards[202] and cards[1004])
down("j"); up("j") -- Last workspace clamps.
assert(selectedID() == 1001)
for _ = 1, 7 do down("k"); up("k") end
cards = visibleCards()
assert(selectedID() == 106 and cards[103] and cards[202]) -- Scroll positions survive offscreen.
down("j"); up("j")
assert(selectedID() == 205)
assert(#tasks == 1) -- Selection never changes actual workspace/focus.
up("tab")
assert(#tasks == 1)
event("flagsChanged", nil, {})
focusIs(205) -- Cross-workspace commit still targets exactly the selected window.
assert(#tasks == 2)
c.stop()

c = start()
focusedID = 1006
manyWorkspaces(query())
cards = visibleCards()
assert(selectedID() == 1006 and cards[1003] and cards[301] and not cards[201])
down("escape"); up("escape"); up("tab")
assert(#tasks == 1 and canvases[1].deleted) -- Cancel from another workspace's row.
c.stop()

-- Unequal row lengths must neither create empty cards nor flatten into a row.
c = start()
focusedID = nil
local mixed = query()
decoded = {
    { ["window-id"] = 1, ["app-name"] = "A", ["window-title"] = "One", workspace = "A" },
    { ["window-id"] = 2, ["app-name"] = "B", ["window-title"] = "Two", workspace = "B" },
    { ["window-id"] = 3, ["app-name"] = "B", ["window-title"] = "Three", workspace = "B" },
}
mixed.callback(0, "json", "")
down("l"); up("l")
assert(selectedID() == 1)
down("j"); up("j"); down("l"); up("l")
assert(selectedID() == 3)
down("k"); up("k")
assert(selectedID() == 1)
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
