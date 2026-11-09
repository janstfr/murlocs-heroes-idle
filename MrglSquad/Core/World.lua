local ADDON, Mrgl = ...
Mrgl.Core = Mrgl.Core or {}
do
  local B, num, credit
  local C = Mrgl.Core
  local W = {}
  C.World = W
  local U = Mrgl.U
  function B()
    return Mrgl.Data.Balance
  end
  function num(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
  end
  W.CharKey = function(name, realm)
    local n = "?"
    local r = "?"
    if type(name) == "string" and name ~= "" then
      n = name
    end
    if type(realm) == "string" and realm ~= "" then
      r = realm
    end
    return n .. "-" .. r
  end
  W.SeeChar = function(key, level, mapID)
    local db = Mrgl.db
    local lv = 0
    if num(level) and level >= 1 then
      lv = math.floor(level)
    end
    local rec = db.chars[key]
    if rec == nil then
      rec = { maxLevel = lv, zones = {}, qTimes = {}, qIds = {} }
      db.chars[key] = rec
      if num(mapID) then
        rec.zones[mapID] = true
      end
    elseif lv > rec.maxLevel then
      rec.maxLevel = lv
    end
    return rec
  end
  W.Amount = function(kind)
    local db = Mrgl.db
    local b = B()
    local F = C.Formula
    local s = C.Combat.FarmStage()
    local inc = F.GoldRate(db.murlocs, db.self, s, 0)
    local g1 = F.Gold(s, false, false, db.murlocs)
    local k = 0
    local sec = 0
    if kind == "quest" then
      k = b.WORLD_QUEST_KILLS
      sec = b.WORLD_QUEST_SEC
    elseif kind == "level" then
      k = b.WORLD_LEVEL_KILLS
      sec = b.WORLD_LEVEL_SEC
    elseif kind == "zone" then
      k = b.WORLD_ZONE_KILLS
      sec = b.WORLD_ZONE_SEC
    end
    return math.ceil(math.max(k * g1, sec * inc))
  end
  function credit(kind, n)
    local db = Mrgl.db
    local gold = W.Amount(kind)
    if not (gold > 0) then
      return 0
    end
    db.gold = db.gold + gold
    db.goldEarned = db.goldEarned + gold
    local w = db.world
    w.gold = w.gold + gold
    if kind == "quest" then
      w.quests = w.quests + 1
    elseif kind == "level" then
      w.levels = w.levels + 1
    else
      w.zones = w.zones + 1
    end
    C.Fire("WORLD_BONUS", { kind = kind, gold = gold, n = n })
    C.Fire("SAVE")
    return gold
  end
  W.Quest = function(key, questID, now)
    local b = B()
    local t0 = now
    if not num(t0) then
      t0 = C.Now()
    end
    local rec = W.SeeChar(key, 0)
    local id = 0
    if num(questID) and questID > 0 then
      id = questID
    end
    local keepT = {}
    local keepI = {}
    for i = 1, U.Len(rec.qTimes) do
      local t = U.At(rec.qTimes, i)
      local age = t0 - t
      if age > -b.WORLD_QUEST_WINDOW and age < b.WORLD_QUEST_WINDOW then
        U.Insert(keepT, t)
        U.Insert(keepI, U.At(rec.qIds, i))
      end
    end
    rec.qTimes = keepT
    rec.qIds = keepI
    if id > 0 then
      for j = 1, U.Len(keepT) do
        if U.At(keepI, j) == id and t0 - U.At(keepT, j) < b.WORLD_QUEST_LOCK then
          return 0
        end
      end
    end
    if U.Len(keepT) >= b.WORLD_QUEST_MAX then
      return 0
    end
    U.Insert(rec.qTimes, t0)
    U.Insert(rec.qIds, id)
    return credit("quest", 1)
  end
  W.Level = function(key, level)
    if not (num(level) and level >= 1) then
      return 0
    end
    local lv = math.floor(level)
    local rec = Mrgl.db.chars[key]
    if rec == nil or rec.maxLevel < 1 then
      W.SeeChar(key, lv)
      return 0
    end
    if lv <= rec.maxLevel then
      return 0
    end
    rec.maxLevel = lv
    return credit("level", lv)
  end
  W.Zone = function(key, mapID)
    if not num(mapID) then
      return 0
    end
    local rec = W.SeeChar(key, 0)
    if rec.zones[mapID] == true then
      return 0
    end
    local known = false
    for _ in pairs(rec.zones) do
      known = true
      break
    end
    rec.zones[mapID] = true
    if not known then
      return 0
    end
    return credit("zone", 1)
  end
end
