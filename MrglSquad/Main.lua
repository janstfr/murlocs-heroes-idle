local ADDON, Mrgl = ...
-- Mrgl Squad - start (MrglSquad.lua equivalent): ADDON_LOADED -> PLAYER_LOGIN, driver frame, saving, combat, /mrgl.
Mrgl.UI = Mrgl.UI or {}

-- port-plan 1: the one global alias, for /run and debugging
MrglSquad = Mrgl

-- r2 W9: /mrgl (no argument: window on/off), /mrgl save, /mrgl reset (position); j1 M4: /mrgl min
SLASH_MRGLSQUAD1 = "/mrgl"
SLASH_MRGLSQUAD2 = "/mhi" -- tide1c C16: short alias for Murlocs Heroes Idle (internal names stay)

do
  local save, playerFaction, fixFaction, Init, Login
  local UI = Mrgl.UI
  local refreshAcc = 0
  local hiddenByCombat = false
  local closed = false
  local blockHidden = false -- j1b W4: hidden by us because a Blizzard panel is open
  local blockerOpen -- j1c H1/H2: defined with the blocker poll below, used by Toggle and OnCombat
  local blockAcc = 0
  local built = false
  local uiReady = false   -- r4 W20: set after UI.Main.Build() and UI.Panel.Build()
  -- port p2 (review p1 WoW M1 / Lua S1): every UI entry point checks uiReady (not w.frame, which exists halfway
  -- through Build). A failed Login() leaves uiReady false: one error, no follow-up errors.
  local pewSeen = false
  local skipFrame = false -- port p2 (WoW K1): the first OnUpdate after Login() is dropped (loading screen elapsed,
  -- ApplyOffline already paid up to GetServerTime())

  -- port p2 (Lua K3): non-finite numbers never reach the SavedVariables (the file would not load); the key is
  -- dropped, so State.fix puts the default back on the next load.
  -- port p3 (review p2 Lua M3 / WoW S1): only ever on a copy; the account copy is the live Mrgl.db
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

  -- port-plan 2.6: the debug sandbox db is never saved; /mrgl debug offline shifts lastSeen back (debug field only)
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
    local acct = s.account -- the live db (State.Save), never changed here
    if hasNonFinite(acct, 0) then
      acct = Mrgl.Core.State.Copy(acct)
      finiteOnly(acct, 0)
    end
    finiteOnly(s.character, 0) -- already a deep copy
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
      on = not (f:IsShown() or blockHidden) -- j1c H2: hidden by a Blizzard panel counts as open, so a toggle closes
    end -- Lua: no "a and b or c" here, show can be false
    closed = not on
    if on and not f:IsShown() and blockerOpen() then
      blockHidden = true -- j1c H2: nothing over the map; it shows when the panel closes (a shown window: the poll hides it)
      return
    end
    blockHidden = false -- j1b W4: the player decides now
    if hiddenByCombat then
      return
    end
    local was = f:IsShown()
    if not on and was then
      UI.Main.SaveMark()
    end -- r3 E7: fill at closing
    f:SetShown(on)
    if on then
      Mrgl.Core.Combat.TakeSquadDealt()
      UI.Juice.OnShow()
      UI.Main.Refresh()
      UI.Juice.StrengthCheck() -- B5: +n% when the squad grew while the window was closed
      if not was then
        UI.Main.SaveCheck()
      end -- r3 E7: +n% when the saving fill grew while closed
    else
      UI.Kit.HideOwnTip() -- port p2 (Lua M2): never hide a tooltip of another addon or the game
    end
  end

  -- WoW combat: hide the window (allowed for non-protected frames), boss fight freezes in Core.
  local fadeOut, fadeIn
  -- j2 A2: the gear switch "Hide in combat" (default on). Off: the window (or the bar) stays in combat. Only the
  -- visibility depends on it; the core's combat flag (Tick C.SetCombat: boss fight frozen, no boss start, auto-fight
  -- waits, gold moments wait) is game logic and stays as it is.
  local function hideCombat()
    return Mrgl.db.settings.hideCombat ~= false
  end
  UI.OnCombat = function(on, gold)
    if not uiReady then
      return
    end
    local f = UI.Main.w.frame
    if on then
      UI.Kit.HideOwnTip() -- j2b WoW S1: an open tooltip of ours goes at combat start (also when the window stays)
      if closed or not f:IsShown() or not hideCombat() then
        return
      end
      hiddenByCombat = true
      UI.Kit.HideOwnTip() -- port p2 (Lua M2): the unit tooltip of the pulled mob stays
      UI.Panel.CloseSettings() -- r3 S7: the settings page closes before the window goes (Esc stays free)
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
      if blockerOpen() then -- j1c H1: never flash over an open map or menu; back when the panel closes
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

  -- j2 A2: the switch changed (gear menu): turned off while hidden by combat -> back now; turned on in combat -> hide
  UI.CombatSetting = function()
    if not uiReady then
      return
    end
    Mrgl.Core.rt.combatGold = 0 -- j2b Lua K2: no "+X" for gold that was shown live before the switch
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

  -- Rebuilds visible state after a new db (presets, faction switch, load)
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
    UI.Main.ApplyZoneLook() -- tide1c C15
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
      UI.Popup.CloseAll() -- New Tide Q: the welcome and the tide popup
    end
    UI.Panel.Show(db.settings.panel, true)
    UI.Main.ApplyMinimized() -- j1 M5: before the anchor (26-px bar); closes the panel while minimized
    UI.Main.ApplyPosition()
    UI.Panel.Reanchor()
    UI.Main.Refresh()
  end

  -- r3 W13: the route follows the character: the faction is read at every PLAYER_LOGIN and PLAYER_ENTERING_WORLD
  -- (nil -> keep). Progress and stage stay account-wide (K7).
  -- port-plan 2.4: pcall, only "Alliance"/"Horde" count, secret-value guard (RezRadar.lua:43)
  function playerFaction()
    local ok, fg = pcall(UnitFactionGroup, "player")
    if not ok then
      return nil
    end
    -- port p2 (Lua K2): secret check before any comparison
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
  UI.PlayerFaction = playerFaction   -- for /mrgl debug info
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
    -- r4 W20: touch the UI only after Main.Build and Panel.Build; before that, Build/Reset take the faction
    if uiReady then
      UI.Main.st.zone = 0
      UI.Main.SetZone(true)
      UI.Main.SetEnemyLook()
      UI.Main.Refresh()
    end
  end

  -- ------------------------------------------------------------ j1 W3: in-world events (amounts and limits: Core.World)
  -- PLAYER_LEVEL_UP (arg1 = new level, fallback UnitLevel), QUEST_TURNED_IN (arg1 = questID, only for the 5-s lock, nil
  -- allowed), ZONE_CHANGED_NEW_AREA (no args; mapID from pcall(C_Map.GetBestMapForUnit, "player")). Every value read
  -- goes through issecretvalue (fallback: never secret, RezRadar.lua:43) and a type check. The handlers only read and
  -- call nothing protected. No quest or zone names in any text (client language; game text stays English).
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
  -- W4: key like ForeverIdle Core.lua:161, UnitName("player") .. "-" .. GetRealmName()
  local function charKey()
    local name = UnitName("player") -- two return values in WoW: name, realm
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
  -- W4: the character is seen at login (and after a new db): maxLevel = level, current zone known, no reward
  local worldOff = false -- j1b W2: set when seeChar failed at login
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
  UI.WorldEvent = worldEvent -- the event handler (debug sandbox)

  -- j1b W4: our window is DIALOG, so it would lie over the options, the game menu and StaticPopups.
  -- While one of them is shown the window hides; it comes back only if WE hid it (not after the player closed it).
  -- Polled from the driver (10 Hz), no hook on Blizzard frames: no taint. Every frame is nil-guarded.
  -- j3 (Jan): the world map is no blocker any more; the window stays as it is while the map is open.
  local function shownBlizz(f)
    return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() -- j1c H3: a non-frame global is no error
  end
  blockerOpen = function()
    return shownBlizz(SettingsPanel) or shownBlizz(InterfaceOptionsFrame)
      or shownBlizz(GameMenuFrame) or shownBlizz(StaticPopup1) or shownBlizz(StaticPopup2)
      or shownBlizz(StaticPopup3) or shownBlizz(StaticPopup4)
  end
  -- j3: the Classic map is FULLSCREEN (above our DIALOG). While it is shown our window (and with it the panel and
  -- the popups, its children) goes to FULLSCREEN_DIALOG, afterwards back to DIALOG. Only our own frame changes, read
  -- from the map without a hook and without parenting to it: taint-free. Polled with the blockers (10 Hz).
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
        hiddenByCombat = true -- back after the fight (OnCombat)
        return
      end
      f:Show()
      UI.Juice.OnShow()
      UI.Main.Refresh()
      UI.Main.SaveCheck()
    end
  end
  UI.BlockerCheck = blockerCheck

  -- r2 W4: idempotent start (ADDON_LOADED, PLAYER_LOGIN, or the C_Timer fallback at the end of this file)
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
    uiReady = true -- before Reset and SetCombat: OnCombat must work for a /reload during a fight
    skipFrame = true
    Mrgl.Core.On("SAVE", function()
      save()
    end)
    UI.Reset()
    -- j1 W4; j1b W2: own pcall, an error here only switches the world events off (reported once, the UI stays)
    local okSee, errSee = pcall(seeChar)
    if not okSee then
      worldOff = true
      geterrorhandler()(errSee)
    end
    if report.gold > 0 and report.seconds >= Mrgl.Data.Balance.OFFLINE_POPUP_MIN then
      UI.Popup.ShowWelcome(report)
    end
    -- /reload or login during a fight: PLAYER_REGEN_DISABLED will not come (plan 2.4)
    if UnitAffectingCombat("player") then
      Mrgl.Core.SetCombat(true)
    end
    C_Timer.NewTicker(Mrgl.Data.Balance.SAVE_EVERY, function()
      save()
    end)
    -- j1 #12: minimap button (setting default on); j1b W2: own pcall, an error only loses the button
    local okMap, errMap = pcall(UI.Minimap.Apply)
    if not okMap then
      local b = UI.Minimap.Frame()
      if b ~= nil then
        b:Hide()
      end
      geterrorhandler()(errMap)
    end
  end

  -- port p2 (review p1 WoW M1): the error handler runs at the error, so Blizzard's error window gets the real stack,
  -- exactly once. built stays true (no retry every frame), the window is hidden, one chat line.
  local function loginError(e)
    local handler = geterrorhandler()
    handler(e)
    return e
  end
  function Login()
    if built then
      return
    end
    fixFaction() -- r4 W20: before built = true; the UI does not exist yet
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

  -- r2 W9: slash command
  SlashCmdList.MRGLSQUAD = function(msg)
    local raw = ""
    if msg ~= nil then
      raw = strtrim(tostring(msg))
    end
    local m = strlower(raw)
    -- port-plan 2.6: /mrgl debug ... goes to Debug.lua (it checks its own preconditions)
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
      UI.Main.SetMinimized(not UI.Main.IsMinimized()) -- j1 M4
      return true
    end
    if m == "minimap" then
      UI.Minimap.Toggle() -- j1 #12
      return true
    end
    if m == "savecheck" then
      -- r4 W21: which SavedVariables copy was loaded
      print(Mrgl.U.Fill(Mrgl.Data.Strings.SAVECHECK, { from = Mrgl.Core.State.loadedFrom, seq = Mrgl.db.saveSeq }))
      return true
    end
    return false
  end

  -- no parent: keeps running when UIParent is hidden (Alt+Z), plan 1.4
  local driver = CreateFrame("Frame", "MrglSquadDriver")
  driver:SetSize(1, 1)
  driver:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  driver:RegisterEvent("ADDON_LOADED")
  driver:RegisterEvent("PLAYER_LOGIN")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  -- port-plan 3: PLAYER_LOGOUT is stricter at registration on Forever
  -- refused: the 30-s save ticker carries the state (review p1 WoW K2; Mrgl.db does not exist yet at this point)
  pcall(driver.RegisterEvent, driver, "PLAYER_LOGOUT")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
  driver:RegisterEvent("UI_SCALE_CHANGED")   -- port-plan 2.4: PixelRefresh also on a new UI scale
  driver:RegisterEvent("PLAYER_LEVEL_UP") -- j1 W3 (ForeverIdle Core.lua:644)
  driver:RegisterEvent("QUEST_TURNED_IN") -- j1 W3 (ForeverIdle Core.lua:645)
  driver:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- j1 W3 (RezRadar.lua:733)

  driver:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
      Init()
    elseif event == "PLAYER_LOGIN" and MrglSquadDebugSkipLogin ~= true then
      -- r4 W21: /mrgl debug skiplogin on (or /run MrglSquadDebugSkipLogin = true) before /reload tests the
      -- IsLoggedIn fallback in WoW
      Init()
      fixFaction()
      Login()
    elseif event == "PLAYER_ENTERING_WORLD" then
      fixFaction()
      -- port v1: skiplogin or a missed PLAYER_LOGIN, when the first-frame fallback ran before IsLoggedIn() was true
      if not built and IsLoggedIn() then
        Init()
        Login()
      end
      -- port p3 (review p2 WoW K1): the first PEW after Login() arms the skip again, so a small OnUpdate during the
      -- loading screen does not use it up before the long frame comes (later loading screens count normally)
      if uiReady and not pewSeen then
        pewSeen = true
        skipFrame = true
      end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
      if uiReady then
        UI.Kit.PixelRefresh()
      end -- r3 W16: new resolution -> 1-px lines again on whole pixels
    elseif event == "PLAYER_LOGOUT" then
      save()
    elseif event == "PLAYER_REGEN_DISABLED" then
      -- own flag: InCombatLockdown() is not yet true here on Forever
      if Mrgl.db ~= nil then
        Mrgl.Core.SetCombat(true)
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      if Mrgl.db ~= nil then
        Mrgl.Core.SetCombat(false)
      end
    elseif event == "PLAYER_LEVEL_UP" or event == "QUEST_TURNED_IN" or event == "ZONE_CHANGED_NEW_AREA" then
      worldEvent(event, arg1) -- j1 W3
    end
  end)

  -- The driver is always shown, so the game runs while the window is hidden (combat, closed).
  -- r4 K1: one OnUpdate with elapsed >= 5 s (tab back from the background, loading screen) is a return: catch-up
  -- with CATCHUP (Tick.Advance simulates at most ADVANCE_MAX = 3600 1-s steps, the rest pays like offline time)
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
    UI.Juice.BonusTick(elapsed) -- j1 W2: a waiting gold moment plays once the window is visible (no combat, no popup)
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

  -- r2 W4: fallback when ADDON_LOADED was missed (the first frame after loading)
  C_Timer.After(0, function()
    Init()
    if not built and IsLoggedIn() then
      Login()
    end
  end)
end
