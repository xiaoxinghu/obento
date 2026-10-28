-- Dictation in any app, through the `dictate` CLI.
--
-- A hotkey starts `dictate --json` and stops it; dictate listens,
-- transcribes as it hears and hands back the text, which goes on the
-- clipboard and is pasted into the frontmost app. A floating panel shows
-- the state, how long it has recorded and the words heard so far. The mic
-- and the words to favour are dictate's own config,
-- ~/.config/dictate/config.toml.
--
-- Escape discards a dictation while it runs. It is taken from every app
-- until the dictation ends, so it never reaches the app being dictated
-- into, where it could interrupt a running agent; every way a dictation
-- ends goes through `finish`, which gives it back.

local M = {}

-- Hammerspoon does not read the shell's PATH.
M.command = os.getenv("HOME") .. "/.cargo/bin/dictate"
M.args = { "--json" }
-- Extra environment for dictate, on top of Hammerspoon's.
M.env = {}

-- Seconds of recording after which discarding takes Escape twice: Escape is
-- a reflex, and a long dictation is a lot to lose.
M.confirmAfter = 10
-- Seconds that the second Escape may take.
M.confirmWindow = 2

local function sound(name)
  local s = hs.sound.getByName(name or "Tink")
  if s then s:play() end
end

-- The panel ----------------------------------------------------------------

local W = 520 -- width, in points
local PAD = 16 -- padding inside the panel
local HEADER = 18 -- height of the header row: dot, label, timer
local LINE = 21 -- height of a transcript line
local LINES = 2 -- transcript lines shown; older words scroll off the top
local COMPACT = PAD * 2 + HEADER
local MARGIN = 24 -- transparent room around the panel for its shadow
local FULL = COMPACT + 10 + LINE * LINES

local colors = {
  recording = { red = 1.0, green = 0.27, blue = 0.23 },
  progress = { red = 1.0, green = 0.62, blue = 0.04 },
  success = { red = 0.19, green = 0.82, blue = 0.35 },
  neutral = { white = 0.62 },
  error = { red = 1.0, green = 0.27, blue = 0.23 },
}

local fonts = {
  label = { name = hs.styledtext.defaultFonts.boldSystem.name, size = 13 },
  timer = { name = "Menlo", size = 12 },
  words = { name = hs.styledtext.defaultFonts.system.name, size = 15 },
}

-- The panel is four canvases, so that what changes often redraws without
-- the rest: a canvas redraws all of itself on any change. Measured at
-- dictation's rates, one canvas took Hammerspoon to over 20% CPU; these,
-- about half that.
local bg -- the background and its shadow: redrawn only when it changes size
local panel -- the label and transcript: redrawn as words come, a few times a second
local front -- the level meter and clock, over the header: its bars resized with each level
local dot -- the dot: it breathes by its canvas's alpha, redrawing nothing
local look = {} -- what the panel shows: tone, label, pulse, timer, words, full, meter
local shownFront, shownDot -- what the meter and the dot were last drawn for
local animation -- timer that breathes the dot and ticks the clock
local hideTimer

local function white(alpha) return { white = 1, alpha = alpha } end

local function withAlpha(color, alpha)
  local c = {}
  for k, v in pairs(color) do c[k] = v end
  c.alpha = alpha
  return c
end

local function styled(text, font, color)
  return hs.styledtext.new(text, { font = font, color = color })
end

