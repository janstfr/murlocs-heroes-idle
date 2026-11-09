local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Tide.lua equivalent: New Tide (prestige), ngplus-plan C2-C4.
-- Saved: db.prestige = { count, best, last, paths = { m, s, a }, trophies = { nef } }. Every New Tide adds exactly 1 point to
-- one path, forever (no respec, no free points). Without db (or with Total() = 0) every factor is 1, every plus value 0 and
-- the offline rate OFFLINE_RATE, so run 1 is unchanged.
Mrgl.Core = Mrgl.Core or {}
do
  local B, F, Cb
  local C = Mrgl.Core
  local T = {}
  C.Tide = T
  local U = Mrgl.U
  function B()
    return Mrgl.Data.Balance
  end
  function F()
    return Mrgl.Core.Formula
  end
  function Cb()
    return Mrgl.Core.Combat
  end

  local PATHS = { "m", "s", "a" }
  local CAST = { "candle", "whelps", "mrgl", "leeroy" } -- C4 auto-cast order

  -- ------------------------------------------------------------ points
  local function paths()
    local db = Mrgl.db
    if db == nil or db.prestige == nil then
      return nil
    end
    return db.prestige.paths
  end
  T.Points = function(p)
    local ps = paths()
    if ps == nil or ps[p] == nil then
      return 0
    end
    return ps[p]
  end
  T.IsPath = function(p)
    return p == "m" or p == "s" or p == "a"
  end
  T.Total = function()
    return T.Points("m") + T.Points("s") + T.Points("a")
  end
  T.Has = function(p, lvl)
    return T.Points(p) >= lvl
  end

  -- ------------------------------------------------------------ unlock and blockers
  -- Standing before Ragnaros (gate to stage 100 open) counts as reached
  T.Reached = function()
    local db = Mrgl.db
    local gate = 0
    if Cb().GateOpen() then
      gate = db.stage + 1
    end
    return math.max(db.maxStage, gate)
  end
  T.Avail = function()
    return T.Reached() >= B().TIDE_STAGE
  end
  -- "combat" first (display order of plan R2: combat before boss before stage); rt.popup does not count
  T.Blocked = function()
    if C.rt.inCombat then
      return "combat"
    end
    if Mrgl.db.boss.active then
      return "boss"
    end
    return nil
  end
  T.Ready = function()
    return T.Avail() and T.Blocked() == nil
  end

  -- ------------------------------------------------------------ factors (C2)
  -- Formula calls these in every damage / cost / gold step: they are computed once per point set (m, s, a) and cached
  -- (same arithmetic, so the values are identical; the cache follows any change of the points by value)
  local fc = { m = -1, s = -1, a = -1 }
  local function cur()
    local m, s, a = 0, 0, 0
    local db = Mrgl.db
    if db ~= nil and db.prestige ~= nil then
      local ps = db.prestige.paths
      m, s, a = ps.m, ps.s, ps.a
    end
    if m == fc.m and s == fc.s and a == fc.a then
      return fc
    end
    m, s, a = T.Points("m"), T.Points("s"), T.Points("a")
    local b = B()
    local tot = m + s + a
    fc.m = m; fc.s = s; fc.a = a
    fc.floodDmg = 1 + b.TIDE_FLOOD_DMG * tot
    fc.floodGold = 1 + b.TIDE_FLOOD_GOLD * tot
    local mp = 1 + b.TIDE_MURLOC * m
    if m >= 10 then
      mp = mp * 1.5
    end
    if m >= 100 then
      mp = mp * 2
    end
    fc.murlocPath = mp
    fc.murloc = fc.floodDmg * mp
    local cm = 1 + b.TIDE_CLICK * s
    if s >= 100 then
      cm = cm * 2
    end
    fc.click = cm
    local sm = 1 + b.TIDE_SPELL * a
    if a >= 100 then
      sm = sm * 3
    end
    fc.spell = sm
    fc.critPlus = 0
    if s >= 25 then
      fc.critPlus = 0.10
    end
    fc.critDmgPlus = 0
    if s >= 50 then
      fc.critDmgPlus = 3
    end
    fc.timerPlus = 0
    if a >= 25 then
      fc.timerPlus = b.TIDE_TIMER_PLUS
    end
    fc.buff = 1
    if a >= 100 then
      fc.buff = 2
    end
    fc.offline = b.OFFLINE_RATE
    if m >= 25 then
      fc.offline = b.TIDE_OFFLINE_RATE
    end
    fc.cost = 1
    if m >= 50 then
      fc.cost = 1 - b.TIDE_DISCOUNT
    end
    -- tide1b T1: Murky fights along from the first New Tide: one Tinyfin's base DPS x MurlocMult (flood x Murlocs path)
    fc.murky = 0
    if tot >= 1 then
      fc.murky = U.At(Mrgl.Data.Murlocs, 1).dps * fc.murloc
    end
    return fc
  end
  T.FloodDmg = function()
    return cur().floodDmg
  end
  T.FloodGold = function()
    return cur().floodGold
  end
  T.MurlocMult = function()
    return cur().murloc
  end
  T.ClickMult = function()
    return cur().click
  end
  T.SpellMult = function()
    return cur().spell
  end
  -- display factor of a path row (R3): murloc damage without the flood, click damage, ability power
  T.PathMult = function(p)
    if p == "s" then
      return cur().click
    end
    if p == "a" then
      return cur().spell
    end
    return cur().murlocPath
  end
  T.CritPlus = function()
    return cur().critPlus
  end
  T.CritDmgPlus = function()
    return cur().critDmgPlus
  end
  T.AutoCps = function()
    if T.Has("s", 100) then
      return B().TIDE_AUTOCLICK_CPS_MAX
    end
    if T.Has("s", 10) then
      return B().TIDE_AUTOCLICK_CPS
    end
    return 0
  end
  T.TimerPlus = function()
    return cur().timerPlus
  end
  T.BuffMult = function()
    return cur().buff
  end
  T.OfflineRate = function()
    return cur().offline
  end
  T.CostMult = function()
    return cur().cost
  end
  -- tide1b T1: Murky's damage per second (0 before the first New Tide). Not buyable, not in counts, ranks or Best Buy;
  -- F.SquadDPS adds it, so offline gold, the squad number and boss readiness all see it
  T.MurkyDPS = function()
    return cur().murky
  end
  T.AutoBuy = function()
    return T.Total() >= 1
  end

  -- ------------------------------------------------------------ data lookups (for the UI)
  T.Path = function(p)
    local l = Mrgl.Data.Tide.paths
    for i = 1, U.Len(l) do
      if U.At(l, i).id == p then
        return U.At(l, i)
      end
    end
    return nil
  end
  -- next milestone of path p not reached yet (nil when all are reached)
  T.NextMs = function(p)
    local d = T.Path(p)
    if d == nil then
      return nil
    end
    local n = T.Points(p)
    for i = 1, U.Len(d.ms) do
      if U.At(d.ms, i).at > n then
        return U.At(d.ms, i)
      end
    end
    return nil
  end
  -- what a New Tide into path p brings now: "first" (Quartermaster, Murky) at Total() = 0, then the milestone ids
  -- reached with points + 1 (e.g. { "first", "m10" })
  T.Gains = function(p)
    local out = {}
    local d = T.Path(p)
    if d == nil then
      return out
    end
    if T.Total() == 0 then
      U.Insert(out, "first")
    end
    local n = T.Points(p) + 1
    for i = 1, U.Len(d.ms) do
      local ms = U.At(d.ms, i)
      if ms.at == n then
        U.Insert(out, ms.id)
      end
    end
    return out
  end
  -- definition of a milestone, a "first" entry or a trophy by id
  T.Def = function(id)
    local D = Mrgl.Data.Tide
    for i = 1, U.Len(D.first) do
      if U.At(D.first, i).id == id then
        return U.At(D.first, i)
      end
    end
    for j = 1, U.Len(D.paths) do
      local ms = U.At(D.paths, j).ms
      for k = 1, U.Len(ms) do
        if U.At(ms, k).id == id then
          return U.At(ms, k)
        end
      end
    end
    for t = 1, U.Len(D.trophies) do
      if U.At(D.trophies, t).id == id then
        return U.At(D.trophies, t)
      end
    end
    return nil
  end
  -- companion slot 1-3 (K): Murky after the first New Tide, Tidecaller at Murlocs 10, Bagurgle at Murlocs 100
  T.Companion = function(slot)
    if slot == 1 and T.Total() >= 1 then
      return T.Def("murky")
    end
    if slot == 2 and T.Has("m", 10) then
      return T.Def("m10")
    end
    if slot == 3 and T.Has("m", 100) then
      return T.Def("m100")
    end
    return nil
  end
  -- the setting behind a toggle is free once its milestone is reached
  T.ToggleFree = function(key)
    if key == "autobuy" then
      return T.AutoBuy()
    end
    if key == "autoclick" then
      return T.Has("s", 10)
    end
    if key == "autocast" then
      return T.Has("a", 10)
    end
    return false
  end
  -- flips settings[key] when free; returns the new value (false when locked)
  T.Toggle = function(key)
    local s = Mrgl.db.settings
    if not T.ToggleFree(key) then
      return false
    end
    s[key] = not s[key]
    C.Fire("SAVE", {})
    return s[key]
  end
  T.Trophy = function(id)
    local db = Mrgl.db
    return db.prestige.trophies[id] == true
  end

  -- ------------------------------------------------------------ New Tide (C3)
  -- committed = true: the player pressed New Tide and the veil is already up (UI F, 0.3 s later). WoW combat that began
  -- in those 0.3 s does not cancel it: the reset touches only our own data (no protected call), and a veil without a
  -- reset would be a moment without effect. A boss fight still blocks (it cannot start during the popup and veil).
  T.Rise = function(path, committed)
    local db = Mrgl.db
    local rt = C.rt
    local b = B()
    local bl = T.Blocked()
    if committed == true and bl == "combat" and not db.boss.active then
      bl = nil
    end -- New Tide guard (orchestrator)
    if not T.Avail() or bl ~= nil or not T.IsPath(path) then
      return false
    end
    local pr = db.prestige
    local reached = T.Reached()
    local old = pr.paths[path]
    local ms = T.Gains(path)
    pr.paths[path] = old + 1
    pr.count = pr.count + 1
    pr.last = path
    pr.best = math.max(pr.best, reached)
    -- C3a: run state back to a new game; abilities, settings, stats, world, prestige stay
    db.gold = b.START_GOLD
    db.stage = 1
    db.kills = 0
    db.maxStage = 1
    db.enemyHp = F().EnemyHP(1)
    db.enemyRare = false
    db.rareStage = 0
    local bo = db.boss
    bo.active = false; bo.time = 0; bo.max = 0; bo.auto = false; bo.lostAt = 0; bo.lostStage = 0; bo.resetStage = 0
    local ml = Mrgl.Data.Murlocs
    for i = 1, U.Len(ml) do
      local e = db.murlocs[U.At(ml, i).id]
      e.n = 0; e.u = 0
    end
    local sl = Mrgl.Data.Self
    for j = 1, U.Len(sl) do
      db.self[U.At(sl, j).id] = 0
    end
    db.buffs.whelps = 0; db.buffs.candle = 0; db.buffs.leeroy = 0
    db.autoFailDps = {}
    -- runtime (inCombat and popup stay as they are)
    rt.gateFired = false
    rt.respawn = 0
    rt.queued = 0
    rt.autoT = 0
    rt.bossSec = 0
    rt.opener = {}
    rt.openerT = 0
    rt.whelpAcc = 0
    rt.autoClickAcc = 0
    rt.leeroyHit = 0
    rt.leeroyLine = 0
    Mrgl.Core.Shop.Dirty()
    C.Fire("TIDE", { path = path, old = old, new = old + 1, total = T.Total(), milestones = ms })
    C.Fire("STAGE", { stage = 1 })
    C.Fire("ZONE", { zone = 1, name = Cb().Zone(1).name })
    C.Fire("SAVE", {})
    return true
  end

  -- ------------------------------------------------------------ automation (C4), called from Tick.Step
  -- LEEROY only while a boss fight runs (checked per ability: a MRGLGLGL! kill at the start ends the fight)
  local function autoCast()
    local A = Mrgl.Core.Abilities
    local rt = C.rt
    for i = 1, U.Len(CAST) do
      local id = U.At(CAST, i)
      local queued = false
      for k = 1, U.Len(rt.opener) do
        if U.At(rt.opener, k) == id then
          queued = true
        end
      end
      if not queued and (id ~= "leeroy" or Mrgl.db.boss.active) and A.IsReady(id) then
        A.Use(id, false, true)
      end
    end
  end
  T.AutoCastOn = function()
    local db = Mrgl.db
    return T.Has("a", 10) and db.settings.autocast == true and not C.rt.inCombat
  end
  -- Boss.Start(true): every ready ability right after the A4 reset, LEEROY included (Orchestrator v2 no. 1)
  T.BossOpen = function()
    if T.AutoCastOn() then
      autoCast()
    end
  end
  T.Step = function(dt)
    local db = Mrgl.db
    local rt = C.rt
    local b = B()
    -- auto-click: Self-Click 10 / 100
    local cps = T.AutoCps()
    if cps > 0 and db.settings.autoclick == true then
      rt.autoClickAcc = rt.autoClickAcc + dt * cps
      while rt.autoClickAcc >= 1 - 1e-9 do
        rt.autoClickAcc = rt.autoClickAcc - 1
        Cb().Click(false, "auto")
      end
    end
    -- auto-cast: once per full game second; LEEROY only in a boss fight
    local sec = math.floor(rt.clock)
    if sec ~= rt.castSec then
      rt.castSec = sec
      if T.AutoCastOn() then
        autoCast()
      end
    end
    -- auto-buy: Buy best every TIDE_AUTOBUY_SEC game seconds (also minimized, hidden, in catch-up and WoW combat)
    local slot = math.floor(rt.clock / b.TIDE_AUTOBUY_SEC)
    if slot ~= rt.autoBuyT then
      rt.autoBuyT = slot
      if T.AutoBuy() and db.settings.autobuy == true then
        for k = 1, 50 do
          if not Mrgl.Core.Shop.BuyBest(true) then
            break
          end
        end
      end
    end
  end
  -- login: the offline jump of the clock must not count as a passed auto-buy / auto-cast slot
  T.Sync = function()
    local rt = C.rt
    rt.castSec = math.floor(rt.clock)
    rt.autoBuyT = math.floor(rt.clock / B().TIDE_AUTOBUY_SEC)
  end
  T.PATHS = PATHS
end
