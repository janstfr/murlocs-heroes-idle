local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Tick.lua equivalent: fixed 0.1-s step, catch-up (Advance), offline report (plan 1.3 #9, 5.1).
Mrgl.Core = Mrgl.Core or {}
do
  local B
  local C = Mrgl.Core
  local T = {}
  C.Tick = T
  local U = Mrgl.U
  function B()
    return Mrgl.Data.Balance
  end
  -- Start the core on a loaded db. now = server time (GetServerTime()).
  C.Init = function(db, now)
    Mrgl.db = db
    C.rt = C.NewRuntime(now)
    Mrgl.Core.Shop.Dirty()
    -- abilities that the stage already allows (old saves, presets) unlock silently
    C.rt.quiet = true
    Mrgl.Core.Abilities.CheckUnlock()
    C.rt.quiet = false
    if db.kills >= B().KILLS_PER_STAGE then
      C.rt.gateFired = true
    end
  end
  T.Step = function(dt)
    C.rt.clock = C.rt.clock + dt
    Mrgl.Core.Abilities.Step(dt)
    Mrgl.Core.Tide.Step(dt)   -- New Tide C4: auto-click, auto-cast, auto-buy (all off while Total() = 0)
    Mrgl.Core.Combat.Squad(dt)
    Mrgl.Core.Boss.Step(dt)
  end
  -- Called from the driver frame's OnUpdate with the real elapsed seconds.
  T.Run = function(elapsed)
    local rt = C.rt
    rt.acc = rt.acc + elapsed
    local tick = B().TICK
    local n = math.floor(rt.acc / tick + 1e-6)
    if n <= 0 then
      return
    end
    rt.acc = rt.acc - n * tick
    if rt.acc < 0 then
      rt.acc = 0
    end
    if n > B().MAX_STEPS then
      T.Advance(n * tick)
      return
    end
    for i = 1, n do
      T.Step(tick)
    end
  end
  -- Catch-up in 1-s steps without juice events (tab in background, loading screen).
  T.Advance = function(sec)
    local db = Mrgl.db
    local rt = C.rt
    local gold0 = db.goldEarned
    local stage0 = db.maxStage
    rt.quiet = true
    -- long sleeps: simulate at most ADVANCE_MAX seconds, the rest pays like offline time
    local extra = 0
    if sec > B().ADVANCE_MAX then
      extra = sec - B().ADVANCE_MAX
      sec = B().ADVANCE_MAX
    end
    local whole = math.floor(sec)
    for i = 1, whole do
      T.Step(1)
    end
    local rest = sec - whole
    if rest > 0 then
      T.Step(rest)
    end
    if extra > 0 then
      local g = Mrgl.Core.Formula.OfflineGold(db.murlocs, db.self, Mrgl.Core.Combat.FarmStage(), extra)
      Mrgl.Core.Combat.AddGold(g)
      rt.clock = rt.clock + extra
      sec = sec + extra
    end
    rt.quiet = false
    C.Fire("CATCHUP", { seconds = sec, gold = db.goldEarned - gold0, stages = db.maxStage - stage0 })
  end
  -- Login: offline gold for the time since the last save. No stage progress offline.
  T.ApplyOffline = function(now)
    local db = Mrgl.db
    local rt = C.rt
    local dt = 0
    if db.lastSeen > 0 then
      dt = math.max(0, now - db.lastSeen)
    end
    rt.clock = now
    rt.bucketSec = math.floor(now)
    Mrgl.Core.Tide.Sync()   -- New Tide C4: no auto-buy for the time offline
    -- a clock that went backwards must not leave cooldowns longer than the cooldown itself
    local al = Mrgl.Data.Abilities
    for a = 1, U.Len(al) do
      local ad = U.At(al, a)
      local ast = db.abilities[ad.id]
      if ast.readyAt > now + ad.cd then
        ast.readyAt = now + ad.cd
      end
    end
    if db.boss.active then
      Mrgl.Core.Boss.Cancel()
    end
    local s = Mrgl.Core.Combat.FarmStage()
    local gold = Mrgl.Core.Formula.OfflineGold(db.murlocs, db.self, s, dt)
    if gold > 0 then
      db.gold = db.gold + gold
      db.goldEarned = db.goldEarned + gold
    end
    local report = { seconds = dt, gold = gold, capped = dt > B().OFFLINE_MAX }
    C.Fire("OFFLINE", report)
    return report
  end
  -- WoW combat (PLAYER_REGEN_DISABLED/ENABLED via the UI's own flag)
  C.SetCombat = function(on)
    local rt = C.rt
    if rt.inCombat == on then
      return
    end
    rt.inCombat = on
    if on then
      rt.combatGold = 0
      rt.autoT = 0
    end
    C.Fire("COMBAT", { on = on, gold = rt.combatGold })
  end
  C.SetPopup = function(open)
    C.rt.popup = open
  end
end
