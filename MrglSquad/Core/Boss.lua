local ADDON, Mrgl = ...
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
  Bo.ReadySet = function()
    local db = Mrgl.db
    local A = Mrgl.Core.Abilities
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
  Bo.Held = function()
    local db = Mrgl.db
    local f = db.autoFailDps[Bo.NextStage()]
    if f == nil then
      return false
    end
    return Cb().SquadDPS() < f * B().AUTO_RETRY_DPS
  end
  Bo.AutoState = function()
    local db = Mrgl.db
    local rt = C.rt
    if not Cb().GateOpen() then
      return { state = "none", left = 0 }
    end
    if not db.settings.autofight then
      return { state = "off", left = 0 }
    end
    local rd = Bo.Ready()
    if rd ~= "green" and not (rd == "greenAbil" and Mrgl.Core.Tide.AutoCastOn()) then
      return { state = "none", left = 0 }
    end
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
    if not Cb().GateOpen() or (rt.inCombat and auto == true) then
      return false
    end
    if rt.tideVeil == true then
      return false
    end
    local bs = db.stage + 1
    db.stage = bs
    if bs > db.maxStage then
      db.maxStage = bs
    end
    if bs > db.prestige.best then
      db.prestige.best = bs
    end
    db.boss.active = true
    db.boss.auto = auto
    db.boss.max = Bo.Timer()
    db.boss.time = db.boss.max
    db.enemyHp = F().EnemyHP(bs)
    Cb().NewLife()
    db.enemyRare = false
    rt.respawn = 0
    rt.queued = 0
    rt.autoT = 0
    rt.bossSec = math.ceil(db.boss.time)
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
    db.boss.resetStage = 0
    db.autoFailDps[bs] = nil
    C.Fire("BOSS_WIN", { stage = bs, name = e.name, gold = gold })
    local tr = db.prestige.trophies
    if F().ZoneIndex(bs) == 11 and F().IsZoneBoss(bs) and tr.nef ~= true then
      tr.nef = true
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
    db.autoFailDps[bs] = math.max(Cb().SquadDPS(), 1e-9)
    local auto = db.boss.auto
    db.boss.lostAt = db.enemyHp / F().EnemyHP(bs)
    db.boss.lostStage = bs
    db.boss.resetStage = 0
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
  Bo.Cancel = function()
    local db = Mrgl.db
    if not db.boss.active then
      return
    end
    db.boss.active = false
    db.stage = db.stage - 1
    db.kills = B().KILLS_PER_STAGE
    db.enemyHp = F().EnemyHP(db.stage)
    Cb().NewLife()
    C.rt.gateFired = true
  end
  Bo.Step = function(dt)
    local db = Mrgl.db
    local rt = C.rt
    if db.boss.active then
      if rt.inCombat then
        return
      end
      if rt.respawn > 0 then
        return
      end
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
