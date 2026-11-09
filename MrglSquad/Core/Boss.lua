local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Boss.lua equivalent: gate, start, timer, win, fail, combat freeze, auto-fight (plan 5.1).
Mrgl.Core = Mrgl.Core or {}
do
  local F, B, Cb
  local Bo = {}
  Mrgl.Core.Boss = Bo
  local C = Mrgl.Core
  local U = Mrgl.U
  function F()
    return Mrgl.Core.Formula
  end
  function B()
    return Mrgl.Data.Balance
  end
  function Cb()
    return Mrgl.Core.Combat
  end
  -- Stage of the next (or current) boss
  Bo.NextStage = function()
    local db = Mrgl.db
    if db.boss.active then
      return db.stage
    end
    return F().NextBossStage(db.stage + 1)
  end
  Bo.NextEnemy = function()
    return Cb().EnemyAt(Bo.NextStage(), 1)
  end
  -- abilities that count for the opener (B4): ready and opener on
  Bo.ReadySet = function()
    local db = Mrgl.db
    local A = Mrgl.Core.Abilities
    -- r3 G3: every ready ability counts, opener on or off (the colour tells the truth)
    return { mrgl = A.IsReady("mrgl"), whelps = A.IsReady("whelps"), candle = A.IsReady("candle"), leeroy = A.IsReady("leeroy") }
  end
  Bo.Ready = function()
    local db = Mrgl.db
    return F().Ready(db.murlocs, db.self, Bo.NextStage(), Cb().ClickRate(), Bo.ReadySet())
  end
  Bo.Strength = function()
    local db = Mrgl.db
    return F().Strength(db.murlocs, db.self, Bo.NextStage(), Bo.ReadySet())
  end
  Bo.Timer = function()
    return F().BossTimer(Mrgl.db.murlocs)
  end
  -- Held after a failed fight until the squad is 25% stronger (auto-fight only)
  Bo.Held = function()
    local db = Mrgl.db
    local f = db.autoFailDps[Bo.NextStage()]
    if f == nil then
      return false
    end
    return Cb().SquadDPS() < f * B().AUTO_RETRY_DPS
  end
  -- Auto-fight state for the UI: "off", "none" (not green / no gate), "wait" (combat or popup),
  -- "held" (lost before, waits for +25% DPS), "countdown" (left = seconds)
  Bo.AutoState = function()
    local db = Mrgl.db
    local rt = C.rt
    if not Cb().GateOpen() then
      return { state = "none", left = 0 }
    end
    if not db.settings.autofight then
      return { state = "off", left = 0 }
    end
    if Bo.Ready() ~= "green" then
      return { state = "none", left = 0 }
    end -- greenAbil never auto-starts
    if Bo.Held() then
      return { state = "held", left = 0 }
    end
    if rt.inCombat or rt.popup or rt.tideVeil == true then
      return { state = "wait", left = 0 }
    end
    return { state = "countdown", left = math.max(0, B().AUTO_FIGHT_DELAY - rt.autoT) }
  end
  Bo.Start = function(auto)
    local db = Mrgl.db
    local rt = C.rt
    if not Cb().GateOpen() or rt.inCombat then
      return false
    end
    if rt.tideVeil == true then
      return false
    end -- tide1c C7: the chosen New Tide must not be lost to a boss start
    local bs = db.stage + 1
    db.stage = bs
    -- r2 L6: abilities of a boss stage unlock after the fight (win or loss), not during it
    if bs > db.maxStage then
      db.maxStage = bs
    end
    if bs > db.prestige.best then
      db.prestige.best = bs
    end -- New Tide C5: highest stage ever, live
    db.boss.active = true
    db.boss.auto = auto
    db.boss.max = Bo.Timer()
    db.boss.time = db.boss.max
    db.enemyHp = F().EnemyHP(bs)
    Cb().NewLife() -- j5 K5
    db.enemyRare = false
    rt.respawn = 0
    rt.queued = 0
    rt.autoT = 0
    rt.bossSec = math.ceil(db.boss.time)
    -- j2 A4 (Jan): at the start of a boss fight every unlocked ability is ready, before the opener queues. readyAt = 0
    -- is "ready" without an ABILITY_READY event (no ready flash; the UI clears the swipe on the next refresh). Running
    -- buffs stay. Once per boss stage until that boss is won or lost by timer: leaving the fight another way (Cancel at
    -- login) does not re-arm it, so start/leave cannot farm resets
    if db.boss.resetStage ~= bs then
      db.boss.resetStage = bs
      local al = Mrgl.Data.Abilities
      for i = 1, U.Len(al) do
        local ast = db.abilities[U.At(al, i).id]
        if ast.unlocked then
          ast.readyAt = 0
        end
      end
    end
    local opener = not auto and db.settings.opener
    local e = Cb().EnemyAt(bs, 1)
    C.Fire("BOSS_START", { stage = bs, auto = auto, opener = opener, name = e.name })
    if opener then
      Mrgl.Core.Abilities.QueueOpener()
    end
    -- New Tide C4: auto-fight start with War Drums (Spells 10) casts every ready ability right after the A4 reset, LEEROY too
    if auto == true then
      Mrgl.Core.Tide.BossOpen()
    end
    return true
  end
  Bo.Win = function(gold)
    local db = Mrgl.db
    local bs = db.stage
    local e = Cb().EnemyAt(bs, 1)
    db.boss.active = false
    db.boss.time = 0
    db.stats.bosses = db.stats.bosses + 1
    db.boss.resetStage = 0 -- j2 A4: the next boss start resets the abilities again
    db.autoFailDps[bs] = nil   -- map entry, no list hole
    C.Fire("BOSS_WIN", { stage = bs, name = e.name, gold = gold })
    -- New Tide T: the first win over Nefarian (zone 11 boss, also at 120, 130 ...) gives the trophy, just for show.
    -- Chromaggus (105, 115 ...) does not count. Also in catch-up and with auto-fight (TROPHY passes quiet)
    if F().ZoneIndex(bs) == 11 and F().IsZoneBoss(bs) and db.prestige.trophies.nef ~= true then
      db.prestige.trophies.nef = true
      C.Fire("TROPHY", { id = "nef" })
    end
    Cb().SetStage(bs + 1)
    Mrgl.Core.Abilities.CheckUnlock()
    C.Fire("SAVE", {})
  end
  Bo.Fail = function()
    local db = Mrgl.db
    local rt = C.rt
    local bs = db.stage
    local e = Cb().EnemyAt(bs, 1)
    -- Any loss holds auto-fight on this boss until +25% squad damage (manual starts ignore it)
    db.autoFailDps[bs] = math.max(Cb().SquadDPS(), 1e-9)
    local auto = db.boss.auto
    -- remember how close it was (before the enemy HP is reset), for the boss tooltip
    db.boss.lostAt = db.enemyHp / F().EnemyHP(bs)
    db.boss.lostStage = bs
    db.boss.resetStage = 0 -- j2 A4: lost by timer: the next try starts with ready abilities again
    db.boss.active = false
    db.boss.time = 0
    db.stage = bs - 1
    db.kills = B().KILLS_PER_STAGE
    db.enemyHp = 0
    rt.respawn = B().RESPAWN
    rt.queued = 0
    rt.autoT = 0
    rt.opener = {}
    rt.gateFired = true
    C.Fire("BOSS_FAIL", { stage = bs, auto = auto, name = e.name, hp = db.boss.lostAt })
    C.Fire("STAGE", { stage = db.stage })
    Mrgl.Core.Abilities.CheckUnlock()
  end
  -- Leaves a running fight without any record (load after a long time, preset changes)
  Bo.Cancel = function()
    local db = Mrgl.db
    if not db.boss.active then
      return
    end
    db.boss.active = false
    db.stage = db.stage - 1
    db.kills = B().KILLS_PER_STAGE
    db.enemyHp = F().EnemyHP(db.stage)
    Cb().NewLife() -- j5 K5
    C.rt.gateFired = true
  end
  Bo.Step = function(dt)
    local db = Mrgl.db
    local rt = C.rt
    if db.boss.active then
      if rt.inCombat then
        return
      end -- frozen
      if rt.respawn > 0 then
        return
      end -- the kill is resolving
      db.boss.time = db.boss.time - dt
      local sec = math.ceil(db.boss.time)
      if sec ~= rt.bossSec then
        rt.bossSec = sec
        C.Fire("BOSS_TICK", { left = db.boss.time, sec = sec })
      end
      if db.boss.time <= 0 and db.enemyHp > 0 then
        Bo.Fail()
      end
      return
    end
    local a = Bo.AutoState()
    if a.state == "countdown" then
      rt.autoT = rt.autoT + dt
      if rt.quiet or rt.autoT >= B().AUTO_FIGHT_DELAY then
        Bo.Start(true)
      end
    else
      rt.autoT = 0
    end
  end
end
