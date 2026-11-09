local ADDON, Mrgl = ...
-- Mrgl Squad - Core/State.lua equivalent: new game, load/check/migrate, save (plan 1.4, 1.5).
-- SavedVariables: MrglSquadDB (account) + MrglSquadCharDB (character copy). Forever lost account
-- SVs on /reload (AzerothIdle 2.9.144), so both get a copy and the higher saveSeq wins on load.
Mrgl.Core = Mrgl.Core or {}
do
  local fix, deep, finite, fixChar
  local St = {}
  Mrgl.Core.State = St
  local U = Mrgl.U
  St.New = function(faction)
    local b = Mrgl.Data.Balance
    local fac = "alliance"
    if faction == "horde" then
      fac = "horde"
    end
    local db = {
      version = b.VERSION,
      saveSeq = 0,
      lastSeen = 0,
      faction = fac,
      gold = b.START_GOLD,
      goldEarned = 0,
      stage = 1,
      kills = 0,
      maxStage = 1,
      enemyHp = 0,
      enemyRare = false,
      rareStage = 0,
      boss = { active = false, time = 0, max = 0, auto = false, lostAt = 0, lostStage = 0, resetStage = 0 }, -- j2 A4: resetStage
      murlocs = {},
      self = { click = 0, echo = 0, crit = 0, critdmg = 0 },
      abilities = {},
      buffs = { whelps = 0, candle = 0, leeroy = 0 },
      autoFailDps = {},
      -- j1 M5: minimized
      settings = { calm = false, opener = true, autofight = b.AUTO_FIGHT_DEFAULT, scale = 1,
                   point = "", rel = "", x = 0, y = 0, panel = false, tab = 1, mode = 1, minimized = false,
                   minimap = true, minimapAngle = 200,   -- j1 #12: minimap button (addon only; the browser keeps the values)
                   hideCombat = false,   -- j2 A2: hide the window in combat; j3 M2 (Jan): default off
                   autobuy = true, autoclick = true, autocast = true },   -- New Tide C5: work once their milestone is reached
      -- one-time migrations already applied (a new game needs none)
      migr = { j3HideOff = true },   -- j3 M2: a new game starts off and needs no switch
      -- j1 W4: in-world gold statistics, and per character: highest level, zones seen, counted quests (Core/World)
      world = { quests = 0, levels = 0, zones = 0, gold = 0 },
      chars = {},
      onboarding = { firstClick = false, firstHire = false, buyShown = false, expandShown = false, bossShown = false,
                     abilitiesShown = false },
      stats = { clicks = 0, kills = 0, bosses = 0, crits = 0, rareSeen = "" },   -- enemies1 E4.1: rareSeen "zoneId:i,..."
      rng = 12345,
      -- New Tide C5: 1 point per New Tide in one path (m Murlocs, s Self-Click, a Spells); count = m + s + a; trophies stay.
      -- best = highest stage ever (kept live with maxStage, so a save/load round trip stays equal; 1 = maxStage of a new game)
      prestige = { count = 0, best = 1, last = "m", paths = { m = 0, s = 0, a = 0 }, trophies = { nef = false } },
      -- prepared for later (not in MVP): guests
      guests = {}
    }
    local list = Mrgl.Data.Murlocs
    for i = 1, U.Len(list) do
      db.murlocs[U.At(list, i).id] = { n = 0, u = 0 }
    end
    local ab = Mrgl.Data.Abilities
    for j = 1, U.Len(ab) do
      db.abilities[U.At(ab, j).id] = { readyAt = 0, used = false, unlocked = false }
    end
    db.enemyHp = Mrgl.Core.Formula.EnemyHP(1)
    return db
  end
  -- Recursively fix a loaded table against the defaults: wrong types, NaN, +-Inf, negatives -> default.
  -- Only the window offsets may be negative.
  local SIGNED = { x = true, y = true }
  local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
  -- Note: JS declared "var sub" inside the loop (function scope), so for a loaded table that LACKS a sub-table the JS
  -- kept the previous key's sub-table (e.g. murlocs = {tinyfin = {...}} filled every murloc with tinyfin's values).
  -- Lua keeps one "sub" per key (each missing table gets its defaults). Saves the addon writes always hold every key,
  -- so both give the same result for them (golden 4.2a checks complete broken tables). See docs/port-work/helper-core.md.
  function fix(t, def)
    local out = {}
    for k, d in pairs(def) do   -- order does not matter
      local v
      if t ~= nil then
        v = t[k]
      end
      out[k] = d -- r2 W10: plain ifs, no "a and b or c" with booleans in Lua
      if type(d) == "number" then
        if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and (v >= 0 or SIGNED[k] == true) then
          out[k] = v
        end
      elseif type(d) == "boolean" then
        if type(v) == "boolean" then
          out[k] = v
        end
      elseif type(d) == "string" then
        if type(v) == "string" then
          out[k] = v
        end
      elseif type(d) == "table" then
        local sub
        if U.IsTable(v) then
          sub = v
        end
        out[k] = fix(sub, d)
      end
    end
    return out
  end
  -- enemies1 E4.1: seen rares as one string "zoneId:i,..." (fix() keeps a string, a free-key table would be dropped).
  -- Keeps only keys that exist in the routes (all factions and shared, i 1-2), each once, in route order (alliance, horde,
  -- shared; per zone :1 before :2). An entry counts only as an exact comma-separated item (" westfall:2" is dropped).
  -- Idempotent: NormRares(NormRares(x)) == NormRares(x). Anything but a string -> "".
  St.NormRares = function(str)
    if type(str) ~= "string" then
      return ""
    end
    local R = Mrgl.Data.Routes
    local hay = "," .. str .. ","
    local out = ""
    local lists = { R.alliance, R.horde, R.shared }
    for l = 1, 3 do
      local zs = U.At(lists, l)
      for z = 1, U.Len(zs) do
        for i = 1, 2 do
          local key = U.At(zs, z).id .. ":" .. i
          if string.find(hay, "," .. key .. ",", 1, true) then
            if out ~= "" then
              out = out .. ","
            end
            out = out .. key
          end
        end
      end
    end
    return out
  end
  -- j1 W4: one character record of the chars map; anything broken falls back to "not seen yet" / empty
  function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
  end
  function fixChar(v)
    if not U.IsTable(v) then
      return nil
    end
    local c = { maxLevel = 0, zones = {}, qTimes = {}, qIds = {} }
    if finite(v.maxLevel) and v.maxLevel >= 1 then
      c.maxLevel = math.floor(v.maxLevel)
    end
    if U.IsTable(v.zones) then
      for z, on in pairs(v.zones) do   -- order does not matter
        -- JS object keys are strings ("1429" == 1429 there); in Lua the mapID key is a number
        local mk = tonumber(z)
        if on == true and finite(mk) then
          c.zones[mk] = true
        end
      end
    end
    if U.IsTable(v.qTimes) and U.IsTable(v.qIds) and U.Len(v.qTimes) == U.Len(v.qIds) then
      local n = U.Len(v.qTimes)
      local first = math.max(1, n - Mrgl.Data.Balance.WORLD_QUEST_MAX + 1)
      for i = first, n do
        local t = U.At(v.qTimes, i)
        local id = U.At(v.qIds, i)
        if finite(t) and t >= 0 and finite(id) and id >= 0 then
          U.Insert(c.qTimes, t)
          U.Insert(c.qIds, id)
        end
      end
    end
    return c
  end
  St.Migrate = function(raw)
    -- version 1 is the first version; later versions convert here step by step
    return raw
  end
  -- Load from both SV tables; returns a valid db (new game when nothing usable).
  St.Load = function(sv, charSv, faction)
    local raw = sv
    St.loadedFrom = "account" -- r4 W21: for /mrgl savecheck
    if U.IsTable(charSv) then
      local cs = 0
      if type(charSv.saveSeq) == "number" then
        cs = charSv.saveSeq
      end
      local as = 0
      if U.IsTable(raw) and type(raw.saveSeq) == "number" then
        as = raw.saveSeq
      end
      if not U.IsTable(raw) or cs > as then
        raw = charSv
        St.loadedFrom = "character"
      end
    end
    local def = St.New(faction)
    if not U.IsTable(raw) then
      St.loadedFrom = "new"
      return def
    end
    raw = St.Migrate(raw)
    -- j3 M2: an old save's hideCombat = true was only the old default; it is switched off once, then never again
    local hideOff = not (U.IsTable(raw.migr) and raw.migr.j3HideOff == true)
    local db = fix(raw, def)
    if hideOff then
      db.settings.hideCombat = false
    end
    db.migr.j3HideOff = true
    db.version = Mrgl.Data.Balance.VERSION
    -- dynamic map: autoFailDps[stage] = dps
    db.autoFailDps = {}
    if U.IsTable(raw.autoFailDps) then
      for k, v in pairs(raw.autoFailDps) do   -- order does not matter
        -- JS object keys are strings ("35" == 35 there); in Lua the stage key is a number
        if type(k) == "string" and tonumber(k) ~= nil then
          k = tonumber(k)
        end
        if type(v) == "number" and v == v and v > 0 and v ~= math.huge then
          db.autoFailDps[k] = v
        end
      end
    end
    -- j2 A3: old saves may hold settings.sound and migr.j1Sound; fix() keeps only default keys, so both are dropped
    -- j1 W4 dynamic map: chars["Name-Realm"] = { maxLevel, zones, qTimes, qIds } (Core/World)
    db.chars = {}
    if U.IsTable(raw.chars) then
      for ck, v in pairs(raw.chars) do   -- order does not matter
        local cv = fixChar(v)
        if type(ck) == "string" and ck ~= "" and cv ~= nil then
          db.chars[ck] = cv
        end
      end
    end
    -- consistency
    local b = Mrgl.Data.Balance
    db.stage = math.max(1, math.floor(db.stage))
    db.maxStage = math.max(db.stage, math.floor(db.maxStage))
    db.kills = U.Clamp(math.floor(db.kills), 0, b.KILLS_PER_STAGE)
    db.settings.scale = U.Clamp(db.settings.scale, b.SCALE_MIN, b.SCALE_MAX)
    -- port p2 (review p1 Lua S2): tab and mode are list indices, whole numbers before the range check (2.5 broke the
    -- panel); scale, x and y may be fractional
    db.settings.tab = math.floor(db.settings.tab)
    db.settings.mode = math.floor(db.settings.mode)
    if db.settings.tab < 1 or db.settings.tab > 4 then   -- New Tide R1: tab 4
      db.settings.tab = 1
    end
    if db.settings.mode < 1 or db.settings.mode > 3 then
      db.settings.mode = 1
    end
    if db.faction ~= "horde" then
      db.faction = "alliance"
    end
    local s = db.settings
    if POINTS[s.point] ~= true or POINTS[s.rel] ~= true then
      s.point = ""
      s.rel = ""
      s.x = 0
      s.y = 0
    end
    -- counts and ranks: whole numbers within their caps; cooldowns never longer than the ability cooldown
    local ml = Mrgl.Data.Murlocs
    for i = 1, U.Len(ml) do
      local m = db.murlocs[U.At(ml, i).id]
      m.n = math.floor(m.n)
      m.u = U.Clamp(math.floor(m.u), 0, 3)
    end
    local sl = Mrgl.Data.Self
    for j = 1, U.Len(sl) do
      local sd = U.At(sl, j)
      local cap = Mrgl.Core.Formula.SelfMax(sd.id)
      db.self[sd.id] = math.floor(db.self[sd.id])
      if cap > 0 and db.self[sd.id] > cap then
        db.self[sd.id] = cap
      end
    end
    local F = Mrgl.Core.Formula
    if db.boss.active and not F.IsBoss(db.stage) then
      db.boss.active = false
    end
    if not db.boss.active and F.IsBoss(db.stage) then
      -- saved mid-fight without the flag: back to the gate
      db.stage = db.stage - 1
      db.kills = b.KILLS_PER_STAGE
    end
    local maxHp = F.EnemyHP(db.stage)
    if not (db.enemyHp > 0) or db.enemyHp > maxHp then
      db.enemyHp = maxHp
    end
    -- New Tide C5: fix() kept only the default keys (old prestige.points, draft keys free/stageAt are dropped); whole points,
    -- count always m + s + a, last a path id, best at least maxStage
    local pr = db.prestige
    pr.paths.m = math.floor(pr.paths.m); pr.paths.s = math.floor(pr.paths.s); pr.paths.a = math.floor(pr.paths.a)
    -- tide1c K1: 1 point per New Tide; absurd values from a broken save are capped
    pr.paths.m = math.min(pr.paths.m, 10000); pr.paths.s = math.min(pr.paths.s, 10000); pr.paths.a = math.min(pr.paths.a, 10000)
    pr.count = pr.paths.m + pr.paths.s + pr.paths.a
    if pr.last ~= "m" and pr.last ~= "s" and pr.last ~= "a" then
      pr.last = "m"
    end
    pr.best = math.max(math.floor(pr.best), db.maxStage)
    db.stats.rareSeen = St.NormRares(db.stats.rareSeen) -- enemies1 E4.1 (old saves: "" through fix())
    return db
  end
  function deep(t)
    if not U.IsTable(t) then
      return t
    end
    local c = {}
    for k, v in pairs(t) do   -- order does not matter
      c[k] = deep(v)
    end
    return c
  end
  St.Copy = deep
  -- Returns {account, character} tables to assign to the SavedVariables globals.
  St.Save = function()
    local db = Mrgl.db
    db.saveSeq = db.saveSeq + 1
    db.lastSeen = Mrgl.Core.Now()
    return { account = db, character = deep(db) }
  end
end
