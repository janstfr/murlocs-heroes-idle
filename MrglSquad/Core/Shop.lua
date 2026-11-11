local ADDON, Mrgl = ...
Mrgl.Core = Mrgl.Core or {}
do
  local F, B, applyCand, evalCand, rankPull, waitFor, itemName, calcChain
  local Sh = {}
  Mrgl.Core.Shop = Sh
  local C = Mrgl.Core
  local U = Mrgl.U
  function F()
    return Mrgl.Core.Formula
  end
  function B()
    return Mrgl.Data.Balance
  end
  Sh.MODE_X1 = 1
  Sh.MODE_NEXT = 2
  Sh.MODE_MAX = 3
  Sh.Count = function()
    return U.Len(Mrgl.Data.Murlocs)
  end
  Sh.Hired = function(i)
    return Mrgl.db.murlocs[F().Murloc(i).id].n
  end
  Sh.NextRank = function()
    for i = 1, Sh.Count() do
      if Sh.Hired(i) <= 0 then
        return i
      end
    end
    return 0
  end
  Sh.Amount = function(i, mode)
    local n = Sh.Hired(i)
    if mode == Sh.MODE_NEXT then
      return F().NextMilestone(n) - n
    end
    if mode == Sh.MODE_MAX then
      return math.max(1, F().MaxAfford(i, n, Mrgl.db.gold))
    end
    return 1
  end
  Sh.Price = function(i, k)
    return F().Bundle(i, Sh.Hired(i), k)
  end
  local function tag(p)
    if C.rt.autoBuy == true then
      p.auto = true
    end
    return p
  end
  Sh.Hire = function(id, k)
    local db = Mrgl.db
    local i = F().MurlocIndex(id)
    if i <= 0 or type(k) ~= "number" or not (k >= 1) then
      return false
    end
    local cost = Sh.Price(i, k)
    if db.gold < cost then
      return false
    end
    local e = db.murlocs[id]
    local before = e.n
    db.gold = db.gold - cost
    e.n = e.n + k
    db.onboarding.firstHire = true
    Sh.Dirty()
    C.Fire("BUY", tag({ kind = "hire", id = id, amount = k, n = e.n, first = before == 0, slot = i }))
    if F().Milestones(e.n) > F().Milestones(before) then
      C.Fire("MILESTONE", tag({ id = id, n = e.n, slot = i }))
    end
    return true
  end
  Sh.UpgradeUnlocked = function(i)
    local e = Mrgl.db.murlocs[F().Murloc(i).id]
    return e.u < F().UpgradeMax(i) and e.n >= F().UpgradeReq(i, e.u + 1)
  end
  Sh.BuyUpgrade = function(id)
    local db = Mrgl.db
    local i = F().MurlocIndex(id)
    if i <= 0 or not Sh.UpgradeUnlocked(i) then
      return false
    end
    local e = db.murlocs[id]
    local cost = F().UpgradeCost(i, e.u + 1)
    if db.gold < cost then
      return false
    end
    db.gold = db.gold - cost
    e.u = e.u + 1
    Sh.Dirty()
    C.Fire("UPGRADE", tag({ id = id, tier = e.u, slot = i }))
    return true
  end
  Sh.SelfVisible = function(id)
    local db = Mrgl.db
    if id == "click" or id == "echo" then
      return db.onboarding.firstHire
    end
    return db.maxStage >= B().SELF_CRIT_STAGE
  end
  Sh.BuySelf = function(id, k)
    local db = Mrgl.db
    local r = db.self[id]
    local n = 1
    if k ~= nil then
      n = k
    end
    if not (n >= 1) or not Sh.SelfVisible(id) or F().SelfMaxed(id, r + n - 1) then
      return false
    end
    local cost = F().SelfCost(id, r)
    if n > 1 then
      cost = Sh.RankPrice("self", id, n)
    end
    if db.gold < cost then
      return false
    end
    db.gold = db.gold - cost
    db.self[id] = r + n
    Sh.Dirty()
    C.Fire("SELF_UP", tag({ id = id, rank = r + n }))
    return true
  end
  Sh.SelfValue = function(id, r)
    local b = B()
    if id == "click" then
      return F().ClickBase({ click = r })
    end
    if id == "echo" then
      return math.floor(b.ECHO_STEP * r * 100 + 0.5)
    end
    if id == "crit" then
      return math.floor((b.CRIT_BASE + b.CRIT_STEP * r) * 100 + 0.5)
    end
    return b.CRITM_BASE + b.CRITM_STEP * r
  end
  Sh.SpellsOpen = function()
    return Mrgl.db.prestige.count >= 1 or Mrgl.Core.Tide.Total() >= 1
  end
  Sh.SpellVisible = function(id)
    return Sh.SpellsOpen() and Mrgl.Core.Abilities.Unlocked(id)
  end
  Sh.BuySpell = function(id, k)
    local db = Mrgl.db
    local n = 1
    if k ~= nil then
      n = k
    end
    if not (n >= 1) or Mrgl.Core.Abilities.Def(id) == nil or not Sh.SpellVisible(id) then
      return false
    end
    local r = db.spells[id]
    local cost = F().SpellCost(id, r)
    if n > 1 then
      cost = Sh.RankPrice("spell", id, n)
    end
    if db.gold < cost then
      return false
    end
    db.gold = db.gold - cost
    db.spells[id] = r + n
    Sh.Dirty()
    C.Fire("SPELL_UP", tag({ id = id, rank = r + n, slot = Mrgl.Core.Abilities.Slot(id) }))
    return true
  end
  local RANK_LIMIT = 10000
  local function rankNow(kind, id)
    if kind == "self" then
      return Mrgl.db.self[id]
    end
    return Mrgl.db.spells[id]
  end
  local function rankCost(kind, id, r)
    if kind == "self" then
      return F().SelfCost(id, r)
    end
    return F().SpellCost(id, r)
  end
  local function rankRoom(kind, id, r)
    if kind ~= "self" then
      return RANK_LIMIT
    end
    local mx = F().SelfMax(id)
    if mx <= 0 then
      return RANK_LIMIT
    end
    return math.max(0, mx - r)
  end
  Sh.RankPrice = function(kind, id, k)
    local r = rankNow(kind, id)
    local sum = 0
    for j = 0, k - 1 do
      sum = sum + rankCost(kind, id, r + j)
    end
    return sum
  end
  Sh.RankAmount = function(kind, id, mode)
    local r = rankNow(kind, id)
    local room = rankRoom(kind, id, r)
    if room <= 0 then
      return 1
    end
    if mode == Sh.MODE_NEXT then
      return math.min(room, 10 - r % 10)
    end
    if mode ~= Sh.MODE_MAX then
      return 1
    end
    local gold = Mrgl.db.gold
    local k, sum = 0, 0
    while k < room do
      sum = sum + rankCost(kind, id, r + k)
      if not (sum <= gold) then
        break
      end
      k = k + 1
    end
    return math.max(1, k)
  end
  Sh.ClickFactor = function()
    return math.min(B().BESTBUY_CLICK_CAP, B().BESTBUY_CLICK_SHARE * Mrgl.Core.Combat.ClickRate() + Mrgl.Core.Tide.AutoSwing())
  end
  function applyCand(cand)
    local db = Mrgl.db
    local M = db.murlocs
    local S = db.self
    local Sp = db.spells
    if cand.kind == "spell" then
      Sp = U.Copy(Sp)
      Sp[cand.id] = Sp[cand.id] + 1
    elseif cand.kind == "hire" then
      M = U.Copy(M)
      M[cand.id] = { n = db.murlocs[cand.id].n + cand.amount, u = db.murlocs[cand.id].u }
    elseif cand.kind == "upgrade" then
      M = U.Copy(M)
      M[cand.id] = { n = db.murlocs[cand.id].n, u = db.murlocs[cand.id].u + 1 }
    else
      S = U.Copy(S)
      S[cand.id] = S[cand.id] + 1
    end
    return { M = M, S = S, Sp = Sp }
  end
  function evalCand(cand, c)
    local a = applyCand(cand)
    return F().EffDPS(a.M, a.S, c, a.Sp)
  end
  Sh.NextJump = function()
    local db = Mrgl.db
    local Bo = Mrgl.Core.Boss
    local bs = Bo.NextStage()
    local R = Bo.ReadySet()
    local base = F().Strength(db.murlocs, db.self, bs, R)
    local cands = Sh.Candidates()
    local best
    local bestD = 0
    for i = 1, U.Len(cands) do
      local cand = U.At(cands, i)
      local ok = cand.cost <= db.gold
      if not ok then
        local wt = waitFor(cand.cost)
        ok = wt >= 0 and wt <= B().NEXTJUMP_SEC
      end
      if ok then
        local a = applyCand(cand)
        local d = F().Strength(a.M, a.S, bs, R, a.Sp) - base
        if d > bestD then
          bestD = d
          best = cand
        end
      end
    end
    if best == nil or bestD < B().NEXTJUMP_MIN then
      return nil
    end
    local to = 0
    if best.kind == "hire" then
      to = db.murlocs[best.id].n + best.amount
    end
    return { kind = best.kind, id = best.id, slot = best.slot, tier = best.tier, amount = best.amount, to = to, name = itemName(best), pct = 100 * bestD }
  end
  Sh.Candidates = function()
    local db = Mrgl.db
    local out = {}
    local nextR = Sh.NextRank()
    for i = 1, Sh.Count() do
      local m = F().Murloc(i)
      local n = db.murlocs[m.id].n
      if n > 0 or i == nextR then
        U.Insert(out, { kind = "hire", id = m.id, slot = i, amount = 1, cost = Sh.Price(i, 1) })
        local toMs = F().NextMilestone(n) - n
        if toMs > 1 then
          U.Insert(out, { kind = "hire", id = m.id, slot = i, amount = toMs, cost = Sh.Price(i, toMs) })
        end
      end
      if Sh.UpgradeUnlocked(i) then
        local t = db.murlocs[m.id].u + 1
        U.Insert(out, { kind = "upgrade", id = m.id, slot = i, tier = t, amount = 1, cost = F().UpgradeCost(i, t) })
      end
    end
    local sl = Mrgl.Data.Self
    for j = 1, U.Len(sl) do
      local id = U.At(sl, j).id
      if Sh.SelfVisible(id) and not F().SelfMaxed(id, db.self[id]) then
        U.Insert(out, { kind = "self", id = id, slot = j, amount = 1, cost = F().SelfCost(id, db.self[id]) })
      end
    end
    if Sh.SpellsOpen() then
      local al = Mrgl.Data.Abilities
      for a = 1, U.Len(al) do
        local aid = U.At(al, a).id
        if Mrgl.Core.Abilities.Unlocked(aid) then
          U.Insert(out, { kind = "spell", id = aid, slot = a, amount = 1, cost = F().SpellCost(aid, db.spells[aid]) })
        end
      end
    end
    return out
  end
  Sh.GoldRate = function(c)
    local db = Mrgl.db
    local cps = c
    if c == nil then
      cps = Mrgl.Core.Combat.ClickRate()
    end
    return F().GoldRate(db.murlocs, db.self, Mrgl.Core.Combat.FarmStage(), cps)
  end
  Sh.BestBuy = function()
    local db = Mrgl.db
    local b = B()
    if not db.onboarding.firstHire then
      local first = { kind = "hire", id = "tinyfin", slot = 1, amount = 1, cost = Sh.Price(1, 1), gain = 100, isNew = true }
      first.affordable = db.gold >= first.cost
      first.wait = 0
      if not first.affordable then
        first.wait = waitFor(first.cost)
      end
      return first
    end
    local c = Sh.ClickFactor()
    local base = F().EffDPS(db.murlocs, db.self, c)
    local cands = Sh.Candidates()
    local best, bestAff
    local nextR = Sh.NextRank()
    local newRank
    for i = 1, U.Len(cands) do
      local cand = U.At(cands, i)
      local after = evalCand(cand, c)
      local gain = after - base
      local pct = 100
      if base > 0 then
        pct = 100 * (after / base - 1)
      end
      if cand.kind == "hire" and cand.slot == nextR and cand.amount == 1 then
        cand.after = after
        newRank = cand
      end
      if gain > 0 and cand.cost > 0 and pct >= b.BESTBUY_MIN_GAIN then
        cand.score = gain / cand.cost
        cand.after = after
        if best == nil or cand.score > best.score then
          best = cand
        end
        if cand.cost <= db.gold and (bestAff == nil or cand.score > bestAff.score) then
          bestAff = cand
        end
      end
    end
    local target
    if newRank ~= nil and nextR > 1 and Mrgl.Core.Tide.Total() == 0 and newRank.cost <= db.gold + b.NEWRANK_SEC * Sh.GoldRate() then
      target = newRank
      target.isNew = true
    else
      if best == nil then
        return nil
      end
      target = best
      local saveFor = best.cost > db.gold and waitFor(best.cost) >= 0 and waitFor(best.cost) <= b.BESTBUY_SAVE_SEC
      if not saveFor and bestAff ~= nil and bestAff.score >= b.BESTBUY_MIN_SHARE * best.score then
        target = bestAff
      end
      if target.kind == "hire" and target.amount > 1 and target.cost > db.gold then
        for j = 1, U.Len(cands) do
          local one = U.At(cands, j)
          if one.kind == "hire" and one.id == target.id and one.amount == 1 and one.after ~= nil then
            target = one
            break
          end
        end
      end
      target.isNew = false
      local pulled = rankPull(cands, target)
      if pulled ~= nil then
        target = pulled
      end
    end
    target.gain = 100
    if base > 0 then
      target.gain = 100 * (target.after / base - 1)
    end
    target.affordable = target.cost <= db.gold
    target.wait = 0
    if not target.affordable then
      target.wait = waitFor(target.cost)
    end
    return target
  end
  function rankPull(cands, target)
    local db = Mrgl.db
    if target.score == nil then
      return nil
    end
    for i = 1, Sh.Count() do
      local id = F().Murloc(i).id
      local n = db.murlocs[id].n
      if n >= 1 and n < 10 then
        local bundle, single
        for j = 1, U.Len(cands) do
          local c = U.At(cands, j)
          if c.kind == "hire" and c.id == id and c.amount == 10 - n then
            bundle = c
          end
          if c.kind == "hire" and c.id == id and c.amount == 1 then
            single = c
          end
        end
        if bundle ~= nil and bundle.score ~= nil and B().RANKPULL * bundle.score >= target.score then
          if bundle.cost <= db.gold then
            return bundle
          end
          if single ~= nil and single.after ~= nil and single.cost <= db.gold then
            return single
          end
          return nil
        end
      end
    end
    return nil
  end
  function waitFor(cost)
    local r = Sh.GoldRate()
    if not (r > 0) then
      return -1
    end
    return math.max(0, (cost - Mrgl.db.gold) / r)
  end
  Sh.WaitFor = waitFor
  function itemName(t)
    if t.kind == "hire" then
      return F().Murloc(t.slot).name
    end
    if t.kind == "upgrade" then
      return U.At(F().Murloc(t.slot).upgrades, t.tier).name
    end
    if t.kind == "spell" then
      return Mrgl.Core.Abilities.Look(t.id).name
    end
    return U.At(Mrgl.Data.Self, t.slot).name
  end
  function calcChain()
    local real = Mrgl.db
    local rt = C.rt
    local t1 = Sh.BestBuy()
    if t1 == nil then
      return nil
    end
    local ch = { first = t1, n = 0, cost = t1.cost, gain = t1.gain, items = {}, affordable = t1.affordable, wait = t1.wait, isNew = t1.isNew }
    if not t1.affordable then
      return ch
    end
    local c = Sh.ClickFactor()
    local base = F().EffDPS(real.murlocs, real.self, c, real.spells)
    local copy = Mrgl.Core.State.Copy(real)
    local wasSilent = rt.silent
    rt.silent = true
    Mrgl.db = copy
    local cost = 0
    local n = 0
    local t = t1
    while t ~= nil and t.affordable and n < B().BUYBEST_CHAIN_MAX do
      local gold0 = copy.gold
      if not Sh.Do(t) then
        break
      end
      n = n + 1
      cost = cost + (gold0 - copy.gold)
      local nm = itemName(t)
      local last = U.At(ch.items, U.Len(ch.items))
      if last ~= nil and last.name == nm and last.kind == t.kind then
        last.count = last.count + t.amount
        last.cost = last.cost + (gold0 - copy.gold)
      else
        U.Insert(ch.items, { name = nm, kind = t.kind, slot = t.slot, count = t.amount, cost = gold0 - copy.gold })
      end
      t = Sh.BestBuy()
    end
    local after = F().EffDPS(copy.murlocs, copy.self, c, copy.spells)
    Mrgl.db = real
    rt.silent = wasSilent
    ch.n = n
    ch.cost = cost
    ch.gain = 100
    if base > 0 then
      ch.gain = 100 * (after / base - 1)
    end
    return ch
  end
  local cache = { valid = false, gold = 0, cps = 0, stage = 0, chain = nil }
  Sh.Dirty = function()
    cache.valid = false
  end
  Sh.Recalcs = 0
  Sh.Chain = function()
    local db = Mrgl.db
    local cps = Mrgl.Core.Combat.ClickRate()
    local ch = cache.chain
    local stale = not cache.valid or db.stage ~= cache.stage or math.abs(cps - cache.cps) >= 0.5 or math.abs(db.gold - cache.gold) > 0.01 * math.max(1, cache.gold)
    if not stale and ch ~= nil then
      if not ch.affordable and db.gold >= ch.first.cost then
        stale = true
      end
      if ch.affordable and db.gold < ch.first.cost then
        stale = true
      end
    end
    if stale == true then
      cache.chain = calcChain()
      cache.valid = true
      cache.gold = db.gold
      cache.cps = cps
      cache.stage = db.stage
      Sh.Recalcs = Sh.Recalcs + 1
    end
    return cache.chain
  end
  Sh.Do = function(t)
    if t == nil or not t.affordable then
      return false
    end
    if t.kind == "hire" then
      return Sh.Hire(t.id, t.amount)
    end
    if t.kind == "upgrade" then
      return Sh.BuyUpgrade(t.id)
    end
    if t.kind == "spell" then
      return Sh.BuySpell(t.id)
    end
    return Sh.BuySelf(t.id)
  end
  Sh.TopUp = function(i)
    local e = Mrgl.db.murlocs[F().Murloc(i).id]
    if e.u < 3 or e.u >= F().UpgradeMax(i) then
      return 0
    end
    return math.max(0, F().UpgradeReq(i, e.u + 1) - e.n)
  end
  local function buyCheap()
    local db = Mrgl.db
    local n = 0
    for guard = 1, 30 do
      local bi, bc, bk = 0, 0, 0
      for i = 1, Sh.Count() do
        local c, k
        if Sh.UpgradeUnlocked(i) then
          c = F().UpgradeCost(i, db.murlocs[F().Murloc(i).id].u + 1)
          if c <= B().TIDE_CHEAP_UPG * db.gold and (bi == 0 or c < bc) then
            bi = i
            bc = c
            bk = 0
          end
        else
          k = Sh.TopUp(i)
          if k > 0 then
            c = Sh.Price(i, k)
            if c <= B().TIDE_CHEAP_UPG * db.gold and (bi == 0 or c < bc) then
              bi = i
              bc = c
              bk = k
            end
          end
        end
      end
      if bi == 0 then
        break
      end
      if bk > 0 then
        if not Sh.Hire(F().Murloc(bi).id, bk) then
          break
        end
      elseif not Sh.BuyUpgrade(F().Murloc(bi).id) then
        break
      end
      n = n + 1
    end
    return n
  end
  Sh.BuyBest = function(auto)
    local rt = C.rt
    local cheap = 0
    if Mrgl.Core.Tide.Total() >= 1 then
      rt.autoBuy = auto == true
      cheap = buyCheap()
      rt.autoBuy = false
    end
    local ch = Sh.Chain()
    local k = 0
    if ch ~= nil and ch.affordable and ch.n > 0 then
      rt.chain = true
      rt.autoBuy = auto == true
      local t = Sh.BestBuy()
      while k < ch.n and t ~= nil and t.affordable do
        if not Sh.Do(t) then
          break
        end
        k = k + 1
        t = Sh.BestBuy()
      end
      rt.chain = false
    elseif cheap <= 0 then
      return false
    end
    rt.autoBuy = auto == true
    Sh.Dirty()
    C.Fire("BUY_CHAIN", tag({ n = k + cheap }))
    rt.autoBuy = false
    return k + cheap > 0
  end
end