-- The words that fit in the transcript's lines: the latest, with the
-- settled ones bright and the unsettled preview dimmer. It runs on every
-- word heard, so it measures plain text, a few times, and styles once.
local function transcriptText(settled, preview)
  local words = {}
  for w in settled:gmatch("%S+") do table.insert(words, w) end
  local nSettled = #words
  for w in preview:gmatch("%S+") do table.insert(words, w) end
  -- Lines wrap at word boundaries, so leave some slack.
  local room = (W - PAD * 2) * LINES * 0.88
  local function fits(from)
    local text = (from > 1 and "… " or "") .. table.concat(words, " ", from)
    return not panel or panel:minimumTextSize(styled(text, fonts.words, white(1))).w <= room
  end
  -- The first word from which the rest fits.
  local lo, hi = 1, math.max(1, #words)
  while lo < hi do
    local mid = (lo + hi) // 2
    if fits(mid) then hi = mid else lo = mid + 1 end
  end
  local from = lo
  local text = styled(from > 1 and "… " or "", fonts.words, white(0.55))
  if from <= nSettled then
    text = text .. styled(table.concat(words, " ", from, nSettled), fonts.words, white(0.95))
  end
  if #words > nSettled then
    local first = math.max(from, nSettled + 1)
    -- Dimmer, but readable: a model can leave a whole sentence unsettled.
    text = text .. styled((first > from and " " or "") .. table.concat(words, " ", first), fonts.words, white(0.7))
  end
  return text
end

-- The canvas's frame for a panel HEIGHT high: centred near the bottom of
-- the screen with the pointer, with MARGIN all round.
local function frameFor(height)
  local screen = (hs.mouse.getCurrentScreen() or hs.screen.mainScreen()):frame()
  return {
    x = screen.x + (screen.w - W) / 2 - MARGIN,
    y = screen.y + screen.h - height - 28 - MARGIN,
    w = W + MARGIN * 2,
    h = height + MARGIN * 2,
  }
end

-- Element frames are relative to the panel, inside the margin.
local function at(f)
  return { x = f.x + MARGIN, y = f.y + MARGIN, w = f.w, h = f.h }
end

-- The front canvas's frame: the header row of the panel at `frame`.
local function headerOf(frame)
  return { x = frame.x + MARGIN, y = frame.y + MARGIN, w = W, h = COMPACT }
end

local DOT = 10 -- the dot's diameter

-- The dot canvas's frame: the dot's place in the panel at `frame`.
local function dotOf(frame)
  return { x = frame.x + MARGIN + PAD, y = frame.y + MARGIN + PAD + (HEADER - DOT) / 2, w = DOT, h = DOT }
end

-- The level meter: bars of the last few seconds' levels, the latest on the
-- right, older ones moving off to the left as they fade.
local BARS = 28
local BAR_W = 3
local STEP = BAR_W + 2 -- a bar and the gap after it
local METER_H = 16 -- the tallest bar
local TIMER_W = 44
local METER_X = W - PAD - TIMER_W - 12 - (BARS - 1) * STEP - BAR_W

-- Where the bar AGE levels back stands, `level` high: the latest (0) on the right.
local function barFrame(age, level)
  local h = math.max(2, level * METER_H)
  return { x = METER_X + (BARS - 1 - age) * STEP, y = PAD + HEADER / 2 - h / 2, w = BAR_W, h = h }
end

-- Draws the background and its shadow, sized to `look`, and moves the other
-- canvases with it. Only a change of size redraws it.
local function drawBg()
  local height = look.full and FULL or COMPACT
  local frame = bg:frame()
  if frame.h == height + MARGIN * 2 and bg[1] then return end
  -- Grow or shrink upwards, keeping the bottom edge put.
  frame = { x = frame.x, y = frame.y + frame.h - height - MARGIN * 2, w = frame.w, h = height + MARGIN * 2 }
  bg:frame(frame)
  panel:frame(frame)
  front:frame(headerOf(frame))
  dot:frame(dotOf(frame))
  bg:replaceElements({
    type = "rectangle", action = "strokeAndFill",
    frame = at({ x = 0, y = 0, w = W, h = height }),
    roundedRectRadii = { xRadius = 16, yRadius = 16 },
    fillColor = { white = 0.11, alpha = 0.94 },
    strokeColor = white(0.12), strokeWidth = 1,
    withShadow = true,
    shadow = { blurRadius = 18, color = { white = 0, alpha = 0.45 }, offset = { h = -6, w = 0 } },
  })
end

-- Draws the label and transcript.
local function drawText()
  local elements = {
    {
      type = "text", frame = at({ x = PAD + 18, y = PAD, w = METER_X - PAD - 18 - 8, h = HEADER }),
      text = styled(look.label or "", fonts.label, look.labelColor or white(0.92)),
    },
  }
  if look.full then
    table.insert(elements, {
      type = "text", frame = at({ x = PAD, y = PAD + HEADER + 10, w = W - PAD * 2, h = LINE * LINES + 4 }),
      text = look.words or styled("", fonts.words, white(1)),
    })
  end
  panel:replaceElements(elements)
end

local function clockText()
  return hs.styledtext.new(look.timer or "", {
    font = fonts.timer, color = white(0.55), paragraphStyle = { alignment = "right" },
  })
end

-- Draws the clock and the meter's bars: the clock first, then one bar per
-- age, the latest first, live (in the tone) or frozen (dim).
local function drawFront()
  if look.clock then look.timer = look.clock() end
  local elements = {
    { type = "text", frame = { x = W - PAD - TIMER_W, y = PAD + 1, w = TIMER_W, h = HEADER }, text = clockText() },
  }
  local meter = look.meter
  if meter then
    local tone = colors[look.tone] or colors.neutral
    for age = 0, BARS - 1 do
      local fade = 1 - age / BARS
      table.insert(elements, {
        type = "rectangle", action = "fill",
        frame = barFrame(age, meter.levels[#meter.levels - age] or 0),
        roundedRectRadii = { xRadius = BAR_W / 2, yRadius = BAR_W / 2 },
        fillColor = meter.live and withAlpha(tone, 0.2 + 0.8 * fade) or white(0.1 + 0.25 * fade),
      })
    end
  end
  front:replaceElements(elements)
end

-- Moves the meter on by the level just added, ten times a second: each bar
-- takes the next one's height, and keeps its place and colour. Setting
-- only the frames costs half what drawing the bars anew does.
local function meterChanged()
  local meter = look.meter
  if not front or not meter or front:elementCount() ~= BARS + 1 then return end
  local levels = meter.levels
  for age = 0, BARS - 1 do
    front[2 + age].frame = barFrame(age, levels[#levels - age] or 0)
  end
end

local function drawDot()
  dot:replaceElements({
    type = "circle", action = "fill",
    center = { x = DOT / 2, y = DOT / 2 }, radius = DOT / 2,
    fillColor = colors[look.tone] or colors.neutral,
  })
  dot:alpha(1)
end

-- Breathes the dot, by its canvas's alpha, which redraws nothing; and ticks
-- the clock when its second changes. Twelve a second is smooth enough for a
-- breath of 1.6 s.
local function animate(on)
  if on and not animation then
    animation = hs.timer.doEvery(1 / 12, function()
      if not dot then return end
      if look.pulse then
        dot:alpha(0.35 + 0.65 * (0.5 + 0.5 * math.cos(hs.timer.secondsSinceEpoch() * math.pi / 0.8)))
      end
      if look.clock and look.clock() ~= look.timer then
        look.timer = look.clock()
        front[1].text = clockText()
      end
    end)
  elseif not on and animation then
    animation:stop()
    animation = nil
  end
end

local function canvas(frame)
  local c = hs.canvas.new(frame)
  c:level(hs.canvas.windowLevels.overlay)
  c:behaviorAsLabels({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
  c:clickActivating(false)
  return c
end

-- Shows the panel as `l` says: tone, label, pulse, timer or clock, words,
-- full, meter. With `timeout`, it fades out after that many seconds.
local function show(l, timeout)
  if hideTimer then hideTimer:stop(); hideTimer = nil end
  look = l
  local fresh = not panel
  if fresh then
    local frame = frameFor(l.full and FULL or COMPACT)
    bg = canvas(frame)
    panel = canvas(frame)
    front = canvas(headerOf(frame))
    dot = canvas(dotOf(frame))
  end
  drawBg()
  drawText()
  -- The meter and the dot change with the state, not with each word.
  local meter = look.meter
  local frontKey = (look.tone or "") .. (meter and (meter.live and " live" or " frozen") or "")
  if fresh or frontKey ~= shownFront then
    shownFront = frontKey
    drawFront()
  elseif look.clock or look.timer then
    look.timer = look.clock and look.clock() or look.timer
    front[1].text = clockText()
  end
  local dotKey = (look.tone or "") .. (look.pulse and " pulse" or "")
  if fresh or dotKey ~= shownDot then
    shownDot = dotKey
    drawDot()
  end
  if fresh then
    for _, c in ipairs({ bg, panel, front, dot }) do c:show(0.12) end
    panel:orderAbove(bg)
    front:orderAbove(panel)
    dot:orderAbove(panel)
  end
  animate(look.pulse or look.clock ~= nil)
  if timeout then
    hideTimer = hs.timer.doAfter(timeout, function()
      hideTimer = nil
      animate(false)
      if panel then
        local canvases = { bg, panel, front, dot }
        bg, panel, front, dot = nil, nil, nil, nil
        for _, c in ipairs(canvases) do c:delete(0.25) end
      end
    end)
  end
end

-- The dictation -------------------------------------------------------------

local d -- the current dictation, while it runs
local escape -- the Escape hotkey, enabled while a dictation runs

local function elapsed()
  if not d or not d.started then return 0 end
  return (d.recorded or hs.timer.secondsSinceEpoch() - d.started)
end

local function clock()
  local s = math.floor(elapsed())
  return string.format("%d:%02d", s // 60, s % 60)
end

local function settled()
  return table.concat(d.finals, " ")
end

local function recordingLook()
  local words = (#d.finals == 0 and d.preview == "")
    and styled("Listening…", fonts.words, white(0.35))
    or transcriptText(settled(), d.preview)
  return {
    tone = "recording", label = "Recording", pulse = true, clock = clock, words = words, full = true,
    meter = d.meter,
  }
end

local function transcribingLook()
  local text = settled() .. (d.preview ~= "" and " " .. d.preview or "")
  return {
    tone = "progress", label = "Transcribing", pulse = true, timer = clock(),
    words = transcriptText(text, ""), full = text ~= "", meter = d.meter,
  }
end

local function refresh()
  if not d or d.confirming then return end
  if d.stopped then show(transcribingLook())
  elseif d.started then show(recordingLook())
  else show({ tone = "neutral", label = "Starting", pulse = true }) end
end

local function fail(reason)
  sound("Basso")
  show({
    tone = "error", label = "Dictation failed", full = true,
    words = styled(reason, fonts.words, white(0.85)),
  }, 4)
  print("dictation failed: " .. reason)
end

local function send(command)
  if d and d.task and d.task:isRunning() then d.task:setInput(command .. "\n") end
end

-- Puts TEXT on the clipboard and pastes it into the frontmost app.
function M.deliver(text)
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({ "cmd" }, "v", 0)
  show({ tone = "success", label = "Pasted" }, 1.2)
end

local function finish()
  if not d or d.finished then return end
  d.finished = true
  if d.confirmTimer then d.confirmTimer:stop() end
  if d.fallback then d.fallback:stop() end
  escape:disable()
  local done = d
  d = nil
  local code = done.exitCode
  if done.cancelled or code == 3 then
    show({ tone = "neutral", label = "Discarded" }, 1.2)
  elseif code == 0 and done.text then
    M.deliver(done.text)
  elseif code == 2 then
    show({ tone = "neutral", label = "No speech" }, 1.2)
  else
    local why = done.error or table.concat(done.stderr, "\n"):match("([^\n]+)\n*$")
    fail(why or string.format("dictate exited with code %s", tostring(code)))
  end
end

local function stopRecording()
  d.stopped = true
  d.recorded = d.started and hs.timer.secondsSinceEpoch() - d.started
  d.meter.live = false
  sound()
  refresh()
end

local function onEvent(e)
  local kind = e.event
  if kind == "recording" and not d.started then
    d.started = hs.timer.secondsSinceEpoch()
    -- Unless stopped while it loaded: it then stops at once.
    if not d.stopped then sound() end
    refresh()
  elseif kind == "level" and not d.stopped then
    local levels = d.meter.levels
    table.insert(levels, e.level)
    if #levels > BARS then table.remove(levels, 1) end
    meterChanged()
  elseif kind == "preview" then
    d.preview = e.text
    refresh()
  elseif kind == "final" then
    table.insert(d.finals, e.text)
    d.preview = ""
    refresh()
  elseif kind == "transcribing" and not d.stopped then
    -- Stopped on its own, at a timeout set in its config: what it recorded
    -- is transcribed as if the user had stopped it.
    stopRecording()
  elseif kind == "text" then
    d.text = e.text
  elseif kind == "error" then
    d.error = e.message
  end
end

-- Handles each whole line of OUT; a line can arrive in pieces.
local function onOutput(dict, out, err)
  if err and err ~= "" then
    table.insert(dict.stderr, err)
    if #dict.stderr > 20 then table.remove(dict.stderr, 1) end
  end
  dict.partial = dict.partial .. (out or "")
  while true do
    local line, rest = dict.partial:match("^([^\n]*)\n(.*)$")
    if not line then break end
    dict.partial = rest
    local ok, e = pcall(hs.json.decode, line)
    if ok and type(e) == "table" and d == dict then onEvent(e) end
  end
end

-- Ends the dictation once dictate has exited and its output is in: the
-- last output can come after the exit.
local function settle(dict)
  if d ~= dict or dict.exitCode == nil then return end
  if dict.exitCode == 0 and not dict.text then
    if not dict.fallback then dict.fallback = hs.timer.doAfter(0.5, finish) end
    return
  end
  finish()
end

local function start()
  d = {
    finals = {}, preview = "", stderr = {}, partial = "",
    meter = { levels = {}, live = true },
  }
  local dict = d
  local task = hs.task.new(M.command, function(code, out, err)
    dict.exitCode = code
    onOutput(dict, out, err)
    settle(dict)
  end, function(_, out, err)
    onOutput(dict, out, err)
    settle(dict)
    return true
  end, M.args)
  if not task then
    d = nil
    return fail("cannot run " .. M.command)
  end
  if next(M.env) then
    local env = task:environment()
    for k, v in pairs(M.env) do env[k] = v end
    task:setEnvironment(env)
  end
  dict.task = task
  escape:enable()
  if not task:start() then
    escape:disable()
    d = nil
    return fail("cannot start " .. M.command)
  end
  refresh()
end

-- Starts dictating, or stops and pastes the text.
function M.toggle()
  if not d then return start() end
  if d.stopped then
    show({ tone = "progress", label = "Still transcribing…", pulse = true, timer = clock() })
    return
  end
  stopRecording()
  send("stop")
end

-- Discards the current dictation. A recording longer than `confirmAfter`
-- seconds takes a second Escape.
function M.cancel()
  if not d then return escape:disable() end
  if elapsed() > M.confirmAfter and not d.confirming then
    d.confirming = true
    d.confirmTimer = hs.timer.doAfter(M.confirmWindow, function()
      if d then d.confirming = false; refresh() end
    end)
    local l = d.stopped and transcribingLook() or recordingLook()
    l.label = "Press Escape again to discard"
    l.labelColor = withAlpha(colors.progress, 1)
    show(l)
    return
  end
  d.cancelled = true
  sound("Pop")
  show({ tone = "neutral", label = "Discarded" }, 1.2)
  -- dictate exits at once, and its exit ends the dictation.
  send("cancel")
end

escape = hs.hotkey.new({}, "escape", M.cancel)

return M
