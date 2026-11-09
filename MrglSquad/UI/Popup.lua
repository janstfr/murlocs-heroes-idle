local ADDON, Mrgl = ...
-- Mrgl Squad - UI/Popup.lua equivalent: "Welcome back" popup (plan 3.5, r2 S2) and the settings page inside the
-- panel (r2 S1, replaces the popover of plan 3.4). The page lives here because of the browser-only faction switch (W7;
-- the switch itself is not ported, in WoW the character decides).
Mrgl.UI = Mrgl.UI or {}
do
  local K, C, Core, Tips, Panel, readinessColor, rowY, toggleRow, textButton, label, screenPos
  local welcomeOpen, tideSmall, tideText, tideRow, tideKeepLayout, pathIndex, tideFill, tideCover
  local Po = {}
  Mrgl.UI.Popup = Po
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
  function Tips()
    return Mrgl.UI.Tips
  end
  function Panel()
    return Mrgl.UI.Panel
  end
  local w = {}
  Po.w = w
  -- New Tide Q: the tide popup's widgets and state (declared here: Po.IsOpen reads it)
  local tp = { open = false, path = "m", picks = {}, keep = {}, reset = {}, inC = false, cover = "", lw = 0 } -- tide1b T6: inC = combat look shown
  Po.tp = tp
  local roll = { from = 0, to = 0, t = 1 }
  local POP_H = 168; local POP_H_NOGATE = 140 -- r3 F3: without a gate (no boss icon) the popup is shorter
  -- ------------------------------------------------------------ welcome back
  Po.BuildWelcome = function(main)
    local S = Mrgl.Data.Strings
    local dim = CreateFrame("Button", "MrglSquadDimmer", main)
    w.dim = dim
    dim:SetAllPoints(main)
    dim:SetFrameLevel(main:GetFrameLevel() + 12) -- r2 L1: popup level +12
    K().Fill(dim, { 0, 0, 0, 0.55 }, "BACKGROUND")
    dim:SetScript("OnClick", function()
      Po.Collect()
    end)
    dim:Hide()
    local p = CreateFrame("Frame", "MrglSquadWelcome", dim, "BackdropTemplate")
    w.popup = p
    p:SetSize(200, POP_H)
    p:SetPoint("CENTER", main, "CENTER", 0, 0)
    p:EnableMouse(true)
    Panel().Backdrop(p, C().panel) -- r2 R1
    w.popIn = p:CreateAnimationGroup()
    K().AddScale(w.popIn, 0.9, 1, 0.15, 0, 1, "OUT")
    K().AddAlpha(w.popIn, 0, 1, 0.15, 0, 1, "OUT")
    local title = K().Text(p, K().FRIZ, 13, C().gold, "OUTLINE")
    title:SetPoint("TOP", p, "TOP", 0, -12)
    title:SetJustifyH("CENTER")
    title:SetText(S.WELCOME)
    w.watch = K().Icon(p, Mrgl.Data.Icons.watch, "ARTWORK")
    w.watch:SetSize(24, 24)
    w.watch:SetPoint("TOP", p, "TOP", -30, -34)
    w.away = K().Text(p, K().ARIALN, 14, C().text, "")
    w.away:SetPoint("LEFT", w.watch, "RIGHT", 6, 0)
    -- r2 S2: away longer than the offline cap -> "8h counted" below the time
    w.counted = K().Text(p, K().ARIALN, 10, C().muted, "")
    w.counted:SetPoint("TOPLEFT", w.away, "BOTTOMLEFT", 0, -1)
    w.amountRow = CreateFrame("Frame", nil, p)
    w.amountRow:SetSize(180, 26)
    w.amountRow:SetPoint("TOP", p, "TOP", 0, -70)
    w.amount = K().Text(w.amountRow, K().ARIALN, 22, C().gold, "OUTLINE")
    w.amount:SetPoint("CENTER", w.amountRow, "CENTER", 12, 0)
    w.amount:SetJustifyH("CENTER")
    w.coin = K().Icon(w.amountRow, Mrgl.Data.Icons.coin, "ARTWORK")
    w.coin:SetSize(20, 20)
    w.coin:SetPoint("RIGHT", w.amount, "LEFT", -4, 0)
    -- r2 S2 / K7: no ability row; with an open gate the next boss with its readiness border
    local bf = CreateFrame("Frame", "MrglSquadWelcomeBoss", p)
    w.boss = bf
    bf:SetSize(24, 24)
    bf:SetPoint("TOP", p, "TOP", 0, -102)
    K().Fill(bf, C().black, "BACKGROUND")
    bf.icon = K().Icon(bf, nil, "ARTWORK")
    bf.icon:SetPoint("TOPLEFT", bf, "TOPLEFT", 2, -2)
    bf.icon:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -2, 2)
    bf.border = K().Border(bf, C().muted, "OVERLAY")
    bf.border2 = K().Border(bf, C().muted, "OVERLAY", 1) -- 2 px status border (R3)
    K().Tip(bf, function(tt)
      Tips().BossButton(tt)
    end)
    bf:Hide()
    local b = CreateFrame("Button", "MrglSquadCollect", p)
    w.collect = b
    b:SetSize(100, 24)
    b:SetPoint("BOTTOM", p, "BOTTOM", 0, 10)
    K().Fill(b, C().gold, "BACKGROUND")
    K().Highlight(b, b, 0.2)
    local bt = K().Text(b, K().FRIZ, 12, C().dark, "")
    bt:SetShadowOffset(0, 0)
    bt:SetPoint("CENTER", b, "CENTER", 0, 0)
    bt:SetJustifyH("CENTER")
    bt:SetText(S.COLLECT)
    b:SetScript("OnClick", function()
      Po.Collect()
    end)
    -- New Tide S: COLLECT_TIP carries the offline rate ({pct} = 50, or 75 with Murlocs 25)
    K().Tip(b, function(tt)
      Tips().Title(tt, S.COLLECT)
      Tips().Line(tt, U.Fill(S.COLLECT_TIP, { pct = math.floor(Core().Tide.OfflineRate() * 100 + 0.5) }), C().tipText, true)
    end)
    p:SetScript("OnUpdate", function(self, dt)
      if roll.t < 1 then
        roll.t = math.min(1, roll.t + dt / 0.8)
        local e = 1 - (1 - roll.t) * (1 - roll.t)
        w.amount:SetText("+" .. U.Short(roll.from + (roll.to - roll.from) * e))
      end
    end)
  end
  function welcomeOpen()
    return w.dim ~= nil and w.dim:IsShown()
  end
  -- New Tide Q: IsOpen covers both popups (bindings, Esc, debug); Collect only the welcome
  Po.IsOpen = function()
    return welcomeOpen() or tp.open
  end
  Po.WelcomeOpen = welcomeOpen
  function readinessColor()
    local Bo = Core().Boss
    local r = Bo.Ready()
    if Bo.Held() then
      return C().warn
    end
    if r == "green" or r == "greenAbil" then
      return C().good
    end
    if r == "yellow" then
      return C().warn
    end
    return C().muted
  end
  -- report = {seconds, gold}
  Po.ShowWelcome = function(report)
    local S = Mrgl.Data.Strings
    if Mrgl.UI.Main.IsMinimized() then
      Mrgl.UI.Main.SetMinimized(false)
    end -- j1 M2: the popup needs the full window
    local cap = Mrgl.Data.Balance.OFFLINE_MAX
    w.away:SetText(U.Clock(report.seconds))
    if report.seconds > cap then
      w.counted:SetText(U.Fill(S.OFFLINE_COUNTED, { h = math.floor(cap / 3600) }))
    else
      w.counted:SetText("")
    end
    roll.from = 0
    roll.to = report.gold
    roll.t = 0
    w.amount:SetText("+0")
    if Core().Combat.GateOpen() then
      K().SetIcon(w.boss.icon, Core().Boss.NextEnemy().icon)
      local c = readinessColor()
      w.boss.border:SetColor(c)
      w.boss.border2:SetColor(c)
      w.boss:Show()
      w.popup:SetHeight(POP_H)
    else
      -- r3 F3: title, time, amount and Collect fill 140 px with even margins (12 top, 10 bottom)
      w.boss:Hide()
      w.popup:SetHeight(POP_H_NOGATE)
    end
    Mrgl.UI.Main.st.goldHold = report.gold
    w.dim:Show()
    K().Replay(w.popIn)
    Core().SetPopup(true)
  end
  Po.Collect = function()
    if not welcomeOpen() then
      return
    end
    w.dim:Hide()
    Core().SetPopup(false)
    Mrgl.UI.Main.st.goldHold = 0
    Mrgl.UI.Main.Refresh()
  end
  -- a new db (UI.Reset): both popups close without effect
  Po.CloseAll = function()
    Po.TideCancel()
    if welcomeOpen() then
      w.dim:Hide()
      Core().SetPopup(false)
    end
  end
  -- ------------------------------------------------------------ New Tide popup (ngplus-plan Q): MrglSquadTide, 200 x 196
  -- Built like "Welcome back": own background and edge, CENTER of MrglSquadFrame, on a dimmer (0,0,0,0.55) at level +12.
  -- Only from tab 4 (full window; a minimized window is restored first). Open: rt.popup = true (auto-fight and gold
  -- moments wait). Nothing is decided until New Tide is pressed: the path icons switch freely (alpha and edge only, at
  -- once); the dimmer, Esc, Not yet, closing or hiding the window (OnHide reaches the popup) end it without effect.
  -- WoW combat: "Hide in combat" on -> closes like Not yet; off -> stays, New Tide at 0.45 and not clickable,
  -- "Not during combat." in the last line, both back when combat ends. Fades in by alpha only.
  -- Deviation (measured): Keep + Reset with their 7 icons need ~194 px in one row (the popup is 200), and the plan's
  -- "forever" line at y -166 lies under the buttons (top at -166). So Keep and Reset are two rows (y -144, -164; labels in
  -- one column, icons aligned), the forever line is at y -186 and the popup is 232 high (TIDE_POP_H).
  -- tide1c C4: a muted tag (ARIALN 10, 2 lines of 62 px: tag + tag2) under every path: the picks are 64 apart and everything
  -- under them moves down 12 px (popup 244 high)
  -- j5 K3 (Jan: "die ganze Fenstergröße nehmen, damit nicht alles so klein ist"): the popup covers the whole addon
  -- window, the main frame plus the open panel (panel closed: the main frame), re-anchored when the panel opens or
  -- closes while it is up (tideCover). Same content and order, larger: path icons 48 (was 32), every text one size up,
  -- the content centred in the popup. The dimmer, Esc, Not yet, the double-click guard and the alpha-only fade stay.
  local TIDE_KEEP_Y, TIDE_RESET_Y, TIDE_FOREVER_Y = -200, -222, -248
  local TIDE_PICK_X, TIDE_PICK = { -76, 0, 76 }, 48
  local TIDE_KEEP = { { "", "TIDE_KEEP_POINTS" }, { "Ability_Warrior_BattleShout", "TIDE_KEEP_ABIL" }, { "INV_Misc_Gear_01", "TIDE_KEEP_SET" } }
  local TIDE_RESET = { { "INV_Misc_Coin_01", "TIDE_RESET_GOLD" }, { "INV_Misc_Head_Murloc_01", "TIDE_RESET_SQUAD" },
    { "INV_Gauntlets_04", "TIDE_RESET_SELF" }, { "INV_Misc_Bone_HumanSkull_01", "TIDE_RESET_STAGE" } }
  function tideSmall(p, list, a)
    local S = Mrgl.Data.Strings
    local out = {}
    for i = 1, U.Len(list) do
      local e = U.At(list, i)
      local ic = U.At(e, 1)
      if ic == "" then
        ic = Mrgl.Data.Tide.icon
      end
      local f = CreateFrame("Frame", nil, p)
      f:SetSize(16, 16)
      f.tex = K().Icon(f, ic, "ARTWORK")
      f.tex:SetAllPoints(f)
      f:SetAlpha(a)
      K().Tip(f, Tips().Simple(S[U.At(e, 2)]))
      U.Insert(out, f)
    end
    return out
  end
  function tideText(p, size, c, y, text)
    local fs = K().Text(p, K().ARIALN, size, c, "")
    fs:SetPoint("TOP", p, "TOP", 0, y)
    fs:SetJustifyH("CENTER")
    if text ~= nil then
      fs:SetText(text)
    end
    return fs
  end
  Po.BuildTide = function(main)
    local S = Mrgl.Data.Strings
    local D = Mrgl.Data.Tide
    local dim = CreateFrame("Button", "MrglSquadTideDimmer", main)
    tp.dim = dim
    dim:SetAllPoints(main)
    dim:SetFrameLevel(main:GetFrameLevel() + 12)
    K().Fill(dim, { 0, 0, 0, 0.55 }, "BACKGROUND")
    dim:SetScript("OnClick", function()
      Po.TideCancel()
    end)
    dim:Hide()
    local p = CreateFrame("Frame", "MrglSquadTide", dim, "BackdropTemplate")
    tp.popup = p
    tp.main = main
    p:Hide() -- shown only while open: WoW's Esc (CloseSpecialWindows) checks IsShown, not IsVisible
    p:SetAllPoints(main) -- j5 K3: tideCover sets the real cover on open
    p:EnableMouse(true)
    Panel().Backdrop(p, C().panel)
    tp.popIn = p:CreateAnimationGroup()
    K().AddAlpha(tp.popIn, 0, 1, 0.15, 0, 1, "OUT")
    -- Esc: WoW hides UISpecialFrames; the popup's OnHide (also when the window hides) cancels
    tinsert(UISpecialFrames, "MrglSquadTide")
    p:SetScript("OnHide", function()
      Po.TideCancel()
    end)
    -- j5b P5: a small static X top right (the window's X is under the popup): exactly like Not yet; muted, white on hover
    local x = CreateFrame("Button", "MrglSquadTideClose", p)
    tp.x = x
    x:SetSize(14, 14)
    x:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
    x.tex = x:CreateTexture(nil, "ARTWORK")
    x.tex:SetTexture(K().Media(Mrgl.Data.Icons.close))
    x.tex:SetAllPoints(x)
    K().SetVertex(x.tex, C().muted)
    x:SetScript("OnEnter", function()
      K().SetVertex(x.tex, C().white)
    end)
    x:SetScript("OnLeave", function()
      K().SetVertex(x.tex, C().muted)
    end)
    K().Tip(x, Tips().Simple(S.TIDE_CANCEL))
    x:SetScript("OnClick", function()
      Po.TideCancel()
    end)
    local title = K().Text(p, K().FRIZ, 14, C().gold, "OUTLINE")
    title:SetPoint("TOP", p, "TOP", 0, -12)
    title:SetJustifyH("CENTER")
    title:SetText(S.TIDE_POP_TITLE)
    tideText(p, 12, C().muted, -34, S.TIDE_CHOOSE)
    for i = 1, U.Len(D.paths) do
      local d = U.At(D.paths, i)
      local b = CreateFrame("Button", "MrglSquadTidePick" .. i, p)
      b:SetSize(TIDE_PICK, TIDE_PICK)
      b:SetPoint("TOP", p, "TOP", U.At(TIDE_PICK_X, i), -54)
      K().Fill(b, C().black, "BACKGROUND")
      b.icon = K().Icon(b, d.icon, "ARTWORK")
      b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
      b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
      b.sel = K().Border(b, C().gold, "OVERLAY", 0, 2)
      b.edge = K().Border(b, C().line, "OVERLAY")
      K().Highlight(b, b.icon, 0.15, true)
      b.id = d.id
      b.index = i
      b:SetScript("OnClick", function(self)
        Po.TidePick(self.id)
      end)
      K().Tip(b, function(tt, self)
        Tips().TidePick(tt, self.index)
      end)
      b.tag = K().Text(p, K().ARIALN, 11, C().muted, "") -- tide1c C4: Best while away / clicking / at bosses
      b.tag:SetWidth(74)
      b.tag:SetPoint("TOP", b, "BOTTOM", 0, -2)
      b.tag:SetJustifyH("CENTER")
      b.tag2 = K().Text(p, K().ARIALN, 11, C().muted, "") -- fontstrings never wrap (K.Text): the last word goes on line 2
      b.tag2:SetWidth(74)
      b.tag2:SetPoint("TOP", b.tag, "BOTTOM", 0, 0)
      b.tag2:SetJustifyH("CENTER")
      local head, last = string.match(d.tag, "^(.*) (%S+)$")
      b.tag:SetText(head or d.tag)
      b.tag2:SetText(last or "")
      U.Insert(tp.picks, b)
    end
    tp.rank = tideText(p, 14, C().text, -138)
    tp.ms = tideText(p, 12, C().good, -158)
    tideText(p, 12, C().good, -176, S.TIDE_POP_FLOOD)
    tp.keepL = K().Text(p, K().ARIALN, 11, C().muted, "")
    tp.keepL:SetText(S.TIDE_KEEP)
    tp.resetL = K().Text(p, K().ARIALN, 11, C().muted, "")
    tp.resetL:SetText(S.TIDE_RESET)
    tp.keep = tideSmall(p, TIDE_KEEP, 1)
    tp.reset = tideSmall(p, TIDE_RESET, 0.7)
    tp.forever = tideText(p, 11, C().muted, TIDE_FOREVER_Y)
    local go = CreateFrame("Button", "MrglSquadTideGo", p)
    tp.go = go
    go:SetSize(100, 24)
    go:SetPoint("BOTTOM", p, "BOTTOM", -46, 10)
    K().Fill(go, C().gold, "BACKGROUND")
    K().Highlight(go, go, 0.2)
    go.icon = K().Icon(go, U.At(D.paths, 1).icon, "ARTWORK")
    go.icon:SetSize(16, 16)
    go.icon:SetPoint("LEFT", go, "LEFT", 5, 0)
    go.text = K().Text(go, K().FRIZ, 13, C().dark, "")
    go.text:SetShadowOffset(0, 0)
    go.text:SetPoint("CENTER", go, "CENTER", 8, 0)
    go.text:SetJustifyH("CENTER")
    go.text:SetText(S.TIDE_GO)
    go:SetScript("OnClick", function()
      Po.TideGo()
    end)
    local no = CreateFrame("Button", "MrglSquadTideCancel", p)
    no:SetSize(80, 24)
    no:SetPoint("BOTTOM", p, "BOTTOM", 54, 10)
    K().Fill(no, C().panel, "BACKGROUND")
    K().Border(no, C().line, "BORDER")
    K().Highlight(no)
    local nt = K().Text(no, K().FRIZ, 13, C().text, "")
    nt:SetPoint("CENTER", no, "CENTER", 0, 0)
    nt:SetJustifyH("CENTER")
    nt:SetText(S.TIDE_CANCEL)
    no:SetScript("OnClick", function()
      Po.TideCancel()
    end)
    -- "Hide in combat" on: the window goes, the popup closes like Not yet at once (the fade-out would end it 0.15 s later)
    Core().On("COMBAT", function(ev)
      if ev.on and tp.open and Mrgl.db.settings.hideCombat ~= false then
        Po.TideCancel()
      end
    end)
    p:SetScript("OnUpdate", function()
      Po.TideRefresh()
    end)
  end
  -- Keep: label + 3 icons, Reset: label + 4 icons; 16 x 16, 4 apart. The labels share one column (ARIALN 11 muted), the
  -- icons start 6 px after the wider label, so both rows line up; j5 K3: the block is centred in the popup (from TOP)
  function tideRow(label, list, y, x0)
    label:ClearAllPoints()
    label:SetPoint("LEFT", tp.popup, "TOP", x0, y - 8)
    for i = 1, U.Len(list) do
      local k = U.At(list, i)
      k:ClearAllPoints()
      k:SetPoint("TOPLEFT", tp.popup, "TOP", x0 + tp.lw + 6 + (i - 1) * 20, y)
    end
  end
  function tideKeepLayout()
    tp.lw = math.ceil(math.max(tp.keepL:GetStringWidth(), tp.resetL:GetStringWidth()))
    local x0 = -math.floor((tp.lw + 6 + U.Len(tp.reset) * 20 - 4) / 2)
    tideRow(tp.keepL, tp.keep, TIDE_KEEP_Y, x0)
    tideRow(tp.resetL, tp.reset, TIDE_RESET_Y, x0)
  end
  -- j5 K3: the popup covers the main frame plus the open panel (whichever side it docks on), else the main frame
  function tideCover()
    local main, pf = tp.main, Mrgl.UI.Panel.Frame()
    local key = "main"
    if pf:IsShown() then
      key = "left"
      if pf:GetLeft() > main:GetLeft() then
        key = "right"
      end
    end
    if key == tp.cover then
      return
    end
    tp.cover = key
    local p = tp.popup
    p:ClearAllPoints()
    if key == "left" then
      p:SetPoint("TOPLEFT", pf, "TOPLEFT", 0, 0)
      p:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
    elseif key == "right" then
      p:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
      p:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", 0, 0)
    else
      p:SetAllPoints(main)
    end
    -- j5b P1: with the panel the three paths spread over the width (thirds of main + panel), else 76 apart
    local dx = 76
    if key ~= "main" then
      dx = math.floor((main:GetWidth() + pf:GetWidth() - 1) / 3)
    end
    for i = 1, U.Len(tp.picks) do
      local b = U.At(tp.picks, i)
      b:ClearAllPoints()
      b:SetPoint("TOP", p, "TOP", (i - 2) * dx, -54)
    end
  end
  Po.TideCover = function() -- tests
    return tp.cover
  end
  function pathIndex(id)
    local paths = Mrgl.Data.Tide.paths
    for i = 1, U.Len(paths) do
      if U.At(paths, i).id == id then
        return i
      end
    end
    return 0
  end
  -- the popup's lines for the chosen path (Q table); called on open, on every pick and per frame (combat look)
  function tideFill()
    local S = Mrgl.Data.Strings
    local D = Mrgl.Data.Tide
    local pr = Mrgl.db.prestige
    local first = pr.count <= 0
    for i = 1, U.Len(tp.picks) do
      local b = U.At(tp.picks, i)
      local on = b.id == tp.path
      b.sel:SetShown(on)
      b.edge:SetShown(not on)
      if on then
        b:SetAlpha(1)
      else
        b:SetAlpha(0.6)
      end
    end
    local pi = pathIndex(tp.path)
    local p = U.At(D.paths, pi)
    local old = pr.paths[p.id]
    tp.rank:SetText(U.Fill(S.TIDE_POP_RANK, { path = p.name, old = old, ["new"] = old + 1 }))
    local hit
    for k = 1, U.Len(p.ms) do
      if U.At(p.ms, k).at == old + 1 then
        hit = U.At(p.ms, k)
      end
    end
    if hit ~= nil then
      tp.ms:SetText(U.Fill(S.TIDE_POP_NEW, { name = hit.name }))
      K().SetTextColor(tp.ms, C().good)
    elseif first then
      tp.ms:SetText(U.Fill(S.TIDE_POP_NEW, { name = U.At(D.first, 1).name .. " · " .. U.At(D.first, 2).name }))
      K().SetTextColor(tp.ms, C().good)
    else
      local nx = Tips().TideNextMs(pi)
      if nx ~= nil then
        tp.ms:SetText(U.Fill(S.TIDE_POP_NEXT, { name = nx.name, r = nx.at }))
      else
        tp.ms:SetText(S.TIDE_ALL_MS)
      end
      K().SetTextColor(tp.ms, C().muted)
    end
    K().SetIcon(tp.go.icon, p.icon)
    local inC = Core().rt.inCombat == true
    tp.inC = inC
    -- tide1b T6: disabled in combat, so the dimmed button shows no hover highlight either
    if inC then
      tp.go:SetAlpha(0.45)
      tp.go:Disable()
      tp.forever:SetText(S.TIDE_NO_COMBAT)
    else
      tp.go:SetAlpha(1)
      tp.go:Enable()
      tp.forever:SetText(S.TIDE_FOREVER)
    end
  end
  Po.ShowTide = function()
    if tp.dim == nil or Po.IsOpen() or not Core().Tide.Ready() then
      return false
    end
    if Mrgl.UI.Main.IsMinimized() then
      Mrgl.UI.Main.SetMinimized(false)
    end -- Q: the popup needs the full window
    local pr = Mrgl.db.prestige
    tp.path = pr.last
    if pr.count <= 0 or pathIndex(tp.path) <= 0 then
      tp.path = "m"
    end -- Q: the first New Tide recommends Murlocs
    tp.open = true
    tp.cover = ""
    tideCover()
    tideKeepLayout()
    tideFill()
    tp.popup:Show()
    tp.dim:Show()
    K().Replay(tp.popIn)
    Core().SetPopup(true)
    Core().rt.tideVeil = true -- tide1c C7: no boss start while the popup or the moment is up
    return true
  end
  Po.TideIsOpen = function()
    return tp.open
  end
  Po.TidePick = function(id)
    if not tp.open or pathIndex(id) <= 0 then
      return
    end
    tp.path = id
    tideFill()
  end
  -- per frame while open: the combat look; New Tide no longer available -> close without effect
  Po.TideRefresh = function()
    if not tp.open then
      return
    end
    if not Core().Tide.Avail() then
      Po.TideCancel()
      return
    end
    tideCover() -- j5 K3: the panel opened or closed while the popup is up
    if (Core().rt.inCombat == true) ~= tp.inC then
      tideFill()
    end -- tide1b T6: only when combat starts or ends
  end
  Po.TideCancel = function()
    if not tp.open then
      return
    end
    tp.open = false
    tp.popup:Hide()
    tp.dim:Hide()
    K().HideOwnTip()
    Core().SetPopup(false)
    Core().rt.tideVeil = false
    Mrgl.UI.Main.Refresh()
  end
  -- New Tide: the choice is final. rt.popup stays true until the reset at 0.3 s (Juice.TideMoment): nothing starts behind
  -- the veil. In combat (hideCombat off) the button is not clickable.
  Po.TideGo = function()
    if not tp.open or not Core().Tide.Ready() then
      return false
    end
    local path = tp.path
    tp.open = false
    tp.popup:Hide()
    tp.dim:Hide()
    K().HideOwnTip()
    if Mrgl.UI.Panel.IsOpen() then
      Mrgl.UI.Panel.Show(false)
    end -- tide1c C10: back to the single window
    Mrgl.UI.Juice.TideMoment(path) -- keeps rt.tideVeil until the veil is gone
    return true
  end
  -- ------------------------------------------------------------ settings page (r2 S1)
  -- Rows 28 px from panel TOPLEFT 12,-40. Anchored to the panel, parented to the page.
  local ROW0 = -40; local ROWH = 28
  function rowY(k)
    return ROW0 - (k - 1) * ROWH
  end
  function toggleRow(page, panel, k, label, get, set, tip)
    local b = CreateFrame("Button", nil, page)
    b:SetSize(236, 24)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, rowY(k) + 4)
    K().Highlight(b)
    b.box = b:CreateTexture(nil, "ARTWORK")
    b.box:SetSize(14, 14)
    b.box:SetPoint("LEFT", b, "LEFT", 4, 0)
    K().SetColor(b.box, { 0, 0, 0, 0.5 })
    b.boxBorder = CreateFrame("Frame", nil, b)
    b.boxBorder:SetAllPoints(b.box)
    K().Border(b.boxBorder, C().muted, "OVERLAY")
    b.fill = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.fill:SetPoint("TOPLEFT", b.box, "TOPLEFT", 3, -3)
    b.fill:SetPoint("BOTTOMRIGHT", b.box, "BOTTOMRIGHT", -3, 3)
    K().SetColor(b.fill, C().gold)
    b.text = K().Text(b, K().FRIZ, 12, C().text, "")
    b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.text:SetText(label)
    b.get = get
    b:SetScript("OnClick", function()
      set(not get())
      Core().Shop.Dirty()
      Po.RefreshSettings()
      Mrgl.UI.Main.Refresh()
    end)
    if tip ~= nil then
      K().Tip(b, Tips().Simple(label, tip))
    end
    U.Insert(w.toggles, b)
    return b
  end
  function textButton(parent, label, wd, h, font, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(wd, h)
    K().Fill(b, { 0, 0, 0, 0.35 }, "BACKGROUND")
    K().Border(b, C().line, "BORDER")
    K().Highlight(b)
    b.text = K().Text(b, font, size, C().text, "")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    return b
  end
  function label(page, panel, k, text)
    local l = K().Text(page, K().FRIZ, 12, C().text, "")
    l:SetPoint("LEFT", panel, "TOPLEFT", 38, rowY(k) - 8)
    l:SetText(text)
    return l
  end
  -- panel = MrglSquadPanel, anchor = gear button (kept for the old signature)
  Po.BuildSettings = function(panel, anchor)
    local S = Mrgl.Data.Strings
    local B = Mrgl.Data.Balance
    local f = CreateFrame("Frame", "MrglSquadSettings", panel)
    w.settings = f
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -32)
    f:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 36)
    f:SetFrameLevel(panel:GetFrameLevel() + 12)
    f:EnableMouse(true)
    -- j1 P1: own opaque background in the panel colour (nothing of the list or behind the panel shows through)
    w.settingsBg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    w.settingsBg:SetAllPoints(f)
    K().SetColor(w.settingsBg, C().panel, 1)
    -- Esc closes the settings page: WoW hides UISpecialFrames on Escape, OnHide returns to the list (r2 S1)
    tinsert(UISpecialFrames, "MrglSquadSettings")
    f:SetScript("OnHide", function()
      if Panel().IsSettingsOpen() then
        Panel().CloseSettings()
      end
    end)
    -- r3 K3: no second tooltip border inside the panel. The page lies on the panel background (the list is hidden
    -- while it is open); the `line` dividers under the tabs (y -30) and above the footer frame it.
    w.toggles = {  }
    local s = function()
      return Mrgl.db.settings
    end
    -- j2 A2: row 1: hide the window in combat
    toggleRow(f, panel, 1, S.SET_HIDE_COMBAT, function()
      return s().hideCombat
    end, function(v)
      s().hideCombat = v
      Mrgl.UI.CombatSetting()
    end)
    toggleRow(f, panel, 2, S.SET_CALM, function()
      return s().calm
    end, function(v)
      s().calm = v
    end, S.SET_CALM_TIP)
    toggleRow(f, panel, 3, S.SET_OPENER, function()
      return s().opener
    end, function(v)
      s().opener = v
    end, S.SET_OPENER_TIP)
    toggleRow(f, panel, 4, S.SET_AUTOFIGHT, function()
      return s().autofight
    end, function(v)
      s().autofight = v
    end, S.SET_AUTOFIGHT_TIP)
    label(f, panel, 5, S.SET_SCALE)
    w.scaleMinus = textButton(f, "-", 20, 20, K().ARIALN, 14)
    w.scaleMinus:SetPoint("LEFT", panel, "TOPLEFT", 150, rowY(5) - 8)
    w.scaleVal = K().Text(f, K().ARIALN, 13, C().white, "")
    w.scaleVal:SetPoint("CENTER", panel, "TOPLEFT", 192, rowY(5) - 8)
    w.scaleVal:SetJustifyH("CENTER")
    w.scalePlus = textButton(f, "+", 20, 20, K().ARIALN, 14)
    w.scalePlus:SetPoint("LEFT", panel, "TOPLEFT", 214, rowY(5) - 8)
    w.scaleMinus:SetScript("OnClick", function(self)
      Po.SetScale(Mrgl.db.settings.scale - B.SCALE_STEP, self)
    end)
    w.scalePlus:SetScript("OnClick", function(self)
      Po.SetScale(Mrgl.db.settings.scale + B.SCALE_STEP, self)
    end)
    -- r3 S6: mouse wheel over the value, one step per notch
    w.scaleWheel = CreateFrame("Frame", "MrglSquadScaleWheel", f)
    w.scaleWheel:SetSize(40, 20)
    w.scaleWheel:SetPoint("CENTER", panel, "TOPLEFT", 192, rowY(5) - 8)
    w.scaleWheel:EnableMouseWheel(true)
    w.scaleWheel:SetScript("OnMouseWheel", function(self, delta)
      local d = B.SCALE_STEP
      if delta < 0 then
        d = -d
      end
      Po.SetScale(Mrgl.db.settings.scale + d, self)
    end)
    local rp = textButton(f, S.SET_RESET_POS, 132, 20, K().FRIZ, 11)
    rp:SetPoint("LEFT", panel, "TOPLEFT", 36, rowY(6) - 8)
    rp:SetScript("OnClick", function()
      Mrgl.UI.Main.ResetPosition()
    end)
    -- [browser] faction switch (in WoW the character decides): not ported
    -- j1 #12: in that row the minimap button on/off (WoW only)
    toggleRow(f, panel, 7, S.SET_MINIMAP, function()
      return s().minimap
    end, function(v)
      s().minimap = v
      if Mrgl.UI.Minimap ~= nil then
        Mrgl.UI.Minimap.Apply()
      end
    end)
    f:Hide()
  end
  Po.RefreshSettings = function()
    if w.settings == nil then
      return
    end
    for i = 1, U.Len(w.toggles) do
      local t = U.At(w.toggles, i)
      t.fill:SetShown(t.get())
    end
    local sc = math.floor(Mrgl.db.settings.scale * 100 + 0.5)
    w.scaleVal:SetText(U.Str(math.floor(sc / 100)) .. "." .. U.Pad2(sc % 100)) -- nonneg
  end
  -- Panel owns the open state (tabs, gear border); these only show or hide the page
  Po.ShowSettingsPage = function(on)
    if w.settings == nil then
      return
    end
    if on then
      Po.RefreshSettings()
      w.settings:Show()
    else
      w.settings:Hide()
    end
  end
  Po.IsSettingsOpen = function()
    return Panel().IsSettingsOpen()
  end
  -- old popover API, kept for main.js, Bindings (Esc) and dev: they now drive the panel page
  Po.ToggleSettings = function()
    Panel().ToggleSettings()
  end
  Po.OpenSettings = function()
    Panel().OpenSettings()
  end
  Po.HideSettings = function()
    if Panel().CloseSettings ~= nil then
      Panel().CloseSettings()
    end
  end
  -- r3 S6: keep = the pressed control (+, - or the wheel field). Its screen position (GetLeft/GetTop x effective
  -- scale) before and after SetScale; the difference goes onto the anchor of the main frame, so it stays under the cursor.
  function screenPos(r)
    local l = r:GetLeft()
    if l == nil then
      return nil
    end
    local e = r:GetEffectiveScale()
    return { x = l * e, y = r:GetTop() * e }
  end
  Po.SetScale = function(v, keep)
    if Mrgl.UI.Main.IsMoving() then
      return
    end -- j1 #13: no scale change while the window is dragged
    local B = Mrgl.Data.Balance
    local s = math.floor(U.Clamp(v, B.SCALE_MIN, B.SCALE_MAX) * 100 + 0.5) / 100
    local main = Mrgl.UI.Main.w.frame
    local before
    if keep ~= nil then
      before = screenPos(keep)
    end
    Mrgl.db.settings.scale = s
    main:SetScale(s)
    K().PixelRefresh()
    Panel().Reanchor()
    if before ~= nil then
      local after = screenPos(keep)
      local pt, _, rel, px, py = main:GetPoint(1)   -- WoW: point, relativeTo, relativePoint, x, y
      if after ~= nil and pt ~= nil then
        local me = main:GetEffectiveScale()
        local x = px + (before.x - after.x) / me
        local y = py + (before.y - after.y) / me
        main:ClearAllPoints()
        main:SetPoint(pt, UIParent, rel, x, y)
        main:SetUserPlaced(false)
        local st = Mrgl.db.settings
        st.point = pt
        st.rel = rel
        st.x = x
        st.y = y -- our SavedVariables own the position (like SavePosition)
        Panel().Reanchor()
      end
    end
    Po.RefreshSettings()
  end
  Po.SetFaction = function(f)
    if Mrgl.db.faction == f then
      return
    end
    Mrgl.db.faction = f
    Mrgl.UI.Main.st.zone = 0
    Mrgl.UI.Main.SetZone(true)
    Mrgl.UI.Main.SetEnemyLook(true)
    Po.RefreshSettings()
    Mrgl.UI.Main.Refresh()
  end
end
