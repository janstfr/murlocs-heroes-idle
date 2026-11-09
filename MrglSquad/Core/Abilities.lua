local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Abilities.lua equivalent: unlock, use, buffs, boss opener (plan 4.4).
-- Cooldowns run on readyAt = server time + CD, so they also run while offline.
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
  -- New Tide C2: ability values are read with the Spells factor (Balance stays unchanged). Keys: MRGL_DPS_SEC (Anyfin Can
  -- Happen at Spells 50: TIDE_ANYFIN_SEC), LEEROY_DPS_SEC, LEEROY_CLICKS, WHELPS_CPS
  A.Power = function(key)
    local T = Mrgl.Core.Tide
    local v = B()[key]
    if key == "MRGL_DPS_SEC" and T.Has("a", 50) then
      v = B().TIDE_ANYFIN_SEC
    end
    return v * T.SpellMult()
  end
  -- buff length of whelps, candle and the LEEROY crit rush (Spells 100: x2)
  A.BuffDur = function(id)
    return A.Def(id).dur * Mrgl.Core.Tide.BuffMult()
  end
  -- look of a slot: Data.Abilities entry, or its alt (Anyfin Can Happen) once Spells 50 is reached
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
  -- auto = true: cast by War Drums (Core/Tide C4); ABILITY_USE then carries auto = true
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
      -- r2 B3: headline first, the charge lands 0.3 s later, then 10 s of crit clicks
      C.rt.leeroyHit = b.LEEROY_DELAY
      C.rt.leeroyLine = b.LEEROY_HEADLINE
      db.buffs.leeroy = C.Now() + A.BuffDur(id)
    end
    return true
  end
  -- Boss opener: ready abilities in the order Candle -> Whelps -> LEEROY -> MRGLGLGL, 0.15 s apart
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
    -- r2 B10: a boss fight frozen by WoW combat also freezes buffs and the opener (cooldowns run on)
    if rt.inCombat and db.boss.active then
      for k, v in pairs(db.buffs) do   -- order does not matter (each buff on its own)
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
    -- opener queue
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
    -- Many Whelps!: 10 automatic clicks per second
    if db.buffs.whelps > 0 then
      if C.Now() < db.buffs.whelps then
        rt.whelpAcc = rt.whelpAcc + A.Power("WHELPS_CPS") * dt
        if rt.quiet == true then
          -- tide1c C6: silent catch-up, one bundle per tick (Spells 100: ~600 whelp clicks per tick)
          local wn = math.floor(rt.whelpAcc + 1e-9)
          rt.whelpAcc = rt.whelpAcc - wn
          if wn > 0 then
            Cb().WhelpBurst(wn)
          end
        else
          -- tide1d D1 online: one bundle per tick, one HIT (no crit flash, no punch); counted with the old loop so the
          -- accumulator keeps exactly the old float steps
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
    -- ready events (no glow: only the cooldown bling in the UI)
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
