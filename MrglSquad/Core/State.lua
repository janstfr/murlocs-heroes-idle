local ADDON, Mrgl = ...
Mrgl.Core = Mrgl.Core or {}
do
  local fix, deep, finite, fixChar, convert
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
      boss = { active = false, time = 0, max = 0, auto = false, lostAt = 0, lostStage = 0, resetStage = 0 },
      murlocs = {},
      self = { click = 0, echo = 0, crit = 0, critdmg = 0 },
      abilities = {},
      buffs = { whelps = 0, candle = 0, leeroy = 0 },
      autoFailDps = {},
      settings = { calm = false, opener = true, autofight = b.AUTO_FIGHT_DEFAULT, scale = 1,
                   point = "", rel = "", x = 0, y = 0, panel = false, tab = 1, mode = 1, minimized = false,
                   minimap = true, minimapAngle = 200,
                   hideCombat = false,
                   autobuy = true, autoclick = true, autocast = true },
      migr = { j3HideOff = true },
      world = { quests = 0, levels = 0, zones = 0, gold = 0 },
      chars = {},
      onboarding = { firstClick = false, firstHire = false, buyShown = false, expandShown = false, bossShown = false,
                     abilitiesShown = false },
      stats = { clicks = 0, kills = 0, bosses = 0, crits = 0, rareSeen = "" },
      rng = 12345,
      prestige = { count = 0, best = 1, last = "m", paths = { m = 0, s = 0, a = 0 },
                  pts = 0, mark = 0, run = 0, dry = 0, prev = 1, recShown = false, ultimate = 0,
                  trophies = { nef = false } },
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
  local SIGNED = { x = true, y = true }
  local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
  function fix(t, def)
    local out = {}
    for k, d in pairs(def) do
      local v
      if t ~= nil then
        v = t[k]
      end
      out[k] = d
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
      for z, on in pairs(v.zones) do
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
    return raw
  end
  St.Load = function(sv, charSv, faction)
    local raw = sv
    St.loadedFrom = "account"
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
    local hideOff = not (U.IsTable(raw.migr) and raw.migr.j3HideOff == true)
    local db = fix(raw, def)
    if hideOff then
      db.settings.hideCombat = false
    end
    db.migr.j3HideOff = true
    db.version = Mrgl.Data.Balance.VERSION
    db.autoFailDps = {}
    if U.IsTable(raw.autoFailDps) then
      for k, v in pairs(raw.autoFailDps) do
        if type(k) == "string" and tonumber(k) ~= nil then
          k = tonumber(k)
        end
        if type(v) == "number" and v == v and v > 0 and v ~= math.huge then
          db.autoFailDps[k] = v
        end
      end
    end
    db.chars = {}
    if U.IsTable(raw.chars) then
      for ck, v in pairs(raw.chars) do
        local cv = fixChar(v)
        if type(ck) == "string" and ck ~= "" and cv ~= nil then
          db.chars[ck] = cv
        end
      end
    end
    local b = Mrgl.Data.Balance
    db.stage = math.max(1, math.floor(db.stage))
    db.maxStage = math.max(db.stage, math.floor(db.maxStage))
    db.kills = U.Clamp(math.floor(db.kills), 0, b.KILLS_PER_STAGE)
    db.settings.scale = U.Clamp(db.settings.scale, b.SCALE_MIN, b.SCALE_MAX)
    db.settings.tab = math.floor(db.settings.tab)
    db.settings.mode = math.floor(db.settings.mode)
    if db.settings.tab < 1 or db.settings.tab > 4 then
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
      db.stage = db.stage - 1
      db.kills = b.KILLS_PER_STAGE
    end
    local maxHp = F.EnemyHP(db.stage)
    if not (db.enemyHp > 0) or db.enemyHp > maxHp then
      db.enemyHp = maxHp
    end
    local pr = db.prestige
    pr.paths.m = math.min(math.floor(pr.paths.m), 10000)
    pr.paths.s = math.min(math.floor(pr.paths.s), 10000)
    pr.paths.a = math.min(math.floor(pr.paths.a), 10000)
    pr.pts = math.min(math.floor(pr.pts), 10000)
    pr.dry = math.min(math.floor(pr.dry), 100)
    pr.mark = math.floor(pr.mark); pr.run = math.floor(pr.run); pr.prev = math.floor(pr.prev)
    pr.count = math.max(math.floor(pr.count), pr.paths.m + pr.paths.s + pr.paths.a)
    if pr.last ~= "m" and pr.last ~= "s" and pr.last ~= "a" then
      pr.last = "m"
    end
    pr.best = math.max(math.floor(pr.best), db.maxStage)
    if not (U.IsTable(raw.prestige) and raw.prestige.mark ~= nil) then
      convert(db)
    end
    db.stats.rareSeen = St.NormRares(db.stats.rareSeen)
    local tr = pr.trophies
    local w = nil
    if U.IsTable(raw.prestige) and U.IsTable(raw.prestige.trophies) then
      w = raw.prestige.trophies.nefw
    end
    if type(w) == "string" and string.find(w, "1", 1, true) ~= nil then
      tr.nef = true
    end
    pr.ultimate = math.floor(pr.ultimate)
    return db
  end
  local ORDER = { "m", "s", "a" }
  function convert(db)
    local b = Mrgl.Data.Balance
    local pr = db.prestige
    local ps = pr.paths
    local n = 0
    pr.mark = 0
    if pr.best >= b.TIDE_STAGE then
      local k = math.floor((pr.best - b.TIDE_STAGE) / b.TIDE_STEP)
      pr.mark = b.TIDE_STAGE + b.TIDE_STEP * k
      n = 1 + k
    end
    local t = ps.m + ps.s + ps.a
    local keep = math.min(t, n)
    if keep < t then
      local q = { m = 0, s = 0, a = 0 }
      local r = { m = 0, s = 0, a = 0 }
      local left = keep
      for i = 1, 3 do
        local p = U.At(ORDER, i)
        local num = keep * ps[p]
        q[p] = math.floor(num / t)
        r[p] = num - q[p] * t
        left = left - q[p]
      end
      while left > 0 do
        local bp = ""
        for j = 1, 3 do
          local pj = U.At(ORDER, j)
          if r[pj] >= 0 and (bp == "" or r[pj] > r[bp]) then
            bp = pj
          end
        end
        q[bp] = q[bp] + 1
        r[bp] = -1
        left = left - 1
      end
      ps.m = q.m; ps.s = q.s; ps.a = q.a
    end
    pr.pts = n - keep
    local reached = db.maxStage
    if not db.boss.active and db.kills >= b.KILLS_PER_STAGE and Mrgl.Core.Formula.IsBoss(db.stage + 1) then
      reached = math.max(reached, db.stage + 1)
    end
    pr.run = 0
    if reached >= b.TIDE_STAGE then
      pr.run = math.min(pr.mark, b.TIDE_STAGE + b.TIDE_STEP * math.floor((reached - b.TIDE_STAGE) / b.TIDE_STEP))
    end
    pr.prev = pr.best
    pr.dry = 0
    pr.recShown = true
  end
  function deep(t)
    if not U.IsTable(t) then
      return t
    end
    local c = {}
    for k, v in pairs(t) do
      c[k] = deep(v)
    end
    return c
  end
  St.Copy = deep
  St.Save = function()
    local db = Mrgl.db
    db.saveSeq = db.saveSeq + 1
    db.lastSeen = Mrgl.Core.Now()
    return { account = db, character = deep(db) }
  end
end
