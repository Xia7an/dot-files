-- AeroSpace owns workspace membership and focus; Hammerspoon owns the overlay
-- and the entire key gesture. No window is moved or focused during selection.
local M = {}
local types = hs.eventtap.event.types
local keys = hs.keycodes.map
local directions = {
    [keys.h] = "left", [keys.j] = "down", [keys.k] = "up", [keys.l] = "right",
    [keys.left] = "left", [keys.down] = "down", [keys.up] = "up", [keys.right] = "right",
}
local log = hs.logger.new("aero-grid", "warning")

function M.start(options)
    options = options or {}
    local binary = options.aerospacePath
    if not binary then
        for _, path in ipairs({ "/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace" }) do
            if hs.fs.attributes(path, "mode") == "file" then binary = path; break end
        end
    end
    if not binary then
        hs.alert.show("Window Grid: aerospace が見つかりません")
        return nil
    end

    local controller = {}
    local session, tap, watchdog
    local swallowed, jobs = {}, {}
    local finish, draw, capture

    -- Keep tasks alive, bound their lifetime, and never block the event tap.
    local function run(arguments, callback)
        local job = {}
        jobs[job] = true
        local function complete(code, stdout, stderr)
            if not jobs[job] then return end
            jobs[job] = nil
            if job.timer then job.timer:stop() end
            callback(code, stdout, stderr)
        end
        job.task = hs.task.new(binary, complete, arguments)
        job.timer = hs.timer.doAfter(3, function()
            if job.task then job.task:terminate() end
            complete(-1, "", "aerospace timed out")
        end)
        if not job.task or not job.task:start() then complete(-1, "", "cannot start aerospace") end
        function job.cancel()
            jobs[job] = nil
            job.timer:stop()
            if job.task then job.task:terminate() end
        end
        return job
    end

    finish = function(commit)
        local s = session
        if not s then return end
        session = nil -- Invalidate pending callbacks before destroying the UI.
        if s.query then s.query.cancel() end
        if s.previewTimer then s.previewTimer:stop() end
        if s.canvas then s.canvas:delete() end
        if commit and s.windows and s.windows[s.selected] then
            run({ "focus", "--window-id", tostring(s.windows[s.selected]["window-id"]) },
                function(code, _, stderr)
                    if code ~= 0 then
                        log.w(stderr)
                        hs.alert.show("Window Grid: ウィンドウにフォーカスできませんでした")
                    end
                end)
        end
    end

    local function label(text, x, y, w, h, size, color)
        return { type = "text", text = text, frame = { x = x, y = y, w = w, h = h },
            textSize = size, textColor = color or { white = 0.95 },
            textLineBreak = "truncateTail", textFont = ".AppleSystemUIFont" }
    end

    draw = function(s)
        if session ~= s then return end
        local count = #s.windows
        local page = math.floor((s.selected - 1) / s.capacity)
        s.page = page
        local first = page * s.capacity + 1
        local last = math.min(count, first + s.capacity - 1)
        local width, height = s.width, s.height
        local elements = {
            { type = "rectangle", action = "fill", roundedRectRadii = { xRadius = 18, yRadius = 18 },
                fillColor = { white = 0.07, alpha = 0.97 }, frame = { x = 0, y = 0, w = width, h = height } },
            label("Workspace " .. s.windows[1].workspace .. "   ·   " .. count .. " windows",
                24, 16, width - 48, 28, 19),
            label("h j k l / ← ↓ ↑ →  移動",
                24, height - 54, width - 110, 24, 12, { white = 0.65 }),
            label((page + 1) .. "/" .. math.ceil(count / s.capacity),
                width - 78, height - 54, 60, 24, 12),
            label("⌥ を離すと確定 · Esc 取消",
                24, height - 30, width - 48, 24, 12, { white = 0.65 }),
        }
        for index = first, last do
            local window = s.windows[index]
            local offset = index - first
            local x = 20 + (offset % s.columns) * (s.cardWidth + 12)
            local y = 56 + math.floor(offset / s.columns) * (s.cardHeight + 12)
            local selected = index == s.selected
            elements[#elements + 1] = {
                type = "rectangle", action = "strokeAndFill", strokeWidth = selected and 3 or 1,
                strokeColor = selected and { red = 0.4, green = 0.7, blue = 1 } or { white = 0.24 },
                fillColor = { white = selected and 0.19 or 0.12 },
                roundedRectRadii = { xRadius = 10, yRadius = 10 },
                frame = { x = x, y = y, w = s.cardWidth, h = s.cardHeight },
            }
            local preview = s.previews[index]
            if preview then
                elements[#elements + 1] = { type = "image", image = preview,
                    imageScaling = "scaleProportionally",
                    frame = { x = x + 10, y = y + 10, w = s.cardWidth - 20, h = s.cardHeight - 70 } }
            else
                elements[#elements + 1] = label(window["app-name"], x + 14, y + 20,
                    s.cardWidth - 28, s.cardHeight - 80, 22, { white = 0.45 })
            end
            elements[#elements + 1] = label(window["app-name"], x + 12, y + s.cardHeight - 54,
                s.cardWidth - 24, 22, 13, { white = 0.65 })
            elements[#elements + 1] = label(window["window-title"], x + 12, y + s.cardHeight - 31,
                s.cardWidth - 24, 24, 14)
        end
        s.canvas:replaceElements(table.unpack(elements)):show()
    end

    -- Capture one visible card per run-loop turn, outside the keyboard callback.
    -- No Accessibility window enumeration, disk screenshots, or persistent cache.
    capture = function(s)
        if s.previewTimer then s.previewTimer:stop() end
        -- Preflight without prompting: a privacy dialog would steal focus while
        -- the gesture is held. Text cards remain usable without this permission.
        if not hs.screenRecordingState() then return end
        s.previewTimer = hs.timer.doAfter(0.01, function()
            if session ~= s then return end
            local first = s.page * s.capacity + 1
            for index = first, math.min(#s.windows, first + s.capacity - 1) do
                if s.previews[index] == nil then
                    local ok, preview = pcall(hs.window.snapshotForID, s.windows[index]["window-id"])
                    s.previews[index] = ok and preview or false
                    draw(s)
                    capture(s)
                    return
                end
            end
        end)
    end

    local function begin()
        local focused = hs.window.focusedWindow()
        local screen = focused and focused:screen() or hs.screen.mainScreen()
        local s = { selected = 1, previews = {}, frame = screen:frame(),
            focusedID = focused and focused:id() }
        session = s
        s.query = run({ "list-windows", "--workspace", "focused", "--json", "--format",
            "%{window-id}%{app-name}%{window-title}%{workspace}" }, function(code, stdout, stderr)
            if session ~= s then return end
            s.query = nil
            if code ~= 0 then
                finish(false)
                log.w(stderr)
                hs.alert.show("Window Grid: AeroSpace のウィンドウ一覧を取得できません")
                return
            end
            local ok, windows = pcall(hs.json.decode, stdout)
            if not ok or type(windows) ~= "table" then finish(false); return end
            s.windows = {}
            for _, window in ipairs(windows) do
                if type(window["window-id"]) == "number" and type(window.workspace) == "string" then
                    s.windows[#s.windows + 1] = window
                end
            end
            if #s.windows == 0 then finish(false); return end
            -- Stable ordering even when AeroSpace changes the traversal order.
            table.sort(s.windows, function(a, b) return a["window-id"] < b["window-id"] end)
            for index, window in ipairs(s.windows) do
                if window["window-id"] == s.focusedID then s.selected = index end
            end
            s.columns = math.min(#s.windows, 4, math.max(1, math.floor((s.frame.w - 60) / 250)))
            local rows = math.min(math.ceil(#s.windows / s.columns), 3,
                math.max(1, math.floor((s.frame.h - 140) / 190)))
            s.capacity = s.columns * rows
            s.cardWidth = math.min(300, (s.frame.w - 60) / s.columns - 12)
            s.cardHeight = math.min(220, (s.frame.h - 140) / rows - 12)
            s.width = 40 + s.columns * (s.cardWidth + 12) - 12
            s.height = 124 + rows * (s.cardHeight + 12) - 12
            s.canvas = hs.canvas.new({ x = s.frame.x + (s.frame.w - s.width) / 2,
                y = s.frame.y + (s.frame.h - s.height) / 2, w = s.width, h = s.height })
            s.canvas:level("overlay"):behaviorAsLabels({ "canJoinAllSpaces", "stationary" })
            draw(s)
            capture(s)
        end)
    end

    local function move(direction)
        local s = session
        if not s or not s.windows then return end
        local index, count = s.selected, #s.windows
        if direction == "left" then index = math.max(1, index - 1)
        elseif direction == "right" then index = math.min(count, index + 1)
        elseif direction == "up" then index = math.max(1, index - s.columns)
        elseif direction == "down" then index = math.min(count, index + s.columns) end
        s.selected = index
        draw(s)
        capture(s)
    end

    tap = hs.eventtap.new({ types.keyDown, types.keyUp, types.flagsChanged }, function(event)
        local kind, code, flags = event:getType(), event:getKeyCode(), event:getFlags()
        if kind == types.flagsChanged then
            if session and not flags.alt then finish(true) end
            return false -- Modifier changes must still reach the focused app.
        end
        if kind == types.keyUp then
            local handled = swallowed[code] == true
            swallowed[code] = nil
            return handled
        end
        if session then
            swallowed[code] = true
            if code == keys.escape then finish(false)
            elseif directions[code] then move(directions[code]) end
            return true -- Includes Tab autorepeat and unrelated workspace shortcuts.
        end
        -- Drain repeats/key-up after Option was released before Tab or hjkl.
        if swallowed[code] then return true end
        if code == keys.tab and flags.alt and not (flags.cmd or flags.ctrl or flags.shift or flags.fn) then
            swallowed[code] = true
            begin()
            return true
        end
        return false
    end):start()

    watchdog = hs.timer.doEvery(0.25, function()
        if hs.eventtap.isSecureInputEnabled() then
            finish(false)
            swallowed = {}
        elseif not tap:isEnabled() then
            finish(false)
            swallowed = {}
            tap:start()
        elseif session and not hs.eventtap.checkKeyboardModifiers().alt then
            finish(true)
        end
    end)

    function controller.stop()
        finish(false)
        tap:stop()
        watchdog:stop()
        local pending = {}
        for job in pairs(jobs) do pending[#pending + 1] = job end
        for _, job in ipairs(pending) do job.cancel() end
    end
    return controller
end

return M
