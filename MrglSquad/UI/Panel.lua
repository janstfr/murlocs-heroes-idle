local ADDON, Mrgl = ...
-- Mrgl Squad - UI/Panel.lua equivalent: shop panel MrglSquadPanel (264 x 304) with 3 tabs (plan 3.3, r2 V3-V5, S1).
-- Squad: all 6 murlocs as rows (V4). Upgrades: one row per murloc with its next upgrade (j1 U). Self: all 4 lines (V5).
-- Settings is a page inside the panel (S1, built in Popup.lua because of the browser-only faction switch).
-- Kit pseudo-objects (K.Border, K.MurlocHead) are called with a colon.
Mrgl.UI = Mrgl.UI or {}
do
  local K, C, Core, F, Tips, Po, backdrop, lockBorder, glowBorder, setGlow, buildStat, buildRow, buildUpgradeParts, retry, setSettings, hireAmount, selfLocked, upgState, anyAffordable, bestMark, isBest, resetRow, setCost, fillSquad, fillSelf, fillUpgrade, bestLine
  local Ti, tideNew, anyNew, tideDot, tideLeave, tideBox, tideNewEdge, lockLook, buildTide, buildTidePath, tideReason, fillTide, fillTidePath
  local P = {}
  Mrgl.UI.Panel = P
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
  function Po()
    return Mrgl.UI.Popup
  end
  local w = {}
  P.w = w
  local tw = { seen = false } -- New Tide tab widgets and state (one table: upvalue limits)
  P.tw = tw
  local side = "right"
  local ROWS = 6
  local TABS = 4 -- New Tide R1: squad, upgrades, self, New Tide
  local LOCK_A = 0.25 -- r2 R6: border `line` at alpha 0.25 around locked / teaser elements
  local settingsOpen = false
  -- r3 W14: reanchor state. A hidden window only marks the need; OnShow of the main frame catches up.
  local needReanchor = false
  local retryPending = false
  local retries = 0
  local RETRY_MAX = 3
  -- r2 R1: tooltip border (BackdropTemplate). j1 P1: the backdrop carries only the edge (no bgFile, no
  -- SetBackdropColor, which a later SetBackdrop would reset to white); the background is an own opaque texture
  -- (BACKGROUND -8, under the edge pieces at -7) inside the insets. Returns that texture.
  function backdrop(f, c)
    local I = Mrgl.Data.Icons
    f:SetBackdrop({ edgeFile = I.TOOLTIP_BORDER, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropBorderColor(0.60, 0.60, 0.65, 1)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    K().SetColor(bg, c, 1)
    return bg
  end
  P.Backdrop = backdrop
  function lockBorder(frame)
    local b = K().Border(frame, C().line, "OVERLAY")
    b:SetColor(C().line, LOCK_A)
    b:SetShown(false)
    return b
  end
  function glowBorder(frame)
    local g = CreateFrame("Frame", nil, frame)
    g:SetAllPoints(frame)
    K().Border(g, C().gold, "OVERLAY")
    g:Hide()
    g.pulse = K().Pulse(g, 0.5, 0.4)   -- j1 #14: 0 -> 0.5 in 0.4 s, then still
    return g
  end
  function setGlow(g, on)
    if on and not g:IsShown() then
      g:Show()
      g.pulse:Play()
    end
    if not on and g:IsShown() then
      g.pulse:Stop()
      g:Hide()
    end
  end
  P.Build = function(main)
    local S = Mrgl.Data.Strings
    local f = CreateFrame("Frame", "MrglSquadPanel", main, "BackdropTemplate")
    w.frame = f
    f:SetSize(264, 304)
    f:EnableMouse(true)
    Mrgl.UI.Main.Drag(f) -- j1 #13: the panel drags the window
    w.bg = backdrop(f, C().panel) -- j1 P1: panel colour, alpha 1
    w.zone = f:CreateTexture(nil, "BORDER")
    w.zone:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    w.zone:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    w.zone:SetHeight(127)
    w.openAnim = f:CreateAnimationGroup()
    w.openMove1 = K().AddMove(w.openAnim, -8, 0, 0, 0, 1)
    w.openMove2 = K().AddMove(w.openAnim, 8, 0, 0.15, 0, 2, "OUT")
    K().AddAlpha(w.openAnim, 0, 1, 0.15, 0, 2, "OUT")
    -- tabs (24 x 24: nothing closer than 4 px to the border, R1). New Tide R1: tab 4 at x 92, always there
    local tabIcons = { Mrgl.Data.Icons.tabSquad, Mrgl.Data.Icons.tabUpgrades, Mrgl.Data.Icons.tabSelf, Mrgl.Data.Tide.icon }
    local tabTips = { { S.TAB_SQUAD, S.TAB_SQUAD_TIP }, { S.TAB_UPGRADES, S.TAB_UPGRADES_TIP }, { S.TAB_SELF, S.TAB_SELF_TIP }, { S.TAB_TIDE, S.TAB_TIDE_TIP } }
    w.tabs = {  }
    for i = 1, TABS do
      local t = K().IconButton(f, "MrglSquadTab" .. i, 24, U.At(tabIcons, i))
      t:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1) * 28, -4)
      t.border = K().Border(t, C().gold, "OVERLAY")
      t.dot = t:CreateTexture(nil, "OVERLAY", nil, 2)
      t.dot:SetSize(6, 6)
      t.dot:SetPoint("TOPRIGHT", t, "TOPRIGHT", 2, 2)
      K().SetColor(t.dot, C().good)
      t.index = i
      local tip = U.At(tabTips, i)
      K().Tip(t, Tips().Simple(U.At(tip, 1), U.At(tip, 2)))
      t:SetScript("OnClick", function(self)
        P.SetTab(self.index)
      end)
      U.Insert(w.tabs, t)
    end
    -- buy mode (squad tab only)
    local modeText = { S.MODE_X1, S.MODE_NEXT, S.MODE_MAX }
    local modeTips = { S.MODE_X1_TIP, S.MODE_NEXT_TIP, S.MODE_MAX_TIP }
    w.modes = {  }
    for m = 1, 3 do
      local b = CreateFrame("Button", "MrglSquadMode" .. m, f)
      b:SetSize(34, 18)
      b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8 - (3 - m) * 36, -6)
      K().Highlight(b)
      b.text = K().Text(b, K().ARIALN, 11, C().muted, "")
      b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
      b.text:SetJustifyH("CENTER")
      b.text:SetText(U.At(modeText, m))
      b.line = b:CreateTexture(nil, "ARTWORK")
      b.line:SetHeight(1)
      b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 0)
      b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 0)
      K().SetColor(b.line, C().gold)
      b.index = m
      K().Tip(b, Tips().Simple(U.At(modeText, m), U.At(modeTips, m)))
      b:SetScript("OnClick", function(self)
        Mrgl.db.settings.mode = self.index
        Core().Shop.Dirty()
        P.Refresh()
      end)
      U.Insert(w.modes, b)
    end
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -30)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -30)
    K().SetColor(sep, C().line)
    -- rows (squad, upgrades, self)
    w.rows = {  }
    for r = 1, ROWS do
      U.Insert(w.rows, buildRow(f, r))
    end
    buildTide(f) -- New Tide R2/R3: tab 4
    -- footer
    local fsep = f:CreateTexture(nil, "ARTWORK")
    fsep:SetHeight(1)
    fsep:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 34)
    fsep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 34)
    K().SetColor(fsep, C().line)
    w.statDps = buildStat(f, "MrglSquadStatDPS", Mrgl.Data.Icons.statDps, 10, function(tt)
      Tips().StatDPS(tt)
    end)
    w.statClick = buildStat(f, "MrglSquadStatClick", Mrgl.Data.Icons.statClick, 90, function(tt)
      Tips().StatClick(tt)
    end)
    w.settings = K().IconButton(f, "MrglSquadSettingsButton", 20, Mrgl.Data.Icons.gear)
    w.settings:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 7) -- j2 A3: in the right corner
    w.settings.border = K().Border(w.settings, C().gold, "OVERLAY")
    w.settings.border:SetShown(false)
    K().Tip(w.settings, Tips().Simple(S.SETTINGS))
    w.settings:SetScript("OnClick", function()
      P.ToggleSettings()
    end)
    Po().BuildSettings(f, w.settings)
    f:Hide()
    main:HookScript("OnShow", function()
      if needReanchor then
        retries = 0
        P.Reanchor()
      end
    end) -- r3 W14
    P.Reanchor()
    return f
  end
  function buildStat(f, name, icon, x, tip)
    local b = CreateFrame("Button", name, f)
    b:SetSize(76, 16)
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 9)
    b.icon = K().Icon(b, icon, "ARTWORK")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.text = K().Text(b, K().ARIALN, 13, C().white, "OUTLINE")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    K().Tip(b, tip)
    return b
  end
  -- Row r: squad tab = murloc r (all six, V4), upgrade tab = next upgrade of murloc r (j1 U), self tab = self line r (1-4)
  function buildRow(f, r)
    local b = CreateFrame("Button", "MrglSquadRow" .. r, f)
    b:SetSize(248, 36)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -34 - (r - 1) * 38)
    b.hl = K().Highlight(b)
    -- icon box 32 x 32: plain icon (self) or the tinted murloc head (M1)
    b.ic = CreateFrame("Frame", nil, b)
    b.ic:SetSize(32, 32)
    b.ic:SetPoint("LEFT", b, "LEFT", 2, 0)
    K().Fill(b.ic, C().black, "BACKGROUND")
    b.icon = K().Icon(b.ic, nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b.ic, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b.ic, "BOTTOMRIGHT", -1, 1)
    b.headF = CreateFrame("Frame", nil, b.ic)
    b.headF:SetAllPoints(b.ic)
    b.head = K().MurlocHead(b.headF, r, 32, "ARTWORK")
    b.head.base:SetPoint("TOPLEFT", b.ic, "TOPLEFT", 1, -1)
    b.head.base:SetPoint("BOTTOMRIGHT", b.ic, "BOTTOMRIGHT", -1, 1)
    b.lock = lockBorder(b.ic)
    b.name = K().Text(b, K().FRIZ, 11, C().text, "")
    b.name:SetWidth(118)
    b.name:SetPoint("TOPLEFT", b.ic, "TOPRIGHT", 6, -2)
    b.sub = K().Text(b, K().ARIALN, 11, C().muted, "")
    b.sub:SetWidth(110)
    b.sub:SetPoint("BOTTOMLEFT", b.ic, "BOTTOMRIGHT", 6, 2)
    b.barBg = b:CreateTexture(nil, "ARTWORK")
    b.barBg:SetSize(110, 3)
    b.barBg:SetPoint("BOTTOMLEFT", b.ic, "BOTTOMRIGHT", 6, 3)
    b.barBg:SetColorTexture(1, 1, 1, 0.1)
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetAllPoints(b.barBg)
    b.bar:SetStatusBarTexture(Mrgl.Data.Icons.WHITE)
    b.bar:SetStatusBarColor(U.At(C().gold, 1), U.At(C().gold, 2), U.At(C().gold, 3), 0.7) -- r2 R2
    b.bar:SetMinMaxValues(0, 1)
    -- r2 R4: count and cost on the centre line
    b.count = K().Text(b, K().ARIALN, 16, C().white, "OUTLINE")
    b.count:SetPoint("RIGHT", b, "RIGHT", -84, 0)
    b.count:SetJustifyH("RIGHT")
    b.coin = K().Icon(b, Mrgl.Data.Icons.coin, "ARTWORK")
    b.coin:SetSize(12, 12)
    b.coin:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.cost = K().Text(b, K().ARIALN, 13, C().white, "OUTLINE")
    b.cost:SetPoint("RIGHT", b, "RIGHT", -18, 0)
    b.cost:SetJustifyH("RIGHT")
    b.amount = K().Text(b, K().ARIALN, 10, C().muted, "")
    b.amount:SetPoint("TOPRIGHT", b.cost, "BOTTOMRIGHT", 0, -1)
    b.amount:SetJustifyH("RIGHT")
    buildUpgradeParts(b)
    b.glowFrame = glowBorder(b)
    b.flash = b:CreateTexture(nil, "OVERLAY")
    b.flash:SetAllPoints(b)
    b.flash:SetColorTexture(U.At(C().gold, 1), U.At(C().gold, 2), U.At(C().gold, 3), 1)
    b.flash:SetBlendMode("ADD")
    b.flash:SetAlpha(0)
    b.flashAnim = b.flash:CreateAnimationGroup()
    K().AddAlpha(b.flashAnim, 0.25, 0, 0.5, 0, 1, "OUT")   -- j1 #26
    b.index = r
    b:SetScript("OnClick", function(self)
      P.ClickRow(self.index)
    end)
    K().Tip(b, function(tt, self)
      P.RowTip(tt, self.index)
    end)
    b:Hide()
    return b
  end
  -- j1 U: the upgrade-tab parts of a row (variant a: one row per murloc, its next upgrade). Shown only on tab 2.
  -- Name FRIZ 12 at x 40 / y +6; below it 3 pips 6 x 6 (gap 3, bought = `muted` fill, open = `line` ring) and the effect;
  -- right: the price (setCost, like Squad) or one condition in ARIALN 11 `muted`.
  function buildUpgradeParts(b)
    b.upg = CreateFrame("Frame", nil, b)
    b.upg:SetAllPoints(b)
    b.uName = K().Text(b.upg, K().FRIZ, 12, C().text, "")
    b.uName:SetWidth(140)
    b.uName:SetPoint("LEFT", b, "LEFT", 40, 6)
    b.pips = {  }
    for p = 1, 3 do
      local pip = CreateFrame("Frame", nil, b.upg)
      pip:SetSize(6, 6)
      pip:SetPoint("LEFT", b, "LEFT", 40 + (p - 1) * 9, -8)
      pip.fill = K().Fill(pip, C().muted, "ARTWORK") -- j1b U1: gold means "selected"; a bought pip is muted grey
      pip.ring = K().Border(pip, C().line, "ARTWORK")
      U.Insert(b.pips, pip)
    end
    b.uFx = K().Text(b.upg, K().ARIALN, 11, C().good, "")
    b.uFx:SetWidth(110)
    b.uFx:SetPoint("LEFT", b, "LEFT", 70, -8)
    b.cond = K().Text(b.upg, K().ARIALN, 11, C().muted, "")
    b.cond:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.cond:SetJustifyH("RIGHT")
    b.upg:Hide()
  end
  -- ------------------------------------------------------------ open / close / anchor
  function retry()
    retryPending = false
    P.Reanchor()
  end
  P.Reanchor = function()
    local f = w.frame; local main = Mrgl.UI.Main.w.frame
    if f == nil then
      return
    end
    -- r3 W14: hidden window -> no timer, OnShow catches up
    if not main:IsVisible() then
      needReanchor = true
      return
    end
    if Mrgl.UI.Main.IsMoving() then
      needReanchor = true
      return
    end -- j1 #13: DragStop reanchors once
    if main:GetRight() == nil then
      -- W3: shown but not laid out yet, at most RETRY_MAX frames
      needReanchor = true
      if not retryPending and retries < RETRY_MAX then
        retries = retries + 1
        retryPending = true
        C_Timer.After(0, retry)
      end
      return
    end
    needReanchor = false
    retries = 0
    -- compare in UIParent units (GetScreenWidth is UIParent space)
    local sc = main:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right = main:GetRight() * sc
    f:ClearAllPoints()
    -- j1 P3: dock left when less than 268 px are free on the right (264 panel + margin)
    if GetScreenWidth() - right < 268 * sc then
      side = "left"
      f:SetPoint("TOPRIGHT", main, "TOPLEFT", 1, 0)
    else
      side = "right"
      f:SetPoint("TOPLEFT", main, "TOPRIGHT", -1, 0)
    end
  end
  P.IsOpen = function()
    return w.frame:IsShown()
  end
  P.Show = function(on, quiet)
    local db = Mrgl.db
    db.settings.panel = on
    Mrgl.UI.Main.SetChevron(on)
    if on and Mrgl.UI.Main.IsMinimized() then
      return
    end -- j1 M2: stays closed while minimized, the wish is kept
    if on then
      P.Reanchor()
      w.frame:Show()
      local dx = 8
      if side == "right" then
        dx = -8
      end
      w.openMove1:SetOffset(dx, 0)
      w.openMove2:SetOffset(-dx, 0)
      if quiet ~= true then
        K().Replay(w.openAnim)
      end
      P.Refresh()
    else
      setSettings(false)
      tideLeave() -- New Tide R1: closing the panel leaves tab 4
      w.frame:Hide()
    end
  end
  P.Toggle = function()
    if not Mrgl.UI.Main.w.expand:IsShown() or Mrgl.UI.Main.IsMinimized() then
      return
    end -- j1 M2
    P.Show(not w.frame:IsShown())
  end
  P.SetTab = function(i)
    if i ~= 4 then
      tideLeave()
    end -- New Tide R1: leaving tab 4 clears what was new
    Mrgl.db.settings.tab = i
    setSettings(false)
    P.Refresh()
  end
  P.NextTab = function()
    P.SetTab(Mrgl.db.settings.tab % TABS + 1) -- nonneg
  end
  -- ------------------------------------------------------------ settings page (r2 S1)
  function setSettings(on)
    if on then
      tideLeave()
    end
    settingsOpen = on
    Po().ShowSettingsPage(on)
    if w.settings ~= nil then
      w.settings.border:SetShown(on)
    end
  end
  P.IsSettingsOpen = function()
    return settingsOpen
  end
  P.OpenSettings = function()
    if w.frame == nil then
      return
    end
    if not w.frame:IsShown() then
      P.Show(true, true)
    end
    setSettings(true)
    Po().RefreshSettings()
    P.Refresh()
  end
  P.CloseSettings = function()
    if not settingsOpen then
      return
    end
    setSettings(false)
    P.Refresh()
  end
  P.ToggleSettings = function()
    if settingsOpen then
      P.CloseSettings()
    else
      P.OpenSettings()
    end
  end
  P.RefreshSettings = function()
    Po().RefreshSettings()
  end
  -- ------------------------------------------------------------ helpers
  function hireAmount(i)
    return Core().Shop.Amount(i, Mrgl.db.settings.mode)
  end
  function selfLocked(id)
    return not Core().Shop.SelfVisible(id)
  end
  -- j1 U: state of murloc i's next upgrade: "done" (all three bought), "nohire" (none hired),
  -- "locked" (fewer hired than its requirement), "buy" (unlocked; affordable or not)
  function upgState(i)
    local e = Mrgl.db.murlocs[F().Murloc(i).id]
    if e.u >= 3 then
      return "done"
    end
    if e.n <= 0 then
      return "nohire"
    end
    if e.n < F().UpgradeReq(e.u + 1) then
      return "locked"
    end
    return "buy"
  end
  P.UpgState = upgState
  function anyAffordable(tab)
    local db = Mrgl.db
    local Sh = Core().Shop
    local i
    if tab == 1 then
      do
        i = 1
        while i <= Sh.Count() do
          if Sh.Price(i, hireAmount(i)) <= db.gold then
            return true
          end
          i = i + 1
        end
      end
    elseif tab == 2 then
      do
        i = 1
        while i <= Sh.Count() do
          local e = db.murlocs[F().Murloc(i).id]
          if upgState(i) == "buy" and F().UpgradeCost(i, e.u + 1) <= db.gold then
            return true
          end
          i = i + 1
        end
      end
    else
      local l = Mrgl.Data.Self
      do
        i = 1
        while i <= U.Len(l) do
          local id = U.At(l, i).id
          if not selfLocked(id) and not F().SelfMaxed(id, db.self[id]) and F().SelfCost(id, db.self[id]) <= db.gold then
            return true
          end
          i = i + 1
        end
      end
    end
    return false
  end
  -- r2 E5: the glow marks the first purchase of the Buy best chain; k = how often that item is in the chain
  function bestMark()
    if Mrgl.UI.Juice == nil or Mrgl.UI.Juice.GlowOwner() ~= "buy" then
      return nil
    end
    local ch = Core().Shop.Chain()
    if ch == nil then
      return nil
    end
    local t = ch.first
    local k = 0
    local upName
    if t.kind == "upgrade" then
      upName = U.At(F().Murloc(t.slot).upgrades, t.tier).name
    end
    for i = 1, U.Len(ch.items) do
      local it = U.At(ch.items, i)
      if it.kind == t.kind and it.slot == t.slot and (upName == nil or it.name == upName) then
        k = k + it.count
      end
    end
    if k < 1 then
      k = t.amount
    end
    return { kind = t.kind, slot = t.slot, tier = t.tier, k = k }
  end
  P.BestMark = bestMark
  function isBest(mark, kind, slot, tier)
    if mark == nil or mark.kind ~= kind or mark.slot ~= slot then
      return false
    end
    if kind == "upgrade" then
      return mark.tier == tier
    end
    return true
  end
  -- ------------------------------------------------------------ refresh
  P.Refresh = function()
    if w.frame == nil or not w.frame:IsShown() then
      return
    end
    local db = Mrgl.db
    local tab = db.settings.tab
    local mark = bestMark()
    for i = 1, TABS do
      local t = U.At(w.tabs, i)
      local active = i == tab and not settingsOpen
      t.border:SetShown(active)
      t.icon:SetDesaturated(not active)
      if active then
        t:SetAlpha(1)
      else
        t:SetAlpha(0.6)
      end
      if i == 4 then
        t.dot:SetShown(tideDot())
      else
        t.dot:SetShown(anyAffordable(i))
      end
    end
    local onTide = tab == 4 and not settingsOpen
    w.tide:SetShown(onTide)
    if onTide then
      tw.seen = true
      fillTide()
    end
    for m = 1, 3 do
      local b = U.At(w.modes, m)
      b:SetShown(tab == 1 and not settingsOpen)
      local on = db.settings.mode == m
      if on then
        K().SetTextColor(b.text, C().gold)
      else
        K().SetTextColor(b.text, C().muted)
      end
      b.line:SetShown(on)
    end
    for r = 1, ROWS do
      local row = U.At(w.rows, r)
      if settingsOpen or onTide or tab == 3 and r > U.Len(Mrgl.Data.Self) then
        row:Hide()
        setGlow(row.glowFrame, false)
      else
        row:Show()
        if tab == 1 then
          fillSquad(row, r, mark)
        elseif tab == 2 then
          fillUpgrade(row, r, mark)
        else
          fillSelf(row, r, mark)
        end
      end
    end
    w.statDps.text:SetText(U.Short(Core().Combat.SquadDPS()))
    w.statClick.text:SetText(U.Short(Core().Combat.ClickDamage()))
    local tint = Core().Combat.Zone(db.stage).tint
    -- j1 B2: tint colour at 0.28 in the texture, the gradient only fades the alpha (never a white area)
    w.zone:SetColorTexture(U.At(tint, 1), U.At(tint, 2), U.At(tint, 3), 0.28)
    w.zone:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
  end
  function resetRow(b)
    b.sub:SetText("")
    b.count:SetText("")
    b.amount:SetText("")
    b.barBg:Hide()
    b.bar:Hide()
    b.coin:Show()
    b.ic:SetAlpha(1)
    b.lock:SetShown(false)
    -- j1 U: back from the upgrade look (32-px icon box, name, full alpha, hover)
    b.ic:SetSize(32, 32)
    b.name:Show()
    b.upg:Hide()
    b:SetAlpha(1)
    b.hl:Show()
  end
  function setCost(fs, cost)
    fs:SetText(U.ShortUp(cost))
    if cost <= Mrgl.db.gold then
      K().SetTextColor(fs, C().white)
    else
      K().SetTextColor(fs, C().bad)
    end
  end
  -- r2 V4: every murloc is a row; not hired = dim head (alpha 0.55), name, cost, count 0
  function fillSquad(b, i, mark)
    local db = Mrgl.db
    local mu = F().Murloc(i)
    local n = db.murlocs[mu.id].n
    resetRow(b)
    b.icon:Hide()
    b.headF:Show()
    b.name:SetText(mu.name)
    K().SetTextColor(b.name, C().text) -- r2 R2: hired names in `text`, not gold
    b.count:SetText(U.Str(n))
    local lo = F().PrevMilestone(n); local hi = F().NextMilestone(n)
    b.barBg:Show()
    b.bar:Show()
    b.bar:SetValue((n - lo) / (hi - lo))
    if n > 0 then
      b.head:SetState("full")
      K().SetTextColor(b.count, C().white)
    else
      b.head:SetState("dim")
      b.ic:SetAlpha(0.55)
      b.lock:SetShown(true)
      K().SetTextColor(b.count, C().muted)
    end
    local k = hireAmount(i)
    if db.settings.mode ~= 1 then
      b.amount:SetText("+" .. U.Str(k))
    end
    setCost(b.cost, Core().Shop.Price(i, k))
    setGlow(b.glowFrame, isBest(mark, "hire", i))
  end
  -- r2 V5: all 4 self lines; crit lines before stage 10 dim (alpha 0.4) with "Stage 10" instead of the cost
  function fillSelf(b, j, mark)
    local db = Mrgl.db
    local S = Mrgl.Data.Strings
    local d = U.At(Mrgl.Data.Self, j)
    local r = db.self[d.id]
    resetRow(b)
    b.headF:Hide()
    b.icon:Show()
    K().SetIcon(b.icon, d.icon)
    b.name:SetText(d.name)
    b.count:SetText(U.Str(r))
    b.sub:SetText(Tips().SelfValueText(d.id, r))
    if selfLocked(d.id) then
      b.icon:SetDesaturated(true)
      b.ic:SetAlpha(0.4)
      b.lock:SetShown(true)
      K().SetTextColor(b.name, C().muted)
      K().SetTextColor(b.count, C().muted)
      b.coin:Hide()
      if d.id == "crit" or d.id == "critdmg" then
        b.cost:SetText(U.Fill(S.SELF_LOCK_STAGE, { s = Mrgl.Data.Balance.SELF_CRIT_STAGE }))
      else
        b.cost:SetText(S.SELF_LOCK_HIRE)
      end
      K().SetTextColor(b.cost, C().muted)
      setGlow(b.glowFrame, false)
      return
    end
    b.icon:SetDesaturated(false)
    K().SetTextColor(b.name, C().text) -- r2 R2
    K().SetTextColor(b.count, C().white)
    if F().SelfMaxed(d.id, r) then
      b.cost:SetText(S.MAX)
      K().SetTextColor(b.cost, C().gold)
      b.coin:Hide()
    else
      setCost(b.cost, F().SelfCost(d.id, r))
      -- r3 U4: dead weight (gain "<1%" at the measured click speed) shows its price muted instead of white
      local gain = Tips().SelfGain(d.id)
      if gain >= 0 and U.GainLow(gain) and F().SelfCost(d.id, r) <= db.gold then
        K().SetTextColor(b.cost, C().muted)
      end
    end
    setGlow(b.glowFrame, isBest(mark, "self", j))
  end
  -- j1 U: one row per murloc with its next upgrade (variant a). Exactly one thing on the right: the price (white or
  -- `bad`, with coin), "{n}/{req} hired", "Hire first" (row alpha 0.35) or nothing when complete (row alpha 0.6).
  function fillUpgrade(b, i, mark)
    local S = Mrgl.Data.Strings
    local mu = F().Murloc(i)
    local e = Mrgl.db.murlocs[mu.id]
    local st = upgState(i)
    resetRow(b)
    b.icon:Hide()
    b.headF:Show()
    b.ic:SetSize(28, 28)
    b.name:Hide()
    b.upg:Show()
    b.coin:Hide()
    b.cost:SetText("")
    b.cond:SetText("")
    for p = 1, 3 do
      local pip = U.At(b.pips, p)
      pip.fill:SetShown(p <= e.u)
      pip.ring:SetShown(p > e.u)
    end
    if e.n > 0 then
      b.head:SetState("full")
    else
      b.head:SetState("dim")
    end
    b.lock:SetShown(st == "locked" or st == "nohire")
    b.hl:SetShown(st == "buy")
    if st == "done" then
      -- j1b U1 (UX-A S2): "Complete" in muted grey, not gold (gold = selected); row alpha 0.85 keeps it readable
      b.uName:SetText(S.UPG_COMPLETE)
      K().SetTextColor(b.uName, C().muted)
      b.uFx:SetText("")
      b:SetAlpha(0.85)
      setGlow(b.glowFrame, false)
      return
    end
    local t = e.u + 1
    local up = U.At(mu.upgrades, t)
    b.uName:SetText(up.name)
    if up.special ~= nil then
      b.uFx:SetText(up.sub)
    else
      b.uFx:SetText(S.UPG_EFFECT_DOUBLE)
    end
    if st == "buy" then
      K().SetTextColor(b.uName, C().text)
      K().SetTextColor(b.uFx, C().good)
      b.coin:Show()
      setCost(b.cost, up.cost)
    else
      K().SetTextColor(b.uName, C().muted)
      K().SetTextColor(b.uFx, C().muted)
      if st == "nohire" then
        b.cond:SetText(S.UPG_HIRE_FIRST)
        b:SetAlpha(0.35)
      else
        b.cond:SetText(U.Fill(S.UPG_REQ, { n = e.n, req = F().UpgradeReq(t) }))
      end
    end
    setGlow(b.glowFrame, st == "buy" and isBest(mark, "upgrade", i, t))
  end
  -- ------------------------------------------------------------ New Tide tab (ngplus-plan R, H, T): tab 4, content 248 wide
  -- Head y -34..-80 (R2), three path rows of 56 px at y -84 / -144 / -204 (R3). Nothing stores a position: all hangs on
  -- the panel (J A1). Locked = desaturated at alpha 0.45; reached = colour with a gold edge; "new" (rt.tideNew) fades its
  -- gold edge in once in 0.4 s and then stands still until tab 4 is left. Alpha only, no motion. Factors come from Core.Tide.
  local TIDE_LOCK = 0.45
  local TIDE_PER = { m = "TIDE_PER_M", s = "TIDE_PER_S", a = "TIDE_PER_A" }
  function Ti()
    return Mrgl.Core.Tide
  end
  -- rt.tideNew: milestone ids, "first" and "nef" not seen yet (lives in the core runtime, so a new db or /reload clears it)
  function tideNew()
    local rt = Core().rt
    if rt.tideNew == nil then
      rt.tideNew = {}
    end
    return rt.tideNew
  end
  P.TideNew = tideNew
  P.MarkNew = function(id)
    tideNew()[id] = true
  end
  function anyNew()
    local t = tideNew()
    if t.nef == true or t.first == true then
      return true
    end
    local paths = Mrgl.Data.Tide.paths
    for i = 1, U.Len(paths) do
      local ms = U.At(paths, i).ms
      for k = 1, U.Len(ms) do
        if t[U.At(ms, k).id] == true then
          return true
        end
      end
    end
    return false
  end
  -- R1: the tab dot: New Tide available (not in a boss fight), or something new not seen yet
  function tideDot()
    return (Ti().Avail() and not Mrgl.db.boss.active) or anyNew()
  end
  P.TideDot = tideDot
  -- R1: opened and left again (other tab, settings page, panel closed) -> what was new is seen
  function tideLeave()
    if not tw.seen then
      return
    end
    tw.seen = false
    Core().rt.tideNew = {}
  end
  -- a framed icon: black fill (the 1-px frame), icon inside with the row crop, a 1-px edge, and the "new" edge on its own
  -- frame (0 -> 1 in 0.4 s, then still)
  function tideBox(parent, name, size, icon, button)
    local kind = "Frame"
    if button == true then
      kind = "Button"
    end
    local b = CreateFrame(kind, name, parent)
    b:SetSize(size, size)
    K().Fill(b, C().black, "BACKGROUND")
    b.icon = K().Icon(b, icon, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.edge = K().Border(b, C().line, "OVERLAY")
    b.newF = CreateFrame("Frame", nil, b)
    b.newF:SetAllPoints(b)
    K().Border(b.newF, C().gold, "OVERLAY")
    b.newF:Hide()
    b.newIn = K().Pulse(b.newF, 1, 0.4)
    return b
  end
  function tideNewEdge(b, on)
    b.edge:SetShown(not on)
    if on and not b.newF:IsShown() then
      b.newF:Show()
      K().Replay(b.newIn)
    end
    if not on and b.newF:IsShown() then
      b.newIn:Stop()
      b.newF:Hide()
    end
  end
  -- R2: locked = grey at 0.45 with a `line` edge; free and on = colour, gold edge; free and off = grey, gold edge at 0.5
  function lockLook(b, have, on, isNew)
    if not have then
      b.icon:SetDesaturated(true)
      b:SetAlpha(TIDE_LOCK)
      b.edge:SetColor(C().line)
    elseif on then
      b.icon:SetDesaturated(false)
      b:SetAlpha(1)
      b.edge:SetColor(C().gold)
    else
      b.icon:SetDesaturated(true)
      b:SetAlpha(1)
      b.edge:SetColor(C().gold, 0.5)
    end
    tideNewEdge(b, isNew)
  end
  function buildTide(f)
    local S = Mrgl.Data.Strings
    local D = Mrgl.Data.Tide
    local pg = CreateFrame("Frame", "MrglSquadTidePage", f)
    w.tide = pg
    pg:SetAllPoints(f)
    -- R2 head: icon, the tide factors, Quartermaster and trophy, the button and its one-line reason
    tw.icon = tideBox(pg, "MrglSquadTideIcon", 28, D.icon)
    tw.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -38)
    tw.icon.edge:SetShown(false)
    K().Tip(tw.icon, function(tt)
      Tips().TideHead(tt)
    end)
    -- tide1c C11: the deepest stage of any tide (prestige.best), grey under the icon, after the first New Tide
    tw.best = CreateFrame("Frame", "MrglSquadTideBest", pg)
    tw.best:SetSize(28, 12)
    tw.best:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -67)
    tw.best.text = K().Text(tw.best, K().ARIALN, 10, C().muted, "")
    tw.best.text:SetPoint("CENTER", tw.best, "CENTER", 0, 0)
    tw.best.text:SetJustifyH("CENTER")
    K().Tip(tw.best, function(tt)
      Tips().TideBest(tt)
    end)
    local fl = CreateFrame("Button", "MrglSquadTideFlood", pg)
    tw.flood = fl
    fl:SetSize(84, 14)
    fl:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -37)
    fl.mur = K().Icon(fl, U.At(D.paths, 1).icon, "ARTWORK")
    fl.mur:SetSize(12, 12)
    fl.mur:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -38)
    fl.d = K().Text(fl, K().ARIALN, 12, C().white, "OUTLINE")
    fl.d:SetPoint("LEFT", fl.mur, "RIGHT", 2, 0)
    fl.coin = K().Icon(fl, Mrgl.Data.Icons.coin, "ARTWORK")
    fl.coin:SetSize(12, 12)
    fl.coin:SetPoint("LEFT", fl.d, "RIGHT", 6, 0)
    fl.g = K().Text(fl, K().ARIALN, 12, C().white, "OUTLINE")
    fl.g:SetPoint("LEFT", fl.coin, "RIGHT", 2, 0)
    K().Tip(fl, function(tt)
      Tips().TideFlood(tt)
    end)
    tw.quarter = tideBox(pg, "MrglSquadTideQuarter", 16, U.At(D.first, 1).icon, true)
    tw.quarter:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -56)
    K().Highlight(tw.quarter, tw.quarter.icon, 0.15, true)
    tw.quarter:SetScript("OnClick", function()
      P.TideQuarterClick()
    end)
    K().Tip(tw.quarter, function(tt)
      Tips().TideFirst(tt, 1)
    end)
    tw.nef = tideBox(pg, "MrglSquadTideNef", 16, U.At(D.trophies, 1).icon)
    tw.nef:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -56)
    K().Tip(tw.nef, function(tt)
      Tips().TideTrophy(tt, 1)
    end)
    -- tide1b T4: Ahn'Qiraj and Naxxramas, grey 16 px right of the trophy (2 px apart), "Coming later."
    tw.coming = {}
    for j = 1, U.Len(D.coming) do
      local cb = tideBox(pg, "MrglSquadTideComing" .. j, 16, U.At(D.coming, j).icon)
      cb:SetPoint("TOPLEFT", f, "TOPLEFT", 66 + j * 18, -56)
      lockLook(cb, false, true, false)
      cb.idx = j
      K().Tip(cb, function(tt, self)
        Tips().TideComing(tt, self.idx)
      end)
      U.Insert(tw.coming, cb)
    end
    local b = CreateFrame("Button", "MrglSquadTideButton", pg)
    tw.btn = b
    b:SetSize(110, 24)   -- plan 120: the tide factors reach x 138 at x301 x151
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -38)
    K().Fill(b, C().panel, "BACKGROUND")
    b.edge = K().Border(b, C().line, "BORDER")
    K().Highlight(b)
    b.text = K().Text(b, K().FRIZ, 12, C().text, "")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetJustifyH("CENTER")
    b:SetScript("OnClick", function()
      P.TideOpen()
    end)
    K().Tip(b, function(tt)
      Tips().TideButton(tt)
    end)
    tw.next = K().Text(pg, K().ARIALN, 10, C().muted, "")
    -- tide1b T4: no fixed width: the box is the text itself, so it ends right of Naxxramas (x 118)
    tw.next:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -66)
    tw.next:SetJustifyH("RIGHT")
    local sep = pg:CreateTexture(nil, "ARTWORK")
    sep:SetSize(248, 1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -80)
    K().SetColor(sep, C().line)
    -- R3 rows
    tw.paths = {}
    for i = 1, U.Len(D.paths) do
      U.Insert(tw.paths, buildTidePath(pg, f, i))
    end
    pg:Hide()
  end
  function buildTidePath(pg, f, i)
    local p = U.At(Mrgl.Data.Tide.paths, i)
    local r = CreateFrame("Button", "MrglSquadTidePath" .. i, pg)
    r:SetSize(248, 56)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -84 - (i - 1) * 60)
    local sep = r:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", r, "BOTTOMLEFT", 0, -2)
    sep:SetPoint("TOPRIGHT", r, "BOTTOMRIGHT", 0, -2)
    K().SetColor(sep, C().line)
    r.ic = tideBox(r, "MrglSquadTidePathIcon" .. i, 28, p.icon)
    r.ic:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -2)
    r.ic.edge:SetShown(false)
    r.rec = K().Border(r.ic, C().gold, "OVERLAY", 0, 1, 1) -- R3: recommended first (Murlocs while Total() = 0), static
    r.rec:SetShown(false)
    r.name = K().Text(r, K().FRIZ, 12, C().text, "")
    r.name:SetPoint("TOPLEFT", r.ic, "TOPRIGHT", 8, -1)
    r.name:SetText(p.name)
    r.points = K().Text(r, K().ARIALN, 16, C().white, "OUTLINE")
    r.points:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -4)
    r.points:SetJustifyH("RIGHT")
    r.effect = K().Text(r, K().ARIALN, 10, C().good, "")
    r.effect:SetWidth(170)
    r.effect:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.ms = {}
    for k = 1, U.Len(p.ms) do
      local d = U.At(p.ms, k)
      local m = tideBox(r, "MrglSquadTideMs" .. i .. k, 20, d.icon, true)
      m:SetPoint("TOPLEFT", r, "TOPLEFT", 38 + (k - 1) * 26, -32)
      K().Highlight(m, m.icon, 0.15, true)
      m.num = K().Text(m, K().ARIALN, 10, C().white, "OUTLINE") -- bottom right, like a bag stack count (tide1c C9: 10 px)
      m.num:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, 1)
      m.num:SetJustifyH("RIGHT")
      m.num:SetText(U.Str(d.at))
      m.path = i
      m.k = k
      m:SetScript("OnClick", function(self)
        P.TideMsClick(self.path, self.k)
      end)
      K().Tip(m, function(tt, self)
        Tips().TideMs(tt, self.path, self.k)
      end)
      U.Insert(r.ms, m)
    end
    r.barBg = r:CreateTexture(nil, "ARTWORK")
    r.barBg:SetSize(20, 2)
    r.barBg:SetColorTexture(1, 1, 1, 0.1)
    r.bar = r:CreateTexture(nil, "ARTWORK", nil, 1)
    r.bar:SetHeight(2)
    r.bar:SetPoint("TOPLEFT", r.barBg, "TOPLEFT", 0, 0)
    K().SetColor(r.bar, C().gold)
    r.index = i
    K().Tip(r, function(tt, self)
      Tips().TidePath(tt, self.index)
    end)
    return r
  end
  -- R2: Ready. / Not during combat. / After the boss fight. / Reach Ragnaros (stage 100). (combat before boss before stage)
  function tideReason()
    local S = Mrgl.Data.Strings
    if Core().rt.inCombat == true then
      return { text = S.TIDE_NO_COMBAT, c = C().muted }
    end
    if Mrgl.db.boss.active then
      return { text = S.TIDE_AFTER_BOSS, c = C().muted }
    end
    if not Ti().Avail() then
      return { text = U.Fill(S.TIDE_REACH, { s = Mrgl.Data.Balance.TIDE_STAGE }), c = C().muted }
    end
    return { text = S.TIDE_READY, c = C().good }
  end
  P.TideReason = tideReason
  -- R4 phases: everything is read from Core.Tide and db.prestige on every refresh
  function fillTide()
    local db = Mrgl.db
    local S = Mrgl.Data.Strings
    local T = Ti()
    local total = T.Total()
    local nw = tideNew()
    local grey = total <= 0 and not T.Avail() -- R2: grey before the first New Tide and before stage 100
    tw.icon.icon:SetDesaturated(grey)
    if grey then
      tw.icon:SetAlpha(TIDE_LOCK)
    else
      tw.icon:SetAlpha(1)
    end
    local fc = C().white
    if total <= 0 then
      fc = C().muted
    end
    tw.flood.d:SetText(U.Fill(S.TIDE_FLOOD_X, { x = U.Short(T.FloodDmg()) }))
    tw.flood.g:SetText(U.Fill(S.TIDE_FLOOD_X, { x = U.Short(T.FloodGold()) }))
    K().SetTextColor(tw.flood.d, fc)
    K().SetTextColor(tw.flood.g, fc)
    lockLook(tw.quarter, total >= 1, db.settings[U.At(Mrgl.Data.Tide.first, 1).toggle] ~= false, nw.first == true)
    lockLook(tw.nef, db.prestige.trophies.nef == true, true, nw.nef == true)
    tw.best:SetShown(db.prestige.count >= 1)
    tw.best.text:SetText("" .. db.prestige.best)
    local b = tw.btn
    if T.Ready() then
      b.text:SetText(S.TIDE_BUTTON)
      K().SetTextColor(b.text, C().gold)
      b.edge:SetColor(C().gold)
      b:SetAlpha(1)
    else
      b.text:SetText(S.TIDE_BUTTON_LOCKED)
      K().SetTextColor(b.text, C().text)
      b.edge:SetColor(C().line)
      b:SetAlpha(TIDE_LOCK)
    end
    local why = tideReason()
    tw.next:SetText(why.text)
    K().SetTextColor(tw.next, why.c)
    for i = 1, U.Len(tw.paths) do
      fillTidePath(U.At(tw.paths, i), i, total, nw)
    end
  end
  -- R3: points, the path factor (or "+50% per point" at 0), milestone states, the bar under the next milestone
  function fillTidePath(r, i, total, nw)
    local S = Mrgl.Data.Strings
    local p = U.At(Mrgl.Data.Tide.paths, i)
    local n = Mrgl.db.prestige.paths[p.id]
    r.points:SetText(U.Str(n))
    if n > 0 then
      K().SetTextColor(r.points, C().white)
      K().SetTextColor(r.effect, C().good)
      r.effect:SetText(U.Fill(S.TIDE_PATH_BONUS, { effect = Tips().TideEffect(p.id) })) -- tide1b T2: on top of the tide
    else
      K().SetTextColor(r.points, C().muted)
      K().SetTextColor(r.effect, C().muted)
      r.effect:SetText(S[TIDE_PER[p.id]])
    end
    r.rec:SetShown(total <= 0 and i == 1)
    local nextK = 0
    for k = 1, U.Len(r.ms) do
      local m = U.At(r.ms, k)
      local st = Tips().TideMsState(i, k)
      if st == "reached" then
        m.icon:SetDesaturated(false)
        m:SetAlpha(1)
        m.edge:SetColor(C().gold)
      elseif st == "off" then
        m.icon:SetDesaturated(true)
        m:SetAlpha(1)
        m.edge:SetColor(C().gold, 0.5)
      elseif st == "next" then
        m.icon:SetDesaturated(true)
        m:SetAlpha(0.7)
        m.edge:SetColor(C().line)
        nextK = k
      else
        m.icon:SetDesaturated(true)
        m:SetAlpha(0.35)
        m.edge:SetColor(C().line)
      end
      tideNewEdge(m, nw[U.At(p.ms, k).id] == true)
    end
    if nextK <= 0 then
      r.barBg:Hide()
      r.bar:Hide()
      return
    end
    local lo = 0
    if nextK > 1 then
      lo = U.At(p.ms, nextK - 1).at
    end
    local hi = U.At(p.ms, nextK).at
    r.barBg:ClearAllPoints()
    r.barBg:SetPoint("TOPLEFT", U.At(r.ms, nextK), "BOTTOMLEFT", 0, -2)
    r.barBg:Show()
    local px = math.floor(20 * (n - lo) / (hi - lo))
    if px >= 1 then
      r.bar:SetWidth(px)
      r.bar:Show()
    else
      r.bar:Hide()
    end
  end
  -- R2/R3: a reached milestone with a toggle (s10, a10) or the Quartermaster after the first New Tide switches settings[key]
  P.TideToggle = function(key)
    Ti().Toggle(key) -- core: flips settings[key] only when its milestone is reached, then SAVE
    Mrgl.UI.Main.Refresh()
  end
  P.TideMsClick = function(i, k)
    local p = U.At(Mrgl.Data.Tide.paths, i)
    local d = U.At(p.ms, k)
    if d.toggle == nil or Mrgl.db.prestige.paths[p.id] < d.at then
      return
    end
    P.TideToggle(d.toggle)
  end
  P.TideQuarterClick = function()
    if Ti().Total() < 1 then
      return
    end
    P.TideToggle(U.At(Mrgl.Data.Tide.first, 1).toggle)
  end
  -- R2: the button opens the popup (Q) only when New Tide is ready; otherwise it is not clickable (alpha 0.45)
  P.TideOpen = function()
    if not Ti().Ready() then
      return false
    end
    Po().ShowTide()
    return true
  end
  -- H: TideMark click: restore a minimized window first (it grows upward, j2 A1), then the panel with tab 4
  P.OpenTide = function()
    if Mrgl.UI.Main.IsMinimized() then
      Mrgl.UI.Main.SetMinimized(false)
    end
    P.SetTab(4)
    if not w.frame:IsShown() then
      P.Show(true)
    end
  end
  -- ------------------------------------------------------------ clicks and tooltips
  P.ClickRow = function(r)
    local tab = Mrgl.db.settings.tab
    local Sh = Core().Shop
    if settingsOpen then
      return
    end
    if tab == 1 then
      Sh.Hire(F().Murloc(r).id, hireAmount(r))
    elseif tab == 2 then
      -- j1 U: only the unlocked next upgrade buys (Core checks the gold); complete / locked rows do nothing
      if upgState(r) ~= "buy" then
        return
      end
      Sh.BuyUpgrade(F().Murloc(r).id)
    elseif tab == 3 then
      local d = U.At(Mrgl.Data.Self, r)
      if d == nil or selfLocked(d.id) then
        return
      end
      Sh.BuySelf(d.id)
    end
    Mrgl.UI.Main.Refresh()
  end
  function bestLine(tt, kind, slot, tier)
    local mark = bestMark()
    if not isBest(mark, kind, slot, tier) then
      return
    end
    -- r3 E8: "(×k)" only from 2
    local S = Mrgl.Data.Strings
    if mark.k >= 2 then
      Tips().Line(tt, U.Fill(S.PART_OF_BEST, { k = mark.k }), C().good)
    else
      Tips().Line(tt, S.PART_OF_BEST_1, C().good)
    end
  end
  P.RowTip = function(tt, r)
    local tab = Mrgl.db.settings.tab
    if tab == 1 then
      Tips().Murloc(tt, r, hireAmount(r), Core().Shop.Hired(r) <= 0)
      bestLine(tt, "hire", r)
    elseif tab == 2 then
      -- j1 U: the next upgrade of murloc r
      local st = upgState(r)
      local t = Mrgl.db.murlocs[F().Murloc(r).id].u + 1
      if st == "done" then
        Tips().UpgradeDone(tt, r)
      elseif st == "buy" then
        Tips().Upgrade(tt, r, t)
        bestLine(tt, "upgrade", r, t)
      else
        Tips().UpgradeTeaser(tt, r, t)
      end
    elseif tab == 3 then
      if U.At(Mrgl.Data.Self, r) == nil then
        return
      end
      Tips().Self(tt, r)
      bestLine(tt, "self", r)
    end
  end
  P.FlashMurloc = function(slot)
    if not w.frame:IsShown() or Mrgl.db.settings.tab ~= 1 or settingsOpen then
      return
    end
    local b = U.At(w.rows, slot)
    if b ~= nil then
      K().Replay(b.flashAnim)
    end
  end
end
