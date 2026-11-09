local ADDON, Mrgl = ...
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
    local i = U.At(PAIR, pos) + (s + k) % 2
    local e = U.At(z.normals, i)
    return { name = e.name, icon = e.icon, kind = "normal", rank = i, tint = e.tint }
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
    if db.enemyRare and e.kind == "normal" then
      local r = U.At(Cb.Zone(db.stage).rares, db.stage % 2 + 1)
      e = { name = r.name, icon = r.icon, kind = "rare", rank = 0, shortName = r.shortName, tint = r.tint }
    end
    return e
  end
  Cb.RareKey = function(s)
    return Cb.Zone(s).id .. ":" .. (s % 2 + 1)
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
  Cb.CritChance = function(kind)
    if Cb.LeeroyActive() and (kind == "click" or (kind == "whelp" and B().LEEROY_RUSH_WHELPS)) then
      return 1
    end
    return F().CritChance(Mrgl.db.self, Cb.CandleActive())
  end
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
        U.Set(rt.buckets, s % n + 1, 0)
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
    local idx = rt.bucketSec % n + 1
    U.Set(rt.buckets, idx, U.At(rt.buckets, idx) + 1)
  end
  Cb.SetClickRate = function(cps)
    local l = C.rt.buckets
    for i = 1, U.Len(l) do
      U.Set(l, i, cps)
    end
    C.rt.bucketSec = math.floor(C.rt.clock)
  end
  Cb.AddGold = function(g)
    local db = Mrgl.db
    db.gold = db.gold + g
    db.goldEarned = db.goldEarned + g
    if C.rt.inCombat then
      C.rt.combatGold = C.rt.combatGold + g
    end
    if C.rt.quiet ~= true then
      C.Fire("GOLD", { amount = g })
    end
  end
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
      if kind ~= "auto" and rt.queued < B().CLICK_QUEUE then
        rt.queued = rt.queued + 1
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
    local g = 1
    if kind == "click" then
      g = B().CLICK_KILL_GOLD
    end
    Cb.Hit(dmg, kind, crit, g)
  end
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
        Cb.Damage(d, 1, "whelp")
        sum = sum + d
        cnt = cnt + 1
        if db.enemyHp <= 0 then
          C.Fire("HIT", { amount = sum, kind = "whelp", crit = false, bundle = cnt, crits = cr })
          sum, cnt, cr, dmg = 0, 0, 0, nil
          Cb.Die(1, "whelp")
        end
      end
    end
    if cnt > 0 then
      C.Fire("HIT", { amount = sum, kind = "whelp", crit = false, bundle = cnt, crits = cr })
    end
  end
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
      if rt.killSet == true then
        return
      end
      local dmg = Cb.ClickDamage()
      local cc = Cb.CritChance("whelp")
      local cm = F().CritMult(db.self)
      local avg = dmg * (1 + cc * (cm - 1))
      local k = left
      if avg > 0 then
        k = math.min(left, math.max(1, math.ceil((db.enemyHp - rt.enemyBank) / avg)))
      end
      local crits = math.min(k, math.floor(k * cc + U.Rand()))
      db.stats.crits = db.stats.crits + crits
      Cb.Damage((k - crits) * dmg + crits * dmg * cm, 1, "whelp")
      left = left - k
      if db.enemyHp <= 0 then
        Cb.Die(1, "whelp")
      end
    end
  end
  Cb.EnemyAge = function()
    return C.rt.enemyAge
  end
  Cb.NewLife = function()
    local rt = C.rt
    rt.enemyAge = 0
    rt.enemyBank = 0
    rt.killSet = false
    rt.killGold = 1
    rt.killKind = nil
  end
  local function lifeFloor()
    local ml = B().MIN_LIFE
    local age = C.rt.enemyAge
    if not (ml ~= nil and ml > 0) or age >= ml then
      return 0
    end
    return F().EnemyHP(Mrgl.db.stage) * (1 - age / ml)
  end
  Cb.Damage = function(amount, goldMult, kind)
    local db = Mrgl.db
    local rt = C.rt
    local ml = B().MIN_LIFE
    if rt.enemyBank == 0 and (not (ml ~= nil and ml > 0) or rt.enemyAge >= ml) then
      db.enemyHp = db.enemyHp - amount
      return
    end
    if rt.killSet ~= true and db.enemyHp - rt.enemyBank - amount <= 0 then
      rt.killSet = true
      rt.killGold = goldMult
      rt.killKind = kind
    end
    local room = db.enemyHp - lifeFloor()
    if room < 0 then
      room = 0
    end
    if amount <= room then
      db.enemyHp = db.enemyHp - amount
    else
      db.enemyHp = db.enemyHp - room
      rt.enemyBank = rt.enemyBank + amount - room
    end
  end
  local function release()
    local db = Mrgl.db
    local rt = C.rt
    if not (rt.enemyBank > 0) then
      return
    end
    local room = db.enemyHp - lifeFloor()
    if room <= 0 then
      return
    end
    local take = math.min(rt.enemyBank, room)
    db.enemyHp = db.enemyHp - take
    rt.enemyBank = rt.enemyBank - take
  end
  Cb.Die = function(goldMult, kind)
    local rt = C.rt
    local g, k = goldMult, kind
    if rt.killSet == true then
      g, k = rt.killGold, rt.killKind
    end
    Mrgl.db.enemyHp = 0
    Cb.NewLife()
    Cb.Kill(g, k)
  end
  Cb.Hit = function(amount, kind, crit, goldMult)
    local db = Mrgl.db
    local rt = C.rt
    if rt.respawn > 0 then
      return false
    end
    if kind == "auto" then
      rt.squadDealt = rt.squadDealt + math.min(amount, math.max(0, db.enemyHp - rt.enemyBank))
    end
    Cb.Damage(amount, goldMult, kind)
    if crit then
      db.stats.crits = db.stats.crits + 1
    end
    local p = { amount = amount, kind = kind, crit = crit }
    C.Fire("HIT", p)
    if crit then
      C.Fire("CRIT", p)
    end
    if db.enemyHp <= 0 then
      Cb.Die(goldMult, kind)
      return true
    end
    return false
  end
  Cb.EnsureEnemy = function()
    if C.rt.respawn > 0 then
      C.rt.respawn = 0
      C.rt.queued = 0
      Cb.Spawn()
    end
  end
  Cb.Squad = function(dt)
    local db = Mrgl.db
    local rt = C.rt
    local d = Cb.SquadDPS()
    local ml = B().MIN_LIFE
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
      elseif rt.enemyBank == 0 and (not (ml ~= nil and ml > 0) or rt.enemyAge >= ml) then
        if not (d > 0) then
          return
        end
        if db.boss.active and rt.inCombat then
          return
        end
        local need = db.enemyHp / d
        if need <= t then
          rt.squadDealt = rt.squadDealt + db.enemyHp
          t = t - need
          Cb.Die(1, nil)
        else
          db.enemyHp = db.enemyHp - d * t
          rt.squadDealt = rt.squadDealt + d * t
          t = 0
        end
      else
        if db.boss.active and rt.inCombat then
          return
        end
        local eff = db.enemyHp - rt.enemyBank
        local need2 = 0
        if eff > 0 then
          if d > 0 then
            need2 = eff / d
          else
            need2 = math.huge
          end
        end
        local tDie = math.max(need2, math.max(0, ml - rt.enemyAge))
        if tDie <= t + 1e-9 then
          if eff > 0 then
            rt.squadDealt = rt.squadDealt + eff
          end
          tDie = math.min(tDie, t)
          rt.enemyAge = rt.enemyAge + tDie
          t = t - tDie
          Cb.Die(1, nil)
        else
          local dd = 0
          if d > 0 then
            dd = d * t
          end
          if dd > 0 then
            rt.squadDealt = rt.squadDealt + math.min(dd, math.max(0, eff))
          end
          rt.enemyAge = rt.enemyAge + t
          if dd > 0 then
            Cb.Damage(dd, 1, nil)
          end
          release()
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
  Cb.Kill = function(goldMult, kind)
    local db = Mrgl.db
    local rt = C.rt
    local s = db.stage
    local boss = db.boss.active
    local rare = db.enemyRare
    local g = F().Gold(s, boss, rare, db.murlocs) * goldMult
    db.stats.kills = db.stats.kills + 1
    if rare and not boss then
      Cb.MarkRare(s)
    end
    rt.respawn = B().RESPAWN
    Cb.AddGold(g)
    if boss then
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
      end
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
    Cb.NewLife()
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
      local qk = U.At(rt.queueKinds, i)
      if qk == nil then
        qk = "click"
      end
      Cb.ClickHit(qk)
    end
  end
end
