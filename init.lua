-- Hammerspoon Configuration: Full & Stable

-- ============================================================================
-- RELOAD CONFIGURATION
-- ============================================================================
hs.hotkey.bind({"cmd", "alt"}, "r", function()
    hs.alert.show("Reloading Hammerspoon Config...")
    hs.reload()
end)

-- ============================================================================
-- WINDOW NAVIGATION & MANAGEMENT (Enhanced Geometric Tiling)
-- ============================================================================

-- Forward-declare autoTileCurrentSpace so it can be used by functions defined before it.
local autoTileCurrentSpace

-- Helper function to get all manageable windows on a given screen
local function getWindowsOnScreen(screen)
    local windowsOnScreen = {}
    for _, win in ipairs(hs.window.allWindows()) do
        if win:screen() == screen and not win:isMinimized() and win:title() ~= "" then
            table.insert(windowsOnScreen, win)
        end
    end
    return windowsOnScreen
end

-- Geometric focus function (with fallback for windowless apps)
local function focus(direction)
    return function()
        local currentWin = hs.window.focusedWindow()

        if not currentWin then
            local screen = hs.mouse.getCurrentScreen()
            local windowsOnScreen = getWindowsOnScreen(screen)
            if #windowsOnScreen > 0 then
                windowsOnScreen[1]:focus()
            end
            return
        end

        local screen = currentWin:screen()
        local currentFrame = currentWin:frame()
        local candidates = {}

        for _, win in ipairs(getWindowsOnScreen(screen)) do
            if win:id() ~= currentWin:id() then
                local frame = win:frame()
                local isCandidate = false
                if direction == "west" and frame.x < currentFrame.x then isCandidate = true
                elseif direction == "east" and frame.x > currentFrame.x then isCandidate = true
                elseif direction == "north" and frame.y < currentFrame.y then isCandidate = true
                elseif direction == "south" and frame.y > currentFrame.y then isCandidate = true
                end
                if isCandidate then table.insert(candidates, win) end
            end
        end

        if #candidates == 0 then return end

        local bestCandidate = nil
        local minDistance = math.huge

        for _, win in ipairs(candidates) do
            local frame = win:frame()
            local dx = (frame.x + frame.w/2) - (currentFrame.x + currentFrame.w/2)
            local dy = (frame.y + frame.h/2) - (currentFrame.y + currentFrame.h/2)
            local dist = dx*dx + dy*dy

            if dist < minDistance then
                minDistance = dist
                bestCandidate = win
            end
        end

        if bestCandidate then bestCandidate:focus() end
    end
end

hs.hotkey.bind({"cmd"}, "left", focus("west"))
hs.hotkey.bind({"cmd"}, "right", focus("east"))
hs.hotkey.bind({"cmd"}, "up", focus("north"))
hs.hotkey.bind({"cmd"}, "down", focus("south"))

-- Geometric position swapping
-- Enhanced geometric position swapping with auto-tiling
local function smartSwap(direction)
    return function()
        local currentWin = hs.window.focusedWindow()
        if not currentWin then return end

        local screen = currentWin:screen()
        local currentFrame = currentWin:frame()
        local candidates = {}

        -- Find all windows in the given direction
        for _, win in ipairs(getWindowsOnScreen(screen)) do
            if win:id() ~= currentWin:id() then
                local frame = win:frame()
                local isCandidate = false
                if direction == "west" and frame.x < currentFrame.x then isCandidate = true
                elseif direction == "east" and frame.x > currentFrame.x then isCandidate = true
                elseif direction == "north" and frame.y < currentFrame.y then isCandidate = true
                elseif direction == "south" and frame.y > currentFrame.y then isCandidate = true
                end
                if isCandidate then table.insert(candidates, win) end
            end
        end

        if #candidates == 0 then return end

        -- Find the closest candidate
        local bestCandidate = nil
        local minDistance = math.huge
        for _, win in ipairs(candidates) do
            local frame = win:frame()
            local dx = (frame.x + frame.w/2) - (currentFrame.x + currentFrame.w/2)
            local dy = (frame.y + frame.h/2) - (currentFrame.y + currentFrame.h/2)
            local dist = dx*dx + dy*dy
            if dist < minDistance then
                minDistance = dist
                bestCandidate = win
            end
        end

        -- Swap frames with the best candidate and then re-tile the whole space
        if bestCandidate then
            local targetFrame = bestCandidate:frame()
            bestCandidate:setFrame(currentFrame)
            currentWin:setFrame(targetFrame)

            -- Use a timer to ensure the swap is registered before tiling
            hs.timer.doAfter(0.1, function()
                autoTileCurrentSpace()
                currentWin:focus()
            end)
        end
    end
