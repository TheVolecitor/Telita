-- Telita OSD - Custom UI for MPV
-- Displays: title, seek bar, play/pause, time, volume, back button

local mp = require 'mp'
local msg = require 'mp.msg'

local osd = mp.create_osd_overlay('ass-events')
local visible = false
local hide_timer = nil
local duration = 0
local pos = 0
local paused = false
local title = ""

-- ASS styling constants
local function fmt_time(secs)
    if not secs or secs < 0 then return "0:00" end
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%d:%02d", m, s)
    end
end

local function render()
    if not visible then
        osd.data = ""
        osd:update()
        return
    end

    local progress = 0
    if duration and duration > 0 then
        progress = (pos or 0) / duration
    end

    local bar_width = 700
    local filled = math.floor(progress * bar_width)
    local empty = bar_width - filled

    local play_icon = paused and "▶" or "⏸"
    local time_str = fmt_time(pos) .. " / " .. fmt_time(duration)

    -- Truncate long titles
    local display_title = title
    if #display_title > 60 then
        display_title = display_title:sub(1, 57) .. "..."
    end

    local ass = ""
    -- Background gradient panel at bottom
    ass = ass .. "{\\an2\\pos(960,1035)\\blur0\\bord0}"
    ass = ass .. "{\\c&H000000&\\1a&H60&}"
    ass = ass .. string.rep(" ", 200) .. "\n"

    -- Title at top center
    ass = ass .. "{\\an8\\pos(960,40)\\fn" .. "Segoe UI" .. "\\fs28\\b1\\c&HFFFFFF&\\1a&H00&\\bord1\\shad1\\blur0}"
    ass = ass .. display_title .. "\n"

    -- Back button top left
    ass = ass .. "{\\an7\\pos(32,40)\\fn" .. "Segoe UI" .. "\\fs26\\b0\\c&HDDDDDD&\\1a&H00&\\bord1\\shad0\\blur0}"
    ass = ass .. "← Back" .. "\n"

    -- Seek bar background
    ass = ass .. "{\\an2\\pos(960,1000)\\fn" .. "Arial" .. "\\fs16\\c&H444444&\\1a&H00&\\bord0\\blur0}"
    ass = ass .. string.rep("─", 100) .. "\n"

    -- Seek bar filled
    if filled > 0 then
        ass = ass .. "{\\an2\\pos(" .. tostring(960 - bar_width/2 + filled/2) .. ",1000)\\fn" .. "Arial" .. "\\fs16\\c&H38BDF8&\\1a&H00&\\bord0\\blur0}"
        ass = ass .. string.rep("─", math.floor(filled / 7)) .. "\n"
    end

    -- Play/pause button center
    ass = ass .. "{\\an2\\pos(960,1045)\\fn" .. "Segoe UI" .. "\\fs36\\b1\\c&HFFFFFF&\\1a&H00&\\bord1\\shad1\\blur0}"
    ass = ass .. play_icon .. "\n"

    -- Time left
    ass = ass .. "{\\an1\\pos(260,1050)\\fn" .. "Segoe UI" .. "\\fs22\\b0\\c&HCCCCCC&\\1a&H00&\\bord0\\shad0\\blur0}"
    ass = ass .. time_str .. "\n"

    osd.data = ass
    osd:update()
end

local function show_ui(duration_sec)
    visible = true
    if hide_timer then
        hide_timer:kill()
    end
    hide_timer = mp.add_timeout(duration_sec or 3, function()
        visible = false
        render()
    end)
    render()
end

local function hide_ui()
    visible = false
    if hide_timer then
        hide_timer:kill()
        hide_timer = nil
    end
    render()
end

-- Track position and duration
mp.observe_property("time-pos", "number", function(_, val)
    pos = val or 0
    if visible then render() end
end)

mp.observe_property("duration", "number", function(_, val)
    duration = val or 0
    if visible then render() end
end)

mp.observe_property("pause", "bool", function(_, val)
    paused = val or false
    if visible then render() end
end)

mp.observe_property("media-title", "string", function(_, val)
    title = val or mp.get_property("filename") or "Playing..."
    if visible then render() end
end)

-- Show OSD on mouse move or key press
mp.register_event("mouse-move", function()
    show_ui(3)
end)

-- Space / Enter = play/pause
mp.add_key_binding("space", "toggle-pause", function()
    mp.commandv("cycle", "pause")
    show_ui(2)
end)

mp.add_key_binding("enter", "toggle-pause-enter", function()
    mp.commandv("cycle", "pause")
    show_ui(2)
end)

-- Arrow keys for seek
mp.add_key_binding("right", "seek-forward", function()
    mp.commandv("seek", "10")
    show_ui(2)
end)

mp.add_key_binding("left", "seek-backward", function()
    mp.commandv("seek", "-10")
    show_ui(2)
end)

-- ESC / Backspace / Q = quit
mp.add_key_binding("escape", "quit-player", function()
    mp.commandv("quit")
end)

mp.add_key_binding("backspace", "quit-player-bs", function()
    mp.commandv("quit")
end)

mp.add_key_binding("q", "quit-player-q", function()
    mp.commandv("quit")
end)

-- Volume
mp.add_key_binding("up", "vol-up", function()
    mp.commandv("add", "volume", "5")
    show_ui(2)
end)

mp.add_key_binding("down", "vol-down", function()
    mp.commandv("add", "volume", "-5")
    show_ui(2)
end)

-- Mouse click to toggle OSD
mp.add_key_binding("mbtn_left", "click-toggle", function()
    if visible then
        hide_ui()
    else
        show_ui(3)
    end
end)

-- Double click = play/pause
mp.add_key_binding("mbtn_left_dbl", "dbl-pause", function()
    mp.commandv("cycle", "pause")
    show_ui(2)
end)

-- Show OSD on start
mp.register_event("file-loaded", function()
    title = mp.get_property("media-title") or mp.get_property("filename") or "Playing..."
    show_ui(4)
end)

msg.info("Telita OSD loaded")
