local ADDON, Mrgl = ...
Mrgl.UI = Mrgl.UI or {}
do
  local K, S, Core, F, title, line, double, w, g, exactUp, gainTok, costTok, upgEffect
  local toggleLine, nextLine, nefw
  local T = {}
  Mrgl.UI.Tips = T
  local U = Mrgl.U
  function K()
    return Mrgl.UI.Kit
  end
  function S()
    return Mrgl.Data.Strings
  end
  function Core()
    return Mrgl.Core
  end
  function F()
    return Mrgl.Core.Formula
  end
  function title(tt, text, c)
    local col = c
    if c == nil then
      col = K().C.white
    end
    tt:SetText(text, Mrgl.U.At(col, 1), Mrgl.U.At(col, 2), Mrgl.U.At(col, 3))
  end
  function line(tt, text, c, wrap)
    local col = c
    if c == nil then
      col = K().C.tipText
    end
    tt:AddLine(text, Mrgl.U.At(col, 1), Mrgl.U.At(col, 2), Mrgl.U.At(col, 3), wrap ~= false)
  end
  function double(tt, left, right, c)
    local lc = K().C.tipText
    local rc = c
    if c == nil then
      rc = K().C.white
    end
    tt:AddDoubleLine(left, right, Mrgl.U.At(lc, 1), Mrgl.U.At(lc, 2), Mrgl.U.At(lc, 3), Mrgl.U.At(rc, 1), Mrgl.U.At(rc, 2), Mrgl.U.At(rc, 3))
  end
  function w(v)
    if type(v) == "number" then
      v = U.Str(v)
    end
    return U.Color(K().C.white, v)
  end
  function g(v)
    if type(v) == "number" then
      v = U.Str(v)
    end
    return U.Color(K().C.good, v)
  end
  function exactUp(n)
    if n >= 1e6 then
      return U.ShortUp(n)
    end
    return U.Exact(math.ceil(n - 1e-7))
  end
  function gainTok(p)
    local c = K().C.good
    if U.GainLow(p) then
      c = K().C.muted
    end
    return U.Color(c, U.Gain(p))
  end
  function costTok(cost)
    local c = K().C.white
    if Mrgl.db.gold < cost then
      c = K().C.bad
    end
    return U.Color(c, exactUp(cost))
  end
  T.Title = title
  T.Line = line
  T.KeyLine = function(tt, binding)
    local k = GetBindingKey(binding)
    if k == nil or k == "" then return end
    line(tt, U.Fill(S().ABILITY_KEY, { key = k }), K().C.muted)
  end
  T.Double = double
  T.ExactUp = exactUp
  T.GainToken = gainTok
  T.Stage = function(tt)
    local db = Mrgl.db
    local Cb = Core().Combat
    title(tt, U.Fill(S().STAGE_TITLE, { s = db.stage }))
    line(tt, Cb.Zone(db.stage).name, K().C.gold)
    if db.boss.active then
      line(tt, U.Fill(S().STAGE_FIGHT, { boss = w(Cb.Enemy().name) }))
    else
      line(tt, U.Fill(S().STAGE_KILLS, { k = w(db.kills) }))
      if Cb.GateOpen() then
        line(tt, U.Fill(S().STAGE_GATE, { boss = w(Core().Boss.NextEnemy().name) }))
      end
    end
    if db.prestige.count >= 1 then
      line(tt, U.Fill(S().STAGE_TIDE, { n = db.prestige.count }), K().C.muted)
    end
    T.StageRares(tt, Cb.Zone(db.stage))
    local rc = T.RareCount()
    line(tt, U.Fill(S().STAGE_RARES, { n = U.At(rc, 1), max = U.At(rc, 2) }), K().C.muted)
    if Cb.Zone(db.stage).id == "blackwing" then
      if not T.NefThis() then
        line(tt, S().NEF_STAGE_TIP, K().C.muted)
      end
      line(tt, S().STAGE_COMING, K().C.muted)
    end
  end
  T.StageRares = function(tt, z)
    if z.rares == nil then
      return
    end
    local seen = Mrgl.db.stats.rareSeen
    if seen == nil then
      seen = ""
    end
    seen = "," .. seen .. ","
    for i = 1, U.Len(z.rares) do
      local c = K().C.muted
      if string.find(seen, "," .. z.id .. ":" .. i .. ",", 1, true) ~= nil then
        c = K().C.white
      end
      line(tt, U.Fill(S().STAGE_RARE, { name = U.At(z.rares, i).name }), c)
    end
  end
  T.RareCount = function()
    local db, Cb = Mrgl.db, Core().Combat
    local seen = db.stats.rareSeen
    if seen == nil then
      seen = ""
    end
    seen = "," .. seen .. ","
    local last = F().ZoneIndex(math.max(db.maxStage, db.prestige.best, db.stage))
    local n, all = 0, 0
    for zi = 1, last do
      local z = Cb.Route(zi)
      if z.rares ~= nil then
        for i = 1, U.Len(z.rares) do
          all = all + 1
          if string.find(seen, "," .. z.id .. ":" .. i .. ",", 1, true) ~= nil then
            n = n + 1
          end
        end
      end
    end
    return { n, all }
  end
  T.Gold = function(tt)
    title(tt, S().GOLD_TITLE)
    line(tt, U.Exact(Mrgl.db.gold), K().C.white)
    line(tt, U.Fill(S().GOLD_RATE, { rate = w(U.Exact(Core().Shop.GoldRate())) }), K().C.tipText, true)
  end
  T.EnemyLevel = function(s)
    local lv = Core().Combat.Zone(s).level
    local DASH = "–"
    local dash = string.find(lv, DASH, 1, true)
    if dash == nil then
      return lv
    end
    local lo = tonumber(string.sub(lv, 1, dash - 1))
    local hi = tonumber(string.sub(lv, dash + #DASH))
    local pos = F().Pos(s)
    return U.Str(lo + math.floor((pos - 1) * (hi - lo) / 9))
  end
  T.Enemy = function(tt)
    local db = Mrgl.db
    local Cb = Core().Combat
    local e = Cb.Enemy()
    local c = K().C.white
    local lvlTpl = S().ENEMY_LEVEL
    local rare = false
    if db.boss.active or e.kind == "boss" then
      c = K().C.boss
      lvlTpl = S().ENEMY_LEVEL_BOSS
    elseif e.kind == "rare" then
      c = K().C.rare
      lvlTpl = S().ENEMY_LEVEL_RARE
      rare = true
    elseif e.kind == "normal" and e.rank ~= nil and e.rank >= 5 then
      lvlTpl = S().ENEMY_LEVEL_ELITE
    end
    title(tt, e.name, c)
    line(tt, U.Fill(lvlTpl, { lvl = T.EnemyLevel(db.stage) }))
    if e.type ~= nil then
      line(tt, e.type, K().C.muted)
    end
    local mx = math.ceil(F().EnemyHP(db.stage))
    local hp = math.max(0, math.ceil(db.enemyHp))
    line(tt, U.Fill(S().ENEMY_HEALTH, { hp = w(U.Exact(hp)), max = w(U.Exact(mx)) }))
    local gold = U.Exact(F().Gold(db.stage, db.boss.active, db.enemyRare, db.murlocs))
    if rare then
      line(tt, U.Fill(S().ENEMY_GOLD_RARE, { gold = w(gold), m = Mrgl.Data.Balance.RARE_GOLD }))
    else
      line(tt, U.Fill(S().ENEMY_GOLD, { gold = w(gold) }))
    end
    line(tt, S().ENEMY_CLICK_GOLD, K().C.tipText, true)
    line(tt, S().ENEMY_CLICK, K().C.muted)
  end
  T.BossButton = function(tt)
    local db = Mrgl.db
    local Bo = Core().Boss
    local e = Bo.NextEnemy()
    local bs = Bo.NextStage()
    title(tt, e.name, K().C.boss)
    if e.type ~= nil then
      line(tt, e.type, K().C.muted)
    end
    local strength = U.Fill(S().BOSS_STRENGTH, { pct = w(U.Share(Bo.Strength())) })
    local r = Bo.Ready()
    if not Core().Combat.GateOpen() then
      line(tt, U.Fill(S().BOSS_TEASER, { s = w(bs) }))
      line(tt, strength)
      T.NextJump(tt, r)
      return
    end
    local held = Bo.Held()
    if held then
      line(tt, S().BOSS_HELD, K().C.warn, true)
    elseif r == "green" then
      line(tt, S().BOSS_GREEN, K().C.good, true)
    elseif r == "greenAbil" then
      local gs = S().BOSS_GREEN_ABIL_OFF
      if Mrgl.db.settings.opener == true then
        gs = S().BOSS_GREEN_ABIL
      end
      line(tt, gs, K().C.good, true)
    elseif r == "yellow" then
      line(tt, S().BOSS_YELLOW, K().C.warn, true)
    else
      line(tt, S().BOSS_GREY, K().C.tipText, true)
    end
    line(tt, U.Fill(S().BOSS_STATS, { hp = w(U.Exact(F().EnemyHP(bs))), t = w(Bo.Timer()) }))
    line(tt, strength)
    T.NextJump(tt, r)
    if db.boss.lostStage == bs and db.boss.lostAt > 0 then
      line(tt, U.Fill(S().BOSS_LOST_AT, { hp = w(U.Share(db.boss.lostAt)) }))
    end
    local a = Bo.AutoState()
    if r == "green" and not held then
      if a.state == "countdown" then
        line(tt, U.Fill(S().BOSS_AUTO_IN, { n = math.max(1, math.ceil(a.left)) }), K().C.muted, true)
      elseif a.state == "wait" then
        line(tt, S().BOSS_AUTO_WAIT, K().C.muted)
      else
        line(tt, S().BOSS_CLICK, K().C.muted)
      end
    elseif r == "greenAbil" and not held then
    elseif held then
      line(tt, S().BOSS_CLICK, K().C.muted)
    else
      line(tt, S().BOSS_CLICK_LOSE, K().C.muted, true)
    end
    if db.settings.opener and Core().Abilities.OpenerReady() then
      line(tt, S().BOSS_OPENER, K().C.muted)
    end
    T.KeyLine(tt, "MRGLSQUAD_BOSS")
  end
  T.NextJump = function(tt, r)
    if r == "green" or r == "greenAbil" then
      return
    end
    local j = Core().Shop.NextJump()
    if j == nil then
      return
    end
    local item = w(j.name)
    if j.kind == "hire" and j.amount > 1 then
      item = U.Fill(S().BOSS_NEXT_TO, { name = w(j.name), m = w(j.to) })
    end
    line(tt, U.Fill(S().BOSS_NEXT, { item = item, gain = U.Color(K().C.good, U.Gain(j.pct)) }), K().C.muted, true)
  end
  T.Portrait = function(tt, i)
    local m = F().Murloc(i)
    local n = Mrgl.db.murlocs[m.id].n
    title(tt, m.name, K().MurlocColor(i))
    if n <= 0 then
      line(tt, S().PORTRAIT_NONE, K().C.muted)
      line(tt, U.Fill(S().MURLOC_EACH, { each = w(U.Exact(F().MurlocEach(Mrgl.db.murlocs, i))) }), K().C.tipText, true)
      line(tt, U.Fill(S().PORTRAIT_COST, { cost = w(U.Exact(math.ceil(Mrgl.Core.Shop.Price(i, 1)))) }), K().C.tipText)
      return
    end
    line(tt, U.Fill(S().PORTRAIT_LINE, { n = w(U.Exact(n)), dps = w(U.Exact(F().MurlocDPS(Mrgl.db.murlocs, i))) }))
  end
  T.Murloc = function(tt, i, amount, teaser)
    local db = Mrgl.db
    local m = F().Murloc(i)
    local n = db.murlocs[m.id].n
    local each = F().MurlocEach(db.murlocs, i)
    title(tt, m.name)
    line(tt, U.Fill(S().MURLOC_EACH, { each = w(U.Exact(each)) }), K().C.tipText, true)
    if teaser ~= true then
      local total = F().MurlocDPS(db.murlocs, i)
      local squad = F().SquadDPS(db.murlocs)
      local pct = "0%"
      if squad > 0 then
        pct = U.Share(total / squad)
      end
      line(tt, U.Fill(S().MURLOC_TOTAL, { n = w(U.Exact(n)), total = w(U.Exact(total)), pct = w(pct) }), K().C.tipText, true)
      line(tt, U.Fill(S().MURLOC_NEXT, { m = w(F().NextMilestone(n)) }))
    end
    line(tt, U.Fill(S().COST, { cost = costTok(Core().Shop.Price(i, amount)) }))
    line(tt, U.Fill(S().MURLOC_CLICK, { amount = amount }), K().C.muted)
  end
  function upgEffect(m, up)
    if up.special ~= nil then
      return up.text
    end
    return U.Fill(S().UPG_DOUBLE, { murloc = m.name })
  end
  T.Upgrade = function(tt, i, tier)
    local m = F().Murloc(i)
    local up = U.At(m.upgrades, tier)
    title(tt, up.name, K().C.gold)
    line(tt, U.Fill(S().UPG_OF, { murloc = m.name, tier = tier }), K().C.muted)
    line(tt, upgEffect(m, up), K().C.good, true)
    line(tt, U.Fill(S().COST, { cost = costTok(up.cost) }))
    line(tt, S().UPG_CLICK, K().C.muted)
  end
  T.UpgradeTeaser = function(tt, i, tier)
    local m = F().Murloc(i)
    local up = U.At(m.upgrades, tier)
    local e = Mrgl.db.murlocs[m.id]
    title(tt, up.name)
    line(tt, U.Fill(S().UPG_OF, { murloc = m.name, tier = tier }), K().C.muted)
    line(tt, upgEffect(m, up), K().C.tipText, true)
    line(tt, U.Fill(S().COST, { cost = w(exactUp(up.cost)) }))
    if e.n < F().UpgradeReq(tier) then
      line(tt, U.Fill(S().UPG_LOCKED, { req = w(F().UpgradeReq(tier)), murloc = m.name, n = w(e.n) }), K().C.tipText, true)
    elseif e.u < tier - 1 then
      line(tt, U.Fill(S().UPG_NEEDS_PREV, { upgrade = w(U.At(m.upgrades, tier - 1).name) }), K().C.tipText, true)
    end
  end
  T.UpgradeDone = function(tt, i)
    local m = F().Murloc(i)
    title(tt, m.name)
    line(tt, S().UPG_COMPLETE, K().C.muted)
    for t = 1, U.Len(m.upgrades) do
      local up = U.At(m.upgrades, t)
      local fx = S().UPG_EFFECT_DOUBLE
      if up.special ~= nil then
        fx = up.sub
      end
      double(tt, up.name, fx, K().C.good)
    end
  end
  T.SelfValueText = function(id, r)
    local v = Core().Shop.SelfValue(id, r)
    if id == "click" then
      return U.Fill(S().SELF_CLICK_VAL, { v = U.Short(v) })
    end
    if id == "critdmg" then
      return U.Fill(S().SELF_MULT_VAL, { v = U.Dec(v, 1) })
    end
    return U.Fill(S().SELF_PCT_VAL, { v = v })
  end
  T.SelfGain = function(id)
    local db = Mrgl.db
    local c = Core().Shop.ClickFactor()
    if not (c > 0) then
      return -1
    end
    local base = F().EffDPS(db.murlocs, db.self, c)
    local S2 = U.Copy(db.self)
    S2[id] = S2[id] + 1
    local after = F().EffDPS(db.murlocs, S2, c)
    if not (base > 0) then
      return 100
    end
    return 100 * (after / base - 1)
  end
  T.Self = function(tt, j)
    local d = U.At(Mrgl.Data.Self, j)
    local r = Mrgl.db.self[d.id]
    title(tt, d.name)
    line(tt, d.text, K().C.tipText, true)
    if not Core().Shop.SelfVisible(d.id) then
      if d.id == "crit" or d.id == "critdmg" then
        line(tt, U.Fill(S().SELF_LOCKED, { s = w(Mrgl.Data.Balance.SELF_CRIT_STAGE) }))
      else
        line(tt, S().SELF_LOCKED_HIRE)
      end
      return
    end
    line(tt, U.Fill(S().SELF_NOW, { value = w(T.SelfValueText(d.id, r)) }))
    if F().SelfMaxed(d.id, r) then
      line(tt, S().SELF_MAXED, K().C.gold)
      return
    end
    line(tt, U.Fill(S().SELF_NEXT, { next = g(T.SelfValueText(d.id, r + 1)) }))
    local gain = T.SelfGain(d.id)
    if gain < 0 then
      line(tt, S().SELF_GAIN_NONE, K().C.muted, true)
    else
      line(tt, U.Fill(S().SELF_GAIN, { gain = gainTok(gain) }), K().C.tipText, true)
    end
    line(tt, U.Fill(S().COST, { cost = costTok(F().SelfCost(d.id, r)) }))
    line(tt, S().UPG_CLICK, K().C.muted)
  end
  T.AbilityAlt = function(i)
    local d = U.At(Mrgl.Data.Abilities, i)
    if d.alt == nil or Mrgl.UI.Main.AnyfinShown == nil or not Mrgl.UI.Main.AnyfinShown() then
      return nil
    end
    return d.alt
  end
  T.Ability = function(tt, i)
    local d = U.At(Mrgl.Data.Abilities, i)
    local A = Core().Abilities
    local alt = T.AbilityAlt(i)
    local name, text = d.name, d.text
    if alt ~= nil then
      name = alt.name
      text = alt.text
    end
    if not A.Unlocked(d.id) then
      title(tt, name, K().C.muted)
      line(tt, text, K().C.tipText, true)
      line(tt, U.Fill(S().ABILITY_LOCKED, { s = w(d.stage) }))
      return
    end
    title(tt, name, K().C.gold)
    line(tt, text, K().C.tipText, true)
    line(tt, U.Fill(S().ABILITY_CD, { cd = w(U.CDLong(d.cd)) }))
    local buff = A.BuffLeft(d.id)
    if buff > 0 then
      line(tt, U.Fill(S().ABILITY_ACTIVE, { t = w(U.Clock(math.ceil(buff))) }), K().C.gold)
    elseif not A.IsReady(d.id) then
      line(tt, U.Fill(S().ABILITY_READY_IN, { t = U.Clock(math.ceil(A.Remaining(d.id))) }), K().C.bad)
    end
    T.KeyLine(tt, "MRGLSQUAD_ABILITY" .. A.Slot(d.id))
  end
  T.TargetName = function(t)
    if t.kind == "hire" then
      local m = F().Murloc(t.slot)
      if t.amount > 1 then
        return U.Fill(S().BUYBEST_AMOUNT, { name = m.name, n = t.amount })
      end
      return m.name
    end
    if t.kind == "upgrade" then
      return U.At(F().Murloc(t.slot).upgrades, t.tier).name
    end
    return U.At(Mrgl.Data.Self, t.slot).name
  end
  T.BuyBest = function(tt)
    local ch = Core().Shop.Chain()
    title(tt, S().BUYBEST)
    if ch == nil then
      line(tt, S().NOTHING_WORTH, K().C.tipText, true)
      T.KeyLine(tt, "MRGLSQUAD_BUYBEST")
      return
    end
    local t = ch.first
    if not ch.affordable or ch.n <= 0 then
      double(tt, T.TargetName(t), exactUp(t.cost))
      local tpl1 = S().BUYBEST_GAIN
      if ch.isNew == true then
        tpl1 = S().BUYBEST_NEW_GAIN
      end
      line(tt, U.Fill(tpl1, { gain = gainTok(t.gain), cost = w(exactUp(t.cost)) }), K().C.tipText, true)
      local wt = "-"
      if t.wait >= 0 then
        wt = U.Wait(t.wait)
      end
      line(tt, U.Fill(S().BUYBEST_WAIT, { t = w(wt) }))
      T.KeyLine(tt, "MRGLSQUAD_BUYBEST")
      return
    end
    local n = U.Len(ch.items)
    local shown = math.min(4, n)
    for i = 1, shown do
      local it = U.At(ch.items, i)
      local nm = it.name
      if it.count > 1 then
        nm = U.Fill(S().BUYBEST_AMOUNT, { name = it.name, n = it.count })
      end
      double(tt, nm, exactUp(it.cost))
    end
    if n > shown then
      line(tt, U.Fill(S().BUYBEST_MORE, { m = n - shown }), K().C.muted)
    end
    local tpl = S().BUYBEST_GAIN
    if ch.isNew == true then
      tpl = S().BUYBEST_NEW_GAIN
    end
    line(tt, U.Fill(tpl, { gain = gainTok(ch.gain), cost = w(exactUp(ch.cost)) }), K().C.tipText, true)
    T.KeyLine(tt, "MRGLSQUAD_BUYBEST")
  end
  T.Simple = function(titleText, text, muted)
    return function(tt)
      title(tt, titleText)
      if text ~= nil then
        line(tt, text, K().C.tipText, true)
      end
      if muted ~= nil then
        line(tt, muted, K().C.muted)
      end
    end
  end
  T.StatDPS = function(tt)
    title(tt, S().STAT_DPS)
    line(tt, U.Fill(S().STAT_DPS_LINE, { dps = w(U.Exact(Core().Combat.SquadDPS())) }))
    local mk = Core().Tide.MurkyDPS()
    if mk > 0 then
      line(tt, U.Fill(S().TIDE_MURKY_DPS, { dps = w(U.Exact(mk)) }), K().C.muted)
    end
  end
  T.StatClick = function(tt)
    local db = Mrgl.db
    title(tt, S().STAT_CLICK)
    line(tt, U.Fill(S().STAT_CLICK_LINE, { click = w(U.Exact(Core().Combat.ClickDamage())) }))
    local p = math.floor(Core().Combat.CritChance("click") * 100 + 0.5)
    line(tt, U.Fill(S().STAT_CRIT_LINE, { chance = w(p), mult = w(U.Dec(F().CritMult(db.self), 1)) }))
  end
  local TIDE_EFF = { m = "TIDE_EFFECT_M", s = "TIDE_EFFECT_S", a = "TIDE_EFFECT_A" }
  T.TideMult = function(id)
    local Td = Core().Tide
    if id == "m" then
      return Td.PathMult("m")
    end
    if id == "s" then
      return Td.ClickMult()
    end
    return Td.SpellMult()
  end
  T.TideEffect = function(id)
    return U.Fill(S()[TIDE_EFF[id]], { x = U.Short(T.TideMult(id)) })
  end
  local WAVES, PATH_MAX = 30, 100
  T.TideWave = function()
    local Td = Core().Tide
    if Td.Wave ~= nil then
      return Td.Wave()
    end
    return math.min(WAVES, math.floor(Mrgl.db.prestige.count / 10) + 1)
  end
  T.TidePathFull = function(id)
    local Td = Core().Tide
    if Td.PathFull ~= nil then
      return Td.PathFull(id) == true
    end
    return Mrgl.db.prestige.paths[id] >= PATH_MAX
  end
  T.TideAllFull = function()
    local Td = Core().Tide
    if Td.Full ~= nil then
      return Td.Full() == true
    end
    return T.TidePathFull("m") and T.TidePathFull("s") and T.TidePathFull("a")
  end
  function nefw()
    local nw = Mrgl.db.prestige.trophies.nefw
    if type(nw) == "string" then
      return nw
    end
    return ""
  end
  T.NefCount = function()
    local Td = Core().Tide
    if Td.NefCount ~= nil then
      return Td.NefCount()
    end
    local nw, n = nefw(), 0
    for i = 1, string.len(nw) do
      if string.sub(nw, i, i) == "1" then
        n = n + 1
      end
    end
    if nw == "" and Mrgl.db.prestige.trophies.nef == true then
      n = 1
    end
    return n
  end
  T.NefThis = function()
    local Td = Core().Tide
    if Td.NefThisWave ~= nil then
      return Td.NefThisWave() == true
    end
    local nw, k = nefw(), T.TideWave()
    if nw == "" then
      return k == 1 and Mrgl.db.prestige.trophies.nef == true
    end
    return string.sub(nw, k, k) == "1"
  end
  T.NefMissed = function()
    local Td = Core().Tide
    if Td.NefMissed ~= nil then
      return Td.NefMissed()
    end
    local nw, n = nefw(), 0
    for i = 1, T.TideWave() - 1 do
      if string.sub(nw, i, i) == "0" then
        n = n + 1
      end
    end
    return n
  end
  T.TideWaveNext = function()
    local n = Mrgl.db.prestige.count
    if n % 10 == 9 and n < 299 then
      return math.floor((n + 1) / 10) + 1
    end
    return nil
  end
  T.TideWaveJump = function()
    local n = Mrgl.db.prestige.count
    if n > 0 and n < 300 and n % 10 == 0 then
      return T.TideWave()
    end
    return nil
  end
  T.TideMsState = function(i, k)
    local p = U.At(Mrgl.Data.Tide.paths, i)
    local d = U.At(p.ms, k)
    local n = Mrgl.db.prestige.paths[p.id]
    if n >= d.at then
      if d.toggle ~= nil and Mrgl.db.settings[d.toggle] == false then
        return "off"
      end
      return "reached"
    end
    local prev = 0
    if k > 1 then
      prev = U.At(p.ms, k - 1).at
    end
    if n >= prev then
      return "next"
    end
    return "later"
  end
  T.TideNextMs = function(i)
    local p = U.At(Mrgl.Data.Tide.paths, i)
    local n = Mrgl.db.prestige.paths[p.id]
    for k = 1, U.Len(p.ms) do
      local d = U.At(p.ms, k)
      if n < d.at then
        return d
      end
    end
    return nil
  end
  function toggleLine(tt, key)
    if Mrgl.db.settings[key] ~= false then
      line(tt, S().TIDE_ON, K().C.good)
    else
      line(tt, S().TIDE_OFF, K().C.muted)
    end
  end
  function nextLine(tt, i)
    local nx = T.TideNextMs(i)
    if nx ~= nil then
      line(tt, U.Fill(S().TIDE_NEXT_MS, { name = nx.name, r = nx.at }), K().C.muted)
    else
      line(tt, S().TIDE_ALL_MS, K().C.muted)
    end
  end
  T.TidePath = function(tt, i)
    local p = U.At(Mrgl.Data.Tide.paths, i)
    local n = Mrgl.db.prestige.paths[p.id]
    title(tt, p.name)
    line(tt, p.tag, K().C.muted)
    T.TideSpellsNeed(tt, p)
    if n == 1 then
      line(tt, S().TIDE_POINT)
    else
      line(tt, U.Fill(S().TIDE_POINTS, { n = w(n) }))
    end
    line(tt, p.per, K().C.tipText, true)
    if n > 0 then
      line(tt, U.Fill(S().TIDE_NOW, { effect = T.TideEffect(p.id) }), K().C.good)
    end
    nextLine(tt, i)
    if T.TidePathFull(p.id) then
      line(tt, S().TIDE_MAX_SHORT, K().C.good)
    end
    if i == 1 and Core().Tide.Total() <= 0 then
      line(tt, S().TIDE_RECOMMENDED, K().C.gold, true)
    end
  end
  T.TideMs = function(tt, i, k)
    local p = U.At(Mrgl.Data.Tide.paths, i)
    local d = U.At(p.ms, k)
    local n = Mrgl.db.prestige.paths[p.id]
    title(tt, d.name)
    line(tt, d.text, K().C.tipText, true)
    if n < d.at then
      line(tt, U.Fill(S().TIDE_MS_AT, { r = d.at, n = n }), K().C.muted)
      return
    end
    if d.toggle ~= nil then
      toggleLine(tt, d.toggle)
      return
    end
    line(tt, S().TIDE_MS_REACHED, K().C.good)
  end
  T.TideFirst = function(tt, j)
    local d = U.At(Mrgl.Data.Tide.first, j)
    title(tt, d.name)
    line(tt, d.text, K().C.tipText, true)
    if Core().Tide.Total() < 1 then
      line(tt, S().TIDE_FIRST_LOCKED, K().C.muted)
      return
    end
    if d.toggle ~= nil then
      toggleLine(tt, d.toggle)
    end
  end
  T.TideTrophy = function(tt, j)
    local d = U.At(Mrgl.Data.Tide.trophies, j)
    title(tt, d.name)
    line(tt, U.Fill(S().NEF_WAVES, { n = T.NefCount(), max = WAVES }))
    if T.NefThis() then
      line(tt, S().NEF_THIS_DONE, K().C.good)
    else
      line(tt, S().NEF_THIS_NEED, K().C.muted, true)
    end
    if T.NefMissed() > 0 then
      line(tt, S().NEF_MISSED, K().C.muted, true)
    end
    line(tt, S().NEF_ONE, K().C.muted)
  end
  T.TideFlood = function(tt)
    local Td = Core().Tide
    title(tt, S().TIDE_FLOOD_TITLE)
    line(tt, U.Fill(S().TIDE_FLOOD_ANY, { d = U.Short(Td.FloodDmg()), g = U.Short(Td.FloodGold()) }), K().C.good, true)
    line(tt, U.Fill(S().TIDE_COUNT, { n = Mrgl.db.prestige.count }), K().C.muted)
  end
  T.TideButton = function(tt)
    title(tt, S().TAB_TIDE)
    line(tt, S().TIDE_BTN_TIP, K().C.tipText, true)
    local Td = Core().Tide
    if T.TideAllFull() then
      line(tt, S().TIDE_ALL_MAX, K().C.muted)
      return
    end
    if Td.Ready() then
      return
    end
    if Core().rt.inCombat ~= true and not Mrgl.db.boss.active and not Td.Avail() then
      line(tt, U.Fill(S().TIDE_REACH_TIP, { s = Mrgl.Data.Balance.TIDE_STAGE }), K().C.muted, true)
      line(tt, S().TIDE_NO_KILL, K().C.muted)
    else
      line(tt, Mrgl.UI.Panel.TideReason().text, K().C.muted)
    end
  end
  T.TideMark = function(tt)
    title(tt, S().TIDE_MARK)
    line(tt, S().TIDE_NO_KILL, K().C.tipText)
    line(tt, S().TIDE_MARK_TIP, K().C.muted)
  end
  T.TideHead = function(tt)
    title(tt, S().TAB_TIDE)
    line(tt, S().TAB_TIDE_TIP, K().C.tipText, true)
    line(tt, S().TIDE_NO_KILL, K().C.muted)
    local k = T.TideWave()
    line(tt, U.Fill(S().TIDE_WAVE, { n = k, max = WAVES }), K().C.white)
    if k <= 1 then
      line(tt, S().TIDE_WAVE_1, K().C.muted, true)
      return
    end
    if not T.TideAllFull() then
      line(tt, S().TIDE_WAVE_HARD, K().C.muted, true)
    end
    if k < WAVES then
      line(tt, U.Fill(S().TIDE_WAVE_NEXT, { n = k * 10 }), K().C.muted)
    end
  end
  T.TideBest = function(tt)
    title(tt, S().TIDE_BEST_TITLE)
    line(tt, U.Fill(S().TIDE_BEST_TIP, { s = w(Mrgl.db.prestige.best) }), K().C.tipText, true)
  end
  T.TideComing = function(tt, j)
    title(tt, U.At(Mrgl.Data.Tide.coming, j).name)
    line(tt, S().TIDE_COMING_TIP, K().C.muted)
  end
  T.TideUlt = function(tt)
    title(tt, S().TIDE_ULT)
    if T.TideAllFull() then
      line(tt, S().TIDE_ALL_MAX, K().C.good)
    else
      line(tt, S().TIDE_ALL_MAX, K().C.muted)
    end
    line(tt, S().TIDE_COMING_TIP, K().C.muted)
  end
  T.TideCompanion = function(idx)
    local D = Mrgl.Data.Tide
    local Td = Core().Tide
    for j = 1, U.Len(D.first) do
      local fd = U.At(D.first, j)
      if fd.companion == idx then
        return { d = fd, has = Td.Total() >= 1 }
      end
    end
    for i = 1, U.Len(D.paths) do
      local p = U.At(D.paths, i)
      for k = 1, U.Len(p.ms) do
        local m = U.At(p.ms, k)
        if m.companion == idx then
          return { d = m, has = Td.Has(p.id, m.at) }
        end
      end
    end
    return nil
  end
  T.Companion = function(tt, idx)
    local c = T.TideCompanion(idx)
    if c == nil then
      return
    end
    title(tt, c.d.name)
    if idx == 1 then
      local mk = Core().Tide.MurkyDPS()
      if mk > 0 then
        line(tt, U.Fill(S().TIDE_MURKY_FIGHTS, { dps = w(U.Exact(mk)) }), K().C.good)
        return
      end
    end
    line(tt, c.d.text, K().C.tipText, true)
  end
  T.TidePick = function(tt, i)
    local p = U.At(Mrgl.Data.Tide.paths, i)
    title(tt, p.name)
    if T.TidePathFull(p.id) then
      line(tt, S().TIDE_MAX, K().C.muted)
      return
    end
    line(tt, p.tag, K().C.muted)
    T.TideSpellsNeed(tt, p)
    line(tt, p.per, K().C.tipText, true)
    nextLine(tt, i)
  end
  T.TideSpellsNeed = function(tt, p)
    if p.id ~= "a" or Mrgl.db.prestige.paths.a >= U.At(p.ms, 1).at then
      return
    end
    line(tt, S().TIDE_SPELLS_BOSS, K().C.muted)
  end
end