end

-- Tiling shortcuts
hs.hotkey.bind({"cmd", "shift"}, "left", smartSwap("west"))
hs.hotkey.bind({"cmd", "shift"}, "right", smartSwap("east"))
hs.hotkey.bind({"cmd", "shift"}, "up", smartSwap("north"))
hs.hotkey.bind({"cmd", "shift"}, "down", smartSwap("south"))

-- ============================================================================
-- MAIN PANE RESIZING
-- ============================================================================
local mainPaneFactor = 0.5 -- Start with a 50% split

local function adjustMainPane(direction)
    -- Adjust the main pane factor
    if direction == "expand" then
        mainPaneFactor = mainPaneFactor + 0.05
    elseif direction == "shrink" then
        mainPaneFactor = mainPaneFactor - 0.05
    end

    -- Clamp the value between 25% and 75%
    mainPaneFactor = math.max(0.25, math.min(0.75, mainPaneFactor))

    -- Identify windows
    local mainWin = hs.window.focusedWindow()
    if not mainWin then return end

    local screen = mainWin:screen()
    local screenFrame = screen:frame()
    local secondaryWindows = {}
    for _, win in ipairs(getWindowsOnScreen(screen)) do
        if win:id() ~= mainWin:id() then
            table.insert(secondaryWindows, win)
        end
    end

    -- Apply the new layout
    -- Main window on the left
    mainWin:setFrame({
        x = screenFrame.x,
        y = screenFrame.y,
        w = screenFrame.w * mainPaneFactor,
        h = screenFrame.h
    })

    -- Secondary windows stacked on the right
    if #secondaryWindows > 0 then
        local secondaryX = screenFrame.x + (screenFrame.w * mainPaneFactor)
        local secondaryW = screenFrame.w * (1 - mainPaneFactor)
        local secondaryH = screenFrame.h / #secondaryWindows

        for i, win in ipairs(secondaryWindows) do
            win:setFrame({
                x = secondaryX,
                y = screenFrame.y + (secondaryH * (i - 1)),
                w = secondaryW,
                h = secondaryH
            })
        end
    end
    hs.alert.show("Windows Organized")
end

hs.hotkey.bind({"cmd", "shift"}, "=", function() adjustMainPane("expand") end)
hs.hotkey.bind({"cmd", "shift"}, "-", function() adjustMainPane("shrink") end)


-- ============================================================================
-- AUTOMATIC LAYOUT MANAGEMENT
-- ============================================================================

-- This function is called whenever the number of windows on a screen changes.
local function handleWindowChange(win)
    -- The `win` object can sometimes be invalid on destroy, so we get the screen from the mouse.
    local screen = hs.mouse.getCurrentScreen()
    if not screen then return end

    -- Use a timer to wait for the window list to be accurate
    hs.timer.doAfter(0.2, function()
        autoTileCurrentSpace()
    end)
end

-- Create a watcher for window events
local windowWatcher = hs.window.filter.new()
windowWatcher:subscribe(hs.window.filter.windowCreated, handleWindowChange)
windowWatcher:subscribe(hs.window.filter.windowDestroyed, handleWindowChange)
windowWatcher:subscribe(hs.window.filter.windowMinimized, handleWindowChange)

-- Close window
hs.hotkey.bind({"cmd"}, "w", function()
    local win = hs.window.focusedWindow()
    if win then win:close() end
end)

-- Minimize window
hs.hotkey.bind({"cmd", "shift"}, "s", function()
    local win = hs.window.focusedWindow()
    if win then win:minimize() end
end)

