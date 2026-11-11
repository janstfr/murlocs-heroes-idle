local ADDON, Mrgl = ...
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
  local CAST = { "candle", "whelps", "mrgl", "leeroy" }
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
  T.Ms = function(i)
    return U.At(B().TIDE_MILESTONES, i)
  end
  T.HasMs = function(p, i)
    return T.Points(p) >= T.Ms(i)
  end
  T.Reached = function()
    local db = Mrgl.db
    local gate = 0
    if Cb().GateOpen() then
      gate = db.stage + 1
    end
    return math.max(db.maxStage, gate)
  end
  local function pr()
    return Mrgl.db.prestige
  end
  T.Waiting = function()
    return pr().pts
  end
  T.NextPoint = function()
    local b = B()
    if pr().mark <= 0 then
      return b.TIDE_STAGE
    end
    return pr().mark + b.TIDE_STEP
  end
  T.Chance = function()
    local b = B()
    return math.min(1, b.TIDE_CHANCE + b.TIDE_LUCK * pr().dry)
  end
  T.Best = function()
    return math.max(pr().best, T.Reached())
  end
  T.CanEmpty = function()
    return pr().mark >= B().TIDE_STAGE + B().TIDE_STEP
  end
  T.Avail = function()
    return T.Reached() >= B().TIDE_STAGE and (pr().pts >= 1 or T.CanEmpty())
  end
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
  T.Check = function()
    local db = Mrgl.db
    if db == nil or db.prestige == nil then
      return
    end
    local p = db.prestige
    local b = B()
    local r = T.Reached()
    if p.recShown ~= true and p.prev >= b.TIDE_STAGE and r > p.prev then
      p.recShown = true
      C.Fire("RECORD", { stage = r })
    end
    local nxt = b.TIDE_STAGE
    if p.run >= b.TIDE_STAGE then
      nxt = p.run + b.TIDE_STEP
    end
    while r >= nxt do
      p.run = nxt
      local got = false
      local lucky = false
      if nxt > p.mark then
        got = true
        p.mark = nxt
      elseif nxt >= b.TIDE_STAGE + b.TIDE_STEP then
        if U.Rand() < T.Chance() then
          got = true
          lucky = true
        end
      end
      if got then
        p.pts = math.min(p.pts + 1, 10000)
        p.dry = 0
        C.Fire("TIDE_POINT", { stage = nxt, lucky = lucky })
        C.Fire("SAVE", {})
      end
      nxt = nxt + b.TIDE_STEP
    end
  end
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
    local cap = b.MULT_CAP
    local ms1, ms2, ms3, ms4 = T.Ms(1), T.Ms(2), T.Ms(3), T.Ms(4)
    fc.m = m; fc.s = s; fc.a = a
    fc.gold = math.min(cap, 1 + b.TIDE_GOLD * tot)
    local mp = b.TIDE_MURLOC_X ^ m
    if m >= ms1 then
      mp = mp * 1.5
    end
    if m >= ms4 then
      mp = mp * 2
    end
    fc.murloc = math.min(cap, mp)
    local cm = b.TIDE_CLICK_X ^ s
    if s >= ms4 then
      cm = cm * 2
    end
    fc.click = math.min(cap, cm)
    local sm = b.TIDE_SPELL_X ^ a
    if a >= ms4 then
      sm = sm * 3
    end
    fc.spell = math.min(cap, sm)
    fc.echo = s >= 1 or a >= 1
    fc.critPlus = 0
    if s >= ms2 then
      fc.critPlus = 0.10
    end
    fc.critDmgPlus = 0
    if s >= ms3 then
      fc.critDmgPlus = 3
    end
    fc.timerPlus = 0
    if a >= ms2 then
      fc.timerPlus = b.TIDE_TIMER_PLUS
    end
    fc.buff = 1
    if a >= ms4 then
      fc.buff = 2
    end
    fc.offline = b.OFFLINE_RATE
    if m >= ms2 then
      fc.offline = b.TIDE_OFFLINE_RATE
    end
    fc.cost = 1
    if m >= ms3 then
      fc.cost = 1 - b.TIDE_DISCOUNT
    end
    fc.murky = 0
    if tot >= 1 then
      fc.murky = U.At(Mrgl.Data.Murlocs, 1).dps * fc.murloc
    end
    return fc
  end
  T.GoldMult = function()
    return cur().gold
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
  T.PathMult = function(p)
    if p == "s" then
      return cur().click
    end
    if p == "a" then
      return cur().spell
    end
    return cur().murloc
  end
  T.EchoFloor = function()
    return cur().echo
  end
  T.CritPlus = function()
    return cur().critPlus
  end
  T.CritDmgPlus = function()
    return cur().critDmgPlus
  end
  T.AutoCps = function()
    if T.HasMs("s", 4) then
      return B().TIDE_AUTOCLICK_CPS_MAX
    end
    if T.HasMs("s", 1) then
      return B().TIDE_AUTOCLICK_CPS
    end
    return 0
  end
  T.AutoSwing = function()
    local db = Mrgl.db
    if db == nil or db.settings == nil or db.settings.autoclick ~= true then
      return 0
    end
    return T.AutoCps()
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
  T.MurkyDPS = function()
    return cur().murky
  end
  T.AutoBuy = function()
    return T.Total() >= 1
  end
  T.Path = function(p)
    local l = Mrgl.Data.Tide.paths
    for i = 1, U.Len(l) do
      if U.At(l, i).id == p then
        return U.At(l, i)
      end
    end
    return nil
  end
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
  T.Gains = function(p, n)
    local out = {}
    local d = T.Path(p)
    if d == nil then
      return out
    end
    if n == nil then
      n = math.max(1, T.Waiting())
    end
    if T.Total() == 0 then
      U.Insert(out, "first")
    end
    local old = T.Points(p)
    for i = 1, U.Len(d.ms) do
      local ms = U.At(d.ms, i)
      if ms.at > old and ms.at <= old + n then
        U.Insert(out, ms.id)
      end
    end
    return out
  end
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
  T.Companion = function(slot)
    if slot == 1 and T.Total() >= 1 then
      return T.Def("murky")
    end
    if slot == 2 and T.HasMs("m", 1) then
      return T.Def("m10")
    end
    if slot == 3 and T.HasMs("m", 4) then
      return T.Def("m100")
    end
    return nil
  end
  T.ToggleFree = function(key)
    if key == "autobuy" then
      return T.AutoBuy()
    end
    if key == "autoclick" then
      return T.HasMs("s", 1)
    end
    if key == "autocast" then
      return T.HasMs("a", 1)
    end
    return false
  end
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
    return Mrgl.db.prestige.trophies[id] == true
  end
  T.Rise = function(path, committed)
    local db = Mrgl.db
    local rt = C.rt
    local b = B()
    local bl = T.Blocked()
    if committed == true and bl == "combat" and not db.boss.active then
      bl = nil
    end
    if not T.Avail() or bl ~= nil then
      return false
    end
    local pe = db.prestige
    local n = pe.pts
    if n >= 1 and not T.IsPath(path) then
      return false
    end
    local reached = T.Reached()
    local p = "none"
    local old = 0
    local ms = {}
    if n >= 1 then
      p = path
      old = pe.paths[path]
      ms = T.Gains(path, n)
      pe.paths[path] = old + n
      pe.last = path
    else
      pe.dry = math.min(pe.dry + 1, 100)
    end
    pe.pts = 0
    pe.count = pe.count + 1
    pe.best = math.max(pe.best, reached)
    pe.prev = pe.best
    pe.recShown = false
    pe.run = 0
    db.gold = b.START_GOLD
    db.stage = 1
    db.kills = 0
    db.maxStage = 1
    db.enemyHp = F().EnemyHP(1)
    Mrgl.Core.Combat.NewLife()
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
    local al = Mrgl.Data.Abilities
    for k = 1, U.Len(al) do
      db.spells[U.At(al, k).id] = 0
    end
    db.autoFailDps = {}
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
    rt.spill = 0
    Mrgl.Core.Shop.Dirty()
    C.Fire("TIDE", { path = p, old = old, new = old + n, total = T.Total(), milestones = ms, points = n })
    C.Fire("STAGE", { stage = 1 })
    C.Fire("ZONE", { zone = 1, name = Cb().Zone(1).name })
    C.Fire("SAVE", {})
    return true
  end
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
    return T.HasMs("a", 1) and db.settings.autocast == true and not C.rt.inCombat
  end
  T.BossOpen = function()
    if T.AutoCastOn() then
      autoCast()
    end
  end
  local function spill()
    local db = Mrgl.db
    local rt = C.rt
    if not (rt.spill > 0) or rt.respawn > 0 or not (db.enemyHp > 0) then
      return
    end
    if db.boss.active and rt.inCombat then
      return
    end
    local room = math.max(0, db.enemyHp - rt.enemyBank)
    if room <= 0 then
      return
    end
    local take = math.min(rt.spill, room)
    rt.spill = rt.spill - take
    Cb().Hit(take, "spill", false, 1)
  end
  T.Step = function(dt)
    local db = Mrgl.db
    local rt = C.rt
    local b = B()
    T.Check()
    spill()
    local cps = T.AutoCps()
    if cps > 0 and db.settings.autoclick == true then
      rt.autoClickAcc = rt.autoClickAcc + dt * cps
      while rt.autoClickAcc >= 1 - 1e-9 do
        rt.autoClickAcc = rt.autoClickAcc - 1
        Cb().Click(false, "auto")
      end
    end
    local sec = math.floor(rt.clock)
    if sec ~= rt.castSec then
      rt.castSec = sec
      if T.AutoCastOn() then
        autoCast()
      end
    end
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
  T.Sync = function()
    local rt = C.rt
    rt.castSec = math.floor(rt.clock)
    rt.autoBuyT = math.floor(rt.clock / B().TIDE_AUTOBUY_SEC)
  end
  T.PATHS = PATHS
end
