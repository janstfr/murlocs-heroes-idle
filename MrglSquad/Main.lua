local ADDON, Mrgl = ...
Mrgl.UI = Mrgl.UI or {}
MrglSquad = Mrgl
SLASH_MRGLSQUAD1 = "/mrgl"
SLASH_MRGLSQUAD2 = "/mhi"
do
  local save, playerFaction, fixFaction, Init, Login
  local UI = Mrgl.UI
  local refreshAcc = 0
  local hiddenByCombat = false
  local closed = false
  local blockHidden = false
  local blockerOpen
  local blockAcc = 0
  local built = false
  local uiReady = false
  local pewSeen = false
  local skipFrame = false
  local function hasNonFinite(t, depth)
    if depth > 8 then
      return false
    end
    for _, v in pairs(t) do
      if type(v) == "number" then
        if v ~= v or v - v ~= 0 then
          return true
        end
      elseif type(v) == "table" and hasNonFinite(v, depth + 1) then
        return true
      end
    end
    return false
  end
  local function finiteOnly(t, depth)
    if depth > 8 then
      return
    end
    for k, v in pairs(t) do
      if type(v) == "number" then
        if v ~= v or v - v ~= 0 then
          t[k] = nil
        end
      elseif type(v) == "table" then
        finiteOnly(v, depth + 1)
      end
    end
  end
  local function debugField(name)
    local D = Mrgl.Debug
    if D == nil then
      return nil
    end
    return D[name]
  end
  function save()
    if Mrgl.db == nil then
      return
    end
    if debugField("sandbox") == true then
      return
    end
    local s = Mrgl.Core.State.Save()
    local shift = debugField("offlineShift")
    if type(shift) == "number" and shift > 0 then
      s.account.lastSeen = s.account.lastSeen - shift
      s.character.lastSeen = s.character.lastSeen - shift
    end
    local acct = s.account
    if hasNonFinite(acct, 0) then
      acct = Mrgl.Core.State.Copy(acct)
      finiteOnly(acct, 0)
    end
    finiteOnly(s.character, 0)
    MrglSquadDB = acct
    MrglSquadCharDB = s.character
  end
  UI.Save = save
  UI.Toggle = function(show)
    if not uiReady then
      return
    end
    local f = UI.Main.w.frame
    local on = show
    if show == nil then
      on = not (f:IsShown() or blockHidden)
    end
    closed = not on
    if on and not f:IsShown() and blockerOpen() then
      blockHidden = true
      return
    end
    blockHidden = false
    if hiddenByCombat then
      return
    end
    local was = f:IsShown()
    if not on and was then
      UI.Main.SaveMark()
    end
    f:SetShown(on)
    if on then
      Mrgl.Core.Combat.TakeSquadDealt()
      UI.Juice.OnShow()
      UI.Main.Refresh()
      UI.Juice.StrengthCheck()
      if not was then
        UI.Main.SaveCheck()
      end
    else
      UI.Kit.HideOwnTip()
    end
  end
  local fadeOut, fadeIn
  local function hideCombat()
    return Mrgl.db.settings.hideCombat ~= false
  end
  UI.OnCombat = function(on, gold)
    if not uiReady then
      return
    end
    local f = UI.Main.w.frame
    if on then
      UI.Kit.HideOwnTip()
      if closed or not f:IsShown() or not hideCombat() then
        return
      end
      hiddenByCombat = true
      UI.Kit.HideOwnTip()
      UI.Panel.CloseSettings()
      UI.Main.SaveMark()
      if fadeIn:IsPlaying() then
        fadeIn:Stop()
      end
      UI.Kit.Replay(fadeOut)
    else
      if not hiddenByCombat then
        return
      end
      hiddenByCombat = false
      if blockerOpen() then
        if fadeOut:IsPlaying() then
          fadeOut:Stop()
        end
        f:Hide()
        f:SetAlpha(1)
        blockHidden = true
        return
      end
      if fadeOut:IsPlaying() then
        fadeOut:Stop()
      end
      f:SetAlpha(1)
      f:Show()
      UI.Juice.OnShow()
      UI.Kit.Replay(fadeIn)
      UI.Main.Refresh()
      UI.Main.SaveCheck()
      if gold > 0 then
        UI.Juice.GoldPlus(gold)
      end
    end
  end
  UI.CombatSetting = function()
    if not uiReady then
      return
    end
    Mrgl.Core.rt.combatGold = 0
    if hideCombat() then
      if Mrgl.Core.rt.inCombat and not hiddenByCombat then
        UI.OnCombat(true, 0)
      end
    elseif hiddenByCombat then
      UI.OnCombat(false, 0)
    end
  end
  UI.Refresh = function()
    if uiReady and UI.Main.w.frame:IsShown() then
      UI.Main.Refresh()
    end
  end
  UI.Reset = function()
    local st = UI.Main.st
    local db = Mrgl.db
    st.goldShown = db.gold
    st.goldTo = db.gold
    st.goldT = 1
    st.goldHold = 0
    st.zone = 0
    st.enemyLocked = false
    st.autoCd = false
    st.lag = 1
    st.unlockAt = {}
    st.collectPulse = false
    st.bossAwayUntil = 0
    st.saveMark = -1
    st.saveFill = -1
    UI.Juice.ResetPools()
    UI.Main.SetZone(true)
    UI.Main.ApplyZoneLook()
    UI.Main.SetEnemyLook()
    local w = UI.Main.w
    for i = 1, 4 do
      w.ab[i].cdState = ""
      w.ab[i].cd:Clear()
    end
    w.bossCd:Clear()
    UI.Juice.CountdownRing(0)
    w.timer:Hide()
    w.timerText:Hide()
    if UI.Popup.IsOpen() then
      UI.Popup.CloseAll()
    end
    UI.Panel.Show(db.settings.panel, true)
    UI.Main.ApplyMinimized()
    UI.Main.ApplyPosition()
    UI.Panel.Reanchor()
    UI.Main.Refresh()
  end
  function playerFaction()
    local ok, fg = pcall(UnitFactionGroup, "player")
    if not ok then
      return nil
    end
    if issecretvalue and issecretvalue(fg) then
      return nil
    end
    if fg == "Horde" then
      return "horde"
    end
    if fg == "Alliance" then
      return "alliance"
    end
    return nil
  end
  UI.PlayerFaction = playerFaction
  function fixFaction()
    local db = Mrgl.db
    if db == nil then
      return
    end
    local fac = playerFaction()
    if fac == nil or fac == db.faction then
      return
    end
    db.faction = fac
    if uiReady then
      UI.Main.st.zone = 0
      UI.Main.SetZone(true)
      UI.Main.SetEnemyLook()
      UI.Main.Refresh()
    end
  end
  local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
  end
  local function numArg(v)
    if isSecret(v) or type(v) ~= "number" or v ~= v then
      return nil
    end
    return v
  end
  local function strArg(v)
    if isSecret(v) or type(v) ~= "string" then
      return nil
    end
    return v
  end
  local function charKey()
    local name = UnitName("player")
    return Mrgl.Core.World.CharKey(strArg(name), strArg(GetRealmName()))
  end
  local function playerLevel()
    return numArg(UnitLevel("player"))
  end
  local function playerMap()
    if C_Map == nil then
      return nil
    end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok then
      return nil
    end
    return numArg(id)
  end
  local worldOff = false
  local function seeChar()
    if Mrgl.db == nil or Mrgl.Core.World == nil then
      return
    end
    Mrgl.Core.World.SeeChar(charKey(), playerLevel(), playerMap())
  end
  UI.SeeChar = seeChar
  local function worldEvent(event, arg1)
    if Mrgl.db == nil or not uiReady or worldOff or Mrgl.Core.World == nil then
      return
    end
    local W = Mrgl.Core.World
    local key = charKey()
    if event == "PLAYER_LEVEL_UP" then
      local lv = numArg(arg1)
      if lv == nil then
        lv = playerLevel()
      end
      W.Level(key, lv)
    elseif event == "QUEST_TURNED_IN" then
      W.Quest(key, numArg(arg1), Mrgl.Core.Now())
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      W.Zone(key, playerMap())
    end
  end
  UI.WorldEvent = worldEvent
  local function shownBlizz(f)
    return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown()
  end
  blockerOpen = function()
    return shownBlizz(SettingsPanel) or shownBlizz(InterfaceOptionsFrame)
      or shownBlizz(GameMenuFrame) or shownBlizz(StaticPopup1) or shownBlizz(StaticPopup2)
      or shownBlizz(StaticPopup3) or shownBlizz(StaticPopup4)
  end
  local MAP_ABOVE = { FULLSCREEN = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG" }
  local function mapLayer()
    local f = UI.Main.w.frame
    local want = "DIALOG"
    if shownBlizz(WorldMapFrame) and type(WorldMapFrame.GetFrameStrata) == "function" then
      want = MAP_ABOVE[WorldMapFrame:GetFrameStrata()] or "DIALOG"
    end
    if f:GetFrameStrata() ~= want then
      f:SetFrameStrata(want)
    end
  end
  UI.MapLayer = mapLayer
  local function blockerCheck()
    local f = UI.Main.w.frame
    mapLayer()
    if blockerOpen() then
      if not blockHidden and f:IsShown() then
        blockHidden = true
        UI.Main.SaveMark()
        UI.Kit.HideOwnTip()
        f:Hide()
      end
    elseif blockHidden then
      blockHidden = false
      if closed or hiddenByCombat then
        return
      end
      if Mrgl.Core.rt.inCombat and hideCombat() then
        hiddenByCombat = true
        return
      end
      f:Show()
      UI.Juice.OnShow()
      UI.Main.Refresh()
      UI.Main.SaveCheck()
    end
  end
  UI.BlockerCheck = blockerCheck
  function Init()
    if Mrgl.db ~= nil then
      return
    end
    local db = Mrgl.Core.State.Load(MrglSquadDB, MrglSquadCharDB, "alliance")
    Mrgl.Core.Init(db, GetServerTime())
  end
  UI.Init = Init
  local function loginBody()
    local report = Mrgl.Core.Tick.ApplyOffline(GetServerTime())
    local main = UI.Main.Build()
    UI.Panel.Build(main)
    fadeOut = main:CreateAnimationGroup()
    UI.Kit.AddAlpha(fadeOut, 1, 0, 0.15, 0, 1)
    fadeOut:SetScript("OnFinished", function()
      main:Hide()
    end)
    fadeIn = main:CreateAnimationGroup()
    UI.Kit.AddAlpha(fadeIn, 0, 1, 0.25, 0, 1)
    uiReady = true
    skipFrame = true
    Mrgl.Core.On("SAVE", function()
      save()
    end)
    UI.Reset()
    local okSee, errSee = pcall(seeChar)
    if not okSee then
      worldOff = true
      geterrorhandler()(errSee)
    end
    if report.gold > 0 and report.seconds >= Mrgl.Data.Balance.OFFLINE_POPUP_MIN then
      UI.Popup.ShowWelcome(report)
    end
    if UnitAffectingCombat("player") then
      Mrgl.Core.SetCombat(true)
    end
    C_Timer.NewTicker(Mrgl.Data.Balance.SAVE_EVERY, function()
      save()
    end)
    local okMap, errMap = pcall(UI.Minimap.Apply)
    if not okMap then
      local b = UI.Minimap.Frame()
      if b ~= nil then
        b:Hide()
      end
      geterrorhandler()(errMap)
    end
  end
  local function loginError(e)
    local handler = geterrorhandler()
    handler(e)
    return e
  end
  function Login()
    if built then
      return
    end
    fixFaction()
    built = true
    local ok = xpcall(loginBody, loginError)
    if not ok then
      uiReady = false
      local f = UI.Main.w.frame
      if f ~= nil then
        f:Hide()
      end
      print("Murlocs Heroes Idle: start failed. Please send the first Lua error (1/N).")
    end
  end
  UI.IsBuilt = function()
    return built
  end
  UI.IsReady = function()
    return uiReady
  end
  SlashCmdList.MRGLSQUAD = function(msg)
    local raw = ""
    if msg ~= nil then
      raw = strtrim(tostring(msg))
    end
    local m = strlower(raw)
    if m == "debug" or string.sub(m, 1, 6) == "debug " then
      if Mrgl.Debug ~= nil then
        return Mrgl.Debug.Slash(strtrim(string.sub(raw, 6)))
      end
      return false
    end
    if Mrgl.db == nil or not uiReady then
      return false
    end
    if m == "" then
      UI.Toggle()
      return true
    end
    if m == "save" then
      save()
      return true
    end
    if m == "reset" then
      UI.Main.ResetPosition()
      return true
    end
    if m == "min" then
      UI.Main.SetMinimized(not UI.Main.IsMinimized())
      return true
    end
    if m == "minimap" then
      UI.Minimap.Toggle()
      return true
    end
    if m == "savecheck" then
      print(Mrgl.U.Fill(Mrgl.Data.Strings.SAVECHECK, { from = Mrgl.Core.State.loadedFrom, seq = Mrgl.db.saveSeq }))
      return true
    end
    return false
  end
  local driver = CreateFrame("Frame", "MrglSquadDriver")
  driver:SetSize(1, 1)
  driver:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  driver:RegisterEvent("ADDON_LOADED")
  driver:RegisterEvent("PLAYER_LOGIN")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(driver.RegisterEvent, driver, "PLAYER_LOGOUT")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
  driver:RegisterEvent("UI_SCALE_CHANGED")
  driver:RegisterEvent("PLAYER_LEVEL_UP")
  driver:RegisterEvent("QUEST_TURNED_IN")
  driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  driver:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
      Init()
    elseif event == "PLAYER_LOGIN" and MrglSquadDebugSkipLogin ~= true then
      Init()
      fixFaction()
      Login()
    elseif event == "PLAYER_ENTERING_WORLD" then
      fixFaction()
      if not built and IsLoggedIn() then
        Init()
        Login()
      end
      if uiReady and not pewSeen then
        pewSeen = true
        skipFrame = true
      end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
      if uiReady then
        UI.Kit.PixelRefresh()
      end
    elseif event == "PLAYER_LOGOUT" then
      save()
    elseif event == "PLAYER_REGEN_DISABLED" then
      if Mrgl.db ~= nil then
        Mrgl.Core.SetCombat(true)
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      if Mrgl.db ~= nil then
        Mrgl.Core.SetCombat(false)
      end
    elseif event == "PLAYER_LEVEL_UP" or event == "QUEST_TURNED_IN" or event == "ZONE_CHANGED_NEW_AREA" then
      worldEvent(event, arg1)
    end
  end)
  driver:SetScript("OnUpdate", function(self, elapsed)
    if Mrgl.db == nil or not uiReady then
      return
    end
    if skipFrame then
      skipFrame = false
      return
    end
    if elapsed >= UI.Juice.LONG_FRAME then
      Mrgl.Core.Tick.Advance(elapsed)
    else
      Mrgl.Core.Tick.Run(elapsed)
    end
    UI.Juice.BonusTick(elapsed)
    blockAcc = blockAcc + elapsed
    if blockAcc >= 0.1 then
      blockAcc = 0
      blockerCheck()
    end
    refreshAcc = refreshAcc + elapsed
    if refreshAcc >= 0.05 then
      refreshAcc = 0
      UI.Refresh()
    end
  end)
  C_Timer.After(0, function()
    Init()
    if not built and IsLoggedIn() then
      Login()
    end
  end)
end