-- Fast restore minimized windows (Cmd + Shift + U for "unminimize")
hs.hotkey.bind({"cmd", "shift"}, "u", function()
    local minimizedWindows = {}
    for _, win in ipairs(hs.window.allWindows()) do
        if win:isMinimized() then
            table.insert(minimizedWindows, {
                window = win,
                title = win:title() or "Untitled",
                app = win:application():name() or "Unknown"
            })
        end
    end

    if #minimizedWindows == 0 then
        hs.alert.show("No minimized windows")
        return
    end

    if #minimizedWindows == 1 then
        minimizedWindows[1].window:unminimize()
        minimizedWindows[1].window:focus()
    else
        local choices = {}
        for _, winInfo in ipairs(minimizedWindows) do
            table.insert(choices, {
                text = winInfo.app .. ": " .. winInfo.title,
                subText = "Enter to restore",
                window = winInfo.window
            })
        end
        local chooser = hs.chooser.new(function(choice)
            if choice then
                choice.window:unminimize()
                choice.window:focus()
            end
        end)
        chooser:choices(choices)
        chooser:show()
    end
end)

-- Toggle fullscreen
hs.hotkey.bind({"cmd"}, "f11", function()
    local win = hs.window.focusedWindow()
    if win then win:toggleFullScreen() end
end)

-- ============================================================================
-- APPLICATION & WEB SHORTCUTS
-- ============================================================================
local apps = {
    a = "Mail",
    s = "Notes",
    c = "FaceTime",
    i = "Terminal",
    b = "Google Chrome",
    n = "Cursor",
    t = "TradingView",
    m = "Spotify",
    d = "Docker Desktop",
    o = "Notion",
    g = "Messages",
    f = "Finder",
    [","] = "System Settings",
    ["return"] = "iTerm"
}

for key, appName in pairs(apps) do
    hs.hotkey.bind({"cmd"}, key, function()
        hs.application.launchOrFocus(appName)
    end)
end

-- Shortcut to open a new iTerm window
hs.hotkey.bind({"cmd", "shift"}, "return", function()
    hs.osascript.applescript('tell application "iTerm" to create window with default profile')
end)

hs.hotkey.bind({"cmd", "alt"}, "t", function() hs.application.launchOrFocus("TextEdit") end)

hs.hotkey.bind({"cmd", "shift"}, "b", function()
    local originalScreen = hs.mouse.getCurrentScreen()
    local chrome = hs.application.find("Google Chrome")
    if not chrome then
        hs.application.launchOrFocus("Google Chrome")
        return
    end
    local existingWindowIDs = {}
    for _, win in ipairs(chrome:allWindows()) do
        existingWindowIDs[win:id()] = true
    end
    chrome:selectMenuItem({"File", "New Window"})
    hs.timer.doAfter(0.5, function()
        local newWindow = nil
        for _, win in ipairs(chrome:allWindows()) do
            if not existingWindowIDs[win:id()] then
                newWindow = win
                break
            end
        end
        if newWindow and newWindow:screen():id() ~= originalScreen:id() then
            newWindow:moveToScreen(originalScreen, false, false)
            newWindow:maximize()
        end
    end)
end)

local web_shortcuts = {
    y = "https://youtube.com",
    x = "https://x.com",
    k = "https://calendar.google.com",
    p = "https://perplexity.ai"
}

for key, url in pairs(web_shortcuts) do
    hs.hotkey.bind({"cmd"}, key, function() hs.urlevent.openURL(url) end)
end

-- ============================================================================
-- DESKTOP MANAGEMENT (Event-Driven, with Focus Follow)
-- ============================================================================

-- This watcher will be used to ensure focus changes *after* a space switch.
local spaceWatcher = nil

-- Assign desktops to screens. Assumes 1-4 are on primary, 5-9 on secondary.
local desktopScreenMap = {
    [1] = {screen_index = 1, space_index = 1},
    [2] = {screen_index = 1, space_index = 2},
    [3] = {screen_index = 1, space_index = 3},
    [4] = {screen_index = 1, space_index = 4},
    [5] = {screen_index = 2, space_index = 1},
    [6] = {screen_index = 2, space_index = 2},
    [7] = {screen_index = 2, space_index = 3},
    [8] = {screen_index = 2, space_index = 4},
    [9] = {screen_index = 2, space_index = 5},
}

-- Caches all spaces across all screens
local allScreensSpaces = nil
local function refreshAllSpaces()
    allScreensSpaces = hs.spaces.allSpaces()
end

-- Refresh spaces cache on startup and periodically
refreshAllSpaces()
hs.timer.doEvery(5, refreshAllSpaces)

