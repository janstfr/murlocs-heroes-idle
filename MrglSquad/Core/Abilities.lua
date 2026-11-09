local ADDON, Mrgl = ...
Mrgl.Core = Mrgl.Core or {}
do
  local F, B, Cb, leeroyHit
  local A = {}
  Mrgl.Core.Abilities = A
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
  A.Def = function(id)
    local l = Mrgl.Data.Abilities
    for i = 1, U.Len(l) do
      if U.At(l, i).id == id then
        return U.At(l, i)
      end
    end
    return nil
  end
  A.Slot = function(id)
    local l = Mrgl.Data.Abilities
    for i = 1, U.Len(l) do
      if U.At(l, i).id == id then
        return i
      end
    end
    return 0
  end
  A.Power = function(key)
    local T = Mrgl.Core.Tide
    local v = B()[key]
    if key == "MRGL_DPS_SEC" and T.Has("a", 50) then
      v = B().TIDE_ANYFIN_SEC
    end
    return v * T.SpellMult()
  end
  A.BuffDur = function(id)
    return A.Def(id).dur * Mrgl.Core.Tide.BuffMult()
  end
  A.Look = function(id)
    local d = A.Def(id)
    if d ~= nil and d.alt ~= nil and Mrgl.Core.Tide.Has("a", 50) then
      return d.alt
    end
    return d
  end
  A.Unlocked = function(id)
    return Mrgl.db.abilities[id].unlocked
  end
  A.AnyUnlocked = function()
    local l = Mrgl.Data.Abilities
    for i = 1, U.Len(l) do
      if A.Unlocked(U.At(l, i).id) then
        return true
      end
    end
    return false
  end
  A.Remaining = function(id)
    return math.max(0, Mrgl.db.abilities[id].readyAt - C.Now())
  end
  A.IsReady = function(id)
    return A.Unlocked(id) and A.Remaining(id) <= 0
  end
  A.BuffLeft = function(id)
    local b = Mrgl.db.buffs[id]
    if b == nil then
      return 0
    end
    return math.max(0, b - C.Now())
  end
  A.CheckUnlock = function()
    local db = Mrgl.db
    local l = Mrgl.Data.Abilities
    for i = 1, U.Len(l) do
      local d = U.At(l, i)
      local st = db.abilities[d.id]
      if not st.unlocked and db.maxStage >= d.stage then
        st.unlocked = true
        st.readyAt = 0
        C.Fire("ABILITY_UNLOCK", { id = d.id, slot = i, first = i == 1 })
      end
    end
  end
  A.Use = function(id, fromOpener, auto)
    local db = Mrgl.db
    if not A.IsReady(id) then
      return false
    end
    if db.boss.active and C.rt.inCombat then
      return false
    end
    local d = A.Def(id)
    local st = db.abilities[id]
    st.readyAt = C.Now() + d.cd
    st.used = true
    local up = { id = id, slot = A.Slot(id), opener = fromOpener == true }
    if auto == true then
      up.auto = true
    end
    C.Fire("ABILITY_USE", up)
    local dps = Cb().SquadDPS()
    local b = B()
    if id == "mrgl" then
      Cb().EnsureEnemy()
      local click = Cb().ClickDamage()
      local crit = U.Rand() < Cb().CritChance("mrgl")
      if crit then
        click = click * F().CritMult(db.self)
      end
      Cb().Hit(click + A.Power("MRGL_DPS_SEC") * dps, "mrgl", crit, 1)
    elseif id == "whelps" then
      db.buffs.whelps = C.Now() + A.BuffDur(id)
      C.rt.whelpAcc = 0
    elseif id == "candle" then
      db.buffs.candle = C.Now() + A.BuffDur(id)
    elseif id == "leeroy" then
      C.rt.leeroyHit = b.LEEROY_DELAY
      C.rt.leeroyLine = b.LEEROY_HEADLINE
      db.buffs.leeroy = C.Now() + A.BuffDur(id)
    end
    return true
  end
  A.QueueOpener = function()
    local rt = C.rt
    rt.opener = {}
    local order = Mrgl.Data.OpenerOrder
    for i = 1, U.Len(order) do
      local id = U.At(order, i)
      if A.IsReady(id) then
        U.Insert(rt.opener, id)
      end
    end
    rt.openerT = 0
  end
  A.OpenerReady = function()
    local order = Mrgl.Data.OpenerOrder
    for i = 1, U.Len(order) do
      if A.IsReady(U.At(order, i)) then
        return true
      end
    end
    return false
  end
  function leeroyHit()
    local db = Mrgl.db
    local b = B()
    Cb().EnsureEnemy()
    local amount = A.Power("LEEROY_CLICKS") * Cb().ClickDamage() * F().CritMult(db.self) + A.Power("LEEROY_DPS_SEC") * Cb().SquadDPS()
    Cb().Hit(amount, "leeroy", true, b.LEEROY_GOLD)
  end
  A.Step = function(dt)
    local db = Mrgl.db
    local rt = C.rt
    if rt.inCombat and db.boss.active then
      for k, v in pairs(db.buffs) do
        if v > 0 then
          db.buffs[k] = v + dt
        end
      end
      return
    end
    if rt.leeroyLine > 0 then
      rt.leeroyLine = math.max(0, rt.leeroyLine - dt)
    end
    if rt.leeroyHit > 0 then
      rt.leeroyHit = rt.leeroyHit - dt
      if rt.leeroyHit <= 1e-9 then
        rt.leeroyHit = 0
        leeroyHit()
      end
    end
    if U.Len(rt.opener) > 0 then
      rt.openerT = rt.openerT - dt
      while U.Len(rt.opener) > 0 and rt.openerT <= 1e-9 do
        local id = U.Remove(rt.opener, 1)
        if db.boss.active then
          A.Use(id, true)
        end
        rt.openerT = rt.openerT + B().OPENER_GAP
      end
    end
    if db.buffs.whelps > 0 then
      if C.Now() < db.buffs.whelps then
        rt.whelpAcc = rt.whelpAcc + A.Power("WHELPS_CPS") * dt
        if rt.quiet == true then
          local wn = math.floor(rt.whelpAcc + 1e-9)
          rt.whelpAcc = rt.whelpAcc - wn
          if wn > 0 then
            Cb().WhelpBurst(wn)
          end
        else
          local wl = 0
          while rt.whelpAcc >= 1 - 1e-9 do
            rt.whelpAcc = rt.whelpAcc - 1
            wl = wl + 1
          end
          if wl > 0 then
            Cb().WhelpBurst(wl)
          end
        end
      else
        db.buffs.whelps = 0
        C.Fire("BUFF_END", { id = "whelps" })
      end
    end
    if db.buffs.candle > 0 and C.Now() >= db.buffs.candle then
      db.buffs.candle = 0
      C.Fire("BUFF_END", { id = "candle" })
    end
    if db.buffs.leeroy > 0 and C.Now() >= db.buffs.leeroy then
      db.buffs.leeroy = 0
      C.Fire("BUFF_END", { id = "leeroy" })
    end
    local l = Mrgl.Data.Abilities
    for i = 1, U.Len(l) do
      local d = U.At(l, i)
      local st = db.abilities[d.id]
      if st.unlocked and st.readyAt > 0 and C.Now() >= st.readyAt then
        st.readyAt = 0
        C.Fire("ABILITY_READY", { id = d.id, slot = i })
      end
    end
  end
end
