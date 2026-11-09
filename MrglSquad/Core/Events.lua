local ADDON, Mrgl = ...
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
  local QUIET_PASS = { STAGE = true, ZONE = true, ABILITY_UNLOCK = true, SAVE = true, CATCHUP = true, COMBAT = true, OFFLINE = true,
                       TROPHY = true }
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
    while i <= Mrgl.U.Len(l) do
      Mrgl.U.At(l, i)(payload)
      i = i + 1
    end
  end
  C.NewRuntime = function(now)
    local buckets = {}
    for i = 1, Mrgl.Data.Balance.CLICK_WINDOW do
      Mrgl.U.Insert(buckets, 0)
    end
    return {
      clock = now,
      acc = 0,
      respawn = 0,
      queued = 0,
      buckets = buckets,
      bucketSec = math.floor(now),
      autoT = 0,
      inCombat = false,
      popup = false,
      quiet = false,
      opener = {},
      openerT = 0,
      whelpAcc = 0,
      squadDealt = 0,
      combatGold = 0,
      bossSec = 0,
      gateFired = false,
      leeroyHit = 0,
      leeroyLine = 0,
      silent = false,
      chain = false,
      bestDirty = true,
      autoClickAcc = 0,
      castSec = math.floor(now),
      autoBuyT = math.floor(now / Mrgl.Data.Balance.TIDE_AUTOBUY_SEC),
      autoBuy = false,
      queueKinds = {},
      tideVeil = false,
      enemyAge = 0,
      enemyBank = 0,
      killSet = false,
      killGold = 1,
      killKind = nil
    }
  end
  C.rt = C.NewRuntime(0)
  C.Now = function()
    return C.rt.clock
  end
end