-- Gets the space ID and screen object for a given desktop number
local function getSpaceForDesktop(desktopNumber)
    local mapping = desktopScreenMap[desktopNumber]
    if not mapping then return nil, nil end
    local screens = hs.screen.allScreens()
    local targetScreen = screens[mapping.screen_index]
    if not targetScreen then return nil, nil end
    local screenSpaces = allScreensSpaces[targetScreen:getUUID()]
    if not screenSpaces then return nil, nil end
    local spaceID = screenSpaces[mapping.space_index]
    if not spaceID then return nil, nil end
    return spaceID, targetScreen
end

-- Switch to a desktop and move focus to that monitor using an event-driven watcher
local function switchToDesktop(desktopNumber)
    local spaceID, targetScreen = getSpaceForDesktop(desktopNumber)
    if not (spaceID and targetScreen) then
        hs.alert.show("Desktop " .. desktopNumber .. " not found")
        return
    end

    if hs.spaces.focusedSpace() == spaceID then return end

    if spaceWatcher then spaceWatcher:stop() end

    spaceWatcher = hs.spaces.watcher.new(function()
        -- This callback fires *after* the space has changed.
        local windowsOnTarget = getWindowsOnScreen(targetScreen)
        if #windowsOnTarget > 0 then
            windowsOnTarget[1]:focus()
        else
            local screenFrame = targetScreen:frame()
            hs.mouse.setAbsolutePosition({x = screenFrame.x + screenFrame.w / 2, y = screenFrame.y + screenFrame.h / 2})
        end
        -- Stop the watcher so it only runs once.
        spaceWatcher:stop()
    end)
    spaceWatcher:start()

    -- Trigger the space change. The watcher will handle the focus change.
    hs.spaces.gotoSpace(spaceID)
end

-- Create desktop switching hotkeys
for i = 1, 9 do
    local key = tostring(i)
    hs.hotkey.bind({"cmd"}, key, function() switchToDesktop(i) end)
end

-- ============================================================================
-- AUTO-ORGANIZATION (RESET LAYOUT)
-- ============================================================================

-- Main tiling function, can be called manually or by watchers
function autoTileCurrentSpace()
    -- Try to get screen from focused window, fall back to mouse's screen.
    local screen
    local focusedWin = hs.window.focusedWindow()
    if focusedWin then
        screen = focusedWin:screen()
    else
        screen = hs.mouse.getCurrentScreen()
    end

    if not screen then return end
    local frame = screen:frame()
    local currentSpaceID = hs.spaces.focusedSpace()

    -- Get all manageable windows on the current screen and space
    local windows = {}
    for _, win in ipairs(getWindowsOnScreen(screen)) do
        if hs.fnutils.contains(hs.spaces.windowSpaces(win), currentSpaceID) then
            table.insert(windows, win)
        end
    end

    local count = #windows

    if count == 0 then
        return -- Nothing to do
    elseif count == 1 then
        windows[1]:setFrame(frame)
    elseif count == 2 then
        windows[1]:setFrame({x=frame.x, y=frame.y, w=frame.w/2, h=frame.h})
        windows[2]:setFrame({x=frame.x+frame.w/2, y=frame.y, w=frame.w/2, h=frame.h})
    elseif count == 3 then
        windows[1]:setFrame({x=frame.x, y=frame.y, w=frame.w/2, h=frame.h})
        windows[2]:setFrame({x=frame.x+frame.w/2, y=frame.y, w=frame.w/2, h=frame.h/2})
        windows[3]:setFrame({x=frame.x+frame.w/2, y=frame.y+frame.h/2, w=frame.w/2, h=frame.h/2})
    elseif count == 4 then
        windows[1]:setFrame({x=frame.x, y=frame.y, w=frame.w/2, h=frame.h/2})
        windows[2]:setFrame({x=frame.x+frame.w/2, y=frame.y, w=frame.w/2, h=frame.h/2})
        windows[3]:setFrame({x=frame.x, y=frame.y+frame.h/2, w=frame.w/2, h=frame.h/2})
        windows[4]:setFrame({x=frame.x+frame.w/2, y=frame.y+frame.h/2, w=frame.w/2, h=frame.h/2})
    elseif count == 5 then
        -- Main on left, 4 in a 2x2 grid on the right
        windows[1]:setFrame({x=frame.x, y=frame.y, w=frame.w/2, h=frame.h})
        local right_x = frame.x + frame.w/2
        local right_w = frame.w/2
        windows[2]:setFrame({x=right_x, y=frame.y, w=right_w/2, h=frame.h/2})
        windows[3]:setFrame({x=right_x + right_w/2, y=frame.y, w=right_w/2, h=frame.h/2})
        windows[4]:setFrame({x=right_x, y=frame.y + frame.h/2, w=right_w/2, h=frame.h/2})
        windows[5]:setFrame({x=right_x + right_w/2, y=frame.y + frame.h/2, w=right_w/2, h=frame.h/2})
    elseif count > 5 then
        -- For more than 5, main on left and stack rest on right
        windows[1]:setFrame({x=frame.x, y=frame.y, w=frame.w/2, h=frame.h})
        local right_x = frame.x + frame.w/2
        local right_w = frame.w/2
        local num_right_windows = count - 1
        local right_h = frame.h / num_right_windows
        for i = 2, count do
            windows[i]:setFrame({
                x = right_x,
                y = frame.y + (right_h * (i - 2)),
                w = right_w,
                h = right_h
            })
        end
    end
