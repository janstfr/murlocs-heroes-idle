local ADDON, Mrgl = ...
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
  M.GEO = { w = 240, h = 304, enemyX = 120, enemyY = -94, enemyHalf = 44, goldIconX = 187.5, goldIconY = -13.5, goldIconHalf = 6.5, coinCtrlX = 182, coinCtrlY = -34, hMin = 26 }
  local w = {}
  M.w = w
  local st = { goldShown = 0, goldFrom = 0, goldTo = 0, goldT = 1, goldHold = 0, lag = 1, lagDelay = 0, hpFrac = 1, enemyLocked = false, zone = 0, tintA = true, bossState = "", autoCd = false, t = 0, hopT = 0, unlockAt = {}, collectPulse = false, wasPopup = false, zoneDefer = false, bossHide = false, strBase = -1, pxScale = 0, hoverA = 0, nameA = 1, nameTarget = 1, saveTo = -1, saveFill = -1, saveMark = -1, bossAwayUntil = 0, plusT = -1, plusFresh = false, buyLow = false, min = false, dimA = 1, clickAt = -10, compHold = {}, anyfinHold = false, lookKey = "", lookBoss = false, lookIcon = "", xfade = 0 }
  local BOSS_AWAY = 3
  M.DIM = { a = 0.35, aClick = 0.6, clickT = 1, inT = 0.2, outT = 0.3 }
  local PLUS_IN = 0.2; local PLUS_HOLD = 1.8; local PLUS_END = 2.2
  M.st = st
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
  local drag = { on = false, min = -1, dbgT = 0 }
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
      local p1, _, p3, px, py = f:GetPoint(1)
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
    M.ApplyPosition()
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Reanchor()
    end
    dragLog("snap")
    if drag.min >= 0 then
      local m = drag.min == 1
      drag.min = -1
      M.SetMinimized(m)
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
  local PFX = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
  local PFY = { BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, TOPLEFT = 1, TOP = 1, TOPRIGHT = 1 }
  local function bottomLeft(point, rel, x, y, h)
    if PFX[point] == nil or PFX[rel] == nil then
      return nil
    end
    local f = w.frame
    local k = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
    return { x = PFX[rel] * UIParent:GetWidth() * k + x - PFX[point] * f:GetWidth(),
             y = PFY[rel] * UIParent:GetHeight() * k + y - PFY[point] * h }
  end
  local function anchorBottom(load)
    local s = Mrgl.db.settings
    if s.point == "" or s.rel == "" or (s.point == "BOTTOMLEFT" and s.rel == "BOTTOMLEFT") then
      return
    end
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
    s.y = b.y
    if drag.on then
      return
    end
    local f = w.frame
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", b.x, b.y)
    f:SetUserPlaced(false)
  end
  function savePosition()
    if drag.on then
      return
    end
    local point, _, relPoint, px, py = w.frame:GetPoint(1)
    w.frame:SetUserPlaced(false)
    local s = Mrgl.db.settings
    s.point = point
    s.rel = relPoint
    s.x = px
    s.y = py
    anchorBottom()
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
    end
    local s = Mrgl.db.settings
    local f = w.frame
    f:SetScale(s.scale)
    anchorBottom(true)
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
  local function minSaved()
    return Mrgl.db.settings.minimized == true
  end
  local function minTint(hover)
    if st.min or hover == true then
      K().SetVertex(w.minIcon, C().white)
    else
      K().SetVertex(w.minIcon, C().muted)
    end
  end
  M.ApplyMinimized = function()
    local on = minSaved()
    st.min = on
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
    local body = { w.zoneLayer, w.surface, w.content, w.fx, w.numbers, w.coins, w.headLayer }
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
      w.min:SetAlpha(1)
    end
    M.PlaceGoldPlus(on)
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
    end
    if v == st.min and v == minSaved() then
      return
    end
    anchorBottom()
    Mrgl.db.settings.minimized = v
    M.ApplyMinimized()
    if GameTooltip:GetOwner() == w.min then
      GameTooltip:Hide()
    end
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Reanchor()
    end
    M.Refresh()
    if Mrgl.UI.Save ~= nil then
      Mrgl.UI.Save()
    end
  end
  function zoneGradient(tex, tint)
    tex:SetColorTexture(U.At(tint, 1), U.At(tint, 2), U.At(tint, 3), 0.28)
    tex:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
  end
  M.Build = function()
    local I = Mrgl.Data.Icons
    local f = CreateFrame("Frame", "MrglSquadFrame", UIParent, "BackdropTemplate")
    w.frame = f
    f:SetSize(240, 304)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:HookScript("OnMouseDown", function()
      f:Raise()
    end)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    w.bg = Mrgl.UI.Panel.Backdrop(f, C().bg)
    M.Drag(f)
    f:HookScript("OnHide", function()
      M.DragStop()
    end)
    f:HookScript("OnShow", function()
      M.ApplyZoneLook()
    end)
    w.surface = layer("MrglSquadSurface", M.LEVEL.surface)
    w.content = layer("MrglSquadContent", M.LEVEL.content)
    w.fx = layer("MrglSquadFx", M.LEVEL.fx)
    w.numbers = layer("MrglSquadNumbers", M.LEVEL.numbers)
    w.coins = layer("MrglSquadCoins", M.LEVEL.coins)
    w.headLayer = layer("MrglSquadHeadline", M.LEVEL.headline)
    w.head = layer("MrglSquadHead", M.LEVEL.content)
    local sf = w.surface; local cf = w.content; local hf = w.head
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
    w.zoneFrameA:SetFrameLevel(f:GetFrameLevel() + 1)
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
    w.spot:SetAlpha(0.15)
    w.onboardRing = K().Glow(sf, "ring", 106, C().gold, "ARTWORK", 1)
    w.onboardRing:SetPoint("CENTER", f, "TOPLEFT", M.GEO.enemyX, M.GEO.enemyY)
    w.onboardRing:Hide()
    w.stageWrap = CreateFrame("Frame", "MrglSquadStage", hf)
    lv(w.stageWrap, 2)
    w.stageWrap:SetSize(22, 14)
    w.stageWrap:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
    w.stage = K().Text(w.stageWrap, K().FRIZ, 13, C().gold, "OUTLINE")
    w.stage:SetPoint("LEFT", w.stageWrap, "LEFT", 0, 0)
    w.stagePop = w.stageWrap:CreateAnimationGroup()
    K().AddScale(w.stagePop, 1, 1.05, 0.12, 0, 1, "OUT", "LEFT")
    K().AddScale(w.stagePop, 1.05, 1, 0.2, 0, 2, "IN", "LEFT")
    w.pips = {  }
    for i = 1, 10 do
      local p = hf:CreateTexture(nil, "ARTWORK")
      p:SetSize(6, 6)
      p:SetPoint("TOPLEFT", f, "TOPLEFT", 40 + (i - 1) * 8, -10)
      p:SetColorTexture(1, 1, 1, 0.15)
      U.Insert(w.pips, p)
    end
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
    w.tideMark = CreateFrame("Button", "MrglSquadTideMark", hf)
    lv(w.tideMark, 3)
    w.tideMark:SetSize(16, 16)
    w.tideMark:SetPoint("TOPLEFT", f, "TOPLEFT", 38, -5)
    w.tideMarkIcon = K().Icon(w.tideMark, Mrgl.Data.Tide.icon, "ARTWORK")
    w.tideMarkIcon:SetSize(12, 12)
    w.tideMarkIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -7)
    w.tideMarkIn = K().FadeIn(w.tideMarkIcon, 0.4)
    K().Border(w.tideMark, C().gold, "OVERLAY", 1)
    M.Drag(w.tideMark)
    K().Tip(w.tideMark, function(tt)
      Tips().TideMark(tt)
    end)
    w.tideMark:SetScript("OnClick", function()
      Mrgl.UI.Panel.OpenTide()
      if Core().Tide.Ready() then
        Mrgl.UI.Popup.ShowTide()
      end
    end)
    w.tideMark:Hide()
    w.goldIcon = K().Icon(hf, I.coin, "ARTWORK")
    w.goldIcon:SetSize(13, 13)
    w.goldIcon:SetPoint("TOPRIGHT", f, "TOPRIGHT", -46, -7)
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
    w.goldPlus:SetAlpha(0)
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
    w.name = K().Text(cf, K().FRIZ, 12, C().text, "OUTLINE")
    w.name:SetPoint("CENTER", f, "TOP", 0, -38)
    w.name:SetJustifyH("CENTER")
    local e = CreateFrame("Button", "MrglSquadEnemy", cf)
    w.enemy = e
    lv(e, 2)
    e:SetSize(88, 88)
    e:SetPoint("TOP", f, "TOP", 0, -50)
    e:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    K().Fill(e, C().black, "BACKGROUND")
    w.enemyBorder = K().Border(e, { 1, 1, 1, 0.25 }, "BORDER", 1)
    w.enemyIcon = K().Icon(e, nil, "ARTWORK")
    w.enemyIcon:SetPoint("TOPLEFT", e, "TOPLEFT", 2, -2)
    w.enemyIcon:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -2, 2)
    w.enemyBack = e:CreateTexture(nil, "BACKGROUND", nil, 1)
    w.enemyBack:SetAllPoints(w.enemyIcon)
    K().SetColor(w.enemyBack, C().black)
    w.enemyBack:Hide()
    w.enemyRareBorder = K().Border(e, C().rare, "OVERLAY", 1, 2)
    w.enemyRareBorder:SetShown(false)
    w.enemyBadge = e:CreateTexture(nil, "OVERLAY", nil, 2)
    w.enemyBadge:SetSize(16, 16)
    w.enemyBadge:SetPoint("TOPLEFT", e, "TOPLEFT", -4, 4)
    w.enemyBadge:Hide()
    w.enemyBadgeBg = e:CreateTexture(nil, "OVERLAY", nil, 1)
    w.enemyBadgeBg:SetSize(18, 18)
    w.enemyBadgeBg:SetPoint("TOPLEFT", e, "TOPLEFT", -5, 5)
    w.enemyBadgeBg:SetColorTexture(0, 0, 0, 1)
    w.enemyBadgeBg:Hide()
    w.enemyIconAdd = K().Icon(e, nil, "ARTWORK", 1)
    w.enemyIconAdd:SetAllPoints(w.enemyIcon)
    w.enemyIconAdd:SetBlendMode("ADD")
    w.enemyIconAdd:SetDesaturated(true)
    w.enemyIconAdd:Hide()
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
    K().Highlight(e, w.enemyIcon, 0.04)
    e:SetScript("OnClick", function()
      M.Hit(true)
    end)
    K().Tip(e, function(tt)
      Tips().Enemy(tt)
    end, { delay = Mrgl.Data.Balance.ENEMY_TIP_DELAY })
    local bb = CreateFrame("Button", "MrglSquadBossButton", cf)
    w.boss = bb
    lv(bb, 2)
    bb:SetSize(34, 34)
    bb:SetPoint("LEFT", e, "RIGHT", 22, 8)
    K().Fill(bb, C().black, "BACKGROUND")
    w.bossIcon = K().Icon(bb, nil, "ARTWORK")
    w.bossIcon:SetPoint("TOPLEFT", bb, "TOPLEFT", 2, -2)
    w.bossIcon:SetPoint("BOTTOMRIGHT", bb, "BOTTOMRIGHT", -2, 2)
    w.bossBorder = K().Border(bb, C().line, "OVERLAY", 0, 2)
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
    w.hpGloss:SetColorTexture(1, 1, 1, 0.18)
    w.hpGloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
    K().Border(w.hp, C().black, "OVERLAY", -1, 1, 1)
    w.hpText = K().Text(w.hp, K().ARIALN, 11, C().white, "OUTLINE")
    w.hpText:SetPoint("CENTER", hpf, "CENTER", 0, 0)
    w.hpText:SetJustifyH("CENTER")
    w.timer = CreateFrame("StatusBar", "MrglSquadTimer", cf)
    lv(w.timer, 2)
    w.timer:SetSize(172, 5)
    w.timer:SetPoint("TOPLEFT", hpf, "BOTTOMLEFT", 0, -3)
    w.timerText = K().Text(cf, K().ARIALN, 12, C().gold, "OUTLINE")
    w.timerText:SetPoint("LEFT", w.timer, "RIGHT", 4, -3)
    w.timerText:SetJustifyH("LEFT")
    w.timerText:Hide()
    w.pausedText = K().Text(cf, K().ARIALN, 11, C().muted, "OUTLINE")
    w.pausedText:SetPoint("CENTER", w.timer, "CENTER", 0, -3)
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
    w.timerFade:SetScript("OnStop", function()
      if not Mrgl.db.boss.active then
        w.timer:Hide()
        w.timerText:Hide()
      end
    end)
    w.timer:Hide()
    w.squad = {  }
    for s = 1, 6 do
      U.Insert(w.squad, buildPortrait(cf, s))
    end
    w.comp = {}
    for c = 1, 3 do
      U.Insert(w.comp, buildCompanion(cf, c))
    end
    local ab = CreateFrame("Frame", "MrglSquadAbilities", cf)
    w.abilities = ab
    lv(ab, 2)
    ab:SetSize(170, 38)
    ab:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -218)
    w.ab = {  }
    for a = 1, 4 do
      U.Insert(w.ab, buildAbility(ab, a))
    end
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
      Tips().KeyLine(tt, "MRGLSQUAD_PANEL")
    end)
    ex:SetScript("OnClick", function()
      Mrgl.UI.Panel.Toggle()
    end)
    M.SetChevron(false)
    local b = CreateFrame("Button", "MrglSquadBuyBest", cf)
    w.buy = b
    lv(b, 2)
    b:SetSize(212, 28)
    b:SetPoint("TOP", f, "TOP", 0, -264)
    K().Fill(b, C().panel, "BACKGROUND")
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
    w.buyTier = K().Text(b, K().ARIALN, 10, C().white, "OUTLINE")
    w.buyTier:SetPoint("TOPLEFT", w.buyIconBg, "TOPLEFT", 1, -1)
    w.buyTier:SetJustifyH("LEFT")
    w.buyTier:SetHeight(10)
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
    w.buyGlow = K().Pulse(w.buyGlowFrame, 0.6, 0.4)
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
    J().Build(f)
    Mrgl.UI.Popup.BuildWelcome(f)
    Mrgl.UI.Popup.BuildTide(f)
    M.RegisterState()
    f:SetScript("OnUpdate", function(self, elapsed)
      M.OnUpdate(elapsed)
    end)
    M.ApplyMinimized()
    M.ApplyPosition()
    return f
  end
  function buildPortrait(parent, i)
    local p = CreateFrame("Frame", "MrglSquadPortrait" .. i, parent)
    lv(p, 2)
    p:SetSize(22, 22)
    p.baseX = 34 + (i - 1) * 26
    p:SetPoint("TOPLEFT", w.frame, "TOPLEFT", p.baseX, -182)
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
    p.popIn = p:CreateAnimationGroup()
    K().AddScale(p.popIn, 0.9, 1, 0.25, 0, 1, "OUT")
    K().AddAlpha(p.popIn, 0, 1, 0.25, 0, 1, "OUT")
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
  M.AnyfinShown = function()
    return Core().Tide.HasMs("a", 3) and st.anyfinHold ~= true
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
    b.glowPulse = K().Pulse(b.glow, 0.5, 0.4)
    b.buffBorder = K().Border(b, C().gold, "OVERLAY")
    b.buffBorder:SetShown(false)
    b.cd = CreateFrame("Cooldown", ("MrglSquadAbility" .. i) .. "Cooldown", b, "CooldownFrameTemplate")
    lv(b.cd, 3)
    b.cd:SetAllPoints(b.icon)
    b.cd:SetSwipeColor(0, 0, 0, 0.75)
    b.cd:SetDrawEdge(true)
    b.cd:SetDrawBling(false)
    b.cd:SetHideCountdownNumbers(true)
    b.cd.noCooldownCount = true
    b.top = CreateFrame("Frame", nil, b)
    lv(b.top, 3)
    b.top:SetAllPoints(b)
    b.time = K().Text(b.top, K().ARIALN, 13, C().white, "OUTLINE")
    b.time:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.time:SetJustifyH("CENTER")
    b.timeFont = "cd"
    b.key = K().Text(b.top, K().ARIALN, 10, C().white, "OUTLINE")
    b.key:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
    b.key:SetJustifyH("RIGHT")
    b.key:SetWidth(34)
    b.key:SetAlpha(0.8)
    b.keyText = ""
    b.punch = b:CreateAnimationGroup()
    K().AddScale(b.punch, 0.9, 1, 0.1, 0, 1, "OUT")
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
  M.SetChevron = function(open)
    if open then
      w.chev:SetTexCoord(1, 0, 0, 1)
    else
      w.chev:SetTexCoord(0, 1, 0, 1)
    end
  end
  M.Hit = function(manual)
    M.Press()
    K().TipPoke(w.enemy)
    if manual == true then
      J().ManualClick()
      st.clickAt = GetTime()
    end
    if not Mrgl.db.onboarding.firstClick then
      w.onboardRing:Hide()
    end
    Core().Combat.Click(manual == true)
  end
  M.PRESS = { px = 4, calm = 3, hold = 0.04, back = 0.10, inset = 2 }
  st.press = { t = -1, d = 0, set = 0 }
  local function pressInset(d)
    if d == st.press.set then
      return
    end
    st.press.set = d
    local i = M.PRESS.inset + d
    w.enemyIcon:SetPoint("TOPLEFT", w.enemy, "TOPLEFT", i, -i)
    w.enemyIcon:SetPoint("BOTTOMRIGHT", w.enemy, "BOTTOMRIGHT", -i, i)
  end
  M.Press = function()
    if w.enemyIcon == nil or not w.frame:IsVisible() then
      return
    end
    local d = M.PRESS.px
    if Mrgl.db.settings.calm then
      d = M.PRESS.calm
    end
    st.press.d = d
    st.press.t = 0
    pressInset(d)
  end
  M.UpdatePress = function(dt)
    local pr = st.press
    if pr.t < 0 then
      return
    end
    pr.t = pr.t + dt
    local P = M.PRESS
    local d = pr.d
    if pr.t >= P.hold + P.back then
      d = 0
      pr.t = -1
    elseif pr.t > P.hold then
      d = math.floor(pr.d * (1 - (pr.t - P.hold) / P.back) + 0.5)
    end
    pressInset(d)
  end
  M.PressDepth = function()
    return st.press.set
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
    K().TipPoke(w.enemy)
    local ok = Core().Shop.BuyBest()
    M.Refresh()
    return ok
  end
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
    On("BOSS_WIN", function()
      st.bossAwayUntil = GetTime() + BOSS_AWAY
      st.hpFrac = 0
      st.lag = 0
      st.lagDelay = 0
      w.hpLag:SetValue(0)
      w.hp:SetValue(0)
    end)
    On("BOSS_FAIL", function()
      st.bossAwayUntil = GetTime() + BOSS_AWAY
    end)
  end
  M.UnlockAge = function(id)
    local t = st.unlockAt[id]
    if t == nil then
      return -1
    end
    return GetTime() - t
  end
  st.nameSet = -1
  st.dimSet = -1
  M.ApplyNameAlpha = function(force)
    local a = st.nameA
    if a == st.nameSet and force ~= true then
      return
    end
    st.nameSet = a
    w.name:SetAlpha(a)
    w.name:SetShown(a > 0)
  end
  M.ApplyDim = function(force)
    if st.dimA == st.dimSet and force ~= true then
      return
    end
    st.dimSet = st.dimA
    w.enemyIcon:SetAlpha(st.dimA)
  end
  function spotLook()
    local db = Mrgl.db
    local e = Core().Combat.Enemy()
    local r, g, b, a
    if Core().Combat.CandleActive() then
      r, g, b, a = 1, 0.8, 0.4, 0.25
    elseif e.kind == "rare" and not db.boss.active then
      r, g, b, a = 0.55, 0.75, 1.0, 0.22
    else
      local tint = Core().Combat.Zone(db.stage).tint
      r, g, b, a = U.At(tint, 1) * 0.5 + 0.5, U.At(tint, 2) * 0.5 + 0.5, U.At(tint, 3) * 0.5 + 0.5, 0.15
    end
    local sig = r .. "," .. g .. "," .. b .. "," .. a
    if sig == st.spotSig then
      return
    end
    st.spotSig = sig
    w.spot:SetVertexColor(r, g, b, 1)
    w.spot:SetAlpha(a)
  end
  M.SpotLook = spotLook
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
  local LOOK_XFADE = 0.15
  function setEnemyLook(force)
    local db = Mrgl.db
    local e = Core().Combat.Enemy()
    local key = e.icon .. "|" .. e.name .. "|" .. e.kind
    local boss = db.boss.active == true
    if key ~= st.lookKey then
      local o, t = w.enemyIconOld, st.lookTint
      local fade = force ~= true and J().FastFarm() and not (boss and not st.lookBoss) and st.xfade <= 0
      if fade and st.lookIcon ~= "" and st.lookIcon ~= e.icon then
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
    end
    local sig = key .. "|" .. tostring(boss) .. "|" .. tostring(e.kind == "rare" and not boss)
    if sig == st.lookSig and force ~= true then
      spotLook()
      return
    end
    st.lookSig = sig
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
    M.ApplyNameAlpha(true)
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
      w.enemyBadge:SetAlpha(0.6)
      w.enemyBadge:Show()
      w.enemyBadgeBg:Hide()
    else
      w.enemyBadge:Hide()
      w.enemyBadgeBg:Hide()
    end
    spotLook()
  end
  M.SetEnemyLook = setEnemyLook
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
    M.ApplyDim(true)
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
  function zoneTint(tint, instant)
    st.zoneFading = true
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
    local stageStr = "" .. db.stage
    if stageStr ~= st.stageStr then
      st.stageStr = stageStr
      w.stage:SetText(stageStr)
    end
    local gate = Cb.GateOpen()
    local mark = Core().Tide.Avail() and Core().Tide.Waiting() >= 1 and not db.boss.active
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
    st.goldTo = math.max(0, db.gold - st.goldHold - J().HeldGold())
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
    end
    if not st.zoneDefer then
      M.SetZone(false)
    end
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
      end
      w.timer:SetStatusBarColor(U.At(tc, 1), U.At(tc, 2), U.At(tc, 3), 1)
      K().SetTextColor(w.timerText, tc)
      w.timerText:SetText("" .. math.ceil(left))
    elseif w.timer:IsShown() and not w.timerFade:IsPlaying() then
      w.timer:Hide()
      w.timerText:Hide()
    end
    refreshBossButton()
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
        end
        pt.ring:SetShown(hired)
        pt.count:SetShown(hired)
      end
      pt.count:SetText("" .. n)
      K().SetTextColor(pt.count, C().white)
    end
    for ci = 1, 3 do
      local cp = U.At(w.comp, ci)
      local want = Tips().TideCompanion(ci).has and st.compHold[ci] ~= true
      if want ~= cp:IsShown() then
        cp:SetShown(want)
      end
    end
    w.compSep:SetShown(U.At(w.comp, 1):IsShown() or U.At(w.comp, 2):IsShown())
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
    local str = Bo.Strength()
    if gate and str < 1 then
      w.bossBar:Show()
      w.bossBar:SetValue(str)
      w.bossBar:SetStatusBarColor(U.At(bc, 1), U.At(bc, 2), U.At(bc, 3), 1)
    else
      w.bossBar:Hide()
    end
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
    if d.alt ~= nil and not b.swapOut:IsPlaying() then
      if M.AnyfinShown() then
        K().SetIcon(b.icon, d.alt.icon)
      else
        K().SetIcon(b.icon, d.icon)
      end
    end
    local unlocked = A.Unlocked(d.id)
    if not unlocked then
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
    local rest = math.min(A.Remaining(d.id), d.cd)
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
  M.GainText = function(fs, p)
    fs:SetText(U.Gain(p))
    if U.GainLow(p) then
      K().SetTextColor(fs, C().muted)
    else
      K().SetTextColor(fs, C().good)
    end
  end
  function saveTarget(ch)
    if ch == nil or ch.affordable or not (ch.first.cost > 0) then
      return -1
    end
    return math.max(0, math.min(1, Mrgl.db.gold / ch.first.cost))
  end
  M.SaveFill = function()
    return st.saveFill
  end
  M.SaveMark = function()
    st.saveMark = saveTarget(Core().Shop.Chain())
  end
  M.SaveCheck = function()
    local cur = saveTarget(Core().Shop.Chain())
    local was = st.saveMark
    st.saveMark = -1
    st.saveFill = cur
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
  M.BuyShown = function()
    return st.buyAff == true
  end
  function refreshBuyBest()
    local db = Mrgl.db
    local pop = Core().rt.popup
    if st.wasPopup and not pop then
      st.collectPulse = true
    end
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
    st.buyAff = false
    if ch == nil then
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
      w.buyTier:SetText(U.Roman(t.tier))
    else
      showHead(0)
      K().SetIcon(w.buyIcon, U.At(Mrgl.Data.Self, t.slot).icon)
      w.buyIcon:Show()
    end
    st.buyLow = not ch.isNew and U.GainLow(ch.gain)
    st.buyAff = ch.affordable
    buyDesat(not ch.affordable)
    if not db.onboarding.firstHire and not ch.affordable then
      w.buy:SetAlpha(0.4)
    else
      w.buy:SetAlpha(1)
    end
    if ch.n >= 2 then
      w.buyTimes:SetText("" .. ch.n)
    end
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
      K().SetFont(w.buyGain, K().ARIALN, 10, "OUTLINE")
      w.buyGain:SetText(S().BUY_NEW)
      K().SetTextColor(w.buyGain, C().good)
    else
      K().SetFont(w.buyGain, K().ARIALN, 12, "OUTLINE")
      M.GainText(w.buyGain, ch.gain)
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
    if edgeHitsText(2 + px) then
      w.buySaveEdge:Hide()
    end
  end
  local edgeTexts
  local edgeText = {}; local edgeLit = {}; local edgeVis = {}
  local edgeSpans = {}
  local edgeDirty = true
  function measureEdgeSpans()
    edgeSpans = {}
    local bl = w.buy:GetLeft()
    if bl == nil then
      return
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
      end
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
      w.timer:SetAlpha(0)
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
    local es = w.frame:GetEffectiveScale()
    if es ~= st.pxScale then
      st.pxScale = es
      K().PixelRefresh()
      edgeDirty = true
    end
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
      st.goldT = math.min(1, st.goldT + dt / J().GoldRoll())
      st.goldShown = st.goldFrom + (st.goldTo - st.goldFrom) * st.goldT
    else
      st.goldShown = st.goldTo
    end
    local goldStr = U.Short(math.floor(st.goldShown))
    if goldStr ~= st.goldStr then
      st.goldStr = goldStr
      w.goldText:SetText(goldStr)
    end
    if Core().rt.enemyBank ~= nil and Core().rt.enemyBank > 0 and Core().rt.respawn <= 0 then
      st.hpFrac = M.HpShown(math.max(0, Mrgl.db.enemyHp), F().EnemyHP(Mrgl.db.stage))
      w.hp:SetValue(st.hpFrac)
    end
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
    end
    w.hpLag:SetValue(st.lag)
    local chNow = Core().Shop.Chain()
    if chNow ~= M.chain or (chNow ~= nil and chNow.affordable ~= st.buyAff) then
      refreshBuyBest()
    end
    updateSaveFill(dt)
    M.UpdatePress(dt)
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
    if drag.on and M.DragDebug ~= nil then
      drag.dbgT = drag.dbgT + dt
      if drag.dbgT >= 0.25 then
        drag.dbgT = 0
        M.DragDebug(M.DragLine("move"))
      end
    end
    if drag.on and not IsMouseButtonDown("LeftButton") then
      M.DragStop()
    end
    if st.nameA > st.nameTarget then
      st.nameA = math.max(st.nameTarget, st.nameA - dt / 0.1)
    elseif st.nameA < st.nameTarget then
      st.nameA = math.min(st.nameTarget, st.nameA + dt / 0.2)
    end
    M.ApplyNameAlpha()
    local dim = M.DIM
    local dimTo = 1
    if J().EnemyDim() then
      dimTo = dim.a
      if GetTime() - st.clickAt < dim.clickT then
        dimTo = dim.aClick
      end
    end
    if st.dimA > dimTo then
      st.dimA = math.max(dimTo, st.dimA - dt * (1 - dim.a) / dim.inT)
    elseif st.dimA < dimTo then
      st.dimA = math.min(dimTo, st.dimA + dt * (1 - dim.a) / dim.outT)
    end
    M.ApplyDim()
    if st.xfade > 0 then
      st.xfade = math.max(0, st.xfade - dt)
      w.enemyIconOld:SetAlpha(st.dimA * st.xfade / LOOK_XFADE)
      if st.xfade <= 0 then
        w.enemyIconOld:Hide()
      end
    end
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
