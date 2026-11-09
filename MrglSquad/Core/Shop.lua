local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Shop.lua equivalent: hire (x1/Next/Max), upgrades, self lines, Best Buy (plan 4.2, 4.3, 5.2).
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
  -- ------------------------------------------------------------ murlocs
  Sh.Count = function()
    return U.Len(Mrgl.Data.Murlocs)
  end
  Sh.Hired = function(i)
    return Mrgl.db.murlocs[F().Murloc(i).id].n
  end
  -- The next murloc not yet hired (0 when all are hired)
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
  -- New Tide C4: purchases of Shop.BuyBest(true) (Quartermaster) carry auto = true (the UI buys them silently)
  local function tag(p)
    if C.rt.autoBuy == true then
      p.auto = true
    end
    return p
  end
  Sh.Hire = function(id, k)
    local db = Mrgl.db
    local i = F().MurlocIndex(id)
    if i <= 0 or type(k) ~= "number" or not (k >= 1) then   -- JS: !(undefined >= 1)
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
  -- ------------------------------------------------------------ upgrades
  Sh.UpgradeUnlocked = function(i)
    local e = Mrgl.db.murlocs[F().Murloc(i).id]
    return e.u < 3 and e.n >= F().UpgradeReq(e.u + 1)
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
  -- ------------------------------------------------------------ self
  Sh.SelfVisible = function(id)
    local db = Mrgl.db
    if id == "click" or id == "echo" then
      return db.onboarding.firstHire
    end
    return db.maxStage >= B().SELF_CRIT_STAGE
  end
  Sh.BuySelf = function(id)
    local db = Mrgl.db
    local r = db.self[id]
    if not Sh.SelfVisible(id) or F().SelfMaxed(id, r) then
      return false
    end
    local cost = F().SelfCost(id, r)
    if db.gold < cost then
      return false
    end
    db.gold = db.gold - cost
    db.self[id] = r + 1
    Sh.Dirty()
    C.Fire("SELF_UP", tag({ id = id, rank = r + 1 }))
    return true
  end
  -- Display value of a self line at rank r
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
  -- ------------------------------------------------------------ Best Buy (plan 5.2)
  Sh.ClickFactor = function()
    return math.min(B().BESTBUY_CLICK_CAP, B().BESTBUY_CLICK_SHARE * Mrgl.Core.Combat.ClickRate())
  end
  -- murloc and self tables after a candidate purchase (copies only where they change)
  function applyCand(cand)
    local db = Mrgl.db
    local M = db.murlocs
    local S = db.self
    if cand.kind == "hire" then
      M = U.Copy(M)
      M[cand.id] = { n = db.murlocs[cand.id].n + cand.amount, u = db.murlocs[cand.id].u }
    elseif cand.kind == "upgrade" then
      M = U.Copy(M)
      M[cand.id] = { n = db.murlocs[cand.id].n, u = db.murlocs[cand.id].u + 1 }
    else
      S = U.Copy(S)
      S[cand.id] = S[cand.id] + 1
    end
    return { M = M, S = S }
  end
  -- effective DPS after a candidate purchase
  function evalCand(cand, c)
    local a = applyCand(cand)
    return F().EffDPS(a.M, a.S, c)
  end
  -- r4 E15: the purchase with the biggest jump in boss readiness (F.Strength, share of a sure win).
  -- Candidates: all of Sh.Candidates() (bundles up to the next milestone included) that are affordable
  -- within NEXTJUMP_SEC of income. Returns undefined below NEXTJUMP_MIN (points of strength).
  -- Result: {kind, id, slot, tier, amount, to, name, pct}
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
        local d = F().Strength(a.M, a.S, bs, R) - base
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
  -- Returns the target: {kind, id, slot, amount, cost, tier, gain (%), affordable, wait (sec), isNew}
  -- r2 E2: candidates below BESTBUY_MIN_GAIN % are dropped (undefined = nothing worth buying)
  -- r2 E3: the next murloc rank is the target as soon as it is within NEWRANK_SEC of income
  -- r2 E4: an unaffordable best target that is at most BESTBUY_SAVE_SEC away is saved for
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
    -- tide1c C5: the "New!" saving rule is run-1 onboarding only; after the first New Tide every rank is known
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
      -- A milestone bundle costs exactly the sum of its singles: while saving for one, buy the
      -- next single of that murloc (same efficiency, always one action). implementer-log #BB1
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
      -- r3 E10 rank pull: a murloc with 1-9 owned gets its bundle to 10 when that is at least 1/RANKPULL as good;
      -- affordable bundle -> bundle, else an affordable single of it, else the target stays (never save for it)
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
          return nil -- first hit counts; never save for the pull
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
    return U.At(Mrgl.Data.Self, t.slot).name
  end
  -- r2 E1: the whole chain one click buys. Simulated on a copy of the db without events.
  -- Returns undefined (nothing worth buying) or
  -- {first, n, cost, gain (%), items = [{name, kind, slot, count, cost}], affordable, wait, isNew}
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
    local base = F().EffDPS(real.murlocs, real.self, c)
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
    local after = F().EffDPS(copy.murlocs, copy.self, c)
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
  -- r2 W8: cached, recalculated only when something relevant changed
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
    -- crossing a price must show at once
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
    return Sh.BuySelf(t.id)
  end
  -- One click (or B) buys the whole chain (r2 E1). Returns true when anything was bought.
  -- auto = true: the Quartermaster (New Tide C4) buys; every event of the chain carries auto = true
  Sh.BuyBest = function(auto)
    local ch = Sh.Chain()
    if ch == nil or not ch.affordable or ch.n <= 0 then
      return false
    end
    local rt = C.rt
    rt.chain = true
    rt.autoBuy = auto == true
    local k = 0
    local t = Sh.BestBuy()
    while k < ch.n and t ~= nil and t.affordable do
      if not Sh.Do(t) then
        break
      end
      k = k + 1
      t = Sh.BestBuy()
    end
    rt.chain = false
    Sh.Dirty()
    C.Fire("BUY_CHAIN", tag({ n = k }))
    rt.autoBuy = false
    return k > 0
  end
end
