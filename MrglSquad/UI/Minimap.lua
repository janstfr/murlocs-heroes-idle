local ADDON, Mrgl = ...
Mrgl.UI = Mrgl.UI or {}
do
  local MB = {}
  Mrgl.UI.Minimap = MB
  local ICON = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
  local button
  local function settings()
    return Mrgl.db.settings
  end
  local function angle()
    local a = settings().minimapAngle
    if type(a) ~= "number" or a ~= a then
      return 200
    end
    return a
  end
  local function ours()
    return button ~= nil and button:GetParent() == Minimap
  end
  local function place()
    if not ours() then
      return
    end
    local a = math.rad(angle())
    local cx, cy = math.cos(a), math.sin(a)
    local w = Minimap:GetWidth() / 2 + 5
    local h = Minimap:GetHeight() / 2 + 5
    local square = false
    if type(GetMinimapShape) == "function" then
      local ok, shape = pcall(GetMinimapShape)
      square = ok and shape == "SQUARE"
    end
    local x, y
    if square then
      x = math.max(-w, math.min(w, cx * w * 1.42))
      y = math.max(-h, math.min(h, cy * h * 1.42))
    else
      x = cx * w
      y = cy * h
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
  end
  local function dragUpdate(self)
    if not IsMouseButtonDown("LeftButton") or not ours() then
      self:SetScript("OnUpdate", nil)
      return
    end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if type(mx) ~= "number" or type(my) ~= "number" or type(px) ~= "number" or type(py) ~= "number"
      or type(scale) ~= "number" or scale <= 0 then
      return
    end
    px = px / scale
    py = py / scale
    local deg = math.floor(math.deg(math.atan2(py - my, px - mx)) + 0.5)
    settings().minimapAngle = math.fmod(deg + 360, 360)
    place()
  end
  local function tip(tt)
    local S = Mrgl.Data.Strings
    local U = Mrgl.U
    local db = Mrgl.db
    tt:AddLine(S.COMPARTMENT, 1, 0.82, 0)
    if db ~= nil then
      tt:AddLine(U.Fill(S.STAGE_TITLE, { s = db.stage }), 1, 1, 1)
      tt:AddLine(U.Fill(S.MINIMAP_GOLD, { gold = U.Short(math.floor(db.gold)) }), 1, 1, 1)
    end
    tt:AddLine(S.MINIMAP_CLICK, 0.7, 0.7, 0.7)
  end
  local function ready()
    local UI = Mrgl.UI
    return Mrgl.db ~= nil and UI.IsReady ~= nil and UI.IsReady()
  end
  local function onClick(self, mouse)
    if not ready() then
      return
    end
    local UI = Mrgl.UI
    UI.Kit.HideOwnTip()
    local f = UI.Main.w.frame
    if mouse == "RightButton" then
      if UI.Main.SetMinimized == nil then
        return
      end
      if not f:IsShown() then
        UI.Main.SetMinimized(true)
        UI.Toggle(true)
      else
        UI.Main.SetMinimized(not UI.Main.IsMinimized())
      end
    elseif IsShiftKeyDown() then
      if UI.Popup.TideIsOpen ~= nil and UI.Popup.TideIsOpen() then
        UI.Popup.TideCancel()
      end
      if UI.Main.SetMinimized ~= nil and UI.Main.IsMinimized() then
        UI.Main.SetMinimized(false)
      end
      if not f:IsShown() then
        UI.Toggle(true)
      end
      if f:IsShown() then
        UI.Panel.OpenSettings()
      end
    else
      UI.Toggle()
    end
  end
  local function create()
    button = CreateFrame("Button", "MrglSquadMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER", button, "CENTER", 0, 0)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(31, 31)
    hl:SetPoint("CENTER", button, "CENTER", 0, 0)
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    button.mrglTipKeepAnchor = true
    button.mrglTip = function(tt)
      tip(tt)
    end
    button:SetScript("OnClick", onClick)
    button:SetScript("OnDragStart", function(self)
      Mrgl.UI.Kit.HideOwnTip()
      if not ours() then
        return
      end
      self:SetScript("OnUpdate", dragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
      self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
      if Mrgl.UI.Kit.NoTips() then
        return
      end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      tip(GameTooltip)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      Mrgl.UI.Kit.HideOwnTip()
    end)
  end
  MB.Apply = function()
    if Mrgl.db == nil or Minimap == nil then
      return
    end
    if settings().minimap == false then
      if button ~= nil then
        button:Hide()
      end
      return
    end
    if button == nil then
      create()
    end
    place()
    button:Show()
  end
  MB.Toggle = function(quiet)
    local s = settings()
    s.minimap = s.minimap == false
    MB.Apply()
    if quiet ~= true then
      local S = Mrgl.Data.Strings
      if s.minimap then
        print(S.MINIMAP_SHOWN)
      else
        print(S.MINIMAP_HIDDEN)
      end
    end
  end
  MB.Frame = function()
    return button
  end
end
