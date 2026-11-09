local ADDON, Mrgl = ...
-- Mrgl Squad - UI/Main.lua equivalent: the compact window MrglSquadFrame (240 x 304, plan 3.2, r2 changes).
-- r2 L1: fixed frame levels relative to MrglSquadFrame, each its own frame:
--   +1 surface (zone tint, spotlight, onboarding ring)   +2 content (enemy, HP, timer, squad, bars, boss button)
--   +4 fx (flash, sparks, rings)   +6 numbers   +8 coins   +10 headline   +12 popup / settings (Popup.js)
Mrgl.UI = Mrgl.UI or {}
do
  local zoneTint
  local K, C, Core, F, Tips, J, S, lv, layer, savePosition, zoneGradient, buildPortrait, buildAbility, spotLook, setEnemyLook, refreshBossButton, setTimeFont, refreshAbility, showHead, buyDesat, saveShown, saveTarget, refreshBuyBest, updateSaveFill, measureEdgeSpans, edgeHitsText, plusAlpha, updateGoldPlus
  local buildCompanion
  local M = {}
  Mrgl.UI.Main = M
  local U = Mrgl.U
  function K()
    return Mrgl.UI.Kit
  end
  function C()
    return Mrgl.UI.Kit.C
  end
  function Core()
    return Mrgl.Core
  end
  function F()
    return Mrgl.Core.Formula
  end
  function Tips()
    return Mrgl.UI.Tips
  end
  function J()
    return Mrgl.UI.Juice
  end
  function S()
    return Mrgl.Data.Strings
  end
  M.LEVEL = { surface = 1, content = 2, fx = 4, numbers = 6, coins = 8, headline = 10, popup = 12 }
  -- fixed geometry (window units from TOPLEFT, y down is negative); Juice uses it instead of GetCenter (W3)
  -- r3 L10: coins end at the GoldIcon RIGHT (-1, 0) and turn under the head row (coinCtrl)
  -- j1 M1 / j2 A3: minimize at TOPRIGHT -24 (the speaker button is gone), the gold icon is back at -46
  M.GEO = { w = 240, h = 304, enemyX = 120, enemyY = -94, enemyHalf = 44, goldIconX = 187.5, goldIconY = -13.5, goldIconHalf = 6.5, coinCtrlX = 182, coinCtrlY = -34, hMin = 26 }
  local w = {} -- widgets
  M.w = w
  local st = { goldShown = 0, goldFrom = 0, goldTo = 0, goldT = 1, goldHold = 0, lag = 1, lagDelay = 0, hpFrac = 1, enemyLocked = false, zone = 0, tintA = true, bossState = "", autoCd = false, t = 0, hopT = 0, unlockAt = {}, collectPulse = false, wasPopup = false, zoneDefer = false, bossHide = false, strBase = -1, pxScale = 0, hoverA = 0, nameA = 1, nameTarget = 1, saveTo = -1, saveFill = -1, saveMark = -1, bossAwayUntil = 0, plusT = -1, plusFresh = false, buyLow = false, min = false, dimA = 1, clickAt = -10, compHold = {}, anyfinHold = false, lookKey = "", lookT = -100, lookFast = false, lookBoss = false, lookIcon = "", xfade = 0 } -- New Tide F: held companions and Anyfin look; tide1d D2: held enemy look
  local BOSS_AWAY = 3
  -- j1b G1: the enemy icon fades to 0.35 while a gold moment stands (Juice.EnemyDim), in 0.2 s, back in 0.3 s; alpha only
  -- j1c M4: an enemy clicked in the last clickT s only fades to aClick (it must not look dead while it is the target)
  M.DIM = { a = 0.35, aClick = 0.6, clickT = 1, inT = 0.2, outT = 0.3 }
  -- r4 K1: "+X" at the gold: in 0.2 s, hold until 1.8 s, out until 2.2 s (was an animation group, see M.GoldPlus)
  local PLUS_IN = 0.2; local PLUS_HOLD = 1.8; local PLUS_END = 2.2
  M.st = st
  -- tide1c C15: every layer sits one level higher than before, so the zone tint frames (main + 1) lie under the surface
  function lv(frame, n)
    frame:SetFrameLevel(w.frame:GetFrameLevel() + 1 + n)
  end
  M.SetLevel = lv
  function layer(name, n)
    local l = CreateFrame("Frame", name, w.frame)
    l:SetAllPoints(w.frame)
    lv(l, n)
    return l
  end
  -- j1 #13: one drag for the window (main frame, head buttons, portraits, panel). While it moves nothing sets points on
  -- main or the panel and nothing saves the position; DragStop saves, snaps (ApplyPosition) and reanchors once.
  -- A missed OnDragStop (button released elsewhere, window hidden) is caught in OnUpdate / OnHide.
  local drag = { on = false, min = -1, dbgT = 0 }
  -- j1b D1 (Jan #13, Persona S1): drag log. M.DragDebug = function(line) is the printer (Debug.lua /mrgl debug drag:
  -- chat; browser MrglDev.dragDebug: console); nil = off. Lines at start, every 0.25 s while moving (OnUpdate),
  -- stop (the raw position before the save) and snap (after ApplyPosition: a jump shows as a difference to stop).
  -- grab = cursor minus the window's top-left in frame units: it stays constant while the window follows the mouse.
  M.DragDebug = nil
  local function dbgNum(v)
    if v == nil then
      return "?"
    end
    return U.Fmt(v, 1)
  end
  M.DragLine = function(phase)
    local f = w.frame
    local es = f:GetEffectiveScale()
    local pt = "none"
    if f:GetNumPoints() > 0 then
      local p1, _, p3, px, py = f:GetPoint(1) -- point, relativeTo, relativePoint, x, y
      pt = p1 .. ">" .. p3 .. " " .. dbgNum(px) .. "," .. dbgNum(py)
    end
    local c1, c2 = GetCursorPosition()
    local cx, cy = c1 / es, c2 / es
    local l, t = f:GetLeft(), f:GetTop()
    local grab = "?"
    if l ~= nil and t ~= nil then
      grab = dbgNum(cx - l) .. "," .. dbgNum(t - cy)
    end
    return "drag " .. phase .. ": point " .. pt .. " | left,top " .. dbgNum(l) .. "," .. dbgNum(t)
      .. " | cursor " .. dbgNum(cx) .. "," .. dbgNum(cy) .. " (px " .. dbgNum(c1) .. "," .. dbgNum(c2) .. ") | grab " .. grab
      .. " | scale " .. U.Dec(Mrgl.db.settings.scale, 3) .. " eff " .. U.Dec(es, 3) .. " ui " .. U.Dec(UIParent:GetEffectiveScale(), 3)
  end
  local function dragLog(phase)
    if M.DragDebug ~= nil then
      M.DragDebug(M.DragLine(phase))
    end
  end
  M.IsMoving = function()
    return drag.on
  end
  M.DragStart = function()
    if drag.on then
      return
    end
    drag.on = true
    drag.dbgT = 0
    w.frame:Raise()
    w.frame:StartMoving()
    dragLog("start")
  end
  M.DragStop = function()
    if not drag.on then
      return
    end
    drag.on = false
    w.frame:StopMovingOrSizing()
    dragLog("stop")
    savePosition()
    M.ApplyPosition() -- snap to the saved (whole-unit) position: saved = shown
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Reanchor()
    end
    dragLog("snap")
    if drag.min >= 0 then
      local m = drag.min == 1
      drag.min = -1
      M.SetMinimized(m) -- deferred minimize key
    end
  end
  M.Drag = function(frame)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
      M.DragStart()
    end)
    frame:SetScript("OnDragStop", function()
      M.DragStop()
    end)
  end
  -- j2 A1 (Jan j2 #1): the window is anchored at its BOTTOM (BOTTOMLEFT of UIParent BOTTOMLEFT). Minimized, the 26-px bar
  -- sits on the former bottom edge; restoring grows the window upward. Any other point (TOPLEFT saves before j2, the point
  -- a move leaves, the point Popup.SetScale keeps) is converted by geometry in frame units, not rounded (0 px). It needs
  -- no layout (works while hidden) and keeps clamping as it was: the same unclamped rect. "" (default place) stays.
  local PFX = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
  local PFY = { BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, TOPLEFT = 1, TOP = 1, TOPRIGHT = 1 }
  local function bottomLeft(point, rel, x, y, h)
    if PFX[point] == nil or PFX[rel] == nil then
      return nil
    end
    local f = w.frame
    local k = UIParent:GetEffectiveScale() / f:GetEffectiveScale() -- UIParent units -> frame units
    return { x = PFX[rel] * UIParent:GetWidth() * k + x - PFX[point] * f:GetWidth(),
             y = PFY[rel] * UIParent:GetHeight() * k + y - PFY[point] * h }
  end
  -- load = true only from ApplyPosition (the load path), never from a drag stop or a toggle
  local function anchorBottom(load)
    local s = Mrgl.db.settings
    if s.point == "" or s.rel == "" or (s.point == "BOTTOMLEFT" and s.rel == "BOTTOMLEFT") then
      return
    end
    -- j2b K1 (orchestrator, Jan wants the bar at the bottom): a MINIMIZED pre-j2 save (TOPLEFT of TOPLEFT, j1 kept the
    -- top edge) puts the bar once at the OLD FULL window's bottom edge (bar bottom = old top - full height): a deliberate
    -- one-time jump. A full-window TOPLEFT save keeps its 0-px migration; afterwards the save is BOTTOMLEFT (no-op).
    local h = w.frame:GetHeight()
    if load == true and Mrgl.db.settings.minimized == true and s.point == "TOPLEFT" and s.rel == "TOPLEFT" then
      h = M.GEO.h
    end
    local b = bottomLeft(s.point, s.rel, s.x, s.y, h)
    if b == nil then
      return
    end
    s.point = "BOTTOMLEFT"
    s.rel = "BOTTOMLEFT"
    s.x = b.x
    s.y = b.y -- our SavedVariables own the position
    if drag.on then
      return
    end -- j1 #13: nothing sets points during a drag
    local f = w.frame
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", b.x, b.y)
    f:SetUserPlaced(false)
  end
  function savePosition()
    if drag.on then
      return
    end -- j1 #13
    -- GetPoint returns point, relativeTo, relativePoint, x, y
    local point, _, relPoint, px, py = w.frame:GetPoint(1)
    w.frame:SetUserPlaced(false) -- our SavedVariables own the position, not layout-local.txt
    local s = Mrgl.db.settings
    s.point = point
    s.rel = relPoint
    s.x = px
    s.y = py
    anchorBottom() -- j2 A1: saved as BOTTOMLEFT
    s.x = math.floor(s.x + 0.5)
    s.y = math.floor(s.y + 0.5)
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Reanchor()
    end
  end
  M.SavePosition = savePosition
  M.ApplyPosition = function()
    if drag.on then
      return
    end -- j1 #13: DragStop applies the position once
    local s = Mrgl.db.settings
    local f = w.frame
    f:SetScale(s.scale) -- j2 A1: before the conversion (frame units)
    anchorBottom(true) -- j2 A1: one-time migration of an old save (TOPLEFT): the window stays where it was (K1: bar)
    f:ClearAllPoints()
    if s.point ~= "" and s.rel ~= "" then
      f:SetPoint(s.point, UIParent, s.rel, s.x, s.y)
    else
      f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -90, 190)
    end
    K().PixelRefresh()
  end
  M.ResetPosition = function()
    local s = Mrgl.db.settings
    s.point = ""
    s.rel = ""
    s.x = 0
    s.y = 0
    M.ApplyPosition()
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Reanchor()
    end
  end
  -- ------------------------------------------------------------ j1 M1-M5: minimize to the head row
  -- Minimized: 26 px high, only the head frame (stage, pips, gold, minimize, close) stays; the content layer and
  -- all effect layers are hidden. The core runs on, bindings still work. No animation: the switch is instant.
  local function minSaved()
    return Mrgl.db.settings.minimized == true -- core builds the field; read defensively
  end
  -- j2 A1 (was j1 M2 anchorTop): the BOTTOM edge stays. SetMinimized converts any other point to BOTTOMLEFT (anchorBottom,
  -- frame units, not rounded: +-0 px) before the height changes; the default place (BOTTOMRIGHT) keeps its bottom too.
  -- j1b U3 (UX-A): Restore in the minimized bar in the gold text's colour (white, alpha 1), no glow; it is the bar's only
  -- control. Minimize in the full window stays muted and turns white on hover (like Close).
  local function minTint(hover)
    if st.min or hover == true then
      K().SetVertex(w.minIcon, C().white)
    else
      K().SetVertex(w.minIcon, C().muted)
    end
  end
  -- visual state from db.settings.minimized (Build, Reset, SetMinimized); no re-anchor here
  M.ApplyMinimized = function()
    local on = minSaved()
    st.min = on
    -- New Tide F/Q: minimizing ends the moment at once (veil 0, headlines gone); the popup lives in the full window only
    if on then
      J().TideAbort()
      Mrgl.UI.Popup.TideCancel()
    end
    local f = w.frame
    if on then
      f:SetHeight(M.GEO.hMin)
    else
      f:SetHeight(M.GEO.h)
    end
    local body = { w.zoneLayer, w.surface, w.content, w.fx, w.numbers, w.coins, w.headLayer } -- tide1c C15: zone layer too
    for i = 1, U.Len(body) do
      U.At(body, i):SetShown(not on)
    end
    local I = Mrgl.Data.Icons
    if on then
      w.minIcon:SetTexture(K().Media(I.restore))
    else
      w.minIcon:SetTexture(K().Media(I.minimize))
    end
    minTint(w.min:IsMouseOver())
    if on then
      w.min:SetAlpha(1) -- j1b U3: at once, not only from the next OnUpdate
    end
    M.PlaceGoldPlus(on)
    -- the panel closes while minimized; db.settings.panel keeps whether it was open (Panel.Show stays closed)
    local P = Mrgl.UI.Panel
    if P ~= nil and P.w.frame ~= nil then
      if on and P.IsOpen() then
        local was = Mrgl.db.settings.panel
        P.Show(false, true)
        Mrgl.db.settings.panel = was
      elseif not on and Mrgl.db.settings.panel and not P.IsOpen() then
        P.Show(true, true)
      end
    end
  end
  M.IsMinimized = function()
    return st.min
  end
  -- "+X" at the gold: under the GoldIcon; minimized left of the gold text (under the icon lies outside the 26-px bar)
  M.PlaceGoldPlus = function(min)
    w.goldPlus:ClearAllPoints()
    if min then
      w.goldPlus:SetPoint("RIGHT", w.goldText, "LEFT", -4, 0)
    else
      w.goldPlus:SetPoint("TOPRIGHT", w.goldIcon, "BOTTOMRIGHT", 0, -1)
    end
  end
  M.SetMinimized = function(on)
    local v = on == true
    if drag.on then
      if v then
        drag.min = 1
      else
        drag.min = 0
      end
      return
    end -- j1 #13: after the drag
    if v == st.min and v == minSaved() then
      return
    end
    anchorBottom()
    Mrgl.db.settings.minimized = v
    M.ApplyMinimized()
    -- j1b U3 (UX-B S1): the Minimize/Restore tooltip would stay at its old place over the panel; hide it on every toggle
    if GameTooltip:GetOwner() == w.min then
      GameTooltip:Hide()
    end
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Reanchor()
    end
    M.Refresh()
    if Mrgl.UI.Save ~= nil then
      Mrgl.UI.Save()
    end -- M5: the state survives /reload at once
  end
  -- j1 B2: the tint colour is in the texture itself at alpha 0.28; the gradient only fades its alpha (white vertex 0 -> 1).
  -- If the client ever drops the gradient, a flat tint at 0.28 stays: never a white area.
  function zoneGradient(tex, tint)
    tex:SetColorTexture(U.At(tint, 1), U.At(tint, 2), U.At(tint, 3), 0.28)
    tex:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
  end
  -- ------------------------------------------------------------ build
  M.Build = function()
    local I = Mrgl.Data.Icons
    -- r2 R1: tooltip border (BackdropTemplate, UI-Tooltip-Border, edge 12, insets 3)
    local f = CreateFrame("Frame", "MrglSquadFrame", UIParent, "BackdropTemplate")
    w.frame = f
    f:SetSize(240, 304)
    -- j1 P2 (coordinator, Jan's 8-panel-noch-durchsichtig.png): DIALOG, because Attune's tracker is HIGH too
    -- (Attune.lua:4035) and the order inside one strata is a coin toss. Tooltips (TOOLTIP) stay above.
    -- Panel, popup and settings are children and inherit it; the levels stay relative (L1). Toplevel + Raise on
    -- mouse-down: the window comes in front of other DIALOG frames when clicked.
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:HookScript("OnMouseDown", function()
      f:Raise()
    end)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    -- j1 P1: the backdrop draws only the edge; the background is an own opaque texture (Panel.Backdrop)
    w.bg = Mrgl.UI.Panel.Backdrop(f, C().bg)
    M.Drag(f) -- j1 #13
    f:HookScript("OnHide", function()
      M.DragStop()
    end)
    f:HookScript("OnShow", function()
      M.ApplyZoneLook()
    end) -- tide1c C15
    -- ---------------- layer frames (L1)
    w.surface = layer("MrglSquadSurface", M.LEVEL.surface)
    w.content = layer("MrglSquadContent", M.LEVEL.content)
    w.fx = layer("MrglSquadFx", M.LEVEL.fx)
    w.numbers = layer("MrglSquadNumbers", M.LEVEL.numbers)
    w.coins = layer("MrglSquadCoins", M.LEVEL.coins)
    w.headLayer = layer("MrglSquadHeadline", M.LEVEL.headline)
    -- j1 M2: the head row has its own frame at the content level; minimized hides content and the other layers
    w.head = layer("MrglSquadHead", M.LEVEL.content)
    local sf = w.surface; local cf = w.content; local hf = w.head
    -- ---------------- surface: zone tint, spotlight, onboarding ring (behind the enemy)
    -- tide1c C15: each tint has its own frame; fades and Hide go to the frames, never SetAlpha or an animation on the
    -- gradient textures (in WoW that flattens the gradient and SetAlpha(0) does not hide it)
    -- the zone layer (main + 1, under the surface) holds both tint frames; minimized hides it with the other layers
    w.zoneLayer = CreateFrame("Frame", "MrglSquadZone", f)
    w.zoneLayer:SetAllPoints(f)
    w.zoneLayer:SetFrameLevel(f:GetFrameLevel() + 1)
    w.zoneFrameA = CreateFrame("Frame", nil, w.zoneLayer)
    w.zoneFrameA:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    w.zoneFrameA:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    w.zoneFrameA:SetHeight(127)
    w.zoneFrameB = CreateFrame("Frame", nil, w.zoneLayer)
    w.zoneFrameB:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    w.zoneFrameB:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    w.zoneFrameB:SetHeight(127)
    w.zoneFrameB:Hide()
    w.zoneFrameA:SetFrameLevel(f:GetFrameLevel() + 1) -- under the surface layer (spotlight, whelps), over the window bg
    w.zoneFrameB:SetFrameLevel(f:GetFrameLevel() + 1)
    w.zoneA = w.zoneFrameA:CreateTexture(nil, "BACKGROUND")
    w.zoneA:SetAllPoints(w.zoneFrameA)
    w.zoneB = w.zoneFrameB:CreateTexture(nil, "BACKGROUND")
    w.zoneB:SetAllPoints(w.zoneFrameB)
    w.zoneFadeA = K().FadeIn(w.zoneFrameA, 1)
    w.zoneFadeA:SetToFinalAlpha(true)
    w.zoneFadeB = K().FadeIn(w.zoneFrameB, 1)
    w.zoneFadeB:SetToFinalAlpha(true)
    w.zoneFadeA:SetScript("OnFinished", function()
      M.ApplyZoneLook()
    end)
    w.zoneFadeA:SetScript("OnStop", function()
      M.ApplyZoneLook()
    end)
    w.zoneFadeB:SetScript("OnFinished", function()
      M.ApplyZoneLook()
    end)
    w.zoneFadeB:SetScript("OnStop", function()
      M.ApplyZoneLook()
    end)
    w.spot = K().Glow(sf, "glow", 170, C().gold, "ARTWORK")
    w.spot:SetPoint("CENTER", f, "TOPLEFT", M.GEO.enemyX, M.GEO.enemyY)
    w.spot:SetAlpha(0.15) -- j1 #22
    -- onboarding: ring hugging the enemy box, behind it (never over the name or HP text)
    w.onboardRing = K().Glow(sf, "ring", 106, C().gold, "ARTWORK", 1)
    w.onboardRing:SetPoint("CENTER", f, "TOPLEFT", M.GEO.enemyX, M.GEO.enemyY)
    w.onboardRing:Hide()
    -- ---------------- head
    w.stageWrap = CreateFrame("Frame", "MrglSquadStage", hf)
    lv(w.stageWrap, 2)
    w.stageWrap:SetSize(22, 14)
    w.stageWrap:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
    w.stage = K().Text(w.stageWrap, K().FRIZ, 13, C().gold, "OUTLINE")
    w.stage:SetPoint("LEFT", w.stageWrap, "LEFT", 0, 0)
    -- j1 A1: no scale above 1.05 outside the rings (was 1.35)
    w.stagePop = w.stageWrap:CreateAnimationGroup()
    K().AddScale(w.stagePop, 1, 1.05, 0.12, 0, 1, "OUT", "LEFT")
    K().AddScale(w.stagePop, 1.05, 1, 0.2, 0, 2, "IN", "LEFT")
    w.pips = {  }
    for i = 1, 10 do
      local p = hf:CreateTexture(nil, "ARTWORK")
      p:SetSize(6, 6)
      p:SetPoint("TOPLEFT", f, "TOPLEFT", 40 + (i - 1) * 8, -10)
      p:SetColorTexture(1, 1, 1, 0.15) -- j1 #19: no pop, the pip only fills
      U.Insert(w.pips, p)
    end
    -- L3: only the skull marks a boss fight (the word "Boss" is gone)
    w.bossMark = K().Icon(hf, I.skull, "ARTWORK")
    w.bossMark:SetSize(12, 12)
    w.bossMark:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -7)
    w.stageHit = CreateFrame("Button", "MrglSquadStageHit", hf)
    lv(w.stageHit, 2)
    w.stageHit:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
    w.stageHit:SetSize(116, 20)
    M.Drag(w.stageHit)
    K().Tip(w.stageHit, function(tt)
      Tips().Stage(tt)
    end)
    -- New Tide H: TideMark 12 x 12 at the pips' place (like the boss skull; the pips hide while it stands), also minimized.
    -- Own 16 x 16 button one level over stageHit; it fades in once (0.4 s) and then stands still, no pulse
    w.tideMark = CreateFrame("Button", "MrglSquadTideMark", hf)
    lv(w.tideMark, 3)
    w.tideMark:SetSize(16, 16)
    w.tideMark:SetPoint("TOPLEFT", f, "TOPLEFT", 38, -5)
    w.tideMarkIcon = K().Icon(w.tideMark, Mrgl.Data.Tide.icon, "ARTWORK")
    w.tideMarkIcon:SetSize(12, 12)
    w.tideMarkIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -7)
    w.tideMarkIn = K().FadeIn(w.tideMarkIcon, 0.4)
    K().Border(w.tideMark, C().gold, "OVERLAY", 1) -- tide1c C9: a static 1-px gold edge round the icon ("ready")
    M.Drag(w.tideMark)
    K().Tip(w.tideMark, function(tt)
      Tips().TideMark(tt)
    end)
    -- tide1c C10: tab 4 and, when New Tide is ready, the popup at once (2 clicks instead of 3)
    w.tideMark:SetScript("OnClick", function()
      Mrgl.UI.Panel.OpenTide()
      if Core().Tide.Ready() then
        Mrgl.UI.Popup.ShowTide()
      end
    end)
    w.tideMark:Hide()
    -- j2 A3: minimize 14x14 at -24 (only while the mouse is over the window), Close at -6, GoldIcon at -46
    w.goldIcon = K().Icon(hf, I.coin, "ARTWORK")
    w.goldIcon:SetSize(13, 13)
    w.goldIcon:SetPoint("TOPRIGHT", f, "TOPRIGHT", -46, -7)
    -- j1 #20: no gold icon pop
    w.goldWrap = CreateFrame("Frame", "MrglSquadGoldWrap", hf)
    lv(w.goldWrap, 2)
    w.goldWrap:SetSize(90, 16)
    w.goldWrap:SetPoint("RIGHT", w.goldIcon, "LEFT", -3, 0)
    w.goldText = K().Text(w.goldWrap, K().ARIALN, 15, C().white, "OUTLINE")
    w.goldText:SetPoint("RIGHT", w.goldWrap, "RIGHT", 0, 0)
    w.goldText:SetJustifyH("RIGHT")
    w.goldHit = CreateFrame("Button", "MrglSquadGoldHit", hf)
    lv(w.goldHit, 2)
    w.goldHit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -3)
    w.goldHit:SetSize(84, 20)
    M.Drag(w.goldHit)
    K().Tip(w.goldHit, function(tt)
      Tips().Gold(tt)
    end)
    w.goldPlus = K().Text(hf, K().ARIALN, 11, C().good, "OUTLINE")
    M.PlaceGoldPlus(false)
    w.goldPlus:SetJustifyH("RIGHT")
    w.goldPlus:SetAlpha(0) -- r4 K1: faded per frame (M.GoldPlus), so a long frame cannot skip it
    -- j1 M1: minimize / restore (minimize.tga, restore.tga while minimized); muted, white on hover, like Close
    w.min = CreateFrame("Button", "MrglSquadMinimize", hf)
    lv(w.min, 2)
    w.min:SetSize(14, 14)
    w.min:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -6)
    w.minIcon = w.min:CreateTexture(nil, "ARTWORK")
    w.minIcon:SetTexture(K().Media(I.minimize))
    w.minIcon:SetAllPoints(w.min)
    K().SetVertex(w.minIcon, C().muted)
    w.min:SetAlpha(0)
    w.min:SetScript("OnEnter", function()
      minTint(true)
    end)
    w.min:SetScript("OnLeave", function()
      minTint(false)
    end)
    K().Tip(w.min, function(tt)
      if st.min then
        Tips().Title(tt, S().RESTORE)
      else
        Tips().Title(tt, S().MINIMIZE)
      end
    end)
    w.min:SetScript("OnClick", function()
      M.SetMinimized(not st.min)
    end)
    w.close = CreateFrame("Button", "MrglSquadClose", hf)
    lv(w.close, 2)
    w.close:SetSize(16, 16)
    w.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -5)
    -- W1: own white texture, tinted (no rotated color quads)
    w.closeTex = w.close:CreateTexture(nil, "ARTWORK")
    w.closeTex:SetTexture(K().Media(I.close))
    w.closeTex:SetAllPoints(w.close)
    K().SetVertex(w.closeTex, C().muted)
    w.close:SetScript("OnEnter", function()
      K().SetVertex(w.closeTex, C().white)
    end)
    w.close:SetScript("OnLeave", function()
      K().SetVertex(w.closeTex, C().muted)
    end)
    K().Tip(w.close, Tips().Simple(S().CLOSE, S().CLOSE_TIP))
    w.close:SetScript("OnClick", function()
      Mrgl.UI.Toggle(false)
    end)
    -- ---------------- name row (L3: TOP 0,-28, 220 x 20; the headline uses the same place on +10)
    w.name = K().Text(cf, K().FRIZ, 12, C().text, "OUTLINE")
    w.name:SetPoint("CENTER", f, "TOP", 0, -38)
    w.name:SetJustifyH("CENTER")
    -- ---------------- enemy
    local e = CreateFrame("Button", "MrglSquadEnemy", cf)
    w.enemy = e
    lv(e, 2)
    e:SetSize(88, 88)
    e:SetPoint("TOP", f, "TOP", 0, -50)
    e:RegisterForClicks("LeftButtonDown", "RightButtonDown") -- j5 K6 (Jan: "mit linksklick UND rechtsklick angreifen")
    K().Fill(e, C().black, "BACKGROUND")
    w.enemyBorder = K().Border(e, { 1, 1, 1, 0.25 }, "BORDER", 1)
    w.enemyIcon = K().Icon(e, nil, "ARTWORK")
    w.enemyIcon:SetPoint("TOPLEFT", e, "TOPLEFT", 2, -2)
    w.enemyIcon:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -2, 2)
    -- r4 J1: the dark square of the punch (r3 K2) is a region of the enemy frame, so die/spawn scale and fade it
    -- with the icon; Juice shows it only with a punch on a living enemy and hides it on KILL and SPAWN
    w.enemyBack = e:CreateTexture(nil, "BACKGROUND", nil, 1)
    w.enemyBack:SetAllPoints(w.enemyIcon)
    K().SetColor(w.enemyBack, C().black)
    w.enemyBack:Hide()
    -- M3: inner rare border 2 px
    w.enemyRareBorder = K().Border(e, C().rare, "OVERLAY", 1, 2)
    w.enemyRareBorder:SetShown(false)
    w.enemyBadge = e:CreateTexture(nil, "OVERLAY", nil, 2)
    w.enemyBadge:SetSize(16, 16)
    w.enemyBadge:SetPoint("TOPLEFT", e, "TOPLEFT", -4, 4)
    w.enemyBadge:Hide()
    -- enemies1: a static 1-px black edge behind the boss skull (18 x 18, like the face badge), only with the skull
    w.enemyBadgeBg = e:CreateTexture(nil, "OVERLAY", nil, 1)
    w.enemyBadgeBg:SetSize(18, 18)
    w.enemyBadgeBg:SetPoint("TOPLEFT", e, "TOPLEFT", -5, 5)
    w.enemyBadgeBg:SetColorTexture(0, 0, 0, 1)
    w.enemyBadgeBg:Hide()
    -- enemies1 G4 (E3.2): King Mrgl-Mrgl. tint = the head desaturated x tint plus an ADD copy at 0.6 x tint (like K.HeadOf);
    -- face = the human inside, 22 x 22 BOTTOMLEFT 4,4 on a black 24 x 24. Static (alpha only with the picture).
    w.enemyIconAdd = K().Icon(e, nil, "ARTWORK", 1)
    w.enemyIconAdd:SetAllPoints(w.enemyIcon)
    w.enemyIconAdd:SetBlendMode("ADD")
    w.enemyIconAdd:SetDesaturated(true)
    w.enemyIconAdd:Hide()
    -- enemies1b F3: the old picture during the fast-mode crossfade (above the new picture and its ADD copy, under the badges)
    w.enemyIconOld = K().Icon(e, nil, "ARTWORK", 2)
    w.enemyIconOld:SetAllPoints(w.enemyIcon)
    w.enemyIconOld:Hide()
    w.enemyFaceBg = e:CreateTexture(nil, "OVERLAY", nil, 2)
    w.enemyFaceBg:SetSize(24, 24)
    w.enemyFaceBg:SetPoint("BOTTOMLEFT", e, "BOTTOMLEFT", 3, 3)
    w.enemyFaceBg:SetColorTexture(0, 0, 0, 1)
    w.enemyFaceBg:Hide()
    w.enemyFace = K().Icon(e, nil, "OVERLAY", 3)
    w.enemyFace:SetSize(22, 22)
    w.enemyFace:SetPoint("BOTTOMLEFT", e, "BOTTOMLEFT", 4, 4)
    w.enemyFace:Hide()
    K().Highlight(e, w.enemyIcon, 0.04) -- j1 #27: 0.04 BLEND (was ADD 0.06)
    e:SetScript("OnClick", function()
      M.Hit(true)
    end)
    K().Tip(e, function(tt)
      Tips().Enemy(tt)
    end, { delay = Mrgl.Data.Balance.ENEMY_TIP_DELAY }) -- T2
    -- ---------------- boss button (V6 teaser from second 0, B4 states, B5 bar)
    local bb = CreateFrame("Button", "MrglSquadBossButton", cf)
    w.boss = bb
    lv(bb, 2)
    bb:SetSize(34, 34)
    bb:SetPoint("LEFT", e, "RIGHT", 22, 8)
    K().Fill(bb, C().black, "BACKGROUND")
    w.bossIcon = K().Icon(bb, nil, "ARTWORK")
    w.bossIcon:SetPoint("TOPLEFT", bb, "TOPLEFT", 2, -2)
    w.bossIcon:SetPoint("BOTTOMRIGHT", bb, "BOTTOMRIGHT", -2, 2)
    w.bossBorder = K().Border(bb, C().line, "OVERLAY", 0, 2) -- R3: 2 px status border
    w.bossCd = CreateFrame("Cooldown", "MrglSquadBossCooldown", bb, "CooldownFrameTemplate")
    lv(w.bossCd, 3)
    w.bossCd:SetAllPoints(w.bossIcon)
    w.bossCd:SetSwipeColor(0, 0, 0, 0.6)
    w.bossCd:SetDrawEdge(true)
    w.bossCd:SetDrawBling(false)
    w.bossCd:SetHideCountdownNumbers(true)
    w.bossCd.noCooldownCount = true
    w.bossTop = CreateFrame("Frame", nil, bb)
    lv(w.bossTop, 3)
    w.bossTop:SetAllPoints(bb)
    w.bossSkull = K().Icon(w.bossTop, I.skull, "OVERLAY")
    w.bossSkull:SetSize(12, 12)
    w.bossSkull:SetPoint("BOTTOMRIGHT", bb, "BOTTOMRIGHT", 3, -3)
    K().Highlight(bb, w.bossIcon, 0.15, true)
    K().PressOffset(bb, w.bossIcon)
    bb:SetScript("OnClick", function()
      M.FightBoss()
    end)
    K().Tip(bb, function(tt)
      Tips().BossButton(tt)
    end)
    -- B5 readiness bar
    w.bossBar = CreateFrame("StatusBar", "MrglSquadBossBar", cf)
    lv(w.bossBar, 2)
    w.bossBar:SetSize(34, 3)
    w.bossBar:SetPoint("TOP", bb, "BOTTOM", 0, -2)
    K().Fill(w.bossBar, { 0, 0, 0, 0.7 }, "BACKGROUND")
    w.bossBar:SetStatusBarTexture(I.WHITE)
    w.bossBar:SetMinMaxValues(0, 1)
    w.bossBar:Hide()
    w.bossGrow = K().Text(cf, K().ARIALN, 10, C().good, "OUTLINE")
    w.bossGrow:SetPoint("TOP", w.bossBar, "BOTTOM", 0, -1)
    w.bossGrow:SetJustifyH("CENTER")
    w.bossGrow:SetAlpha(0)
    w.bossGrowAnim = w.bossGrow:CreateAnimationGroup()
    K().AddAlpha(w.bossGrowAnim, 0, 1, 0.15, 0, 1)
    K().AddAlpha(w.bossGrowAnim, 1, 0, 0.3, 1.7, 2)
    w.bossGrowAnim:SetToFinalAlpha(true)
    -- ---------------- HP (lag bar = frame, red bar on top) and boss timer
    local hpf = CreateFrame("StatusBar", "MrglSquadHP", cf)
    w.hpFrame = hpf
    w.hpLag = hpf
    lv(hpf, 2)
    hpf:SetSize(196, 14)
    hpf:SetPoint("TOP", f, "TOP", 0, -148)
    K().Fill(hpf, { 0, 0, 0, 0.6 }, "BACKGROUND")
    hpf:SetStatusBarTexture(I.WHITE)
    hpf:SetStatusBarColor(U.At(C().hpLag, 1), U.At(C().hpLag, 2), U.At(C().hpLag, 3), U.At(C().hpLag, 4))
    hpf:SetMinMaxValues(0, 1)
    w.hp = CreateFrame("StatusBar", "MrglSquadHPBar", hpf)
    lv(w.hp, 3)
    w.hp:SetPoint("TOPLEFT", hpf, "TOPLEFT", 1, -1)
    w.hp:SetPoint("BOTTOMRIGHT", hpf, "BOTTOMRIGHT", -1, 1)
    w.hp:SetStatusBarTexture(I.WHITE)
    local hpTex = w.hp:GetStatusBarTexture()
    hpTex:SetGradient("VERTICAL", CreateColor(U.At(C().hp, 1), U.At(C().hp, 2), U.At(C().hp, 3), 1), CreateColor(U.At(C().hpTop, 1), U.At(C().hpTop, 2), U.At(C().hpTop, 3), 1))
    w.hp:SetMinMaxValues(0, 1)
    w.hpGloss = w.hp:CreateTexture(nil, "OVERLAY")
    w.hpGloss:SetAllPoints(hpTex)
    w.hpGloss:SetColorTexture(1, 1, 1, 0.18)   -- j1 B2: alpha in the texture, the gradient only fades it
    w.hpGloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
    K().Border(w.hp, C().black, "OVERLAY", -1, 1, 1)
    w.hpText = K().Text(w.hp, K().ARIALN, 11, C().white, "OUTLINE")
    w.hpText:SetPoint("CENTER", hpf, "CENTER", 0, 0)
    w.hpText:SetJustifyH("CENTER")
    -- r3 F1: timer bar 172 wide, left-aligned with HP; the seconds stand right of it (not in the HP bar)
    w.timer = CreateFrame("StatusBar", "MrglSquadTimer", cf)
    lv(w.timer, 2)
    w.timer:SetSize(172, 5)
    w.timer:SetPoint("TOPLEFT", hpf, "BOTTOMLEFT", 0, -3)
    w.timerText = K().Text(cf, K().ARIALN, 12, C().gold, "OUTLINE")
    w.timerText:SetPoint("LEFT", w.timer, "RIGHT", 4, -3) -- -3: clear of the HP bar edge
    w.timerText:SetJustifyH("LEFT")
    w.timerText:Hide() -- j1 #15: no pop in the last 5 s
    -- j2 A2: a boss fight frozen by WoW combat (window visible with "Hide in combat" off): a quiet static label on the
    -- timer, muted, alpha in only; the timer and its seconds dim. Gone when combat ends (M.OnUpdate, pauseLook)
    w.pausedText = K().Text(cf, K().ARIALN, 11, C().muted, "OUTLINE")
    w.pausedText:SetPoint("CENTER", w.timer, "CENTER", 0, -3) -- -3: clear of the HP bar edge (like the seconds)
    w.pausedText:SetText(S().PAUSED_COMBAT)
    w.pausedText:SetAlpha(0)
    w.pausedText:Hide()
    w.pausedIn = w.pausedText:CreateAnimationGroup()
    K().AddAlpha(w.pausedIn, 0, 1, 0.3, 0, 1)
    w.pausedIn:SetToFinalAlpha(true)
    K().Fill(w.timer, { 0, 0, 0, 0.6 }, "BACKGROUND")
    w.timer:SetStatusBarTexture(I.WHITE)
    w.timer:SetMinMaxValues(0, 30)
    w.timerFill = w.timer:CreateAnimationGroup()
    K().AddScale(w.timerFill, 0.01, 1, 0.3, 0, 1, "OUT", "LEFT")
    w.timerFade = w.timer:CreateAnimationGroup()
    K().AddAlpha(w.timerFade, 1, 0, 0.3, 0, 1)
    w.timerFade:SetScript("OnFinished", function()
      w.timer:Hide()
      w.timerText:Hide()
    end)
    -- a hidden window stops the fade without OnFinished (WoW): clean up the same way
    w.timerFade:SetScript("OnStop", function()
      if not Mrgl.db.boss.active then
        w.timer:Hide()
        w.timerText:Hide()
      end
    end)
    w.timer:Hide()
    -- ---------------- squad (V2: all 6 slots, fixed places)
    w.squad = {  }
    for s = 1, 6 do
      U.Insert(w.squad, buildPortrait(cf, s))
    end
    -- New Tide K: three companion slots right of the squad (Murky, Tidecaller, King Bagurgle)
    w.comp = {}
    for c = 1, 3 do
      U.Insert(w.comp, buildCompanion(cf, c))
    end
    -- ---------------- abilities (V1: visible from second 0)
    local ab = CreateFrame("Frame", "MrglSquadAbilities", cf)
    w.abilities = ab
    lv(ab, 2)
    ab:SetSize(170, 38)
    ab:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -218)
    w.ab = {  }
    for a = 1, 4 do
      U.Insert(w.ab, buildAbility(ab, a))
    end
    -- ---------------- expand (V7: from second 0)
    local ex = CreateFrame("Button", "MrglSquadExpand", cf)
    w.expand = ex
    lv(ex, 2)
    ex:SetSize(32, 38)
    ex:SetPoint("TOPLEFT", f, "TOPLEFT", 194, -218)
    K().Fill(ex, C().panel, "BACKGROUND")
    K().Border(ex, C().line, "BORDER")
    K().Highlight(ex)
    w.chev = ex:CreateTexture(nil, "ARTWORK")
    w.chev:SetTexture(K().Media(I.chevron))
    w.chev:SetSize(16, 16)
    w.chev:SetPoint("CENTER", ex, "CENTER", 0, 0)
    K().SetVertex(w.chev, C().muted)
    ex:SetScript("OnEnter", function()
      K().SetVertex(w.chev, C().white)
    end)
    ex:SetScript("OnLeave", function()
      K().SetVertex(w.chev, C().muted)
    end)
    K().Tip(ex, function(tt)
      if Mrgl.db.settings.panel then
        Tips().Title(tt, S().HIDE_SHOP)
      else
        Tips().Title(tt, S().SHOW_SHOP)
      end
      Tips().KeyLine(tt, "MRGLSQUAD_PANEL")   -- port v1: own binding or nothing
    end)
    ex:SetScript("OnClick", function()
      Mrgl.UI.Panel.Toggle()
    end)
    M.SetChevron(false)
    -- ---------------- buy best (V7, E1-E4)
    local b = CreateFrame("Button", "MrglSquadBuyBest", cf)
    w.buy = b
    lv(b, 2)
    b:SetSize(212, 28)
    b:SetPoint("TOP", f, "TOP", 0, -264)
    K().Fill(b, C().panel, "BACKGROUND")
    -- r3 E7 saving fill: over the background, under icon and text (inset 2); width = gold / cost.
    -- r4 E14: gold at 0.18 with a 1-px gold edge line on its right side that moves with it (j1 #24: alpha 0.5)
    w.buySave = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    w.buySave:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    w.buySave:SetHeight(28 - 4)
    w.buySave:SetWidth(1)
    K().SetColor(w.buySave, C().gold, 0.18)
    w.buySave:Hide()
    w.buySaveEdge = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    w.buySaveEdge:SetPoint("TOPLEFT", w.buySave, "TOPRIGHT", 0, 0)
    w.buySaveEdge:SetPoint("BOTTOMLEFT", w.buySave, "BOTTOMRIGHT", 0, 0)
    K().PixelLine(w.buySaveEdge, false, 1)
    K().SetColor(w.buySaveEdge, C().gold, 0.5)
    w.buySaveEdge:Hide()
    w.buyBorder = K().Border(b, C().line, "BORDER")
    K().Highlight(b)
    w.buyIconBg = b:CreateTexture(nil, "ARTWORK", nil, -2)
    w.buyIconBg:SetSize(24, 24)
    w.buyIconBg:SetPoint("LEFT", b, "LEFT", 2, 0)
    K().SetColor(w.buyIconBg, C().black)
    w.buyHeads = {  }
    for h = 1, 6 do
      local head = K().MurlocHead(b, h, 22, "ARTWORK")
      head.base:SetSize(22, 22)
      head.base:SetPoint("LEFT", b, "LEFT", 3, 0)
      head:SetShown(false)
      U.Insert(w.buyHeads, head)
    end
    w.buyIcon = K().Icon(b, nil, "ARTWORK")
    w.buyIcon:SetSize(22, 22)
    w.buyIcon:SetPoint("LEFT", b, "LEFT", 3, 0)
    w.buyIcon:Hide()
    -- r4 E12: the rank of an upgrade stands top left on the icon ("III"), the chain size bottom right like a WoW
    -- bag stack (from 2); right of the icon only one value: the gain or New!
    w.buyTier = K().Text(b, K().ARIALN, 10, C().white, "OUTLINE")
    w.buyTier:SetPoint("TOPLEFT", w.buyIconBg, "TOPLEFT", 1, -1)
    w.buyTier:SetJustifyH("LEFT")
    w.buyTier:SetHeight(10) -- r5 C3: rank (top) and stack (bottom) boxes never overlap on the 22er icon
    w.buyTimes = K().Text(b, K().ARIALN, 10, C().white, "OUTLINE")
    w.buyTimes:SetPoint("BOTTOMRIGHT", w.buyIconBg, "BOTTOMRIGHT", -1, 1)
    w.buyTimes:SetJustifyH("RIGHT")
    w.buyTimes:SetHeight(10)
    w.buyGain = K().Text(b, K().ARIALN, 12, C().good, "OUTLINE")
    w.buyGain:SetPoint("LEFT", w.buyIconBg, "RIGHT", 6, 0)
    w.buyLabel = K().Text(b, K().FRIZ, 11, C().muted, "OUTLINE")
    w.buyLabel:SetPoint("CENTER", b, "CENTER", 0, 0)
    w.buyLabel:SetJustifyH("CENTER")
    w.buyLabel:SetText(S().BUYBEST)
    w.buyLabel:Hide()
    w.buyCoin = K().Icon(b, I.coin, "ARTWORK")
    w.buyCoin:SetSize(12, 12)
    w.buyCoin:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    w.buyCost = K().Text(b, K().ARIALN, 13, C().white, "OUTLINE")
    w.buyCost:SetPoint("RIGHT", w.buyCoin, "LEFT", -3, 0)
    w.buyCost:SetJustifyH("RIGHT")
    w.buyGlowFrame = CreateFrame("Frame", nil, b)
    lv(w.buyGlowFrame, 3)
    w.buyGlowFrame:SetAllPoints(b)
    K().Border(w.buyGlowFrame, C().gold, "OVERLAY")
    w.buyGlowFrame:Hide()
    w.buyGlow = K().Pulse(w.buyGlowFrame, 0.6, 0.4) -- j1 #10: 0 -> 0.6 in 0.4 s, then still
    -- r3 E7: "+n%" (fill points) for 2 s when the fill grew while the window was closed.
    -- r4 E14: inside the button, left of the wait time (RIGHT at buyWait LEFT -4); buyCost is the wait text then
    w.buyWait = w.buyCost
    w.buyGrowWrap = CreateFrame("Frame", "MrglSquadBuyGrow", cf)
    lv(w.buyGrowWrap, 3)
    w.buyGrowWrap:SetSize(40, 12)
    w.buyGrowWrap:SetPoint("RIGHT", w.buyWait, "LEFT", -4, 0)
    w.buyGrow = K().Text(w.buyGrowWrap, K().ARIALN, 10, C().good, "OUTLINE")
    w.buyGrow:SetPoint("RIGHT", w.buyGrowWrap, "RIGHT", 0, 0)
    w.buyGrow:SetJustifyH("RIGHT")
    w.buyGrow:SetAlpha(0)
    w.buyGrowAnim = w.buyGrow:CreateAnimationGroup()
    K().AddAlpha(w.buyGrowAnim, 0, 1, 0.15, 0, 1)
    K().AddAlpha(w.buyGrowAnim, 1, 1, 1.55, 0, 2)
    K().AddAlpha(w.buyGrowAnim, 1, 0, 0.3, 0, 3)
    w.buyGrowAnim:SetToFinalAlpha(true)
    w.buyPop = b:CreateAnimationGroup()
    K().AddScale(w.buyPop, 1, 1.04, 0.06, 0, 1, "OUT")
    K().AddScale(w.buyPop, 1.04, 1, 0.1, 0, 2, "IN")
    K().PressOffset(b, w.buyIconBg)
    b:SetScript("OnClick", function()
      M.BuyBest()
    end)
    K().Tip(b, function(tt)
      Tips().BuyBest(tt)
    end)
    -- ---------------- effects, headline, popup
    J().Build(f)
    Mrgl.UI.Popup.BuildWelcome(f)
    Mrgl.UI.Popup.BuildTide(f) -- New Tide Q
    M.RegisterState()
    f:SetScript("OnUpdate", function(self, elapsed)
      M.OnUpdate(elapsed)
    end)
    M.ApplyMinimized() -- j1 M5: height first, so the saved anchor places the 26-px bar where it was
    M.ApplyPosition()
    return f
  end
  function buildPortrait(parent, i)
    local p = CreateFrame("Frame", "MrglSquadPortrait" .. i, parent)
    lv(p, 2)
    p:SetSize(22, 22)
    p.baseX = 34 + (i - 1) * 26 -- New Tide K: 26 px apart (was 30), the last one ends at x 186
    p:SetPoint("TOPLEFT", w.frame, "TOPLEFT", p.baseX, -182)
    -- W2: icon 22x22 with its own round mask of the same geometry; thin ring 24x24 over it, no mask
    p.head = K().MurlocHead(p, i, 22, "ARTWORK")
    p.head.base:SetAllPoints(p)
    local mask = p:CreateMaskTexture()
    mask:SetTexture(Mrgl.Data.Icons.ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(p.head.base)
    p.head.base:AddMaskTexture(mask)
    p.head.add:AddMaskTexture(mask)
    p.ring = p:CreateTexture(nil, "ARTWORK", nil, -1)
    p.ring:SetTexture(K().Media(Mrgl.Data.Icons.ringThin))
    p.ring:SetSize(24, 24)
    p.ring:SetPoint("CENTER", p, "CENTER", 0, 0)
    K().SetVertex(p.ring, K().MurlocColor(i))
    p.count = K().Text(p, K().ARIALN, 10, C().white, "OUTLINE")
    p.count:SetPoint("TOP", p, "BOTTOM", 0, -1)
    p.count:SetJustifyH("CENTER")
    -- j1 #18: appears 0.9 -> 1 with alpha 0 -> 1 in 0.25 s
    p.popIn = p:CreateAnimationGroup()
    K().AddScale(p.popIn, 0.9, 1, 0.25, 0, 1, "OUT")
    K().AddAlpha(p.popIn, 0, 1, 0.25, 0, 1, "OUT")
    -- j1 A2 #31/#32: hop 2 px and cheer 3 px only as smoothed Translation groups (sub-pixel, the client interpolates);
    -- the base position above is set once here and never per frame
    p.hop = p:CreateAnimationGroup()
    K().AddMove(p.hop, 0, 2, 0.20, 0, 1, "OUT")
    K().AddMove(p.hop, 0, -2, 0.25, 0, 2, "IN")
    p.cheer = p:CreateAnimationGroup()
    p.cheerUp = K().AddMove(p.cheer, 0, 3, 0.2, 0, 1, "OUT")
    K().AddMove(p.cheer, 0, -3, 0.25, 0, 2, "IN")
    p.hired = nil
    K().Tip(p, function(tt)
      Tips().Portrait(tt, i)
    end)
    M.Drag(p)
    return p
  end
  -- New Tide K: companion slot idx at TOPLEFT 192 / 207 / 222, -186: 14 x 14, round mask, no ring, no motion. Free slots
  -- stay empty. A new companion fades in (0.4 s) with its headline (Juice holds it until then: st.compHold)
  -- tide1b T3: murloc heads (tint + badge from Data.Tide), centred on the portrait row (y -193). tide1c C9: 14 px with a
  -- 1-px gap, after a thin divider at x 189 (the squad's last portrait ends at 186), so they don't read as ranks 7-9
  local COMP_X, COMP_S, COMP_SEP_X = { 192, 207, 222 }, 14, 189
  function buildCompanion(parent, idx)
    local c = Tips().TideCompanion(idx)
    if idx == 1 then
      w.compSep = parent:CreateTexture(nil, "ARTWORK")
      w.compSep:SetSize(1, COMP_S)
      w.compSep:SetPoint("TOPLEFT", w.frame, "TOPLEFT", COMP_SEP_X, -193 + COMP_S / 2)
      K().SetColor(w.compSep, C().line)
      w.compSep:Hide()
    end
    local p = CreateFrame("Frame", "MrglSquadCompanion" .. idx, parent)
    lv(p, 2)
    p:SetSize(COMP_S, COMP_S)
    p:SetPoint("TOPLEFT", w.frame, "TOPLEFT", U.At(COMP_X, idx), -193 + COMP_S / 2)
    p.head = K().HeadOf(p, { icon = U.At(Mrgl.Data.Murlocs, 1).icon, tint = c.d.tint, badge = c.d.badge }, COMP_S, "ARTWORK")
    p.head.base:SetAllPoints(p)
    local mask = p:CreateMaskTexture()
    mask:SetTexture(Mrgl.Data.Icons.ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(p.head.base)
    p.head.base:AddMaskTexture(mask)
    p.head.add:AddMaskTexture(mask)
    p.fadeIn = K().FadeIn(p, 0.4)
    p.idx = idx
    K().Tip(p, function(tt, self)
      Tips().Companion(tt, self.idx)
    end)
    M.Drag(p)
    p:Hide()
    return p
  end
  -- F: the moment holds a new companion and the Anyfin look until their headline shows (Juice), then they fade in
  M.TideHold = function(idx)
    if idx == 0 then
      st.anyfinHold = true
    else
      st.compHold[idx] = true
    end
  end
  M.TideShow = function(idx)
    if idx == 0 then
      if st.anyfinHold ~= true then
        return
      end
      st.anyfinHold = false
      local b = U.At(w.ab, 1)
      if w.frame:IsVisible() and not st.min then
        K().Replay(b.swapOut)
      else
        refreshAbility(b)
      end
      return
    end
    if st.compHold[idx] ~= true then
      return
    end
    st.compHold[idx] = false
    local cp = U.At(w.comp, idx)
    cp:Show()
    K().Replay(cp.fadeIn)
  end
  -- F: minimize / hide / new db during the moment: companions and slot 1 stand right at once
  M.TideRelease = function()
    st.compHold = {}
    st.anyfinHold = false
    local b = U.At(w.ab, 1)
    if b.swapOut:IsPlaying() then
      b.swapOut:Stop()
    end
    if b.swapIn:IsPlaying() then
      b.swapIn:Stop()
    end
  end
  -- N: slot 1 looks like Anyfin Can Happen from Spells 50 (not while the moment still holds it)
  M.AnyfinShown = function()
    return Core().Tide.Has("a", 50) and st.anyfinHold ~= true
  end
  function buildAbility(parent, i)
    local d = U.At(Mrgl.Data.Abilities, i)
    local b = K().IconButton(parent, "MrglSquadAbility" .. i, 38, d.icon)
    lv(b, 2)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", (i - 1) * 44, 0)
    b:RegisterForClicks("LeftButtonDown")
    b.glow = K().Glow(b, "glow", 62, C().gold, "BACKGROUND", -8)
    b.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.glow:Hide()
    b.glowPulse = K().Pulse(b.glow, 0.5, 0.4) -- j1 #11: 0 -> 0.5 in 0.4 s, then still
    b.buffBorder = K().Border(b, C().gold, "OVERLAY")
    b.buffBorder:SetShown(false)
    b.cd = CreateFrame("Cooldown", ("MrglSquadAbility" .. i) .. "Cooldown", b, "CooldownFrameTemplate")
    lv(b.cd, 3)
    b.cd:SetAllPoints(b.icon)
    b.cd:SetSwipeColor(0, 0, 0, 0.75)
    b.cd:SetDrawEdge(true)
    b.cd:SetDrawBling(false) -- W6: own ready flash (Juice), same in browser and WoW
    b.cd:SetHideCountdownNumbers(true)
    b.cd.noCooldownCount = true -- OmniCC / ElvUI
    b.top = CreateFrame("Frame", nil, b)
    lv(b.top, 3)
    b.top:SetAllPoints(b)
    b.time = K().Text(b.top, K().ARIALN, 13, C().white, "OUTLINE")
    b.time:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.time:SetJustifyH("CENTER")
    b.timeFont = "cd"
    b.key = K().Text(b.top, K().ARIALN, 10, C().white, "OUTLINE") -- R5: 10 px white a 0.8
    b.key:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
    b.key:SetJustifyH("RIGHT")
    b.key:SetWidth(34) -- port p3 (review p2 WoW K2): button 38 minus 2+2; long keys (MOUSEWHEELUP) are cut by WoW
    b.key:SetAlpha(0.8)
    b.keyText = "" -- port p2 (review p1 Lua M1): the label comes from the WoW binding, see refreshAbility
    b.punch = b:CreateAnimationGroup()
    K().AddScale(b.punch, 0.9, 1, 0.1, 0, 1, "OUT")
    -- New Tide F: the Anyfin swap of slot 1, alpha only: the icon out in 0.3 s, the new icon in 0.3 s
    b.swapOut = b.icon:CreateAnimationGroup()
    K().AddAlpha(b.swapOut, 1, 0, 0.3, 0, 1)
    b.swapOut:SetToFinalAlpha(true)
    b.swapIn = b.icon:CreateAnimationGroup()
    K().AddAlpha(b.swapIn, 0, 1, 0.3, 0, 1)
    b.swapOut:SetScript("OnFinished", function()
      refreshAbility(b)
      b.icon:SetAlpha(1)
      K().Replay(b.swapIn)
    end)
    b.swapOut:SetScript("OnStop", function()
      b.icon:SetAlpha(1)
      refreshAbility(b)
    end)
    b.slot = i
    b.id = d.id
    b.cdState = ""
    K().PressOffset(b, b.icon)
    b:SetScript("OnClick", function()
      M.UseAbility(i)
    end)
    K().Tip(b, function(tt)
      Tips().Ability(tt, i)
    end)
    return b
  end
  -- W1: one chevron texture, mirrored by its tex coords when the panel is open
  M.SetChevron = function(open)
    if open then
      w.chev:SetTexCoord(1, 0, 0, 1)
    else
      w.chev:SetTexCoord(0, 1, 0, 1)
    end
  end
  -- ------------------------------------------------------------ actions
  M.Hit = function(manual)
    K().TipPoke(w.enemy) -- T2: a click hides the delayed enemy tooltip and restarts the wait
    if manual == true then
      J().ManualClick()
      st.clickAt = GetTime() -- j1c M4: the dim reads the last click
    end
    if not Mrgl.db.onboarding.firstClick then
      w.onboardRing:Hide()
    end
    Core().Combat.Click(manual == true)
    J().Punch() -- j4 H2 (b): after the click, so the killing hit has no punch (the enemy is locked then)
  end
  M.FightBoss = function()
    if Core().Combat.GateOpen() then
      Core().Boss.Start(false)
    end
  end
  M.UseAbility = function(i)
    local d = U.At(Mrgl.Data.Abilities, i)
    local b = U.At(w.ab, i)
    if Core().Abilities.Use(d.id, false) then
      K().Replay(b.punch)
    end
  end
  M.BuyBest = function()
    K().TipPoke(w.enemy) -- r4 T6: a Buy best click (also by key) restarts the enemy tooltip wait as well
    local ok = Core().Shop.BuyBest()
    M.Refresh()
    return ok
  end
  -- ------------------------------------------------------------ state handlers (no juice, run while hidden too)
  M.RegisterState = function()
    local On = Core().On
    On("ABILITY_UNLOCK", function(p)
      st.unlockAt[p.id] = GetTime()
    end)
    On("BUY_CHAIN", function()
      st.collectPulse = false
    end)
    On("COMBAT", function(p)
      Mrgl.UI.OnCombat(p.on, p.gold)
    end)
    -- r3 G1: the boss button stays away for 3 s after a fight (also while the window is hidden)
    On("BOSS_WIN", function()
      st.bossAwayUntil = GetTime() + BOSS_AWAY
      st.hpFrac = 0
      st.lag = 0
      st.lagDelay = 0
      w.hpLag:SetValue(0)
      w.hp:SetValue(0) -- r5 C4: no HP remnant after a win
    end)
    On("BOSS_FAIL", function()
      st.bossAwayUntil = GetTime() + BOSS_AWAY
    end)
  end
  -- r2 L6: an ability unlocked this session glows (10 s ahead of Buy best, then until used or 120 s)
  M.UnlockAge = function(id)
    local t = st.unlockAt[id]
    if t == nil then
      return -1
    end
    return GetTime() - t
  end
  -- ------------------------------------------------------------ refresh (<= 20 Hz)
  -- spotlight: candle warm, rare blue (M3), else the zone tint
  function spotLook()
    local db = Mrgl.db
    local e = Core().Combat.Enemy()
    if Core().Combat.CandleActive() then
      -- j1 #22: 0.15, rare 0.22, candle 0.25
      K().SetVertex(w.spot, { 1, 0.8, 0.4, 1 })
      w.spot:SetAlpha(0.25)
      return
    end
    if e.kind == "rare" and not db.boss.active then
      K().SetVertex(w.spot, { 0.55, 0.75, 1.0, 1 })
      w.spot:SetAlpha(0.22)
      return
    end
    local tint = Core().Combat.Zone(db.stage).tint
    K().SetVertex(w.spot, { U.At(tint, 1) * 0.5 + 0.5, U.At(tint, 2) * 0.5 + 0.5, U.At(tint, 3) * 0.5 + 0.5, 1 })
    w.spot:SetAlpha(0.15)
  end
  M.SpotLook = spotLook
  -- j5 K5 (b): a held enemy (rt.enemyBank > 0, Core MIN_LIFE) drains along its life floor. Between the 0.1-s core steps
  -- the bar follows the floor at this frame (age + rt.acc), so the drain is smooth (width only, no flash).
  M.HpShown = function(hp, max)
    local rt, ml = Core().rt, Mrgl.Data.Balance.MIN_LIFE
    local f = 0
    if max > 0 then
      f = hp / max
    end
    if rt.enemyBank ~= nil and rt.enemyBank > 0 and ml ~= nil and ml > 0 and rt.respawn <= 0
      and not (Mrgl.db.boss.active and rt.inCombat) then
      f = math.min(f, math.max(0, 1 - (rt.enemyAge + math.max(0, rt.acc)) / ml))
    end
    return f
  end
  -- tide1d D2: in fast mode the picture (and the name with it) swaps at most once per LOOK_HOLD s;
  -- the HP bar and number stay live (Refresh). force: faction switch.
  -- enemies1b F4: a boss start swaps everything at once (picture, name, red colour, border, skull) and starts a new hold;
  -- everything else, the boss end too, holds picture and name together (the shown boss stays until the hold is over;
  -- j4 H4: its skull and edge go at once).
  -- enemies1b F3: a held swap in fast mode fades the old picture out over LOOK_XFADE s (alpha only, w.enemyIconOld on top
  -- of the new one); a boss start and a faction switch cut.
  local LOOK_HOLD, LOOK_XFADE = 2, 0.15
  function setEnemyLook(force)
    local db = Mrgl.db
    local e = Core().Combat.Enemy()
    local key = e.icon .. "|" .. e.name .. "|" .. e.kind
    local boss = db.boss.active == true
    if key ~= st.lookKey then
      -- a swap made in fast mode holds its 2 s even when fast mode ends meanwhile (no quick swap at the edge)
      local fast = J().FastFarm()
      local held = force ~= true and not (boss and not st.lookBoss) and (fast or st.lookFast)
      if held and GetTime() - st.lookT < LOOK_HOLD then
        -- j4 H4 (UX-B): the boss is over, so the skull and its edge go at once (the held picture stays)
        if st.lookBoss and not boss then
          w.enemyBadge:Hide()
          w.enemyBadgeBg:Hide()
        end
        spotLook()
        return
      end
      local o, t = w.enemyIconOld, st.lookTint
      if held and st.lookIcon ~= "" and st.lookIcon ~= e.icon then
        K().SetIcon(o, st.lookIcon)
        o:SetDesaturated(t ~= nil)
        if t ~= nil then
          o:SetVertexColor(U.At(t, 1), U.At(t, 2), U.At(t, 3), 1)
        else
          o:SetVertexColor(1, 1, 1, 1)
        end
        st.xfade = LOOK_XFADE
        o:SetAlpha(st.dimA)
        o:Show()
      else
        st.xfade = 0
        o:Hide()
      end
      st.lookKey = key
      st.lookT = GetTime()
      st.lookFast = fast
    end
    st.lookBoss = boss
    st.lookIcon = e.icon
    st.lookTint = e.tint
    K().SetIcon(w.enemyIcon, e.icon)
    M.EnemyLookExtra(e)
    w.name:SetText(e.name)
    local c = C().text; local bc = { 1, 1, 1, 0.25 }
    local rare = e.kind == "rare" and not db.boss.active
    if db.boss.active then
      c = C().boss
      bc = C().boss
    elseif rare then
      c = C().rare
      bc = C().rare
    end
    K().SetTextColor(w.name, c)
    w.enemyBorder.SetColor(bc)
    w.enemyRareBorder:SetShown(rare)
    if db.boss.active then
      w.enemyBadge:SetTexture(K().IconPath(Mrgl.Data.Icons.skull))
      w.enemyBadge:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      w.enemyBadge:SetVertexColor(1, 1, 1, 1)
      w.enemyBadge:SetBlendMode("BLEND")
      w.enemyBadge:SetSize(16, 16)
      w.enemyBadge:SetAlpha(1)
      w.enemyBadge:Show()
      w.enemyBadgeBg:SetAlpha(1)
      w.enemyBadgeBg:Show()
    elseif rare then
      w.enemyBadge:SetTexture(K().Media("spark"))
      w.enemyBadge:SetTexCoord(0, 1, 0, 1)
      K().SetVertex(w.enemyBadge, C().rare)
      w.enemyBadge:SetBlendMode("ADD")
      w.enemyBadge:SetSize(28, 28)
      w.enemyBadge:SetAlpha(0.6) -- j1 #23
      w.enemyBadge:Show()
      w.enemyBadgeBg:Hide()
    else
      w.enemyBadge:Hide()
      w.enemyBadgeBg:Hide()
    end
    spotLook()
  end
  M.SetEnemyLook = setEnemyLook
  -- enemies1 G4: tint and face go with the picture (held with it in fast mode); without the fields all of it is off
  M.EnemyLookExtra = function(e)
    local t = e.tint
    if t ~= nil then
      w.enemyIcon:SetDesaturated(true)
      w.enemyIcon:SetVertexColor(U.At(t, 1), U.At(t, 2), U.At(t, 3), 1)
      K().SetIcon(w.enemyIconAdd, e.icon)
      w.enemyIconAdd:SetVertexColor(0.6 * U.At(t, 1), 0.6 * U.At(t, 2), 0.6 * U.At(t, 3), 1)
      w.enemyIconAdd:Show()
    else
      w.enemyIcon:SetDesaturated(false)
      w.enemyIcon:SetVertexColor(1, 1, 1, 1)
      w.enemyIconAdd:Hide()
    end
    if e.face ~= nil then
      K().SetIcon(w.enemyFace, e.face)
      w.enemyFace:Show()
      w.enemyFaceBg:Show()
    else
      w.enemyFace:Hide()
      w.enemyFaceBg:Hide()
    end
  end
  M.LockEnemy = function(on)
    st.enemyLocked = on
  end
  M.SetZone = function(instant)
    local db = Mrgl.db
    local zi = F().ZoneIndex(db.stage)
    if zi == st.zone then
      return
    end
    st.zone = zi
    local tint = Core().Combat.Zone(db.stage).tint
    spotLook()
    zoneTint(tint, instant)
  end
  -- the tint itself: at once, or a 1-s fade-in of the new layer (also /mrgl debug zone next, j1 B2).
  -- tide1c C15: only the frames fade or hide; the outgoing layer is hidden, never set to alpha 0
  function zoneTint(tint, instant)
    st.zoneFading = true -- the OnStop below must not settle the old state over the new one
    if w.zoneFadeA:IsPlaying() then
      w.zoneFadeA:Stop()
    end
    if w.zoneFadeB:IsPlaying() then
      w.zoneFadeB:Stop()
    end
    st.zoneFading = false
    st.tintNow = tint
    if instant == true then
      st.tintA = true
      M.ApplyZoneLook()
      return
    end
    local incoming = w.zoneFrameA; local outgoing = w.zoneFrameB; local tex = w.zoneA; local g = w.zoneFadeA
    if st.tintA then
      incoming = w.zoneFrameB
      outgoing = w.zoneFrameA
      tex = w.zoneB
      g = w.zoneFadeB
    end
    st.tintA = not st.tintA
    zoneGradient(tex, tint)
    outgoing:Hide()
    incoming:SetAlpha(0)
    incoming:Show()
    g:Play()
  end
  M.ZoneTint = zoneTint
  -- tide1c C15: the zone look from the state (main frame OnShow, UI.Reset, the end of every fade): the active layer has
  -- the gradient of the current tint at frame alpha 1, the other layer is hidden; a fade that still runs stops first
  M.ApplyZoneLook = function()
    if w.zoneFrameA == nil or st.tintNow == nil or st.zoneFading then
      return
    end
    st.zoneFading = true
    if w.zoneFadeA:IsPlaying() then
      w.zoneFadeA:Stop()
    end
    if w.zoneFadeB:IsPlaying() then
      w.zoneFadeB:Stop()
    end
    st.zoneFading = false
    local on = w.zoneFrameA; local off = w.zoneFrameB; local tex = w.zoneA
    if not st.tintA then
      on = w.zoneFrameB
      off = w.zoneFrameA
      tex = w.zoneB
    end
    zoneGradient(tex, st.tintNow)
    off:Hide()
    on:SetAlpha(1)
    on:Show()
  end
  M.Refresh = function()
    local db = Mrgl.db
    local Cb = Core().Combat
    local A = Core().Abilities
    -- head
    local stageStr = "" .. db.stage
    if stageStr ~= st.stageStr then -- port p2 (review p1 WoW S3): SetText only on a change
      st.stageStr = stageStr
      w.stage:SetText(stageStr)
    end
    local gate = Cb.GateOpen()
    -- New Tide H: the hint stands while New Tide is available and no boss fight runs (WoW combat does not count)
    local mark = Core().Tide.Avail() and not db.boss.active
    if mark ~= w.tideMark:IsShown() then
      w.tideMark:SetShown(mark)
      if mark then
        K().Replay(w.tideMarkIn)
      end
    end
    for i = 1, 10 do
      local p = U.At(w.pips, i)
      p:SetShown(not db.boss.active and not mark)
      if gate then
        K().SetColor(p, C().good)
      elseif i <= db.kills then
        K().SetColor(p, C().gold)
      else
        p:SetColorTexture(1, 1, 1, 0.15)
      end
    end
    w.bossMark:SetShown(db.boss.active)
    st.goldTo = math.max(0, db.gold - st.goldHold - J().HeldGold()) -- j1 W2: a waiting gold moment holds its gold
    -- enemy
    -- j1 #22: the spotlight follows the candle buff also while the enemy is locked (ABILITY_USE fires before the buff)
    if not st.enemyLocked then
      setEnemyLook()
    else
      spotLook()
    end
    local max = F().EnemyHP(db.stage)
    local pause = Core().rt.respawn > 0
    local hp = math.max(0, db.enemyHp)
    if pause then
      hp = 0
    end
    st.hpFrac = M.HpShown(hp, max)
    w.hp:SetValue(st.hpFrac)
    if pause then
      w.hpText:SetText("")
    else
      w.hpText:SetText(U.Short(math.ceil(hp)))
    end -- L2: empty in the pause
    if not st.zoneDefer then
      M.SetZone(false)
    end
    -- timer
    if db.boss.active then
      if not w.timer:IsShown() then
        w.timer:Show()
        w.timerText:Show()
        w.timer:SetAlpha(1)
        if w.timerFade:IsPlaying() then
          w.timerFade:Stop()
        end
      end
      w.timer:SetMinMaxValues(0, db.boss.max)
      w.timer:SetValue(math.max(0, db.boss.time))
      local left = math.max(0, db.boss.time)
      local tc = C().gold
      if left <= 5 then
        tc = C().timerLow
      elseif left <= 10 then
        tc = C().timerMid
      end -- R3
      w.timer:SetStatusBarColor(U.At(tc, 1), U.At(tc, 2), U.At(tc, 3), 1)
      K().SetTextColor(w.timerText, tc)
      w.timerText:SetText("" .. math.ceil(left))
      -- j1 #15: no pulse in the last 5 s, only the colour above
    elseif w.timer:IsShown() and not w.timerFade:IsPlaying() then
      w.timer:Hide()
      w.timerText:Hide()
    end
    refreshBossButton()
    -- squad (V2): all six, not hired = dim head, no count, no ring
    for s = 1, 6 do
      local pt = U.At(w.squad, s)
      local n = db.murlocs[F().Murloc(s).id].n
      local hired = n > 0
      if pt.hired ~= hired then
        pt.hired = hired
        if hired then
          pt.head.SetState("full")
          pt:SetAlpha(1)
        else
          pt.head.SetState("dim")
          pt:SetAlpha(0.35)
        end -- r3 U5
        pt.ring:SetShown(hired)
        pt.count:SetShown(hired)
      end
      pt.count:SetText("" .. n)
      K().SetTextColor(pt.count, C().white) -- r5 C5: a count is never red (red = not affordable, prices only)
    end
    -- New Tide K: companions (never removed: there is no respec); one held by the moment waits for its headline
    for ci = 1, 3 do
      local cp = U.At(w.comp, ci)
      local want = Tips().TideCompanion(ci).has and st.compHold[ci] ~= true
      if want ~= cp:IsShown() then
        cp:SetShown(want)
      end
    end
    w.compSep:SetShown(U.At(w.comp, 1):IsShown() or U.At(w.comp, 2):IsShown()) -- tide1c C9
    for a = 1, 4 do
      refreshAbility(U.At(w.ab, a))
    end
    refreshBuyBest()
    J().UpdateGlow()
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Refresh()
    end
    K().RefreshTip()
  end
  -- B5: readiness bar; called on purchases and on window open (Juice shows +n%)
  M.Strength = function()
    return Core().Boss.Strength()
  end
  function refreshBossButton()
    local db = Mrgl.db
    local Cb = Core().Combat
    local Bo = Core().Boss
    local bb = w.boss
    local shown = not db.boss.active and not st.bossHide and GetTime() >= st.bossAwayUntil
    bb:SetShown(shown)
    if not shown then
      w.bossBar:Hide()
      st.bossState = "hidden"
      -- r3 G1: the rings go with the button (any start: auto, click, key Q, opener)
      if J().BossRingsShown() then
        J().BossRingsOff()
      end
      if st.autoCd then
        st.autoCd = false
        w.bossCd:Clear()
      end
      return
    end
    K().SetIcon(w.bossIcon, Bo.NextEnemy().icon)
    local gate = Cb.GateOpen()
    local state = "teaser"
    if gate then
      state = Bo.Ready()
      if Bo.Held() then
        state = "held"
      end
    end
    local a = Bo.AutoState()
    local bc = C().line
    if state == "teaser" then
      w.bossIcon:SetDesaturated(true)
      bb:SetAlpha(0.6)
      w.bossBorder.SetColor(C().line, 0.25)
    else
      w.bossIcon:SetDesaturated(false)
      bb:SetAlpha(1)
      if state == "green" or state == "greenAbil" then
        bc = C().good
      elseif state == "yellow" or state == "held" then
        bc = C().warn
      else
        bc = C().muted
      end
      w.bossBorder.SetColor(bc)
    end
    -- B5 bar: only at an open gate, hidden when full
    local str = Bo.Strength()
    if gate and str < 1 then
      w.bossBar:Show()
      w.bossBar:SetValue(str)
      w.bossBar:SetStatusBarColor(U.At(bc, 1), U.At(bc, 2), U.At(bc, 3), 1)
    else
      w.bossBar:Hide()
    end
    -- auto-fight countdown as a cooldown swipe (S5; the shrinking ring is in Juice)
    if a.state == "countdown" then
      if not st.autoCd then
        st.autoCd = true
        local B = Mrgl.Data.Balance
        w.bossCd:SetCooldown(GetTime() - (B.AUTO_FIGHT_DELAY - a.left), B.AUTO_FIGHT_DELAY)
        J().CountdownRing(a.left)
      end
    elseif st.autoCd then
      st.autoCd = false
      w.bossCd:Clear()
      J().CountdownRing(0)
    end
    st.bossState = state
  end
  function setTimeFont(b, kind)
    if b.timeFont == kind then
      return
    end
    b.timeFont = kind
    if kind == "locked" then
      K().SetFont(b.time, K().ARIALN, 12, "OUTLINE")
    else
      K().SetFont(b.time, K().ARIALN, 13, "OUTLINE")
    end
  end
  -- port p2 (review p1 Lua M1): WoW starts unbound, so the corner label shows the player's own binding or nothing
  -- (data key "1".."4" was the browser's fixed key). Modifiers short like the action bars: SHIFT-1 -> s-1.
  local KEY_SHORT = { { "SHIFT-", "s-" }, { "CTRL-", "c-" }, { "ALT-", "a-" } }
  local function keyLabel(binding)
    local k = GetBindingKey(binding)
    if k == nil or k == "" then
      return ""
    end
    for i = 1, #KEY_SHORT do
      local pair = KEY_SHORT[i]
      local at = string.find(k, pair[1], 1, true)
      if at ~= nil then
        k = string.sub(k, 1, at - 1) .. pair[2] .. string.sub(k, at + string.len(pair[1]))
      end
    end
    return k
  end
  function refreshAbility(b)
    local A = Core().Abilities
    local d = U.At(Mrgl.Data.Abilities, b.slot)
    -- New Tide N: slot 1 as Anyfin Can Happen (the swap animation sets it at its middle)
    if d.alt ~= nil and not b.swapOut:IsPlaying() then
      if M.AnyfinShown() then
        K().SetIcon(b.icon, d.alt.icon)
      else
        K().SetIcon(b.icon, d.icon)
      end
    end
    local unlocked = A.Unlocked(d.id)
    if not unlocked then
      -- V1: locked but visible: desaturated, alpha 0.35, unlock stage in muted
      b.icon:SetDesaturated(true)
      b:SetAlpha(0.35)
      setTimeFont(b, "locked")
      b.time:SetText("" .. d.stage)
      K().SetTextColor(b.time, C().muted)
      b.key:Hide()
      b.buffBorder:SetShown(false)
      if b.cdState ~= "locked" then
        b.cdState = "locked"
        b.cd:Clear()
      end
      return
    end
    b.icon:SetDesaturated(false)
    b:SetAlpha(1)
    local key = keyLabel("MRGLSQUAD_ABILITY" .. b.slot)
    if key ~= b.keyText then
      b.keyText = key
      b.key:SetText(key)
    end
    b.key:SetShown(key ~= "")
    setTimeFont(b, "cd")
    local buff = A.BuffLeft(d.id)
    local rest = math.min(A.Remaining(d.id), d.cd) -- r3 K1: never more than the cooldown itself
    local state = "ready"
    if buff > 0 then
      state = "buff"
    elseif rest > 0 then
      state = "cd"
    end
    if state ~= b.cdState then
      if state == "buff" then
        b.cd:SetReverse(true)
        b.cd:SetCooldown(GetTime() - (d.dur - buff), d.dur)
      elseif state == "cd" then
        b.cd:SetReverse(false)
        b.cd:SetCooldown(GetTime() - (d.cd - rest), d.cd)
      else
        b.cd:Clear()
      end
      b.cdState = state
    end
    if state == "buff" then
      b.time:SetText(U.CD(buff))
      K().SetTextColor(b.time, C().white)
      b.buffBorder:SetShown(true)
    elseif state == "cd" then
      b.time:SetText(U.CD(rest))
      K().SetTextColor(b.time, C().white)
    else
      b.time:SetText("")
    end
    if state ~= "buff" then
      b.buffBorder:SetShown(false)
    end
    if J().GlowOwner() ~= b then
      b.glow:Hide()
    end
  end
  function showHead(i)
    for h = 1, 6 do
      U.At(w.buyHeads, h):SetShown(h == i)
    end
  end
  -- r4 E13: a chain gain < 1 % looks like "no target": icon desaturated (heads grey, without tint and glow copy)
  function buyDesat(on)
    local st2 = "full"
    if on then
      st2 = "grey"
    end
    for h = 1, 6 do
      U.At(w.buyHeads, h).SetState(st2)
    end
    w.buyIcon:SetDesaturated(on)
  end
  function saveShown(on)
    w.buySave:SetShown(on)
    w.buySaveEdge:SetShown(on)
  end
  -- r3 P1: a gain token in its colour (muted "<1%", else good)
  M.GainText = function(fs, p)
    fs:SetText(U.Gain(p))
    if U.GainLow(p) then
      K().SetTextColor(fs, C().muted)
    else
      K().SetTextColor(fs, C().good)
    end
  end
  -- r3 E7: fill target 0..1 while Buy best waits for gold (-1 = no fill)
  function saveTarget(ch)
    if ch == nil or ch.affordable or not (ch.first.cost > 0) then
      return -1
    end
    return math.max(0, math.min(1, Mrgl.db.gold / ch.first.cost))
  end
  M.SaveFill = function()
    return st.saveFill
  end
  -- window closes: remember the fill; window opens: "+n%" when it grew (called by main.js)
  M.SaveMark = function()
    st.saveMark = saveTarget(Core().Shop.Chain())
  end
  M.SaveCheck = function()
    local cur = saveTarget(Core().Shop.Chain())
    local was = st.saveMark
    st.saveMark = -1
    st.saveFill = cur -- no slide on open: the fill shows the truth at once, the text tells the growth
    if cur < 0 or was < 0 then
      return
    end
    local d = (cur - was) * 100
    if d < 1 then
      return
    end
    M.GainText(w.buyGrow, d)
    K().Replay(w.buyGrowAnim)
  end
  function refreshBuyBest()
    local db = Mrgl.db
    local pop = Core().rt.popup
    if st.wasPopup and not pop then
      st.collectPulse = true
    end -- E1: the first target after Collect always pulses
    st.wasPopup = pop
    local ch = Core().Shop.Chain()
    M.chain = ch
    M.best = nil
    if ch ~= nil then
      M.best = ch.first
    end
    w.buyTier:SetText("")
    w.buyTimes:SetText("")
    st.saveTo = saveTarget(ch)
    if st.saveTo < 0 then
      st.saveFill = -1
      saveShown(false)
    end
    st.buyLow = false
    if ch == nil then
      -- E2: nothing worth buying
      w.buy:SetAlpha(0.4)
      showHead(0)
      w.buyIcon:Hide()
      w.buyIconBg:Hide()
      w.buyGain:SetText("")
      w.buyCost:SetText("")
      w.buyCoin:Hide()
      w.buyLabel:Show()
      return
    end
    w.buyLabel:Hide()
    w.buyIconBg:Show()
    local t = ch.first
    if t.kind == "hire" then
      showHead(t.slot)
      w.buyIcon:Hide()
    elseif t.kind == "upgrade" then
      showHead(t.slot)
      w.buyIcon:Hide()
      w.buyTier:SetText(U.Roman(t.tier)) -- E12: top left on the icon
    else
      showHead(0)
      K().SetIcon(w.buyIcon, U.At(Mrgl.Data.Self, t.slot).icon)
      w.buyIcon:Show()
    end
    -- E13: chain gain < 1 % (not for a new rank, which says New!): dimmed like "no target", still clickable
    st.buyLow = not ch.isNew and U.GainLow(ch.gain)
    buyDesat(st.buyLow)
    -- V7: dimmed until the very first target is affordable
    if not db.onboarding.firstHire and not ch.affordable then
      w.buy:SetAlpha(0.4)
    elseif st.buyLow then
      w.buy:SetAlpha(0.5)
    else
      w.buy:SetAlpha(1)
    end
    -- E12: chain size from 2 as a stack count on the icon; right of the icon the chain gain (New! for a new rank)
    if ch.n >= 2 then
      w.buyTimes:SetText("" .. ch.n)
    end
    -- r5 C3: no role badge on the Buy best icon while the rank or the stack count stands on it
    local tierText = w.buyTier:GetText()
    local timesText = w.buyTimes:GetText()
    local plain = (tierText == nil or tierText == "") and (timesText == nil or timesText == "")
    if t.kind ~= "self" then
      local hd = U.At(w.buyHeads, t.slot)
      if hd.badge ~= nil then
        hd.badge:SetShown(plain)
        hd.badgeBg:SetShown(plain)
      end
    end
    if ch.isNew then
      -- E8: the first piece is a new rank: the label says New!, the chain gain stands in the tooltip only
      K().SetFont(w.buyGain, K().ARIALN, 10, "OUTLINE")
      w.buyGain:SetText(S().BUY_NEW)
      K().SetTextColor(w.buyGain, C().good)
    else
      K().SetFont(w.buyGain, K().ARIALN, 12, "OUTLINE")
      M.GainText(w.buyGain, ch.gain) -- r3 P1
    end
    if ch.affordable then
      w.buyCost:SetText(U.ShortUp(ch.cost))
      K().SetTextColor(w.buyCost, C().white)
      w.buyCoin:Show()
    elseif ch.wait >= 0 then
      w.buyCost:SetText(U.Wait(ch.wait))
      K().SetTextColor(w.buyCost, C().muted)
      w.buyCoin:Hide()
    else
      w.buyCost:SetText(U.ShortUp(ch.cost))
      K().SetTextColor(w.buyCost, C().muted)
      w.buyCoin:Show()
    end
  end
  -- r3 E7: the fill follows the gold smoothly (0.2 s), per frame
  function updateSaveFill(dt)
    if st.saveTo < 0 then
      return
    end
    if st.saveFill < 0 then
      st.saveFill = st.saveTo
    end
    st.saveFill = st.saveFill + (st.saveTo - st.saveFill) * math.min(1, dt / 0.2 * 3)
    if math.abs(st.saveTo - st.saveFill) < 0.001 then
      st.saveFill = st.saveTo
    end
    local px = math.floor((212 - 4) * st.saveFill + 0.5)
    if px < 1 then
      saveShown(false)
      return
    end
    w.buySave:SetWidth(px)
    saveShown(true)
    -- r5 C2: the 1-px edge stays off while it would cross a text in the button (2 px margin): the fill alone shows it.
    -- The edge x relative to the button's left edge: buySave starts at +2 and is px wide (= buySave:GetRight() - left).
    if edgeHitsText(2 + px) then
      w.buySaveEdge:Hide()
    end
  end
  -- Port-plan 6 (v1): the text spans are measured (GetLeft/GetRight lay the strings out) only when a text, its
  -- lit state or its visibility changes, or the scale changes; per frame only cheap getters and arithmetic run.
  -- Spans are stored relative to the button's left edge, so moving the window needs no new measurement.
  local edgeTexts -- the five texts of the button, filled on first use
  local edgeText = {}; local edgeLit = {}; local edgeVis = {}
  local edgeSpans = {}
  local edgeDirty = true
  function measureEdgeSpans()
    edgeSpans = {}
    local bl = w.buy:GetLeft()
    if bl == nil then
      return -- not laid out yet: stays dirty, measured again next frame
    end
    edgeDirty = false
    for i = 1, #edgeTexts do
      local text = edgeText[i]
      if edgeLit[i] and edgeVis[i] and text ~= nil and text ~= "" then
        local fs = edgeTexts[i]
        local l = fs:GetLeft(); local r = fs:GetRight()
        if l ~= nil and r ~= nil then
          tinsert(edgeSpans, { l - bl, r - bl })
        end
      end
    end
  end
  M.EdgeDirty = function()
    edgeDirty = true
  end
  function edgeHitsText(x)
    if edgeTexts == nil then
      edgeTexts = { w.buyCost, w.buyGain, w.buyGrow, w.buyTier, w.buyTimes }
    end
    for i = 1, #edgeTexts do
      local fs = edgeTexts[i]
      local lit = fs:GetAlpha() > 0
      if fs == w.buyGrow then
        lit = w.buyGrowAnim:IsPlaying()
      end -- its alpha lives in the animation
      local text = fs:GetText()
      local vis = fs:IsVisible()
      if text ~= edgeText[i] or lit ~= edgeLit[i] or vis ~= edgeVis[i] then
        edgeText[i] = text
        edgeLit[i] = lit
        edgeVis[i] = vis
        edgeDirty = true
      end
    end
    if edgeDirty then
      measureEdgeSpans()
    end
    for i = 1, #edgeSpans do
      local sp = edgeSpans[i]
      if x >= sp[1] - 2 and x <= sp[2] + 2 then
        return true
      end
    end
    return false
  end
  -- E1 pulse rule for the one-glow logic: gain >= 3 %, the onboarding target, or the first target after Collect.
  -- r4 E13: never for a chain gain < 1 %
  M.BuyWantsGlow = function()
    local ch = M.chain
    if ch == nil or not ch.affordable or st.buyLow then
      return false
    end
    if not Mrgl.db.onboarding.firstHire or st.collectPulse then
      return true
    end
    return ch.gain >= Mrgl.Data.Balance.BESTBUY_GLOW_MIN
  end
  -- r4 K1: "+X" at the gold (combat end, return to the tab). Faded per frame instead of an animation group: a long
  -- frame (OnUpdate elapsed >= 5 s = return) would run a group to its end in the same frame. The frame that starts it
  -- does not advance it. instant: starts fully visible (a return shows the result at once).
  function plusAlpha(t)
    if t < PLUS_IN then
      return t / PLUS_IN
    end
    if t < PLUS_HOLD then
      return 1
    end
    return math.max(0, 1 - (t - PLUS_HOLD) / (PLUS_END - PLUS_HOLD))
  end
  M.GoldPlus = function(gold, instant)
    w.goldPlus:SetText(U.Fill(S().PLUS, { v = U.Short(gold) }))
    st.plusT = 0
    if instant == true then
      st.plusT = PLUS_IN
    end
    st.plusFresh = true
    w.goldPlus:SetAlpha(plusAlpha(st.plusT))
  end
  M.GoldPlusStop = function()
    st.plusT = -1
    st.plusFresh = false
    w.goldPlus:SetAlpha(0)
  end
  function updateGoldPlus(dt)
    if st.plusT < 0 then
      return
    end
    if st.plusFresh then
      st.plusFresh = false
    else
      st.plusT = st.plusT + dt
    end
    if st.plusT >= PLUS_END then
      M.GoldPlusStop()
      return
    end
    w.goldPlus:SetAlpha(plusAlpha(st.plusT))
  end
  -- ------------------------------------------------------------ per-frame (OnUpdate) work
  -- j2 A2: "Paused in combat" while a boss fight is frozen by WoW combat (only seen with "Hide in combat" off)
  local function pauseLook()
    local on = Mrgl.db.boss.active and Core().rt.inCombat == true
    if on == st.paused then
      return
    end
    st.paused = on
    if on then
      w.pausedText:SetAlpha(0)
      w.pausedText:Show()
      K().Replay(w.pausedIn)
      w.timer:SetAlpha(0) -- j2b UX-A 1: no bar under the label (fill and background), only the seconds at 0.3
      w.timerText:SetAlpha(0.3)
    else
      w.pausedIn:Stop()
      w.pausedText:Hide()
      w.timer:SetAlpha(1)
      w.timerText:SetAlpha(1)
    end
  end
  M.IsPausedLook = function()
    return st.paused == true
  end
  M.OnUpdate = function(dt)
    local db = Mrgl.db
    st.t = st.t + dt
    pauseLook()
    updateGoldPlus(dt)
    -- W5: 1-px lines follow scale changes
    local es = w.frame:GetEffectiveScale()
    if es ~= st.pxScale then
      st.pxScale = es
      K().PixelRefresh()
      edgeDirty = true -- C2 text spans: measure again at the new scale
    end
    -- gold rolls up in 0.3 s, spending shows at once
    if st.goldTo < st.goldShown then
      st.goldShown = st.goldTo
      st.goldFrom = st.goldTo
      st.goldT = 1
    elseif st.goldTo > st.goldShown and st.goldT >= 1 and st.goldTo ~= st.goldTarget then
      st.goldFrom = st.goldShown
      st.goldT = 0
    end
    st.goldTarget = st.goldTo
    if st.goldT < 1 then
      st.goldT = math.min(1, st.goldT + dt / J().GoldRoll()) -- 0.3 s, a gold moment 0.6 s (j1 G)
      st.goldShown = st.goldFrom + (st.goldTo - st.goldFrom) * st.goldT
    else
      st.goldShown = st.goldTo
    end
    local goldStr = U.Short(math.floor(st.goldShown))
    if goldStr ~= st.goldStr then -- port p2 (review p1 WoW S3): SetText only on a change (every frame before)
      st.goldStr = goldStr
      w.goldText:SetText(goldStr)
    end
    -- j5 K5 (b): the drain of a held enemy moves every frame
    if Core().rt.enemyBank ~= nil and Core().rt.enemyBank > 0 and Core().rt.respawn <= 0 then
      st.hpFrac = M.HpShown(math.max(0, Mrgl.db.enemyHp), F().EnemyHP(Mrgl.db.stage))
      w.hp:SetValue(st.hpFrac)
    end
    -- HP lag: waits 0.15 s, then follows with 0.35 s smoothing
    if st.hpFrac >= st.lag then
      st.lag = st.hpFrac
      st.lagDelay = 0.15
    elseif st.lagDelay > 0 then
      st.lagDelay = st.lagDelay - dt
    else
      st.lag = st.lag + (st.hpFrac - st.lag) * math.min(1, dt / 0.35 * 3)
    end
    if st.lag - st.hpFrac < 0.004 then
      st.lag = st.hpFrac
    end -- r5 C4: the smoothing never leaves a sliver
    w.hpLag:SetValue(st.lag)
    updateSaveFill(dt)
    -- T5 / j1 M1: minimize only while the mouse is over the window (in 0.15 s, out 0.4 s).
    -- j1b U3: minimized, Restore is the bar's only control and always shows (alpha 1)
    local over = w.frame:IsMouseOver()
    if over then
      st.hoverA = math.min(1, st.hoverA + dt / 0.15)
    else
      st.hoverA = math.max(0, st.hoverA - dt / 0.4)
    end
    if st.min then
      w.min:SetAlpha(1)
    else
      w.min:SetAlpha(st.hoverA)
    end
    if drag.on and M.DragDebug ~= nil then -- j1b D1: drag log while moving, every 0.25 s
      drag.dbgT = drag.dbgT + dt
      if drag.dbgT >= 0.25 then
        drag.dbgT = 0
        M.DragDebug(M.DragLine("move"))
      end
    end
    if drag.on and not IsMouseButtonDown("LeftButton") then
      M.DragStop()
    end -- j1 #13: missed OnDragStop
    -- L3: the name fades out (0.1 s) while a headline runs, back in 0.2 s
    if st.nameA > st.nameTarget then
      st.nameA = math.max(st.nameTarget, st.nameA - dt / 0.1)
    elseif st.nameA < st.nameTarget then
      st.nameA = math.min(st.nameTarget, st.nameA + dt / 0.2)
    end
    w.name:SetAlpha(st.nameA)
    -- j1b G1: the enemy icon is the stage of the gold moment only by alpha (no move, no scale)
    local dim = M.DIM
    local dimTo = 1
    if J().EnemyDim() then
      dimTo = dim.a
      if GetTime() - st.clickAt < dim.clickT then
        dimTo = dim.aClick
      end -- j1c M4
    end
    if st.dimA > dimTo then
      st.dimA = math.max(dimTo, st.dimA - dt * (1 - dim.a) / dim.inT)
    elseif st.dimA < dimTo then
      st.dimA = math.min(dimTo, st.dimA + dt * (1 - dim.a) / dim.outT)
    end
    w.enemyIcon:SetAlpha(st.dimA)
    if st.xfade > 0 then -- enemies1b F3: the old picture fades out, linear, alpha only
      st.xfade = math.max(0, st.xfade - dt)
      w.enemyIconOld:SetAlpha(st.dimA * st.xfade / LOOK_XFADE)
      if st.xfade <= 0 then
        w.enemyIconOld:Hide()
      end
    end
    -- j1 A2 #30/#31: no squad bob and no per-frame SetPoint. Every 1.5 s one hired murloc hops (Translation group), never
    -- while another hop, a cheer or a pop-in runs (at most one murloc moves). Calm mode: still (A3)
    if not db.settings.calm then
      st.hopT = st.hopT + dt
      if st.hopT >= 1.5 then
        st.hopT = 0
        local shown = {  }
        local busy = false
        for k = 1, 6 do
          local pk = U.At(w.squad, k)
          if pk.hop:IsPlaying() or pk.cheer:IsPlaying() or pk.popIn:IsPlaying() then
            busy = true
          end
          if pk.hired == true then
            U.Insert(shown, pk)
          end
        end
        if not busy and U.Len(shown) > 0 then
          U.At(shown, 1 + math.floor(math.random() * U.Len(shown))).hop:Play()
        end
      end
    end
  end
end
