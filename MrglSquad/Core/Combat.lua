local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Combat.lua equivalent: clicks, hits, kills, respawn, stages, rares (plan 4.1, 5.1).
Mrgl.Core = Mrgl.Core or {}
do
  local F, B, rollBuckets, recordClick
  local Cb = {}
  Mrgl.Core.Combat = Cb
  local C = Mrgl.Core
  local U = Mrgl.U
  function F()
    return Mrgl.Core.Formula
  end
  function B()
    return Mrgl.Data.Balance
  end
  -- ------------------------------------------------------------ route
  Cb.Route = function(zi)
    local R = Mrgl.Data.Routes
    if zi <= R.FACTION_ZONES then
      return U.At(R[Mrgl.db.faction], zi)
    end
    return U.At(R.shared, zi - R.FACTION_ZONES)
  end
  Cb.Zone = function(s)
    return Cb.Route(F().ZoneIndex(s))
  end
  -- enemy definition for stage s and kill k (1-10)
  -- enemies1 E1.1: position 1-9 picks a pair of the 6 normals (sorted by threat), the kill alternates inside the pair:
  -- pos 1-2 N1/N2, 3-4 N2/N3, 5 mini, 6-7 N4/N5, 8-9 N5/N6, 10 boss. rank = N index (the tooltip says "Elite" at 5-6), 0 for
  -- mini, boss and rare. Bosses pass shortName and the optional look fields tint / face / type (King Mrgl-Mrgl, E3).
  local PAIR = { 1, 1, 2, 2, 0, 4, 4, 5, 5 }
  local function bossEntry(b)
    return { name = b.name, icon = b.icon, kind = "boss", rank = 0, shortName = b.shortName, tint = b.tint, face = b.face, type = b.type }
  end
  Cb.EnemyAt = function(s, k)
    local z = Cb.Zone(s)
    local pos = F().Pos(s)
    if pos == 5 then
      return bossEntry(z.mini)
    end
    if pos == 10 then
      return bossEntry(z.boss)
    end
    local i = U.At(PAIR, pos) + (s + k) % 2   -- nonneg (stage, kill >= 1)
    local e = U.At(z.normals, i)
    return { name = e.name, icon = e.icon, kind = "normal", rank = i }
  end
  Cb.KillIndex = function()
    local db = Mrgl.db
    if db.kills >= B().KILLS_PER_STAGE then
      return db.stats.kills
    end
    return db.kills + 1
  end
  Cb.Enemy = function()
    local db = Mrgl.db
    local e = Cb.EnemyAt(db.stage, Cb.KillIndex())
    -- enemies1 E4: a rare is one of the 2 named rares of the zone, chosen by stage parity (only enemyRare is saved)
    if db.enemyRare and e.kind == "normal" then
      local r = U.At(Cb.Zone(db.stage).rares, db.stage % 2 + 1)   -- nonneg (stage >= 1)
      e = { name = r.name, icon = r.icon, kind = "rare", rank = 0, shortName = r.shortName }
    end
    return e
  end
  -- enemies1 E4.1: rare key "zoneId:i" of stage s (same choice as Cb.Enemy) and the seen list stats.rareSeen
  Cb.RareKey = function(s)
    return Cb.Zone(s).id .. ":" .. (s % 2 + 1)   -- nonneg (stage >= 1)
  end
  Cb.MarkRare = function(s)
    local st = Mrgl.db.stats
    st.rareSeen = Mrgl.Core.State.NormRares(st.rareSeen .. "," .. Cb.RareKey(s))
  end
  Cb.GateOpen = function()
    local db = Mrgl.db
    return not db.boss.active and db.kills >= B().KILLS_PER_STAGE and F().IsBoss(db.stage + 1)
  end
  Cb.FarmStage = function()
    local db = Mrgl.db
    if db.boss.active or F().IsBoss(db.stage) then
      return math.max(1, db.stage - 1)
    end
    return db.stage
  end
  Cb.SquadDPS = function()
    return F().SquadDPS(Mrgl.db.murlocs)
  end
  Cb.ClickDamage = function()
    return F().ClickDamage(Mrgl.db.murlocs, Mrgl.db.self, Cb.SquadDPS())
  end
  Cb.CandleActive = function()
    return Mrgl.db.buffs.candle > C.Now()
  end
  Cb.LeeroyActive = function()
    return Mrgl.db.buffs.leeroy > C.Now()
  end
  -- kind: "click" (own), "whelp" (Many Whelps!), "auto" (New Tide auto-click) - LEEROY's 10 s rush makes every own click
  -- (and whelp click) crit, never an auto click
  Cb.CritChance = function(kind)
    if Cb.LeeroyActive() and (kind == "click" or (kind == "whelp" and B().LEEROY_RUSH_WHELPS)) then
      return 1
    end
    return F().CritChance(Mrgl.db.self, Cb.CandleActive())
  end
  -- ------------------------------------------------------------ measured clicks (last 30 s)
  function rollBuckets()
    local rt = C.rt
    local sec = math.floor(rt.clock)
    local n = U.Len(rt.buckets)
    if sec - rt.bucketSec >= n then
      for i = 1, n do
        U.Set(rt.buckets, i, 0)
      end
    else
      for s = rt.bucketSec + 1, sec do
        U.Set(rt.buckets, s % n + 1, 0)   -- nonneg (server seconds)
      end
    end
    rt.bucketSec = sec
  end
  Cb.ClickRate = function()
    rollBuckets()
    local t, l = 0, C.rt.buckets
    for i = 1, U.Len(l) do
      t = t + U.At(l, i)
    end
    return t / U.Len(l)
  end
  function recordClick()
    rollBuckets()
    local rt = C.rt
    local n = U.Len(rt.buckets)
    local idx = rt.bucketSec % n + 1   -- nonneg (server seconds)
    U.Set(rt.buckets, idx, U.At(rt.buckets, idx) + 1)
  end
  Cb.SetClickRate = function(cps) -- for tests and presets
    local l = C.rt.buckets
    for i = 1, U.Len(l) do
      U.Set(l, i, cps)
    end
    C.rt.bucketSec = math.floor(C.rt.clock)
  end
  -- ------------------------------------------------------------ gold
  Cb.AddGold = function(g)
    local db = Mrgl.db
    db.gold = db.gold + g
    db.goldEarned = db.goldEarned + g
    if C.rt.inCombat then
      C.rt.combatGold = C.rt.combatGold + g
    end
    -- j1: in catch-up (quiet) Fire drops these juice events anyway; skipping the call saves the payload table per kill
    if C.rt.quiet ~= true then
      C.Fire("GOLD", { amount = g })
    end
  end
  -- ------------------------------------------------------------ hits
  -- manual = true for real clicks/keys (counted for the click rate)
  Cb.Click = function(manual, kind)
    local db = Mrgl.db
    local rt = C.rt
    if manual then
      recordClick()
      db.stats.clicks = db.stats.clicks + 1
      db.onboarding.firstClick = true
    end
    if db.boss.active and rt.inCombat then
      return
    end
    if rt.respawn > 0 then
      -- New Tide C4: an auto click is not queued (a queued click would pay the real-click gold)
      if kind ~= "auto" and rt.queued < B().CLICK_QUEUE then
        rt.queued = rt.queued + 1
        -- tide1c C2: the queue keeps the hit kind (a whelp hit stays a whelp hit: no click gold, number or punch)
        local qk = kind
        if qk == nil then
          qk = "click"
        end
        U.Set(rt.queueKinds, rt.queued, qk)
      end
      return
    end
    if kind == nil then
      kind = "click"
    end
    Cb.ClickHit(kind)
  end
  Cb.ClickHit = function(kind)
    local db = Mrgl.db
    local dmg = Cb.ClickDamage()
    local crit = U.Rand() < Cb.CritChance(kind)
    if crit then
      dmg = dmg * F().CritMult(db.self)
    end
    -- r2 B2: a kill by a real click (mouse, key, queued) pays double
    local g = 1
    if kind == "click" then
      g = B().CLICK_KILL_GOLD
    end
    Cb.Hit(dmg, kind, crit, g)
  end
  -- n Many Whelps! clicks of one tick as one bundle (Abilities.Step).
  -- tide1d D1 online: Cb.WhelpLive - exactly n x Click(false, "whelp") (same RNG draws, same HP arithmetic, same queue,
  -- so run 1 and the balance stay byte-identical), but ONE HIT per bundle and no CRIT event:
  --   HIT { amount = sum of the click hits, kind = "whelp", crit = false, bundle = n clicks, crits = k }
  -- crit is false on purpose: whelp hits never start the crit flash or the punch (Jan's calm rule); the UI adds them
  -- silently to lane L (keyed on kind "whelp"). A killing bundle fires its HIT before the KILL; the rest of the tick queues.
  -- tide1c C6 catch-up (rt.quiet): Cb.WhelpQuiet below - aggregated crits, no HIT.
  Cb.WhelpBurst = function(n)
    if C.rt.quiet == true then
      Cb.WhelpQuiet(n)
    else
      Cb.WhelpLive(n)
    end
  end
  Cb.WhelpLive = function(n)
    local db = Mrgl.db
    local rt = C.rt
    local sum, cnt, cr = 0, 0, 0
    local dmg, cc, cm
    for i = 1, n do
      if db.boss.active and rt.inCombat then
        break
      end
      if rt.respawn > 0 then
        if rt.queued < B().CLICK_QUEUE then
          rt.queued = rt.queued + 1
          U.Set(rt.queueKinds, rt.queued, "whelp")
        end
      else
        if dmg == nil then
          dmg = Cb.ClickDamage()
          cc = Cb.CritChance("whelp")
          cm = F().CritMult(db.self)
        end
        local d = dmg
        if U.Rand() < cc then
          d = dmg * cm
          db.stats.crits = db.stats.crits + 1
          cr = cr + 1
        end
        db.enemyHp = db.enemyHp - d
        sum = sum + d
        cnt = cnt + 1
        if db.enemyHp <= 0 then
          db.enemyHp = 0
          C.Fire("HIT", { amount = sum, kind = "whelp", crit = false, bundle = cnt, crits = cr })
          sum, cnt, cr, dmg = 0, 0, 0, nil
          Cb.Kill(1, "whelp")
        end
      end
    end
    if cnt > 0 then
      C.Fire("HIT", { amount = sum, kind = "whelp", crit = false, bundle = cnt, crits = cr })
    end
  end
  -- tide1c C6: catch-up only. Crits = k x chance rounded with one random draw: the right mean but almost no spread, fine
  -- for silent catch-up, not meant for online play (lua review tide1c K2). A kill takes the clicks it needs on average,
  -- the rest is queued as whelp hits like single clicks during the respawn. Same expected damage and gold.
  Cb.WhelpQuiet = function(n)
    local db = Mrgl.db
    local rt = C.rt
    local left = n
    local guard = 0
    while left > 0 and guard < 100 do
      guard = guard + 1
      if db.boss.active and rt.inCombat then
        return
      end
      if rt.respawn > 0 then
        while left > 0 and rt.queued < B().CLICK_QUEUE do
          rt.queued = rt.queued + 1
          U.Set(rt.queueKinds, rt.queued, "whelp")
          left = left - 1
        end
        return
      end
      local dmg = Cb.ClickDamage()
      local cc = Cb.CritChance("whelp")
      local cm = F().CritMult(db.self)
      local avg = dmg * (1 + cc * (cm - 1))
      local k = left
      if avg > 0 then
        k = math.min(left, math.max(1, math.ceil(db.enemyHp / avg)))
      end
      local crits = math.min(k, math.floor(k * cc + U.Rand()))
      db.stats.crits = db.stats.crits + crits
      db.enemyHp = db.enemyHp - ((k - crits) * dmg + crits * dmg * cm)
      left = left - k
      if db.enemyHp <= 0 then
        db.enemyHp = 0
        Cb.Kill(1, "whelp")
      end
    end
  end
  -- A hit on the current enemy. Returns true when it killed.
  Cb.Hit = function(amount, kind, crit, goldMult)
    local db = Mrgl.db
    if C.rt.respawn > 0 then
      return false
    end
    -- New Tide C4: auto-click damage joins the squad number (1x/s), the UI shows no own number for kind "auto"
    if kind == "auto" then
      C.rt.squadDealt = C.rt.squadDealt + math.min(amount, db.enemyHp)
    end
    db.enemyHp = db.enemyHp - amount
    if crit then
      db.stats.crits = db.stats.crits + 1
    end
    local p = { amount = amount, kind = kind, crit = crit }
    C.Fire("HIT", p)
    if crit then
      C.Fire("CRIT", p)
    end
    if db.enemyHp <= 0 then
      db.enemyHp = 0
      Cb.Kill(goldMult, kind)
      return true
    end
    return false
  end
  -- Brings the next enemy in at once (abilities never hit air).
  Cb.EnsureEnemy = function()
    -- queued clicks are dropped here: they could kill the fresh enemy before the ability lands
    if C.rt.respawn > 0 then
      C.rt.respawn = 0
      C.rt.queued = 0
      Cb.Spawn()
    end
  end
  -- Squad damage over dt seconds, exact across kills and the respawn pause (no overkill carry).
  Cb.Squad = function(dt)
    local db = Mrgl.db
    local rt = C.rt
    local d = Cb.SquadDPS()
    local t = dt
    local guard = 0
    while t > 1e-9 and guard < 1000 do
      guard = guard + 1
      if rt.respawn > 0 then
        local w = math.min(t, rt.respawn)
        rt.respawn = rt.respawn - w
        t = t - w
        if rt.respawn <= 1e-9 then
          rt.respawn = 0
          Cb.Spawn()
        end
      else
        if not (d > 0) then
          return
        end
        if db.boss.active and rt.inCombat then
          return
        end -- boss fight frozen in combat
        local need = db.enemyHp / d
        if need <= t then
          rt.squadDealt = rt.squadDealt + db.enemyHp
          db.enemyHp = 0
          t = t - need
          Cb.Kill(1)
        else
          db.enemyHp = db.enemyHp - d * t
          rt.squadDealt = rt.squadDealt + d * t
          t = 0
        end
      end
    end
  end
  Cb.TakeSquadDealt = function()
    local v = C.rt.squadDealt
    C.rt.squadDealt = 0
    return v
  end
  -- ------------------------------------------------------------ kill, spawn, stages
  -- kind: hit kind of the last hit ("click", "whelp", "mrgl", "leeroy") or undefined (squad)
  Cb.Kill = function(goldMult, kind)
    local db = Mrgl.db
    local rt = C.rt
    local s = db.stage
    local boss = db.boss.active
    local rare = db.enemyRare
    local g = F().Gold(s, boss, rare, db.murlocs) * goldMult
    db.stats.kills = db.stats.kills + 1
    if rare and not boss then
      Cb.MarkRare(s) -- enemies1 E4.1: seen rares (also in catch-up)
    end
    rt.respawn = B().RESPAWN
    Cb.AddGold(g)
    if boss then
      -- the victory headline waits for a running LEEROY headline (r2 L3)
      rt.respawn = B().BOSS_RESPAWN + math.max(0, rt.leeroyLine)
      C.Fire("KILL", { gold = g, boss = true, rare = false, stage = s, pip = 0, leeroy = kind == "leeroy", click = kind == "click" })
      Mrgl.Core.Boss.Win(g)
      return
    end
    if db.kills < B().KILLS_PER_STAGE then
      db.kills = db.kills + 1
    end
    if rt.quiet ~= true then
      C.Fire("KILL", { gold = g, boss = false, rare = rare, stage = s, pip = db.kills, leeroy = kind == "leeroy", click = kind == "click" })
    end
    if db.kills >= B().KILLS_PER_STAGE then
      if F().IsBoss(s + 1) then
        if not rt.gateFired then
          rt.gateFired = true
          C.Fire("GATE_OPEN", { stage = s + 1 })
        end
      else
        Cb.SetStage(s + 1)
      end
    end
  end
  Cb.SetStage = function(s)
    local db = Mrgl.db
    local oldZone = F().ZoneIndex(db.stage)
    db.stage = s
    db.kills = 0
    C.rt.gateFired = false
    if s > db.maxStage then
      db.maxStage = s
      if s > db.prestige.best then
        db.prestige.best = s
      end -- New Tide C5: highest stage ever, live
      Mrgl.Core.Abilities.CheckUnlock()
    end
    C.Fire("STAGE", { stage = s })
    if F().ZoneIndex(s) ~= oldZone then
      C.Fire("ZONE", { zone = F().ZoneIndex(s), name = Cb.Zone(s).name })
    end
  end
  Cb.Spawn = function()
    local db = Mrgl.db
    local rt = C.rt
    db.enemyHp = F().EnemyHP(db.stage)
    db.enemyRare = false
    if not F().IsBoss(db.stage) and db.rareStage ~= db.stage and U.Rand() < B().RARE_CHANCE then
      db.enemyRare = true
      db.rareStage = db.stage
    end
    if rt.quiet ~= true then
      C.Fire("SPAWN", { stage = db.stage, rare = db.enemyRare })
      if db.enemyRare then
        C.Fire("RARE_SPAWN", { stage = db.stage })
      end
    end
    local q = rt.queued
    rt.queued = 0
    for i = 1, q do
      if rt.respawn > 0 then
        break
      end
      local qk = U.At(rt.queueKinds, i) -- tide1c C2: replay with the stored kind
      if qk == nil then
        qk = "click"
      end
      Cb.ClickHit(qk)
    end
  end
end