end

-- Bind the manual tiling shortcut
hs.hotkey.bind({"cmd", "shift"}, "r", autoTileCurrentSpace)

-- ============================================================================
-- UNIVERSAL CONTROL JUMP
-- ============================================================================
hs.hotkey.bind({"cmd", "alt"}, "down", function()
    local minX = math.huge
    local maxX = -math.huge
    local bottomY = -math.huge

    for _, screen in ipairs(hs.screen.allScreens()) do
        local frame = screen:frame()
        minX = math.min(minX, frame.x)
        maxX = math.max(maxX, frame.x + frame.w)
        bottomY = math.max(bottomY, frame.y + frame.h)
    end

    local center_x = minX + (maxX - minX) / 2
    local target_y = bottomY - 1 -- Move to the very edge

    hs.mouse.setAbsolutePosition({x = center_x, y = target_y})
end)

-- ============================================================================
-- HELP SCREEN
-- ============================================================================
hs.hotkey.bind({"cmd"}, "h", function()
    local shortcuts = [[
    🖥️  WINDOW MANAGEMENT:
    Cmd + ←/→/↑/↓     Focus on adjacent window
    Cmd + Shift + ←/→/↑/↓ Swap window & auto-tile space
    Cmd + Shift + R     Re-tile all windows in space
    Cmd + W             Close window
    Cmd + Shift + S     Minimize window
    Cmd + Shift + U     Restore minimized window
    Cmd + F11           Toggle fullscreen
    Cmd + Shift + =     Expand main pane
    Cmd + Shift + -     Shrink main pane

    🚀 DESKTOPS:
    Cmd + 1-9           Switch to desktop
    Cmd + Alt + ↓     Jump to MacBook (Universal Control)

    📱 APPLICATIONS:
    Cmd + Return        iTerm (focus)
    Cmd + Shift + Return  iTerm (new window)
    Cmd + A             Mail
    Cmd + B             Chrome (focus)
    Cmd + Shift + B     Chrome (new window)
    Cmd + C             FaceTime
    Cmd + D             Docker
    Cmd + F             Finder
    Cmd + G             Messages
    Cmd + I             Terminal
    Cmd + M             Spotify
    Cmd + N             Cursor
    Cmd + O             Notion
    Cmd + S             Notes
    Cmd + T             TradingView
    Cmd + Alt + T       TextEdit
    Cmd + ,             System Settings

    🌐 WEB:
    Cmd + Y             YouTube
    Cmd + X             X.com
    Cmd + K             Google Calendar
    Cmd + P             Perplexity

    📋 OTHER:
    Cmd + H             Show this help
    Cmd + Space         Spotlight
    Cmd + Alt + R       Reload Hammerspoon
    ]]

    -- Show with custom styling for better visibility
    hs.alert.show(shortcuts, {
        strokeWidth = 2,
        strokeColor = {white = 1, alpha = 1},
        fillColor = {white = 0.05, alpha = 0.95},
        textColor = {white = 1, alpha = 1},
        textFont = "Monaco",
        textSize = 14,
        radius = 8,
        atScreenEdge = 0,
        fadeInDuration = 0.2,
        fadeOutDuration = 0.3
    }, hs.screen.mainScreen(), 20)
end)

-- ============================================================================
-- STARTUP
-- ============================================================================
hs.alert.show("Hammerspoon Config Loaded!", 2)