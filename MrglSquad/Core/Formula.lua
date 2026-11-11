local ADDON, Mrgl = ...
Mrgl.Core = Mrgl.Core or {}
do
  local B, Ti, Pw, rankOf
  local F = {}
  Mrgl.Core.Formula = F
  local U = Mrgl.U
  function B()
    return Mrgl.Data.Balance
  end
  function Ti()
    return Mrgl.Core.Tide
  end
  function Pw(key, M, Sp)
    return Mrgl.Core.Abilities.Power(key, M, Sp)
  end
  F.IsBoss = function(s)
    return s % B().BOSS_EVERY == 0
  end
  F.IsZoneBoss = function(s)
    return s % B().STAGES_PER_ZONE == 0
  end
  F.HP = function(s)
    return B().HP_BASE * B().HP_GROWTH ^ (s - 1) + B().HP_LIN * (s - 1)
  end
  F.HardMult = function(s)
    local b = B()
    local d = s - b.HARD_STAGE
    if d <= 0 then
      return 1
    end
    return b.HARD_GROWTH ^ d * b.HARD_CURVE ^ (d * d / b.HARD_CURVE_DIV)
  end
  local function baseHP(s)
    if F.IsZoneBoss(s) then
      if s >= 30 and s <= 50 then
        return F.HP(s) * B().BOSS_HP_MULT_MID
      end
      return F.HP(s) * B().BOSS_HP_MULT
    end
    if F.IsBoss(s) and s >= 30 and s <= 50 then
      return F.HP(s) * B().MINIBOSS_HP_MULT_MID
    end
    if F.IsBoss(s) then
      return F.HP(s) * B().MINIBOSS_HP_MULT
    end
    return F.HP(s)
  end
  F.EnemyHP = function(s)
    local b = B()
    local h = baseHP(s) * F.HardMult(s)
    if s > b.HARD_STAGE then
      if F.IsZoneBoss(s) then
        h = h * b.BOSS_HP_HIGH
      elseif F.IsBoss(s) then
        h = h * b.MINIBOSS_HP_HIGH
      end
    end
    return math.min(b.HP_CAP, h)
  end
  F.ZoneIndex = function(s)
    return math.min(B().ZONES, math.floor((s - 1) / B().STAGES_PER_ZONE) + 1)
  end
  F.Pos = function(s)
    return (s - 1) % B().STAGES_PER_ZONE + 1
  end
  F.NextBossStage = function(s)
    return math.ceil(s / B().BOSS_EVERY) * B().BOSS_EVERY
  end
  F.GoldMult = function(M)
    local u = M.raider.u
    if u >= 3 then
      local p = B().RAIDER_GOLD
      if u >= 4 then
        p = p + B().RAIDER_GOLD_4
      end
      if u >= 5 then
        p = p + B().RAIDER_GOLD_5
      end
      return (1 + p) * Ti().GoldMult()
    end
    return Ti().GoldMult()
  end
  F.Gold = function(s, boss, rare, M)
    local b = B()
    local g = math.ceil(b.GOLD_LIN * s + F.HP(s) / b.GOLD_DIV) + b.GOLD_PLUS
    if boss then
      g = g * b.BOSS_GOLD_MULT
    end
    if boss and M.raider.u >= 6 then
      g = g * b.RAIDER_BOSS_GOLD_6
    end
    if rare then
      g = g * b.RARE_GOLD
    end
    return g * F.GoldMult(M)
  end
  F.BossTimer = function(M)
    if M.tidehunter.u >= 4 then
      return B().BOSS_TIMER + B().TIDE_TIMER + B().TIDE_TIMER_4 + Ti().TimerPlus()
    end
    if M.tidehunter.u >= 3 then
      return B().BOSS_TIMER + B().TIDE_TIMER + Ti().TimerPlus()
    end
    return B().BOSS_TIMER + Ti().TimerPlus()
  end
  F.BossDmg = function(M)
    local u = M.tidehunter.u
    if u >= 6 then
      return 1 + B().TIDEHUNTER_BOSS_5 + B().TIDEHUNTER_BOSS_6
    end
    if u >= 5 then
      return 1 + B().TIDEHUNTER_BOSS_5
    end
    return 1
  end
  F.Milestones = function(n)
    local b = B()
    if n < b.MILESTONE_FIRST then
      return 0
    end
    if n < b.MILESTONE_SECOND then
      return 1
    end
    return 2 + math.floor((n - b.MILESTONE_SECOND) / b.MILESTONE_STEP)
  end
  F.NextMilestone = function(n)
    local b = B()
    if n < b.MILESTONE_FIRST then
      return b.MILESTONE_FIRST
    end
    if n < b.MILESTONE_SECOND then
      return b.MILESTONE_SECOND
    end
    return b.MILESTONE_SECOND + (math.floor((n - b.MILESTONE_SECOND) / b.MILESTONE_STEP) + 1) * b.MILESTONE_STEP
  end
  F.PrevMilestone = function(n)
    local b = B()
    if n < b.MILESTONE_FIRST then
      return 0
    end
    if n < b.MILESTONE_SECOND then
      return b.MILESTONE_FIRST
    end
    return b.MILESTONE_SECOND + math.floor((n - b.MILESTONE_SECOND) / b.MILESTONE_STEP) * b.MILESTONE_STEP
  end
  F.Murloc = function(i)
    return U.At(Mrgl.Data.Murlocs, i)
  end
  F.MurlocIndex = function(id)
    local list = Mrgl.Data.Murlocs
    for i = 1, U.Len(list) do
      if U.At(list, i).id == id then
        return i
      end
    end
    return 0
  end
  F.Cost = function(i, n)
    return F.Murloc(i).cost * Ti().CostMult() * B().COST_GROWTH ^ n
  end
  F.Bundle = function(i, n, k)
    local g = B().COST_GROWTH
    return F.Murloc(i).cost * Ti().CostMult() * g ^ n * (g ^ k - 1) / (g - 1)
  end
  F.MaxAfford = function(i, n, gold)
    local g = B().COST_GROWTH
    local c = F.Cost(i, n)
    if gold < c then
      return 0
    end
    if not (gold - gold == 0) then
      return 0
    end
    local k = math.floor(math.log(gold * (g - 1) / c + 1) / math.log(g))
    while k > 0 and F.Bundle(i, n, k) > gold do
      k = k - 1
    end
    while F.Bundle(i, n, k + 1) <= gold do
      k = k + 1
    end
    return k
  end
  F.HiredTotal = function(M)
    local list, t = Mrgl.Data.Murlocs, 0
    for i = 1, U.Len(list) do
      t = t + M[U.At(list, i).id].n
    end
    return t
  end
  F.MurlocEach = function(M, i)
    local m = F.Murloc(i)
    local n = M[m.id].n
    if n > 0 then
      return F.MurlocDPS(M, i) / n
    end
    return m.dps * B().UPG_DPS_MULT ^ math.min(M[m.id].u, 2) * F.LateMult(M[m.id].u) * Ti().MurlocMult()
  end
  F.LateMult = function(u)
    if u <= 3 then
      return 1
    end
    return B().UPG_DPS_MULT ^ (u - 3)
  end
  local function warAura(u)
    local b = B()
    if u >= 6 then
      return b.WARLEADER_AURA_6
    end
    if u >= 5 then
      return b.WARLEADER_AURA_5
    end
    if u >= 4 then
      return b.WARLEADER_AURA_4
    end
    return b.WARLEADER_AURA
  end
  local function murkPer(u)
    local b = B()
    if u >= 6 then
      return b.MURKEYE_PER_6
    end
    if u >= 5 then
      return b.MURKEYE_PER_5
    end
    if u >= 4 then
      return b.MURKEYE_PER_4
    end
    return b.MURKEYE_PER
  end
  F.MurlocDPS = function(M, i)
    local b = B()
    local m = F.Murloc(i)
    local e = M[m.id]
    if e.n <= 0 then
      return 0
    end
    local d = m.dps * e.n * 2 ^ F.Milestones(e.n) * b.UPG_DPS_MULT ^ math.min(e.u, 2)
    if e.u > 3 then
      d = d * F.LateMult(e.u)
    end
    local aura = 1
    if m.id ~= "oracle" and M.oracle.u >= 3 then
      aura = aura + b.ORACLE_AURA
    end
    if m.id ~= "warleader" and M.warleader.u >= 3 then
      aura = aura + warAura(M.warleader.u)
    end
    d = d * aura
    if m.id == "murkeye" and e.u >= 3 then
      d = d * (1 + murkPer(e.u) * F.HiredTotal(M))
    end
    return d * Ti().MurlocMult()
  end
  F.MurkyDPS = function()
    return Ti().MurkyDPS()
  end
  F.SquadRaw = function(M)
    local t = 0
    for i = 1, U.Len(Mrgl.Data.Murlocs) do
      t = t + F.MurlocDPS(M, i)
    end
    return math.min(B().HP_CAP, t + F.MurkyDPS())
  end
  local sq = { v = 0, M = nil, mm = -1, mk = -1, n = {}, u = {} }
  F.SquadDPS = function(M)
    local db = Mrgl.db
    if db == nil or M ~= db.murlocs then
      return F.SquadRaw(M)
    end
    local mm = Ti().MurlocMult()
    local mk = F.MurkyDPS()
    local same = sq.M == M and sq.mm == mm and sq.mk == mk
    local list = Mrgl.Data.Murlocs
    for i = 1, U.Len(list) do
      local e = M[U.At(list, i).id]
      if U.At(sq.n, i) ~= e.n or U.At(sq.u, i) ~= e.u then
        same = false
        U.Set(sq.n, i, e.n)
        U.Set(sq.u, i, e.u)
      end
    end
    if same ~= true then
      sq.M = M
      sq.mm = mm
      sq.mk = mk
      sq.v = F.SquadRaw(M)
    end
    return sq.v
  end
  F.UpgradeCost = function(i, tier)
    return U.At(F.Murloc(i).upgrades, tier).cost * Ti().CostMult()
  end
  F.UpgradeReq = function(i, tier)
    local up = U.At(F.Murloc(i).upgrades, tier)
    if up ~= nil and up.at ~= nil then
      return up.at
    end
    return U.At(B().UPG_AT, tier)
  end
  F.UpgradeMax = function(i)
    return U.Len(F.Murloc(i).upgrades)
  end
  F.ClickBase = function(S)
    return (1 + S.click) * 2 ^ math.floor(S.click / B().CLICK_DOUBLE_EVERY)
  end
  F.EchoShare = function(M, S)
    local p = B().ECHO_STEP * S.echo
    if M.tinyfin.u >= 3 then
      p = p + B().TINYFIN_ECHO
    end
    if M.tinyfin.u >= 4 then
      p = p + B().TINYFIN_ECHO_4
    end
    if M.tinyfin.u >= 5 then
      p = p + B().TINYFIN_ECHO_5
    end
    if Ti().EchoFloor() then
      p = math.max(B().TIDE_ECHO_FLOOR, p)
    end
    return p
  end
  F.ClickDamage = function(M, S, dps)
    local v = (F.ClickBase(S) + F.EchoShare(M, S) * dps) * Ti().ClickMult()
    if M.tinyfin.u >= 6 then
      v = v * B().TINYFIN_CLICK_6
    end
    return math.min(B().HP_CAP, v)
  end
  F.CritChance = function(S, candle)
    local p = B().CRIT_BASE + B().CRIT_STEP * S.crit
    if candle then
      p = p + B().CANDLE_CRIT
    end
    return math.min(1, p + Ti().CritPlus())
  end
  F.CritMult = function(S)
    return B().CRITM_BASE + B().CRITM_STEP * S.critdmg + Ti().CritDmgPlus()
  end
  F.ClickExpected = function(M, S, dps, candle)
    return F.ClickDamage(M, S, dps) * (1 + F.CritChance(S, candle) * (F.CritMult(S) - 1))
  end
  F.SelfMax = function(id)
    local b = B()
    if id == "echo" then
      return U.Len(b.ECHO_COSTS)
    end
    if id == "crit" then
      return b.CRIT_MAX
    end
    if id == "critdmg" then
      return b.CRITM_MAX
    end
    return 0
  end
  F.SelfCost = function(id, r)
    local b = B()
    if id == "click" then
      return b.CLICK_COST_BASE * b.CLICK_COST_GROWTH ^ r
    end
    if id == "echo" then
      return U.At(b.ECHO_COSTS, r + 1)
    end
    if id == "crit" then
      return b.CRIT_COST_BASE * b.CRIT_COST_GROWTH ^ r
    end
    return b.CRITM_COST_BASE * b.CRITM_COST_GROWTH ^ r
  end
  F.SelfMaxed = function(id, r)
    local mx = F.SelfMax(id)
    return mx > 0 and r >= mx
  end
  F.EffDPS = function(M, S, c, Sp)
    local d = F.SquadDPS(M)
    local v = d + c * F.ClickExpected(M, S, d, false)
    if Ti().Total() >= 1 then
      v = v + F.AbilDPS(M, S, c, d, Sp)
    end
    v = v * F.GoldMult(M)
    if M.tidehunter.u >= 3 then
      v = v * 1.05
    end
    if M.tidehunter.u >= 4 then
      v = v * 1.05
    end
    if M.tidehunter.u >= 5 then
      v = v * (1 + B().UPG_BOSS_VALUE * (F.BossDmg(M) - 1))
    end
    return v
  end
  function rankOf(Sp, id)
    local t = Sp
    if t == nil and Mrgl.db ~= nil then
      t = Mrgl.db.spells
    end
    if t == nil or t[id] == nil then
      return 0
    end
    return t[id]
  end
  F.SpellRank = rankOf
  F.SpellBoost = function(M, id, Sp)
    local v = 1 + B().SPELL_RANK_STEP * rankOf(Sp, id)
    if M.oracle.u >= 5 then
      v = v * B().ORACLE_SPELL_5
    end
    return v
  end
  F.SpellCdMult = function(r)
    local b = B()
    return 1 - math.min(b.SPELL_CD_MAX, b.SPELL_CD_STEP * math.floor(r / b.SPELL_CD_EVERY))
  end
  F.SpellCd = function(M, id, Sp)
    local cd = Mrgl.Core.Abilities.Def(id).cd
    local r = rankOf(Sp, id)
    if r >= B().SPELL_CD_EVERY then
      cd = cd * F.SpellCdMult(r)
    end
    local u = M.oracle.u
    if u >= 6 then
      return cd * B().ORACLE_CD_6
    end
    if u >= 4 then
      return cd * B().ORACLE_CD_4
    end
    return cd
  end
  F.SpellCost = function(id, r)
    local b = B()
    return U.At(b.SPELL_COST_BASE, Mrgl.Core.Abilities.Slot(id)) * b.SPELL_COST_GROWTH ^ r
  end
  F.WhelpMult = function(M, Sp)
    return Ti().SpellMult() * F.SpellBoost(M, "whelps", Sp)
  end
  F.AbilDPS = function(M, S, c, d, Sp)
    local A = Mrgl.Core.Abilities
    local b = B()
    local click = F.ClickDamage(M, S, d)
    local cm = F.CritMult(S)
    local ce = 1 + F.CritChance(S, false) * (cm - 1)
    local v = 0
    if A.Unlocked("mrgl") then
      v = v + (click * ce + Pw("MRGL_DPS_SEC", M, Sp) * d) / F.SpellCd(M, "mrgl", Sp)
    end
    if A.Unlocked("whelps") then
      v = v + Pw("WHELPS_CPS", M, Sp) * A.BuffDur("whelps", M, Sp) * click * F.WhelpMult(M, Sp) * ce / F.SpellCd(M, "whelps", Sp)
    end
    if A.Unlocked("candle") then
      v = v + c * click * b.CANDLE_CRIT * (cm - 1) * math.min(1, A.BuffDur("candle", M, Sp) / F.SpellCd(M, "candle", Sp))
    end
    if A.Unlocked("leeroy") then
      v = v + (Pw("LEEROY_CLICKS", M, Sp) * click * cm + Pw("LEEROY_DPS_SEC", M, Sp) * d) / F.SpellCd(M, "leeroy", Sp)
    end
    return math.min(b.HP_CAP, v)
  end
  F.Burst = function(M, S, R, Sp)
    local d = F.SquadDPS(M)
    local click = F.ClickDamage(M, S, d)
    local cm = F.CritMult(S)
    local b = B()
    local t = 0
    if R.mrgl == true then
      t = t + click + Pw("MRGL_DPS_SEC", M, Sp) * d
    end
    if R.leeroy == true then
      t = t + Pw("LEEROY_CLICKS", M, Sp) * click * cm + Pw("LEEROY_DPS_SEC", M, Sp) * d
    end
    if R.whelps == true then
      local p = F.CritChance(S, false)
      if R.candle == true then
        p = math.min(1, p + b.CANDLE_CRIT)
      end
      if R.leeroy == true then
        p = 1
      end
      local cl = Pw("WHELPS_CPS", M, Sp) * Mrgl.Core.Abilities.BuffDur("whelps", M, Sp)
      t = t + cl * click * F.WhelpMult(M, Sp) * (1 + p * (cm - 1))
    end
    return t
  end
  F.Rush = function(M, S, R, cps)
    if R.leeroy ~= true then
      return 0
    end
    local d = F.SquadDPS(M)
    return B().LEEROY_CRIT_SEC * Ti().BuffMult() * cps * F.ClickDamage(M, S, d) * F.CritMult(S)
  end
  F.Ready = function(M, S, bs, cps, R)
    local b = B()
    local d = F.SquadDPS(M)
    local T = F.BossTimer(M)
    local hp = F.EnemyHP(bs) / F.BossDmg(M)
    local dg = d
    local ac = Ti().AutoSwing()
    if ac > 0 then
      dg = d + ac * F.ClickExpected(M, S, d, false)
    end
    if dg * T >= b.READY_GREEN * hp then
      return "green"
    end
    local burst = F.Burst(M, S, R)
    if d * T + burst >= b.READY_GREEN * hp then
      return "greenAbil"
    end
    local c = math.max(0, cps)
    local clickDps = c * F.ClickExpected(M, S, d, false)
    if (d + clickDps) * T + burst + F.Rush(M, S, R, c) >= b.READY_YELLOW * hp then
      return "yellow"
    end
    return "grey"
  end
  F.Strength = function(M, S, bs, R, Sp)
    local d = F.SquadDPS(M)
    local need = B().READY_GREEN * F.EnemyHP(bs) / F.BossDmg(M)
    return math.min(1, (d * F.BossTimer(M) + F.Burst(M, S, R, Sp)) / need)
  end
  F.GoldRate = function(M, S, s, cps)
    local d = F.SquadDPS(M)
    local total = d + cps * F.ClickExpected(M, S, d, false)
    if not (total > 0) then
      return 0
    end
    return F.Gold(s, false, false, M) / (F.HP(s) * F.HardMult(s) / total + B().RESPAWN)
  end
  F.OfflineGold = function(M, S, s, dt)
    local b = B()
    local d = F.SquadDPS(M)
    if not (d > 0) or not (dt > 0) then
      return 0
    end
    local t = math.min(dt, b.OFFLINE_MAX)
    return Ti().OfflineRate() * t * F.Gold(s, false, false, M) / (F.HP(s) * F.HardMult(s) / d + b.RESPAWN)
  end
end
