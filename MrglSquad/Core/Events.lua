local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Events.lua equivalent: callback table On/Fire (plan 1.3 #11) and runtime state.
-- Event names: HIT, CRIT, KILL, SPAWN, RARE_SPAWN, STAGE, ZONE, GATE_OPEN, BOSS_START, BOSS_TICK, BOSS_WIN,
-- BOSS_FAIL, BUY, MILESTONE, UPGRADE, SELF_UP, ABILITY_USE, ABILITY_READY, ABILITY_UNLOCK, BUFF_END, GOLD,
-- OFFLINE, COMBAT, CATCHUP, SAVE, WORLD_BONUS (j1, Core/World), TIDE, TROPHY (New Tide, Core/Tide + Boss.Win).
Mrgl.Core = Mrgl.Core or {}
do
  local C = Mrgl.Core
  local handlers = {}
  C.On = function(name, fn)
    local l = handlers[name]
    if l == nil then
      l = {}
      handlers[name] = l
    end
    Mrgl.U.Insert(l, fn)
  end
  C.ClearHandlers = function()
    handlers = {}
  end
  -- In catch-up (Advance) only state events reach the UI, no juice.
  local QUIET_PASS = { STAGE = true, ZONE = true, ABILITY_UNLOCK = true, SAVE = true, CATCHUP = true, COMBAT = true, OFFLINE = true,
                       TROPHY = true }   -- New Tide T: the trophy also counts in catch-up (tab dot, no headline)
  C.Fire = function(name, payload)
    if C.rt.silent == true then
      return
    end
    if C.rt.quiet and QUIET_PASS[name] ~= true then
      return
    end
    local l = handlers[name]
    if l == nil then
      return
    end
    local i = 1
    while i <= Mrgl.U.Len(l) do   -- JS re-reads the length each pass (a handler may add one)
      Mrgl.U.At(l, i)(payload)
      i = i + 1
    end
  end
  -- Runtime state (not saved). Reset on every load.
  C.NewRuntime = function(now)
    local buckets = {}
    for i = 1, Mrgl.Data.Balance.CLICK_WINDOW do
      Mrgl.U.Insert(buckets, 0)
    end
    return {
      clock = now,          -- game clock in server seconds, advanced by Step
      acc = 0,              -- unprocessed seconds for the fixed tick
      respawn = 0,          -- seconds until the next enemy appears
      queued = 0,           -- clicks stored during respawn
      buckets = buckets,    -- clicks per second, last 30 s
      bucketSec = math.floor(now),
      autoT = 0,            -- auto-fight countdown
      inCombat = false,
      popup = false,
      quiet = false,
      opener = {},          -- queued ability ids for the boss opener
      openerT = 0,
      whelpAcc = 0,
      squadDealt = 0,       -- squad damage since the UI last asked
      combatGold = 0,
      bossSec = 0,
      gateFired = false,
      leeroyHit = 0,        -- seconds until the delayed LEEROY hit lands (0 = none)
      leeroyLine = 0,       -- seconds left of the LEEROY headline
      silent = false,       -- no events at all (Best Buy chain simulation)
      chain = false,        -- a Buy best chain is being bought
      bestDirty = true,     -- W8: Best Buy needs a recalculation
      -- New Tide C4 automation (Core/Tide)
      autoClickAcc = 0,     -- auto-click accumulator (Self-Click 10/100)
      castSec = math.floor(now),   -- last whole game second of auto-cast
      autoBuyT = math.floor(now / Mrgl.Data.Balance.TIDE_AUTOBUY_SEC),   -- last auto-buy slot
      autoBuy = false,      -- Shop.BuyBest(true) is buying: BUY/UPGRADE/SELF_UP/MILESTONE/BUY_CHAIN carry auto = true
      queueKinds = {},      -- tide1c C2: hit kind per queued click (slots 1..queued)
      tideVeil = false,     -- tide1c C7: the tide popup or moment is up (set by the UI): no boss start
      enemyAge = 0,         -- j5 K5: seconds the current enemy has lived (Combat.Squad), see Combat.Damage
      enemyBank = 0,        -- j5 K5: damage held by the MIN_LIFE floor
      killSet = false,      -- j5 K5: the killer of the current enemy is known (killGold, killKind)
      killGold = 1,
      killKind = nil
    }
  end
  C.rt = C.NewRuntime(0)
  C.Now = function()
    return C.rt.clock
  end
end
