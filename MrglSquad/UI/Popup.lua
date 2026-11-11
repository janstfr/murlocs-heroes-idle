local ADDON, Mrgl = ...
Mrgl.UI = Mrgl.UI or {}
do
  local K, C, Core, Tips, Panel, readinessColor, rowY, toggleRow, textButton, label, screenPos
  local welcomeOpen, tideSmall, tideText, tideRow, tideKeepLayout, pathIndex, tideFill, tideCover, gainNames
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
  local tp = { open = false, path = "m", picks = {}, keep = {}, reset = {}, inC = false, cover = "", lw = 0 }
  Po.tp = tp
  local roll = { from = 0, to = 0, t = 1 }
  local POP_H = 168; local POP_H_NOGATE = 140
  Po.BuildWelcome = function(main)
    local S = Mrgl.Data.Strings
    local dim = CreateFrame("Button", "MrglSquadDimmer", main)
    w.dim = dim
    dim:SetAllPoints(main)
    dim:SetFrameLevel(main:GetFrameLevel() + 12)
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
    Panel().Backdrop(p, C().panel)
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
    local bf = CreateFrame("Frame", "MrglSquadWelcomeBoss", p)
    w.boss = bf
    bf:SetSize(24, 24)
    bf:SetPoint("TOP", p, "TOP", 0, -102)
    K().Fill(bf, C().black, "BACKGROUND")
    bf.icon = K().Icon(bf, nil, "ARTWORK")
    bf.icon:SetPoint("TOPLEFT", bf, "TOPLEFT", 2, -2)
    bf.icon:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -2, 2)
    bf.border = K().Border(bf, C().muted, "OVERLAY")
    bf.border2 = K().Border(bf, C().muted, "OVERLAY", 1)
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
  Po.ShowWelcome = function(report)
    local S = Mrgl.Data.Strings
    if Mrgl.UI.Main.IsMinimized() then
      Mrgl.UI.Main.SetMinimized(false)
    end
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
  Po.CloseAll = function()
    Po.TideCancel()
    if welcomeOpen() then
      w.dim:Hide()
      Core().SetPopup(false)
    end
  end
  local TIDE_KEEP_Y, TIDE_RESET_Y, TIDE_FOREVER_Y = -200, -222, -248
  local TIDE_PICK_X, TIDE_PICK = { -76, 0, 76 }, 48
  local TIDE_KEEP = { { "", "TIDE_KEEP_POINTS" }, { "INV_Misc_Key_03", "TIDE_KEEP_ABIL" }, { "INV_Misc_Gear_01", "TIDE_KEEP_SET" } }
  local TIDE_RESET = { { "INV_Misc_Coin_01", "TIDE_RESET_GOLD" }, { "INV_Misc_Head_Murloc_01", "TIDE_RESET_SQUAD" },
    { "INV_Gauntlets_04", "TIDE_RESET_SELF" }, { "Ability_Warrior_BattleShout", "TIDE_RESET_SPELLS" },
    { "INV_Misc_Bone_HumanSkull_01", "TIDE_RESET_STAGE" } }
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
    p:Hide()
    p:SetAllPoints(main)
    p:EnableMouse(true)
    Panel().Backdrop(p, C().panel)
    tp.popIn = p:CreateAnimationGroup()
    K().AddAlpha(tp.popIn, 0, 1, 0.15, 0, 1, "OUT")
    tinsert(UISpecialFrames, "MrglSquadTide")
    p:SetScript("OnHide", function()
      Po.TideCancel()
    end)
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
    tp.choose = tideText(p, 12, C().muted, -34, S.TIDE_CHOOSE)
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
      b.tag = K().Text(p, K().ARIALN, 11, C().muted, "")
      b.tag:SetWidth(74)
      b.tag:SetPoint("TOP", b, "BOTTOM", 0, -2)
      b.tag:SetJustifyH("CENTER")
      b.tag2 = K().Text(p, K().ARIALN, 11, C().muted, "")
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
    tp.gold = tideText(p, 12, C().good, -176, S.TIDE_POP_GOLD)
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
    Core().On("COMBAT", function(ev)
      if ev.on and tp.open and Mrgl.db.settings.hideCombat ~= false then
        Po.TideCancel()
      end
    end)
    p:SetScript("OnUpdate", function()
      Po.TideRefresh()
    end)
  end
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
  Po.TideCover = function()
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
  function gainNames(id, n)
    local Td = Core().Tide
    local D = Mrgl.Data.Tide
    local g = Td.Gains(id, n)
    local out = ""
    for i = 1, U.Len(g) do
      local x = U.At(g, i)
      local nm
      if x == "first" then
        nm = U.At(D.first, 1).name .. " · " .. U.At(D.first, 2).name
      else
        nm = Td.Def(x).name
      end
      if out == "" then
        out = nm
      else
        out = out .. " · " .. nm
      end
    end
    return out
  end
  function tideFill()
    local S = Mrgl.Data.Strings
    local D = Mrgl.Data.Tide
    local pr = Mrgl.db.prestige
    local n = Core().Tide.Waiting()
    local none = n <= 0
    if n == 1 then
      tp.choose:SetText(S.TIDE_CHOOSE)
    elseif n > 1 then
      tp.choose:SetText(U.Fill(S.TIDE_CHOOSE_N, { n = n }))
    else
      tp.choose:SetText(S.TIDE_NO_PT)
    end
    for i = 1, U.Len(tp.picks) do
      local b = U.At(tp.picks, i)
      local on = b.id == tp.path
      b.sel:SetShown(on and not none)
      b.edge:SetShown(not on or none)
      b.icon:SetDesaturated(none)
      b:SetEnabled(not none)
      if none then
        b:SetAlpha(0.35)
      elseif on then
        b:SetAlpha(1)
      else
        b:SetAlpha(0.6)
      end
      if none then
        b.tag:SetAlpha(0.35)
        b.tag2:SetAlpha(0.35)
      else
        b.tag:SetAlpha(1)
        b.tag2:SetAlpha(1)
      end
    end
    local pi = pathIndex(tp.path)
    local p = U.At(D.paths, pi)
    local old = pr.paths[p.id]
    if none then
      tp.rank:SetText(Tips().TideLuck())
      tp.ms:SetText("")
    else
      tp.rank:SetText(U.Fill(S.TIDE_POP_RANK, { path = p.name, old = old, ["new"] = old + n }))
      local names = gainNames(p.id, n)
      if names ~= "" then
        tp.ms:SetText(U.Fill(S.TIDE_POP_NEW, { name = names }))
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
    end
    tp.gold:SetShown(not none)
    K().SetIcon(tp.go.icon, p.icon)
    tp.go.icon:SetShown(not none)
    tp.go.text:ClearAllPoints()
    if none then
      tp.go.text:SetPoint("CENTER", tp.go, "CENTER", 0, 0)
    else
      tp.go.text:SetPoint("CENTER", tp.go, "CENTER", 8, 0)
    end
    local inC = Core().rt.inCombat == true
    tp.inC = inC
    if inC then
      tp.go:SetAlpha(0.45)
      tp.go:Disable()
      tp.forever:SetText(S.TIDE_NO_COMBAT)
    else
      tp.go:SetAlpha(1)
      tp.go:Enable()
      if none then
        tp.forever:SetText(S.TIDE_NOPT_FOREVER)
      else
        tp.forever:SetText(S.TIDE_FOREVER)
      end
    end
  end
  Po.ShowTide = function()
    if tp.dim == nil or Po.IsOpen() or not Core().Tide.Ready() then
      return false
    end
    if Mrgl.UI.Main.IsMinimized() then
      Mrgl.UI.Main.SetMinimized(false)
    end
    local pr = Mrgl.db.prestige
    tp.path = pr.last
    if pr.count <= 0 or pathIndex(tp.path) <= 0 then
      tp.path = "m"
    end
    tp.open = true
    tp.cover = ""
    tideCover()
    tideKeepLayout()
    tideFill()
    tp.popup:Show()
    tp.dim:Show()
    K().Replay(tp.popIn)
    Core().SetPopup(true)
    Core().rt.tideVeil = true
    return true
  end
  Po.TideIsOpen = function()
    return tp.open
  end
  Po.TidePick = function(id)
    if not tp.open or pathIndex(id) <= 0 or Core().Tide.Waiting() <= 0 then
      return
    end
    tp.path = id
    tideFill()
  end
  Po.TideRefresh = function()
    if not tp.open then
      return
    end
    if not Core().Tide.Avail() then
      Po.TideCancel()
      return
    end
    tideCover()
    if (Core().rt.inCombat == true) ~= tp.inC then
      tideFill()
    end
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
    end
    Mrgl.UI.Juice.TideMoment(path)
    return true
  end
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
  Po.BuildSettings = function(panel, anchor)
    local S = Mrgl.Data.Strings
    local B = Mrgl.Data.Balance
    local f = CreateFrame("Frame", "MrglSquadSettings", panel)
    w.settings = f
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -32)
    f:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 36)
    f:SetFrameLevel(panel:GetFrameLevel() + 12)
    f:EnableMouse(true)
    w.settingsBg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    w.settingsBg:SetAllPoints(f)
    K().SetColor(w.settingsBg, C().panel, 1)
    tinsert(UISpecialFrames, "MrglSquadSettings")
    f:SetScript("OnHide", function()
      if Panel().IsSettingsOpen() then
        Panel().CloseSettings()
      end
    end)
    w.toggles = {  }
    local s = function()
      return Mrgl.db.settings
    end
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
    w.scaleVal:SetText(U.Str(math.floor(sc / 100)) .. "." .. U.Pad2(sc % 100))
  end
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
    end
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
      local pt, _, rel, px, py = main:GetPoint(1)
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
        st.y = y
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
