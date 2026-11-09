local ADDON, Mrgl = ...
-- Mrgl Squad - UI/Kit.lua: colors and widget helpers (Fill, Border, Text, Icon, Button, Anim).
-- Only WoW API calls (CreateFrame, CreateTexture, SetPoint, ...). Port of web/ui/Kit.js (port-plan 2.4).
-- Kit pseudo-objects (K.Border, K.MurlocHead) accept both call forms: obj.SetShown(on) and obj:SetShown(on)
-- (same for SetColor / SetState), so a dot/colon slip in a caller cannot shift the arguments.
Mrgl.UI = Mrgl.UI or {}
do
  local pixelLine, inUI, inPanel, setIconTexture
  local K = {}
  Mrgl.UI.Kit = K
  K.FRIZ = "Fonts\\FRIZQT__.TTF"
  K.ARIALN = "Fonts\\ARIALN.TTF"
  K.C = {
    bg = { 0.055, 0.060, 0.070, 0.94 },
    panel = { 0.085, 0.090, 0.105, 1 },
    line = { 1, 1, 1, 0.10 },
    black = { 0, 0, 0, 1 },
    gold = { 1, 0.82, 0, 1 },
    white = { 1, 1, 1, 1 },
    text = { 0.94, 0.93, 0.89, 1 },
    tipText = { 0.82, 0.82, 0.80, 1 },   -- r2 T3
    muted = { 0.60, 0.59, 0.55, 1 },
    bad = { 1, 0.30, 0.30, 1 },
    good = { 0.35, 0.90, 0.35, 1 },
    warn = { 1, 0.60, 0.10, 1 },          -- r2 R3
    hp = { 0.78, 0.13, 0.10, 1 },
    hpTop = { 0.95, 0.30, 0.22, 1 },
    hpLag = { 0.85, 0.55, 0.25, 0.9 },
    crit = { 1, 0.62, 0.10, 1 },
    boss = { 1, 0.55, 0.15, 1 },
    rare = { 0.40, 0.70, 1.00, 1 },       -- r2 M3
    ability = { 1, 0.92, 0.55, 1 },       -- r2 L2 (ability numbers)
    leeroy = { 1, 0.5, 0.1, 1 },
    timerMid = { 1, 0.5, 0.1, 1 },
    timerLow = { 1, 0.35, 0.10, 1 },      -- r2 R3
    dim = { 1, 1, 1, 0.15 },
    dark = { 0.10, 0.08, 0.03, 1 },
  }
  K.IconPath = function(name)
    return Mrgl.Data.Icons.ICON_PATH .. name
  end
  K.Media = function(name)
    return Mrgl.Data.Icons.MEDIA_PATH .. name
  end
  K.SetColor = function(tex, c, a)
    local alpha = a
    if alpha == nil then
      alpha = c[4]
    end
    tex:SetColorTexture(c[1], c[2], c[3], alpha)
  end
  K.SetVertex = function(tex, c, a)
    local alpha = a
    if alpha == nil then
      alpha = c[4]
    end
    tex:SetVertexColor(c[1], c[2], c[3], alpha)
  end
  K.SetTextColor = function(fs, c)
    fs:SetTextColor(c[1], c[2], c[3], c[4])
  end
  -- Port-plan 3: FRIZQT__ is unchecked on Forever. Only an explicit failure (SetFont returns false) falls back
  -- to the font of GameFontNormal, at the same size and flags.
  K.SetFont = function(fs, font, size, flags)
    local ok = fs:SetFont(font, size, flags)
    if ok == false and GameFontNormal ~= nil then
      local fb = GameFontNormal:GetFont()
      if fb ~= nil then
        fs:SetFont(fb, size, flags)
      end
    end
  end
  K.Fill = function(frame, c, layer, sub)
    local L = layer
    if L == nil then
      L = "BACKGROUND"
    end
    local sl = sub
    if sl == nil then
      sl = 0
    end
    local t = frame:CreateTexture(nil, L, nil, sl)
    t:SetAllPoints(frame)
    K.SetColor(t, c)
    return t
  end
  -- 4 lines of `thick` pixels (ForeverIdle "Border"). inset = pixels inside the frame edge.
  -- r2 W5: line thickness goes through PixelUtil (whole physical pixels) and is set again on scale changes.
  local pixelLines = {}
  function pixelLine(tex, horiz, thick)
    local e = { tex = tex, horiz = horiz, thick = thick }
    tinsert(pixelLines, e)
    K.PixelApply(e)
  end
  -- port p2 (review p1 WoW S1): without PixelUtil the plain size (not pixel-snapped) instead of an error in Build
  K.PixelApply = function(e)
    local P = PixelUtil
    if e.horiz then
      if P ~= nil and P.SetHeight ~= nil then
        P.SetHeight(e.tex, e.thick, e.thick)
      else
        e.tex:SetHeight(e.thick)
      end
    else
      if P ~= nil and P.SetWidth ~= nil then
        P.SetWidth(e.tex, e.thick, e.thick)
      else
        e.tex:SetWidth(e.thick)
      end
    end
  end
  -- Call after SetScale (and DISPLAY_SIZE_CHANGED / UI_SCALE_CHANGED)
  K.PixelRefresh = function()
    for i = 1, #pixelLines do
      K.PixelApply(pixelLines[i])
    end
  end
  K.PixelLine = pixelLine
  K.Border = function(frame, c, layer, inset, thick, sub)
    local o = inset
    if o == nil then
      o = 0
    end
    local t = thick
    if t == nil then
      t = 1
    end
    local lines = {}
    local L = layer
    if L == nil then
      L = "BORDER"
    end
    local sl = sub
    if sl == nil then
      sl = 0
    end
    lines.top = frame:CreateTexture(nil, L, nil, sl)
    lines.top:SetPoint("TOPLEFT", frame, "TOPLEFT", o, -o)
    lines.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -o, -o)
    pixelLine(lines.top, true, t)
    lines.bottom = frame:CreateTexture(nil, L, nil, sl)
    lines.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o, o)
    lines.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -o, o)
    pixelLine(lines.bottom, true, t)
    lines.left = frame:CreateTexture(nil, L, nil, sl)
    lines.left:SetPoint("TOPLEFT", frame, "TOPLEFT", o, -o - t)
    lines.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o, o + t)
    pixelLine(lines.left, false, t)
    lines.right = frame:CreateTexture(nil, L, nil, sl)
    lines.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -o, -o - t)
    lines.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -o, o + t)
    pixelLine(lines.right, false, t)
    local b = { lines = lines }
    -- b.SetColor(c2, a) or b:SetColor(c2, a)
    b.SetColor = function(x, c2, a)
      if x ~= b then
        x, c2, a = b, x, c2
      end
      K.SetColor(lines.top, c2, a)
      K.SetColor(lines.bottom, c2, a)
      K.SetColor(lines.left, c2, a)
      K.SetColor(lines.right, c2, a)
    end
    -- b:SetShown(on) or b.SetShown(on)
    b.SetShown = function(x, on)
      if x ~= b then
        on = x
      end
      lines.top:SetShown(on)
      lines.bottom:SetShown(on)
      lines.left:SetShown(on)
      lines.right:SetShown(on)
    end
    if c == nil then
      b.SetColor(K.C.line)
    else
      b.SetColor(c)
    end
    return b
  end
  K.Text = function(parent, font, size, c, flags, layer)
    local L = layer
    if L == nil then
      L = "OVERLAY"
    end
    local fl = flags
    if fl == nil then
      fl = ""
    end
    local fs = parent:CreateFontString(nil, L)
    K.SetFont(fs, font, size, fl)
    if c == nil then
      K.SetTextColor(fs, K.C.text)
    else
      K.SetTextColor(fs, c)
    end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    if flags == nil or flags == "" then
      fs:SetShadowOffset(1, -1)
      fs:SetShadowColor(0, 0, 0, 1)
    end
    return fs
  end
  -- Port-plan 3: an icon missing on Forever shows the question mark. Only an explicit failure (SetTexture returns
  -- false) falls back; a client that returns nothing keeps the texture as set.
  function setIconTexture(t, name)
    local ok = t:SetTexture(K.IconPath(name))
    if ok == false then
      t:SetTexture(K.IconPath(Mrgl.Data.Icons.question))
    end
  end
  -- Icon texture with the standard edge crop
  K.Icon = function(frame, name, layer, sub)
    local L = layer
    if L == nil then
      L = "ARTWORK"
    end
    local sl = sub
    if sl == nil then
      sl = 0
    end
    local t = frame:CreateTexture(nil, L, nil, sl)
    if name ~= nil then
      setIconTexture(t, name)
    end
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return t
  end
  K.SetIcon = function(tex, name)
    if tex.mrglIcon ~= name then
      tex.mrglIcon = name
      setIconTexture(tex, name)
    end
  end
  -- r2 M1: murloc head = INV_Misc_Head_Murloc_01, tinted per rank (desaturated base x tint + ADD copy at 0.6 x tint),
  -- role badge bottom left (10 px on 22er heads, 12 px on 28-32er). Returns {base, add, badge, badgeBg, SetState}.
  -- SetState("full" | "dim"): dim = only the base, no ADD copy (locked / not hired); alpha is up to the caller.
  -- No grey icon copies in WoW: every grey look is SetDesaturated.
  K.MurlocHead = function(frame, i, size, layer)
    return K.HeadOf(frame, Mrgl.Core.Formula.Murloc(i), size, layer)
  end
  -- tide1b T3: the same head for any { icon, tint, badge, natural } (New Tide companions); badge 7 px under 20-px heads
  K.HeadOf = function(frame, m, size, layer)
    local L = layer
    if L == nil then
      L = "ARTWORK"
    end
    local h = {}
    h.base = K.Icon(frame, m.icon, L, 0)
    h.add = K.Icon(frame, m.icon, L, 1)
    h.add:SetAllPoints(h.base)
    h.add:SetBlendMode("ADD")
    local t = m.tint
    if m.natural == true then
      h.add:Hide()
    else
      h.base:SetDesaturated(true)
      h.base:SetVertexColor(t[1], t[2], t[3], 1)
      h.add:SetDesaturated(true)
      h.add:SetVertexColor(0.6 * t[1], 0.6 * t[2], 0.6 * t[3], 1)
    end
    if m.badge ~= "" then
      local bs = 10
      if size >= 28 then
        bs = 12
      end
      if size < 20 then
        bs = 7
      end
      h.badgeBg = frame:CreateTexture(nil, L, nil, 2)
      h.badgeBg:SetColorTexture(0, 0, 0, 1)
      h.badgeBg:SetSize(bs + 2, bs + 2)
      h.badgeBg:SetPoint("BOTTOMLEFT", h.base, "BOTTOMLEFT", -1, -1)
      h.badge = K.Icon(frame, m.badge, L, 3)
      h.badge:SetSize(bs, bs)
      h.badge:SetPoint("CENTER", h.badgeBg, "CENTER", 0, 0)
    end
    h.state = "full"
    h.shown = true
    -- h:SetShown(on) or h.SetShown(on)
    h.SetShown = function(x, on)
      if x ~= h then
        on = x
      end
      h.shown = on
      h.base:SetShown(on)
      if m.natural ~= true then
        h.add:SetShown(on and h.state == "full")
      end
      if h.badge ~= nil then
        h.badge:SetShown(on)
        h.badgeBg:SetShown(on)
      end
    end
    -- r4 E13: "grey" = like dim, but without the rank tint (a fully desaturated head)
    -- h.SetState(st) or h:SetState(st)
    h.SetState = function(x, st)
      if x ~= h then
        st = x
      end
      if st == h.state then
        return
      end
      local was = h.state
      h.state = st
      if m.natural ~= true then
        h.add:SetShown(st == "full" and h.shown)
      end
      if m.natural == true then
        h.base:SetDesaturated(st ~= "full")
      end
      if h.badge ~= nil then
        h.badge:SetDesaturated(st ~= "full")
      end
      if m.natural ~= true and st == "grey" then
        h.base:SetVertexColor(1, 1, 1, 1)
      elseif m.natural ~= true and was == "grey" then
        h.base:SetVertexColor(t[1], t[2], t[3], 1)
      end
    end
    return h
  end
  -- Murloc accent colour (ring, row accents): Tinyfin has its own, the others use their tint
  K.MurlocColor = function(i)
    local m = Mrgl.Core.Formula.Murloc(i)
    local c = m.tint
    if m.ring ~= nil then
      c = m.ring
    end
    return { c[1], c[2], c[3], 1 }
  end
  -- Own texture (glow, ring, spark): white + alpha, tinted via vertex color
  K.Glow = function(frame, name, size, c, layer, sub)
    local L = layer
    if L == nil then
      L = "OVERLAY"
    end
    local sl = sub
    if sl == nil then
      sl = 0
    end
    local t = frame:CreateTexture(nil, L, nil, sl)
    t:SetTexture(K.Media(name))
    t:SetBlendMode("ADD")
    t:SetSize(size, size)
    if c == nil then
      K.SetVertex(t, K.C.gold)
    else
      K.SetVertex(t, c)
    end
    return t
  end
  -- HIGHLIGHT layer texture (shown by the client while the mouse is over the button)
  K.Highlight = function(btn, region, alpha, add)
    local h = btn:CreateTexture(nil, "HIGHLIGHT")
    if region == nil then
      h:SetAllPoints(btn)
    else
      h:SetAllPoints(region)
    end
    local al = alpha
    if al == nil then
      al = 0.04   -- j1 A1 #27
    end
    h:SetColorTexture(1, 1, 1, al)
    if add == true then
      h:SetBlendMode("ADD")
    end
    return h
  end
  -- Icon button: black 1-px frame, icon inside, hover highlight. size = outer size.
  K.IconButton = function(parent, name, size, icon)
    local b = CreateFrame("Button", name, parent)
    b:SetSize(size, size)
    b.bg = K.Fill(b, K.C.black, "BACKGROUND")
    b.icon = K.Icon(b, icon, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.hl = K.Highlight(b, b.icon, 0.15, true)
    return b
  end
  -- Pressed look: content 1 px right/down while the mouse button is held (plan 3.6)
  -- Moves every anchor point of the region, so two-point regions keep their size.
  -- GetPoint(i) returns point, relativeTo, relativePoint, x, y (Lua: p[1]..p[5]).
  K.PressOffset = function(btn, region)
    local saved
    btn:HookScript("OnMouseDown", function()
      saved = {}
      for i = 1, region:GetNumPoints() do
        tinsert(saved, { region:GetPoint(i) })
      end
      for j = 1, #saved do
        local p = saved[j]
        region:SetPoint(p[1], p[2], p[3], p[4] + 1, p[5] - 1)
      end
    end)
    btn:HookScript("OnMouseUp", function()
      if saved == nil then
        return
      end
      for j = 1, #saved do
        local p = saved[j]
        region:SetPoint(p[1], p[2], p[3], p[4], p[5])
      end
      saved = nil
    end)
  end
  -- ------------------------------------------------------------ tooltips (r2 T1, T2)
  -- No tooltip ever lies over the window or the panel: ANCHOR_NONE, placed at the outer edge of the
  -- window+panel group on the side with more room; top edge = owner top, clamped to the screen;
  -- if neither side fits, above the group.
  function inUI(f, v)
    return v * f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  end
  function inPanel(owner)
    local P = Mrgl.UI.Panel
    if P == nil or P.w.frame == nil then
      return false
    end
    local p = owner
    while p ~= nil and p ~= UIParent do   -- GetParent() is nil at the top
      if p == P.w.frame then
        return true
      end
      p = p:GetParent()
    end
    return false
  end
  K.PlaceTip = function(owner)
    local main = Mrgl.UI.Main.w.frame
    local P = Mrgl.UI.Panel
    local tip = GameTooltip
    if main:GetLeft() == nil or owner:GetTop() == nil then   -- W3: not visible
      return
    end
    local l = inUI(main, main:GetLeft()); local r = inUI(main, main:GetRight()); local top = inUI(main, main:GetTop())
    local panelOpen = P ~= nil and P.w.frame ~= nil and P.w.frame:IsVisible() and P.w.frame:GetLeft() ~= nil
    local pl = l; local pr = r
    if panelOpen then
      pl = inUI(P.w.frame, P.w.frame:GetLeft())
      pr = inUI(P.w.frame, P.w.frame:GetRight())
    end
    local gl = math.min(l, pl); local gr = math.max(r, pr)
    local sw = GetScreenWidth(); local sh = GetScreenHeight()
    local ts = tip:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local tw = tip:GetWidth() * ts; local th = tip:GetHeight() * ts
    local side
    if panelOpen then
      local panelRight = pl >= r - 2
      if inPanel(owner) then
        side = (panelRight and "right" or "left")
      else
        side = (panelRight and "left" or "right")
      end
    else
      side = "right"
      if gl > sw - gr then
        side = "left"
      end
    end
    -- tide1c C3: the preferred outer side, then the other outer side of the group, then above it only if that fits on
    -- the screen, else below it. Never clamped onto the header
    local xl = gl - 4 - tw; local xr = gr + 4
    local fitL = xl >= 0; local fitR = xr + tw <= sw
    local x = 0; local found = false
    if side == "left" then
      if fitL then
        x = xl found = true
      elseif fitR then
        x = xr found = true
      end
    else
      if fitR then
        x = xr found = true
      elseif fitL then
        x = xl found = true
      end
    end
    local y = inUI(owner, owner:GetTop())
    if y > sh then
      y = sh
    end
    if y - th < 0 then
      y = th
    end
    tip:ClearAllPoints()
    if found then
      tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / ts, y / ts)
      return
    end
    local gt = top; local gb = inUI(main, main:GetBottom())
    if panelOpen then
      gt = math.max(top, inUI(P.w.frame, P.w.frame:GetTop()))
      gb = math.min(gb, inUI(P.w.frame, P.w.frame:GetBottom()))
    end
    local cx = ((gl + gr) / 2) / ts
    if gt + 4 + th <= sh then
      tip:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx, (gt + 4) / ts)
      return
    end
    tip:SetPoint("TOP", UIParent, "BOTTOMLEFT", cx, (gb - 4) / ts)
  end
  -- Tooltip on hover. build(tooltip, owner) fills the lines. opts.delay: seconds of hover before it shows (T2).
  -- j1c U2 (UX-A 3): the delay is real time (GetTime) since the last click or mouse-enter, not summed frame dt (j1b capped
  -- dt at 0.1 s, so under load the 0.8-s wait took 8+ slow frames). GetTime is the time of the current frame: a click
  -- handled between frames right after a hitch carries the old frame's time. So the wait starts at the first frame whose
  -- time is later than the click (fresh: at = that frame's time) and never shows the tooltip in that frame; from then on
  -- real time decides. Costs at most one frame of extra delay.
  local tipWait = { owner = nil, at = 0, delay = 0, fresh = false }
  local tipTimer = CreateFrame("Frame")
  tipTimer:Hide()
  tipTimer:SetScript("OnUpdate", function(self)
    local o = tipWait.owner
    if o == nil then
      self:Hide()
      return
    end
    local now = GetTime()
    if tipWait.fresh then
      if now > tipWait.at then
        tipWait.at = now
        tipWait.fresh = false
      end
      return
    end
    if now - tipWait.at >= tipWait.delay then
      self:Hide()
      tipWait.owner = nil
      K.ShowTip(o)
    end
  end)
  local function tipStart(frame, delay)
    tipWait.owner = frame
    tipWait.at = GetTime()
    tipWait.delay = delay
    tipWait.fresh = true
    tipTimer:Show()
  end
  -- j2b WoW S1: none of our tooltips in combat (window, panel, bar, minimap button; with "Hide in combat" off).
  -- rt.inCombat is our flag from PLAYER_REGEN_DISABLED to _ENABLED, so it also covers InCombatLockdown()
  K.NoTips = function()
    local rt = Mrgl.Core.rt
    return rt ~= nil and rt.inCombat == true
  end
  K.ShowTip = function(owner)
    if owner.mrglTip == nil or not owner:IsVisible() or K.NoTips() then
      return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    owner.mrglTip(GameTooltip, owner)
    GameTooltip:Show()
    K.PlaceTip(owner)
  end
  K.Tip = function(frame, build, opts)
    frame.mrglTip = build
    local delay = 0
    if opts ~= nil and opts.delay ~= nil then
      delay = opts.delay
    end
    frame.mrglTipDelay = delay
    frame:HookScript("OnEnter", function(self)
      self.mrglHover = true
      -- r4 T6: a delayed tooltip always waits its full delay from OnEnter (not from the last click)
      if delay > 0 then
        tipStart(self, delay)
        return
      end
      K.ShowTip(self)
    end)
    frame:HookScript("OnLeave", function(self)
      self.mrglHover = false
      if tipWait.owner == self then
        tipWait.owner = nil
        tipTimer:Hide()
      end
      K.HideOwnTip()
    end)
    frame:EnableMouse(true)
  end
  -- port p2 (review p1 Lua M2): hide GameTooltip only while one of our frames owns it (owner.mrglTip)
  K.HideOwnTip = function()
    local o = GameTooltip:GetOwner()
    -- port p3 (review p2 WoW K3): never index a forbidden owner
    if o ~= nil and not (o.IsForbidden ~= nil and o:IsForbidden()) and o.mrglTip ~= nil then
      GameTooltip:Hide()
    end
  end
  -- T2: a click (or Space/F on the hovered enemy) hides a delayed tooltip and restarts the wait
  K.TipPoke = function(frame)
    if frame.mrglTipDelay == nil or frame.mrglTipDelay <= 0 then
      return
    end
    if GameTooltip:GetOwner() == frame then
      GameTooltip:Hide()
    end
    if frame.mrglHover == true then
      tipStart(frame, frame.mrglTipDelay)
    end
  end
  -- Rebuild an open tooltip (values change while hovering), at most 5 times a second (W8)
  local lastTipRefresh = 0
  K.RefreshTip = function()
    local o = GameTooltip:GetOwner()
    if o == nil or not GameTooltip:IsShown() then
      return
    end
    -- j1c H3: a forbidden tooltip or owner (secure UI) is not ours to touch; checked before any field of the owner
    if (GameTooltip.IsForbidden ~= nil and GameTooltip:IsForbidden()) or (o.IsForbidden ~= nil and o:IsForbidden()) then
      return
    end
    if o.mrglTip == nil then
      return
    end
    if K.NoTips() then
      GameTooltip:Hide()
      return
    end -- j2b WoW S1: ours, and combat started: away
    local now = GetTime()
    if now - lastTipRefresh < 0.2 then
      return
    end
    lastTipRefresh = now
    GameTooltip:ClearLines()   -- no SetOwner: that would re-anchor and reset the tooltip
    o.mrglTip(GameTooltip, o)
    GameTooltip:Show()
    -- j1b W1: owners with their own anchor (the minimap button) keep it; the rebuild only refreshes the lines
    if o.mrglTipKeepAnchor ~= true then
      K.PlaceTip(o)
    end
  end
  -- Lets a child frame move the main window by dragging
  K.DragThrough = function(frame, target, onStop)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
      target:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
      target:StopMovingOrSizing()
      if onStop ~= nil then
        onStop()
      end
    end)
  end
  -- ------------------------------------------------------------ animation helpers (AnimationGroup only)
  K.Replay = function(g)
    if g:IsPlaying() then
      g:Stop()
    end
    g:Play()
  end
  -- Scale animation values: SetScaleFrom/SetScaleTo, older clients only know SetFromScale/SetToScale (RezRadar)
  K.ScaleFrom = function(a, x, y)
    if a.SetScaleFrom then
      a:SetScaleFrom(x, y)
    else
      a:SetFromScale(x, y)
    end
  end
  K.ScaleTo = function(a, x, y)
    if a.SetScaleTo then
      a:SetScaleTo(x, y)
    else
      a:SetToScale(x, y)
    end
  end
  K.AddAlpha = function(g, from, to, dur, delay, order, smooth)
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    a:SetDuration(dur)
    a:SetStartDelay((delay == nil and 0 or delay))
    a:SetOrder((order == nil and 1 or order))
    if smooth ~= nil then
      a:SetSmoothing(smooth)
    end
    return a
  end
  K.AddScale = function(g, from, to, dur, delay, order, smooth, origin)
    local a = g:CreateAnimation("Scale")
    K.ScaleFrom(a, from, from)
    K.ScaleTo(a, to, to)
    a:SetDuration(dur)
    a:SetStartDelay((delay == nil and 0 or delay))
    a:SetOrder((order == nil and 1 or order))
    if smooth ~= nil then
      a:SetSmoothing(smooth)
    end
    a:SetOrigin((origin == nil and "CENTER" or origin), 0, 0)
    return a
  end
  K.AddMove = function(g, x, y, dur, delay, order, smooth)
    local a = g:CreateAnimation("Translation")
    a:SetOffset(x, y)
    a:SetDuration(dur)
    a:SetStartDelay((delay == nil and 0 or delay))
    a:SetOrder((order == nil and 1 or order))
    if smooth ~= nil then
      a:SetSmoothing(smooth)
    end
    return a
  end
  -- j1 A1: a glow fades in once (0 -> to in dur) and then stands still. No loop (the BOUNCE pulse is gone).
  -- The region itself keeps alpha `to`, so the glow stays after the group has ended.
  K.Pulse = function(region, to, dur)
    local g = region:CreateAnimationGroup()
    K.AddAlpha(g, 0, to, dur, 0, 1, "OUT")
    region:SetAlpha(to)
    return g
  end
  -- Slide in from an offset: order 1 jumps to (dx, dy) instantly, order 2 moves back, plus fade in
  K.SlideIn = function(region, dx, dy, dur)
    local g = region:CreateAnimationGroup()
    K.AddMove(g, dx, dy, 0, 0, 1)
    K.AddMove(g, -dx, -dy, dur, 0, 2, "OUT")
    K.AddAlpha(g, 0, 1, dur, 0, 2, "OUT")
    return g
  end
  K.FadeIn = function(region, dur)
    local g = region:CreateAnimationGroup()
    K.AddAlpha(g, 0, 1, dur, 0, 1, "OUT")
    return g
  end
end
