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
        local row = s.rows and s.rows[s.selectedRow]
        local window = row and row.windows[row.selected]
        if commit and window then
            run({ "focus", "--window-id", tostring(window["window-id"]) },
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

    -- Each workspace owns its horizontal viewport and selection. Vertical
    -- navigation never changes another row's horizontal position.
    local function reveal(s)
        s.firstRow = math.max(s.selectedRow - s.visibleRows + 1, math.min(s.firstRow, s.selectedRow))
        local row = s.rows[s.selectedRow]
        row.first = math.max(row.selected - s.columns + 1, math.min(row.first, row.selected))
    end

    local function visibleWindows(s, visit)
        for rowIndex = s.firstRow, math.min(#s.rows, s.firstRow + s.visibleRows - 1) do
            local row = s.rows[rowIndex]
            for index = row.first, math.min(#row.windows, row.first + s.columns - 1) do
                if visit(row.windows[index], rowIndex, index, row) then return end
            end
        end
    end

    draw = function(s)
        if session ~= s then return end
        local lastRow = math.min(#s.rows, s.firstRow + s.visibleRows - 1)
        local width, height = s.width, s.height
        local elements = {
            { type = "rectangle", action = "fill", roundedRectRadii = { xRadius = 18, yRadius = 18 },
                fillColor = { white = 0.07, alpha = 0.97 }, frame = { x = 0, y = 0, w = width, h = height } },
            label("Windows   ·   " .. s.windowCount .. " windows / " .. #s.rows .. " workspaces",
                24, 16, width - 48, 28, 19),
            label("h l  ウィンドウ    j k  ワークスペース",
                24, height - 54, width - 48, 24, 12, { white = 0.65 }),
            label("⌥ を離すと確定 · Esc 取消",
                24, height - 30, width - 48, 24, 12, { white = 0.65 }),
        }
        elements[#elements + 1] = label(
            (s.firstRow > 1 and "↑ " or "") .. s.firstRow .. "–" .. lastRow .. " / " .. #s.rows
                .. (lastRow < #s.rows and " ↓" or ""),
            width - 150, height - 30, 126, 24, 12, { white = 0.65 })
        for rowIndex = s.firstRow, lastRow do
            local row = s.rows[rowIndex]
            local y = 56 + (rowIndex - s.firstRow) * s.rowHeight
            local last = math.min(#row.windows, row.first + s.columns - 1)
            local color = rowIndex == s.selectedRow and { red = 0.4, green = 0.7, blue = 1 }
                or { white = 0.65 }
            local name = label(row.name, 20, y + 12, 80, 26, 18, color)
            name.id = "workspace-" .. rowIndex
            elements[#elements + 1] = name
            elements[#elements + 1] = label(row.first .. "–" .. last .. "/" .. #row.windows,
                20, y + 40, 80, 22, 11, color)
            elements[#elements + 1] = label(
                (row.first > 1 and "← " or "") .. (last < #row.windows and "→" or ""),
                20, y + 62, 80, 22, 14, color)
        end
        visibleWindows(s, function(window, rowIndex, index, row)
            local x = 112 + (index - row.first) * (s.cardWidth + 12)
            local y = 56 + (rowIndex - s.firstRow) * s.rowHeight
            local selected = rowIndex == s.selectedRow and index == row.selected
            elements[#elements + 1] = {
                id = "window-" .. window["window-id"],
                type = "rectangle", action = "strokeAndFill", strokeWidth = selected and 3 or 1,
                strokeColor = selected and { red = 0.4, green = 0.7, blue = 1 } or { white = 0.24 },
                fillColor = { white = selected and 0.19 or 0.12 },
                roundedRectRadii = { xRadius = 10, yRadius = 10 },
                frame = { x = x, y = y, w = s.cardWidth, h = s.cardHeight },
            }
            local preview = s.previews[window["window-id"]]
            if preview then
                elements[#elements + 1] = { type = "image", image = preview,
                    imageScaling = "scaleProportionally",
                    frame = { x = x + 8, y = y + 6, w = s.cardWidth - 16, h = s.cardHeight - 48 } }
            else
                elements[#elements + 1] = label(window["app-name"], x + 12, y + 6,
                    s.cardWidth - 24, math.max(0, s.cardHeight - 48), 18, { white = 0.45 })
            end
            elements[#elements + 1] = label(window["app-name"], x + 10, y + s.cardHeight - 40,
                s.cardWidth - 20, 18, 11, { white = 0.65 })
            elements[#elements + 1] = label(window["window-title"], x + 10, y + s.cardHeight - 23,
                s.cardWidth - 20, 20, 12)
        end)
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
            visibleWindows(s, function(window)
                local id = window["window-id"]
                if s.previews[id] == nil then
                    local ok, preview = pcall(hs.window.snapshotForID, id)
                    s.previews[id] = ok and preview or false
                    draw(s)
                    capture(s)
                    return true
                end
            end)
        end)
    end

    local function begin()
        local focused = hs.window.focusedWindow()
        local screen = focused and focused:screen() or hs.screen.mainScreen()
        local s = { selectedRow = 1, firstRow = 1, previews = {}, frame = screen:frame(),
            focusedID = focused and focused:id() }
        session = s
        s.query = run({ "list-windows", "--all", "--json", "--format",
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
            s.rows, s.windowCount = {}, 0
            local byWorkspace, seen = {}, {}
            for _, window in ipairs(windows) do
                local id, name = window["window-id"], window.workspace
                if type(id) == "number" and type(name) == "string" and not seen[id] then
                    seen[id] = true
                    if not byWorkspace[name] then
                        local row = { name = name, windows = {}, selected = 1, first = 1 }
                        byWorkspace[name] = row
                        s.rows[#s.rows + 1] = row
                    end
                    local row = byWorkspace[name]
                    row.windows[#row.windows + 1] = window
                    s.windowCount = s.windowCount + 1
                end
            end
            if #s.rows == 0 then finish(false); return end
            -- Numeric workspace names precede named workspaces, with 2 before 10.
            table.sort(s.rows, function(a, b)
                local an, bn = tonumber(a.name), tonumber(b.name)
                if an and bn and an ~= bn then return an < bn end
                if (an ~= nil) ~= (bn ~= nil) then return an ~= nil end
                return a.name < b.name
            end)
            local maxWindows = 1
            for rowIndex, row in ipairs(s.rows) do
                table.sort(row.windows, function(a, b) return a["window-id"] < b["window-id"] end)
                maxWindows = math.max(maxWindows, #row.windows)
                for index, window in ipairs(row.windows) do
                    if window["window-id"] == s.focusedID then
                        s.selectedRow, row.selected = rowIndex, index
                    end
                end
            end
            s.columns = math.min(maxWindows, 4)
            s.visibleRows = math.min(#s.rows, 6)
            s.cardWidth = math.min(300, (s.frame.w - 180) / s.columns - 12)
            s.rowHeight = math.min(232, (s.frame.h - 164) / s.visibleRows)
            s.cardHeight = s.rowHeight - 12
            s.width = 132 + s.columns * (s.cardWidth + 12) - 12
            s.height = 124 + s.visibleRows * s.rowHeight - 12
            reveal(s)
            s.canvas = hs.canvas.new({ x = s.frame.x + (s.frame.w - s.width) / 2,
                y = s.frame.y + (s.frame.h - s.height) / 2, w = s.width, h = s.height })
            s.canvas:level("overlay"):behaviorAsLabels({ "canJoinAllSpaces", "stationary" })
            draw(s)
            capture(s)
        end)
    end

    local function move(direction)
        local s = session
        if not s or not s.rows then return end
        local row = s.rows[s.selectedRow]
        if direction == "left" then row.selected = math.max(1, row.selected - 1)
        elseif direction == "right" then row.selected = math.min(#row.windows, row.selected + 1)
        elseif direction == "up" then s.selectedRow = math.max(1, s.selectedRow - 1)
        elseif direction == "down" then s.selectedRow = math.min(#s.rows, s.selectedRow + 1) end
        reveal(s)
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
