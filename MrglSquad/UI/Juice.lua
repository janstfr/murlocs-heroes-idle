local ADDON, Mrgl = ...
-- Mrgl Squad - UI/Juice.lua equivalent: numbers (r2 L2), headline (L3), coins (L4), flash, sparks, whelps,
-- one-glow rule (plan 3.6, 6.1; r2 L5 calm, L6 polish, W3 hidden window, W6 ready flash).
-- Everything is pooled and built once; nothing is created while playing.
-- W3: every juice handler starts with "if not MrglSquadFrame:IsVisible() then return end";
-- state displays come from Main.Refresh. OnShow() drops all running juice when the window comes back.
Mrgl.UI = Mrgl.UI or {}
do
  local buyKey
  local quietIn
  local K, C, Core, W, M, S, calm, visible, rush, laneColor, buildNumber, placeNumber, stopNumber, killNumber, number, laneLive, updateNumbers, fadeAllNumbers, fitText, utf8Head, beginHeadline, setReward, showHeadline, endHeadline, updateHeadline, clearHeadline, buildSpark, buildCoin, buildWhelp, ringFx, flashFx, flash, canPunch, punch, burst, coinFlight, coinsFlying, updateCoins, whelpFlight, chainReset, popPortrait, milestoneFx, silhouette, bossGlow, newAbility, bossRingColor, setNumberColor
  local J = {}
  Mrgl.UI.Juice = J
  local U = Mrgl.U
  function K()
    return Mrgl.UI.Kit
  end
  function C()
    return Mrgl.UI.Kit.C
  end
  function Core()
    return Mrgl.Core
  end
  function W()
    return Mrgl.UI.Main.w
  end
  function M()
    return Mrgl.UI.Main
  end
  function S()
    return Mrgl.Data.Strings
  end
  function calm()
    return Mrgl.db.settings.calm
  end
  function visible()
    return MrglSquadFrame ~= nil and MrglSquadFrame:IsVisible()
  end
  local glowOwner -- current one-glow element
  local lastStage = 0
  -- ------------------------------------------------------------ L2 number lanes (relative to the enemy centre)
  -- r3 L7: lane R in the free field under the boss button (x +80, start y -47, 13 px: j1 A2 un-rounded numbers sit up to
  -- 1 px higher, 14 px touched the boss +n%).
  -- r4 L13: lanes R and L show exactly one number each: hits within 0.3 s (R) / 0.5 s (L) add up on it and pop
  -- (1.15 -> 1 in 0.1 s); a new number hides the old one at once, without a fade (hard).
  -- r3 L8: lane A inside the icon (y +24, 8 px, FRIZ 22); lane C centred, see number() for the rush rules.
  -- j1 A1 #28: pop = first pop of a new number, bpop = pop of a number that takes a bundled hit (C 1.15, A 1.2, R/L 1.05)
  local LANES = { R = { font = "FRIZ", size = 13, c = "white", x = 80, y = -47, dist = 13, dur = 0.5, fade = 0.25, cap = 1, pool = 2, pop = 1, bpop = 1.05, hard = true, bundle = 0.3, popDur = 0.1 }, L = { font = "ARIALN", size = 11, c = "squad", x = -66, y = -38, dist = 24, dur = 0.8, fade = 0.45, cap = 1, pool = 2, pop = 1, bpop = 1.05, hard = true, bundle = 0.5, popDur = 0.1 }, C = { font = "FRIZ", size = 20, c = "crit", x = 0, y = 6, dist = 22, dur = 0.7, fade = 0.4, cap = 2, pool = 3, pop = 1.15, bpop = 1.15, bundle = 0.3 }, A = { font = "FRIZ", size = 22, c = "ability", x = 0, y = 24, dist = 8, dur = 1.0, fade = 0.65, cap = 1, pool = 2, pop = 1.2, bpop = 1.2 } }
  local LANE_KEYS = { "R", "L", "C", "A" }
  J.LANES = LANES -- j1: read by the motion checks (j1-motion.json row 28)
  local BUNDLE = 0.15; local KILL_FADE = 0.08
  -- r3 L8 rush (LEEROY or candle buff): lane C keeps one number, hits within 0.5 s add up and pop 1.1 -> 1 in 0.1 s (j1 #28)
  local RUSH_BUNDLE = 0.5; local RUSH_POP = 1.1; local RUSH_POP_DUR = 0.1; local POP_DUR = 0.15
  J.RUSH_POP = RUSH_POP
  local C_UNDER_A = -14; local C_SECOND = 16
  function rush()
    return Core().Combat.LeeroyActive() or Core().Combat.CandleActive()
  end
  local bossPause = false -- after a boss kill until the next spawn: no numbers (L2)
  local shownQueued = 0; local skipHits = 0
  local squadT = 0; local whelpSum = 0; local whelpT = 0
  function laneColor(l)
    if l.c == "squad" then
      return { 0.75, 0.75, 0.75, 1 }
    end
    return C()[l.c]
  end
  function buildNumber(key, i)
    local l = LANES[key]
    local f = CreateFrame("Frame", ("MrglSquadNumber" .. key) .. i, W().numbers)
    M().SetLevel(f, M().LEVEL.numbers)
    f:SetSize(120, 30)
    f.mrglLane = key
    local font = K().FRIZ
    if l.font == "ARIALN" then
      font = K().ARIALN
    end
    f.text = K().Text(f, font, l.size, laneColor(l), "OUTLINE")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.text:SetJustifyH("CENTER")
    f.pop = f:CreateAnimationGroup()
    f.popScale = K().AddScale(f.pop, l.pop, 1, 0.15, 0, 1, "OUT")
    f:Hide()
    return { f = f, key = key, active = false, live = false, t = 0, fa = 0, k = 0, x = 0, dy = 0, born = 0, amount = 0, crit = false }
  end
  function placeNumber(r)
    local l = LANES[r.key]
    local p = math.min(1, r.t / l.dur)
    local y = l.y + r.dy + l.dist * (1 - (1 - p) * (1 - p))
    local a = 1 -- j5 K1: the fade runs on its own clock (fa): an own click re-lights the R number, it does not move back
    if r.fa > l.fade then
      a = math.max(0, 1 - (r.fa - l.fade) / (l.dur - l.fade))
    end
    if not r.live then
      a = a * math.max(0, 1 - r.k / KILL_FADE)
    end
    -- j1 A2: a moving number is not rounded to whole units (rounding made it step); only static lines are (W5)
    r.f:SetPoint("CENTER", W().enemy, "CENTER", r.x, y)
    r.f:SetAlpha(a)
  end
  function stopNumber(r)
    r.active = false
    r.live = false
    r.f:Hide()
    if r.f.pop:IsPlaying() then
      r.f.pop:Stop()
    end
  end
  function killNumber(r, dur)
    if r.live then
      r.live = false
      r.k = KILL_FADE - dur
      if r.k < 0 then
        r.k = 0
      end
    end
  end
  -- amount on a lane: bundles hits within BUNDLE seconds (calm: R one number per 0.3 s), keeps the lane cap
  -- j5 K1/K1+ (Jan: "bei jedem Klick soll auch feedback kommen, dass man angreift"): own = an own click. It shows in
  -- the boss pause too, and on lane R a bundled click re-lights the number (alpha back to 1, no pop, no move).
  -- j5 K5 (c): in fast mode a crit goes to lane R (small, beside the face, crit colour), so at most 2 numbers, none on
  -- the face.
  function setNumberColor(r, crit)
    r.crit = crit
    local c = laneColor(LANES[r.key])
    if crit then
      c = C().crit
    end
    K().SetTextColor(r.f.text, c)
  end
  function number(key, amount, own, crit)
    if (bossPause and own ~= true) or not visible() then
      return
    end
    local l = LANES[key]
    local now = GetTime()
    local inRush = key == "C" and rush()
    local win = BUNDLE
    if l.bundle ~= nil then
      win = l.bundle
    end -- crits: 0.3 s, so two live crits never cover each other
    if inRush then
      win = RUSH_BUNDLE
    end
    if key == "R" and calm() then
      win = 0.3
    end
    local cap = l.cap
    if inRush then
      cap = 1
    end
    local quietN = (key == "C" or key == "R") and J.FastFarm() -- j4 H2 (c): fast mode: <= 2 click numbers, no pop
    if quietN and key == "C" then
      cap = 1
    end
    local pool = l.list
    local newest; local oldest; local live = 0
    for i = 1, U.Len(pool) do
      local r = U.At(pool, i)
      if r.live then
        live = live + 1
        if newest == nil or r.born > newest.born then
          newest = r
        end
        if oldest == nil or r.born < oldest.born then
          oldest = r
        end
      end
    end
    if newest ~= nil and now - newest.born < win then
      newest.amount = newest.amount + amount
      newest.f.text:SetText(U.Short(newest.amount))
      if key == "R" then -- j5 K1: re-light (the bundle stays where it is); a crit inside turns it crit-coloured
        newest.fa = 0
        if crit == true and not newest.crit then
          setNumberColor(newest, true)
        end
      end
      if quietN then
        return
      end
      local pd = POP_DUR
      if l.popDur ~= nil then
        pd = l.popDur
      end
      if inRush then
        K().ScaleFrom(newest.f.popScale, RUSH_POP, RUSH_POP)
        newest.f.popScale:SetDuration(RUSH_POP_DUR)
      else
        K().ScaleFrom(newest.f.popScale, l.bpop, l.bpop)
        newest.f.popScale:SetDuration(pd)
      end
      K().Replay(newest.f.pop)
      return
    end
    if l.hard == true then
      -- r4 L13: hard lanes (R, L): every number of the lane goes at once, also one still fading out
      for hs = 1, U.Len(pool) do
        local rh = U.At(pool, hs)
        if rh.active then
          stopNumber(rh)
        end
      end
    elseif live >= cap and oldest ~= nil then
      killNumber(oldest, KILL_FADE)
    end
    if quietN and key == "C" then -- j4 H2 (c): the one crit number replaces the old one at once
      for qc = 1, U.Len(pool) do
        local rq = U.At(pool, qc)
        if rq.active then
          stopNumber(rq)
        end
      end
    end
    if key == "A" then
      -- the ability number takes the middle: running crits give way at once (L8: no overlap)
      local cp = LANES.C.list
      for c = 1, U.Len(cp) do
        local rc = U.At(cp, c)
        if rc.active then
          stopNumber(rc)
        end
      end
    end
    local other -- a number of this lane that stays live next to the new one
    for o = 1, U.Len(pool) do
      local ro = U.At(pool, o)
      if ro.live then
        other = ro
      end
    end
    local use
    for j = 1, U.Len(pool) do
      local q = U.At(pool, j)
      if not q.active then
        use = q
        break
      end
    end
    if use == nil then
      for k = 1, U.Len(pool) do
        local q2 = U.At(pool, k)
        if not q2.live and (use == nil or q2.born < use.born) then
          use = q2
        end
      end
    end
    if use == nil then
      return
    end
    if use.active then
      stopNumber(use)
    end
    use.active = true
    use.live = true
    use.t = 0
    use.fa = 0
    use.k = 0
    use.born = now
    use.amount = amount
    if key == "R" or use.crit then
      setNumberColor(use, key == "R" and crit == true)
    end
    use.x = l.x
    use.dy = 0
    if key == "C" then
      if laneLive("A") then
        use.dy = C_UNDER_A - l.y
      -- L8: under a live MRGL/LEEROY number the crit starts at y -14
      elseif other ~= nil then
        use.dy = C_SECOND
      end -- L8: outside the rush the second crit starts 16 px higher
      -- The older crit (bundle 0.3 s / rush 0.5 s) has already risen 15-22 px and would sit right under the new one
      -- (measured overlap up to 100 %), so it goes at once instead of fading: never two crits on top of each other.
      for oc = 1, U.Len(pool) do
        local rc2 = U.At(pool, oc)
        if rc2.active and rc2 ~= use then
          stopNumber(rc2)
        end
      end
    end
    use.f.text:SetText(U.Short(amount))
    use.f:Show()
    placeNumber(use)
    use.f.popScale:SetDuration(POP_DUR)
    if l.pop > 1 and not quietN then
      K().ScaleFrom(use.f.popScale, l.pop, l.pop)
      K().Replay(use.f.pop)
    elseif use.f.pop:IsPlaying() then
      use.f.pop:Stop()
    end
  end
  function laneLive(key)
    local pool = LANES[key].list
    for i = 1, U.Len(pool) do
      if U.At(pool, i).live then
        return true
      end
    end
    return false
  end
  function updateNumbers(dt)
    local fastNow = J.FastFarm()
    for n = 1, 4 do
      local pool = LANES[U.At(LANE_KEYS, n)].list
      for i = 1, U.Len(pool) do
        local r = U.At(pool, i)
        if r.active then
          if fastNow and r.key == "C" and r.live then -- j5 K5 (c): fast mode: off the face
            killNumber(r, KILL_FADE)
          end
          local l = LANES[r.key]
          r.t = r.t + dt
          r.fa = r.fa + dt
          if not r.live then
            r.k = r.k + dt
          end
          if r.fa >= l.dur or not r.live and r.k >= KILL_FADE then
            stopNumber(r)
          else
            placeNumber(r)
          end
        end
      end
    end
  end
  -- boss win: all running numbers fade out in 0.1 s
  function fadeAllNumbers(dur)
    for n = 1, 4 do
      local pool = LANES[U.At(LANE_KEYS, n)].list
      for i = 1, U.Len(pool) do
        local r = U.At(pool, i)
        if r.active then
          killNumber(r, dur)
        end
      end
    end
  end
  -- ------------------------------------------------------------ L3 headline (one at a time, queue of 3)
  -- j1 G: the gold moment (boss = "victory", rare/quest/level/zone = "bonus"): title FRIZ 16 gold, amount rolls 0.6 s,
  -- stands 1.4 s (dur 2.0 from the show), fades out in 0.4 s (out). j1b G1: the amount stands in the same row (bn.layout)
  local HL = { leeroy = { size = 16, flags = "OUTLINE", c = "leeroy", dur = 1.0 }, victory = { size = 16, flags = "", c = "gold", dur = 2.0, out = 0.4 }, bonus = { size = 16, flags = "", c = "gold", dur = 2.0, out = 0.4 }, zone = { size = 18, flags = "OUTLINE", c = "gold", dur = 2.0 }, retreat = { size = 14, flags = "OUTLINE", c = "text", dur = 1.2 }, rare = { size = 14, flags = "OUTLINE", c = "rare", dur = 1.2 }, tide = { size = 16, flags = "", c = "gold", dur = 2.0, out = 0.4 } } -- New Tide F/T: like victory without an amount, alpha only
  local HL_W = 220; local HL_OUT = 0.25; local REWARD_ROLL = 0.6
  local hic = { size = 20, gap = 6 } -- tide1b T3: a milestone line's icon left of its text (tex, fade)
  J.hic = hic
  local hq = {  }; local hcur
  local hf; local hfs; local hIn; local hOut; local hreward
  -- tide1c C1/C8: fast farming = kills per second over the last 2 s, on at 1.5, off at 1.0 (hysteresis). While on, a
  -- normal kill swaps the enemy icon without the die/spawn fade, and headlines of these kinds come at most every 8 s, only
  -- on an empty row (the rest is dropped, never queued; a dropped gold moment only rolls the head's gold)
  -- swap = the last kill skipped its die fade, so its spawn skips the spawn fade too
  -- j4 H2 (Jan: "es vibriert dann alles und flackert"): fast mode by enemy lifetime. On when the mean lifetime of the
  -- last N normal kills is < LIFE_ON s or at >= RATE kills/s (over WIN s); off when the mean (with the living enemy's
  -- age once it is older than the mean) is > LIFE_OFF s and the rate is below RATE. The first BOSS_T s after a boss win
  -- always count (the next stages are trivial). Boss kills do not count as a lifetime.
  local ff = { times = {}, lives = {}, born = -1, on = false, swap = false, WIN = 5, RATE = 0.6, N = 5, LIFE_ON = 1.5, LIFE_OFF = 2.5,
    BOSS_T = 3, bossT = -100, GAP = 8, last = -100, punchT = -100, PUNCH_GAP = 0.6,
    kinds = { victory = true, bonus = true, rare = true, zone = true } }
  -- the state now (between kills too: a pause or a boss fight ends fast farming)
  ff.check = function()
    local now = GetTime()
    while U.Len(ff.times) > 0 and now - U.At(ff.times, 1) > ff.WIN do
      U.Remove(ff.times, 1)
    end
    local rate = U.Len(ff.times) / ff.WIN
    local n, sum = U.Len(ff.lives), 0
    for i = 1, n do
      sum = sum + U.At(ff.lives, i)
    end
    local life = 99
    if n >= 3 or (ff.on and n > 0) then -- j4 H5: an early start (click kill) keeps its own mean
      life = sum / n
    end
    if ff.born >= 0 and now - ff.born > life then -- a pause or a long fight counts as it runs
      life = now - ff.born
    end
    if not ff.on and ((n >= 3 and life < ff.LIFE_ON) or rate >= ff.RATE) then
      ff.on = true
    end
    if ff.on and life > ff.LIFE_OFF and rate < ff.RATE then
      ff.on = false
    end
    return ff.on or now - ff.bossT < ff.BOSS_T
  end
  ff.kill = function(boss, click)
    local now = GetTime()
    if boss ~= true then
      U.Insert(ff.times, now)
      if ff.born >= 0 then
        U.Insert(ff.lives, now - ff.born)
      end
      while U.Len(ff.lives) > ff.N do
        U.Remove(ff.lives, 1)
      end
      -- j4 H5 (UX-B S2): a click kill of an enemy younger than LIFE_ON s is fast mode at once (the first one-shot kill
      -- has no die and spawn fade)
      if click == true and ff.born >= 0 and now - ff.born < ff.LIFE_ON then
        ff.on = true
      end
    end
    ff.born = -1
    ff.swap = ff.check()
  end
  ff.spawn = function()
    ff.born = GetTime()
  end
  -- j4 H2 (b): punch and click flash: never on the killing hit (M.Hit punches after the click; a crit checks the HP),
  -- at most one per PUNCH_GAP s, none in fast mode
  ff.punchOk = function()
    if ff.check() or GetTime() - ff.punchT < ff.PUNCH_GAP or not canPunch() or Mrgl.db.enemyHp <= 0 then
      return false
    end
    ff.punchT = GetTime()
    return true
  end
  ff.quiet = function()
    return ff.check() and (GetTime() - ff.last < ff.GAP or hcur ~= nil or U.Len(hq) > 0)
  end
  ff.reset = function()
    ff.times = {}
    ff.lives = {}
    ff.born = -1
    ff.on = false
    ff.swap = false
    ff.bossT = -100
  end
  J.FastFarm = function()
    return ff.check()
  end
  J.FastFarmReset = function()
    ff.reset()
  end -- tests: a state that farmed fast before
  local bn = { outB = nil } -- j1 G: the 0.4-s fade out of the gold moment, helpers (J.Bonus); j1b G1: no line 3 (no room)
  -- j4 H1 (Jan: "die Popup Texte kommen nicht hinterher, besonders nach einem Boss kill"): the queue never runs late.
  -- rank "tide" = the New Tide moment and the trophy (in order, never dropped: a companion is never held forever) and
  -- LEEROY; "high" = boss victory (3), a gold moment with a rare kill (2), the rare spawn (1); "low" = zone line, the other
  -- gold moments (level, quest, zone), retreat.
  -- - coalesce: one pending low line (the newest; a gold moment merges into the pending one, bn.alive) and one pending
  --   high line (a lower one gives way to a higher or equal one, never the other way round)
  -- - priority: a high or tide line drops the pending low line
  -- - after a boss: while a victory runs or waits, at most ONE more line waits (rec.after, the newest; a waiting zone line
  --   only gives way to a newer zone line); it shows the current state (a zone line takes the current zone's name)
  -- - max age: a low line older than AGE s at its turn is dropped (not the one after a boss: it waited on purpose);
  --   the rare spawn line only shows while a rare is the enemy
  -- - min time: a line holds >= MIN s; with a line waiting it goes out then (tide lines keep their 2 s)
  -- A dropped zone line still switches the zone (tide1c C15), a dropped companion line still shows it (New Tide F).
  local hl = { MIN = 1.2, AGE = 1.5, PRIO = { victory = 3, bonus = 2, rare = 1 } }
  hl.rank = function(rec)
    if rec.kind == "tide" or rec.kind == "leeroy" then
      return "tide"
    end
    if rec.kind == "victory" or rec.kind == "rare" then
      return "high"
    end
    if rec.kind == "bonus" and rec.b ~= nil and rec.b.rares > 0 then
      return "high"
    end
    return "low"
  end
  hl.drop = function(rec)
    endHeadline(rec) -- a dropped victory / retreat still brings the boss button back (when no other one waits)
    if rec.kind == "zone" then
      M().st.zoneDefer = false
      M().SetZone(false)
    end
    if rec.comp ~= nil then
      M().TideShow(rec.comp)
    end
    if rec == bn.rec then
      bn.rec = nil
    end
  end
  -- takes the pending lines that match (after = true: the line after a boss; else rank rk, not after) out of the queue
  hl.take = function(rk, after)
    local keep, out = {}, nil
    for i = 1, U.Len(hq) do
      local q = U.At(hq, i)
      local hit
      if after then
        hit = q.after == true
      else
        hit = q.after ~= true and hl.rank(q) == rk
      end
      if hit then
        out = q
      else
        U.Insert(keep, q)
      end
    end
    hq = keep
    return out
  end
  -- returns rec, or nil when it gives way at once
  hl.enqueue = function(rec)
    local rk = hl.rank(rec)
    local old
    if rk == "tide" then
      old = hl.take("low", false)
      if old ~= nil then
        hl.drop(old)
      end
      U.Insert(hq, rec)
      return rec
    end
    local boss = hcur ~= nil and hcur.kind == "victory"
    for i = 1, U.Len(hq) do
      if U.At(hq, i).kind == "victory" then
        boss = true
      end
    end
    if boss and rec.kind ~= "victory" then
      old = hl.take("", true)
      if old ~= nil and old.kind == "zone" and rec.kind ~= "zone" then
        U.Insert(hq, old)
        hl.drop(rec)
        return nil
      end
      if old ~= nil then
        hl.drop(old)
      end
      rec.after = true
      U.Insert(hq, rec)
      return rec
    end
    old = hl.take("low", false)
    if old ~= nil then
      hl.drop(old)
    end
    if rk == "high" then
      old = hl.take("high", false)
      if old ~= nil and hl.PRIO[old.kind] > hl.PRIO[rec.kind] then
        U.Insert(hq, old)
        hl.drop(rec)
        return nil
      end
      if old ~= nil then
        hl.drop(old)
      end
    end
    U.Insert(hq, rec)
    return rec
  end
  -- the next line to show (stale ones are dropped on the way), or nil
  hl.next = function()
    while U.Len(hq) > 0 do
      local rec = U.Remove(hq, 1)
      local ok = true
      if rec.kind == "rare" then
        ok = Core().Combat.Enemy().kind == "rare" and not Mrgl.db.boss.active
      end
      if hl.rank(rec) == "low" and rec.after ~= true and GetTime() - rec.born > hl.AGE then
        ok = false
      end
      if ok then
        if rec.kind == "zone" then
          rec.text = Core().Combat.Zone(Mrgl.db.stage).name
        end
        return rec
      end
      hl.drop(rec)
    end
    return nil
  end
  J.HeadlineQueue = function() -- tests: the waiting lines
    local out = {}
    for i = 1, U.Len(hq) do
      U.Insert(out, U.At(hq, i).text)
    end
    return out
  end
  -- shrink to 11 px, then cut with an ellipsis (the full text stays in the enemy tooltip, N7)
  -- j1b G1: maxW = the room left of the amount in a gold moment (default HL_W). j1c M3: minS = the smallest size (default 11)
  function fitText(fs, size, flags, text, maxW, minS)
    local s = size
    local mw = HL_W
    if maxW ~= nil then
      mw = maxW
    end
    local lo = 11
    if minS ~= nil then
      lo = minS
    end
    K().SetFont(fs, K().FRIZ, s, flags)
    fs:SetText(text)
    while fs:GetStringWidth() > mw and s > lo do
      s = s - 1
      K().SetFont(fs, K().FRIZ, s, flags)
    end
    if fs:GetStringWidth() <= mw then
      return
    end
    local n = strlenutf8(text)   -- characters, not bytes (port-plan 2.3)
    while n > 1 do
      n = n - 1
      fs:SetText(utf8Head(text, n) .. "...") -- port p2: ASCII dots (U+2026 may be missing in FRIZQT__)
      if fs:GetStringWidth() <= mw then
        return
      end
    end
  end
  -- the first n UTF-8 characters of t (JS text.substring(0, n) for text without surrogate pairs)
  function utf8Head(t, n)
    local i = 1
    local chars = 0
    local len = string.len(t)
    while i <= len and chars < n do
      local b = string.byte(t, i)
      local step = 1
      if b >= 240 then
        step = 4
      elseif b >= 224 then
        step = 3
      elseif b >= 192 then
        step = 2
      end
      i = i + step
      chars = chars + 1
    end
    return string.sub(t, 1, i - 1)
  end
  J.FitText = fitText
  -- tide1c C14: no boss quote headline any more (no flavour quotes)
  -- r3 F2: the victory headline carries the reward "+{gold}" under it, rolling up from 0 in 0.5 s.
  -- j1 G: returns the record (the gold moment merges into it, W2). j1b G1: alt = the shorter title when the text
  -- would be cut next to the amount (boss: the name without "defeated!")
  -- j1c M3: short = the boss's shortName title, tried before alt ("Victory!", the last fallback)
  J.Headline = function(kind, text, gold, alt, short)
    if not visible() then
      return nil
    end
    -- tide1c C8; j4 H1: the zone line after a boss win is the one "current state" line: the 3 s after the win alone
    -- (H2 d) do not hold it back, only real fast farming does
    if ff.kinds[kind] == true and (kind ~= "zone" or (ff.check() and ff.on)) then
      if ff.quiet() then
        return nil
      end
      ff.last = GetTime()
    end
    local rec = { kind = kind, text = text, phase = "nameOut", t = 0, wait = 0, gold = 0, roll = 0, from = 0, life = 0, born = GetTime() }
    if kind == "bonus" then -- j4: the bundle decides the rank (a rare kill: high)
      rec.b = bn.nextB
      bn.nextB = nil
    end
    if gold ~= nil then
      rec.gold = gold
    end
    if alt ~= nil then
      rec.alt = alt
    end
    if short ~= nil then
      rec.short = short
    end
    local cut = false
    if hcur ~= nil then
      -- LEEROY never waits (its hit lands 0.3 s after the button)
      if kind == "leeroy" and hcur.kind ~= "victory" and hcur.kind ~= "zone" then
        cut = true
      end
    end
    if cut and (hcur.phase == "nameOut" or hcur.phase == "wait") then
      hcur = rec
      rec.wait = 0
      M().st.nameTarget = 0
      return rec
    end
    if cut then
      if hIn:IsPlaying() then
        hIn:Stop()
      end
      if hOut:IsPlaying() then
        hOut:Stop()
      end
      if bn.outB:IsPlaying() then
        bn.outB:Stop()
      end
      hcur = nil
      showHeadline(rec)
      return rec
    end
    if kind == "leeroy" then
      local front = { rec } -- Lua: table.insert(hq, 1, rec)
      do
        local i = 1
        while i <= U.Len(hq) do
          U.Insert(front, U.At(hq, i))
          i = i + 1
        end
      end
      hq = front
    elseif hl.enqueue(rec) == nil then -- j4 H1 (tide1c C15 in hl.drop)
      return nil
    end
    if hcur == nil then
      local nx = hl.next()
      if nx ~= nil then
        beginHeadline(nx)
      end
    end
    return rec
  end
  function beginHeadline(rec)
    hcur = rec
    if rec.wait > 0 then
      rec.phase = "wait"
      M().st.nameTarget = 1
      return
    end
    M().st.nameTarget = 0
    if M().st.nameA <= 0 then
      showHeadline(rec)
    else
      rec.phase = "nameOut"
    end
  end
  -- j1 G: the amount rolls from rec.from to rec.gold in REWARD_ROLL (ease-out); a merge restarts it from the shown value
  function setReward(rec)
    if (rec.kind ~= "victory" and rec.kind ~= "bonus") or rec.gold <= 0 then
      hreward:SetText("")
      return
    end
    hreward:SetText(U.Fill(S().PLUS, { v = U.Short(bn.rewardShown(rec)) }))
  end
  function showHeadline(rec)
    J.CoinsAbort() -- r5 C1
    local st = HL[rec.kind]
    hcur = rec
    rec.phase = "hold"
    rec.t = 0
    rec.roll = 0
    rec.life = 0
    M().st.nameTarget = 0
    bn.layout(rec) -- j1b G1: title (and the amount of a gold moment) in the row
    K().SetTextColor(hfs, C()[st.c])
    if st.flags == "" then
      hfs:SetShadowOffset(1, -1)
    else
      hfs:SetShadowOffset(0, 0)
    end
    if hOut:IsPlaying() then
      hOut:Stop()
    end
    if bn.outB:IsPlaying() then
      bn.outB:Stop()
    end
    hf:SetAlpha(0)
    K().Replay(hIn)
    if rec.kind == "zone" then
      M().st.zoneDefer = false
      M().SetZone(false)
    end -- tint crossfade in parallel
    if rec.kind == "victory" then
      silhouette()
    end
    if rec.kind == "victory" or rec.kind == "bonus" then
      bn.shown(rec)
    end -- j1 G: sparks
    if rec.comp ~= nil then
      M().TideShow(rec.comp)
    end -- New Tide F: a companion / the Anyfin look comes with its line
  end
  function endHeadline(rec)
    if rec.kind == "victory" or rec.kind == "retreat" then
      local more = false
      for i = 1, U.Len(hq) do
        local q = U.At(hq, i)
        if q.kind == "victory" or q.kind == "retreat" then
          more = true
        end
      end
      if not more then
        M().st.bossHide = false
      end
    end
    if rec.kind == "zone" then
      M().st.zoneDefer = false
    end
  end
  function updateHeadline(dt)
    if hcur == nil then
      local nx = hl.next()
      if nx ~= nil then
        beginHeadline(nx)
      else
        M().st.nameTarget = 1
      end
      return
    end
    local rec = hcur
    if rec.phase == "wait" then
      rec.wait = rec.wait - dt
      if rec.wait <= 0 then
        rec.wait = 0
        beginHeadline(rec)
      end
      return
    end
    if rec.phase == "nameOut" then
      if M().st.nameA <= 0 then
        showHeadline(rec)
      end
      return
    end
    rec.t = rec.t + dt
    rec.life = rec.life + dt
    if rec.phase == "hold" and rec.roll <= REWARD_ROLL then
      rec.roll = rec.roll + dt
      setReward(rec)
    end
    if rec.phase == "hold" and rec.spark == true and rec.roll > REWARD_ROLL then
      rec.spark = false
      bn.burst()
    end -- j1c M2
    -- j4 H1: with a line waiting, a shown line goes after MIN s (tide lines keep their time)
    local due = HL[rec.kind].dur
    if U.Len(hq) > 0 and rec.kind ~= "tide" then
      due = math.min(due, hl.MIN)
    end
    if rec.phase == "hold" and rec.t >= due then
      rec.phase = "out"
      rec.t = 0
      K().Replay(bn.outGroup(rec))
    elseif rec.phase == "out" and rec.t >= bn.outDur(rec) then
      hcur = nil
      hf:SetAlpha(0)
      hreward:SetText("")
      endHeadline(rec)
      local nx2 = hl.next()
      if nx2 ~= nil then
        showHeadline(nx2)
      else
        M().st.nameTarget = 1
      end
    end
  end
  function clearHeadline()
    hq = {  }
    hcur = nil
    if hIn:IsPlaying() then
      hIn:Stop()
    end
    if hOut:IsPlaying() then
      hOut:Stop()
    end
    if bn.outB:IsPlaying() then
      bn.outB:Stop()
    end
    hf:SetAlpha(0)
    hreward:SetText("")
    local st = M().st
    st.nameTarget = 1
    st.nameA = 1
    W().name:SetAlpha(1)
    st.bossHide = false
    if st.zoneDefer then
      st.zoneDefer = false
      M().SetZone(true)
    end
  end
  J.RewardText = function()
    if hcur == nil or hcur.phase ~= "hold" then
      return ""
    end
    return hreward:GetText() or ""
  end
  J.HeadlineText = function()
    if hcur == nil or hcur.phase == "nameOut" or hcur.phase == "wait" then
      return ""
    end
    return hfs:GetText() or ""
  end
  -- ------------------------------------------------------------ j1 G / W2: the gold moment (J.Bonus)
  -- One part for rare kill, boss victory and the in-world events (W1): the title in the name row (headline), "+{gold}"
  -- right of it in the same row (j1b G1: "Level 13!  +964", never on the enemy icon) rolling up in 0.6 s (ease-out),
  -- 8 sparks once from the amount (A1 #6), the gold in the head rolling up at the same time.
  -- j1b G1: the enemy icon fades to 0.35 while a bonus moment stands (J.EnemyDim, Main.OnUpdate); the boss victory
  -- leaves it alone (the next enemy spawns 1.0 s after the win and is never dimmed). Line 3 is gone (no room).
  -- W2: world gold is in the core at once; only the moment waits: for a visible window, no combat, no popup. All that
  -- arrives within BN.BUNDLE s or waits in the queue is ONE moment (sum, title by rank Level > Quest > Zone > Rare,
  -- quests counted). Minimized: no headline, no sparks; the head rolls the gold and "+{gold}" stands 2 s next to it.
  -- Until its moment plays, the gold is held out of the head (J.HeldGold, like the offline popup goldHold).
  -- The helpers live in bn (Lua: local and upvalue limits of this chunk).
  local BN = { BUNDLE = 3, SPARKS = 8, SPARK_R = 24, SPARK_RY = 0.35, SPARK_T = 0.5, SPARK_A = 0.6, SPARK_HALF = 8, PLUS = 2, SWAP = 0.15, ROLL = 0.6, ROLL_OLD = 0.3,
               GAP = 10, EDGE = 4, MARGIN = 8, MIN_PX = 13 } -- j1b G1: sparks flat (y = 0.35 of x: they stay in the row band);
                                    -- GAP = "  " between title and amount; EDGE = 2 px each side of the pair for outline and
                                    -- shadow. j1c M3: the pair keeps >= MARGIN px to the row edges, the title never < MIN_PX
  bn.wait = nil -- the waiting bundle { gold, quests, level, zones, rares }
  bn.rec = nil -- the last "bonus" headline record (merge target, W2)
  bn.held = 0 -- gold of the waiting bundle, kept out of the head
  bn.rollT = 0 -- > 0 while the head rolls a moment (0.6 s instead of 0.3 s, Main.OnUpdate)
  bn.ax = HL_W / 2 -- j1c: spark origin x in the row: in the gap, the spark's right edge 1 px left of the amount
  bn.sparks = {}
  bn.plusT = -1
  bn.plusGold = 0

  bn.build = function(f)
    local w = W()
    bn.outB = hf:CreateAnimationGroup()
    K().AddAlpha(bn.outB, 1, 0, HL.bonus.out, 0, 1)
    bn.outB:SetToFinalAlpha(true)
    -- 8 sparks from the amount, once (own frame at the headline level, so the title fade in does not dim them)
    bn.fx = CreateFrame("Frame", "MrglSquadBonusFx", w.headLayer)
    M().SetLevel(bn.fx, M().LEVEL.headline)
    bn.fx:SetAllPoints(f)
    for i = 1, BN.SPARKS do
      local t = K().Glow(bn.fx, "spark", 16, C().gold, "OVERLAY")
      t:SetPoint("CENTER", hf, "LEFT", bn.ax, 0) -- bn.shown moves it to the amount (a fixed point: the roll never drags it)
      t:SetAlpha(0)
      t.anim = t:CreateAnimationGroup()
      -- j1c: a half ring to the left (cos < 0), so no spark ever crosses the amount (it may pass over the title)
      local ang = math.pi / 2 + (i - 0.5) / BN.SPARKS * math.pi
      K().AddMove(t.anim, math.cos(ang) * BN.SPARK_R, math.sin(ang) * BN.SPARK_R * BN.SPARK_RY, BN.SPARK_T, 0, 1, "OUT")
      K().AddAlpha(t.anim, BN.SPARK_A, 0, BN.SPARK_T, 0, 1, "IN")
      U.Insert(bn.sparks, t)
    end
    -- minimized (W2): "+{gold}" ARIALN 12 gold for 2 s, in the head frame (shown while minimized). j1b G1 follow-up:
    -- it takes the pips' place (LEFT of pip 1); the pips (and the boss skull) fade out meanwhile and come back. Restore
    -- at the right stays untouched. A plain swap: alpha only, no motion
    local head = w.head
    if head == nil then
      head = w.content
    end
    bn.plus = K().Text(head, K().ARIALN, 12, C().gold, "")
    bn.plus:SetPoint("LEFT", U.At(w.pips, 1), "LEFT", 0, 0)
    bn.plus:SetText("")
    bn.plus:SetAlpha(0)
  end
  -- the amount on screen: rolls from rec.from to rec.gold in REWARD_ROLL (ease-out); a merge restarts it from here
  bn.rewardShown = function(rec)
    local x = math.min(1, rec.roll / REWARD_ROLL)
    local p = 1 - (1 - x) * (1 - x)
    return math.floor(rec.from + (rec.gold - rec.from) * p)
  end
  bn.isMoment = function(rec)
    return (rec.kind == "victory" or rec.kind == "bonus") and rec.gold > 0
  end
  -- j1b G1: a gold moment is one row "Title  +amount", centred as a pair on the FINAL amount, so the roll (the amount
  -- grows to the right from a fixed LEFT point) never moves the title; the title shrinks/cuts into the room left of
  -- the amount. Every other headline: the title centred, no amount.
  bn.layout = function(rec)
    local st = HL[rec.kind]
    hfs:ClearAllPoints()
    if not bn.isMoment(rec) then
      hreward:SetText("")
      if rec.icon == nil then
        hic.tex:Hide()
        fitText(hfs, st.size, st.flags, rec.text)
        hfs:SetPoint("CENTER", hf, "CENTER", 0, 0)
        return
      end
      -- tide1b T3: icon (20 px, full colour) + text, centred together; the icon fades in 0.4 s (alpha only)
      fitText(hfs, st.size, st.flags, rec.text, HL_W - hic.size - hic.gap)
      local ix = math.floor((HL_W - hic.size - hic.gap - hfs:GetStringWidth()) / 2)
      K().SetIcon(hic.tex, rec.icon)
      hic.tex:ClearAllPoints()
      hic.tex:SetPoint("LEFT", hf, "LEFT", ix, 0)
      hfs:SetPoint("LEFT", hf, "LEFT", ix + hic.size + hic.gap, 0)
      hic.tex:Show()
      K().Replay(hic.fade)
      return
    end
    hic.tex:Hide()
    hreward:SetText(U.Fill(S().PLUS, { v = U.Short(rec.gold) }))
    local aw = hreward:GetStringWidth()
    local room = HL_W - 2 * BN.MARGIN - BN.EDGE - aw - BN.GAP
    fitText(hfs, st.size, st.flags, rec.text, room, BN.MIN_PX)
    local fit = hfs:GetText() == rec.text
    if not fit and rec.short ~= nil then
      fitText(hfs, st.size, st.flags, rec.short, room, BN.MIN_PX)
      fit = hfs:GetText() == rec.short
    end
    if not fit and rec.alt ~= nil then
      fitText(hfs, st.size, st.flags, rec.alt, room, BN.MIN_PX)
    end
    local tw = hfs:GetStringWidth()
    local x = math.floor((HL_W - tw - BN.GAP - aw) / 2)
    hfs:SetPoint("LEFT", hf, "LEFT", x, 0)
    hreward:ClearAllPoints()
    hreward:SetPoint("LEFT", hf, "LEFT", x + tw + BN.GAP, 0)
    bn.ax = x + tw + BN.GAP - BN.SPARK_HALF - 1 -- j1c: from the gap, never over the amount
    setReward(rec)
  end
  -- the gold moment fades out in 0.4 s, every other headline in HL_OUT
  bn.outDur = function(rec)
    local o = HL[rec.kind].out
    if o == nil then
      return HL_OUT
    end
    return o
  end
  bn.outGroup = function(rec)
    if HL[rec.kind].out == nil then
      return hOut
    end
    return bn.outB
  end
  bn.min = function()
    local Mn = M()
    return Mn.IsMinimized ~= nil and Mn.IsMinimized() == true
  end
  -- W2: a moment plays only on a visible window, out of combat, without the offline popup
  bn.canPlay = function()
    if not visible() then
      return false
    end
    local rt = Core().rt
    return not rt.inCombat and not rt.popup
  end
  bn.newBundle = function()
    return { gold = 0, quests = 0, level = 0, zones = 0, rares = 0 }
  end
  bn.add = function(b, kind, gold, n)
    b.gold = b.gold + gold
    if kind == "quest" then
      b.quests = b.quests + 1
    elseif kind == "level" then
      local lv = 1
      if type(n) == "number" then
        lv = n
      end
      b.level = math.max(b.level, lv)
    elseif kind == "zone" then
      b.zones = b.zones + 1
    else
      b.rares = b.rares + 1
    end
  end
  bn.merge = function(into, b)
    into.gold = into.gold + b.gold
    into.quests = into.quests + b.quests
    into.level = math.max(into.level, b.level)
    into.zones = into.zones + b.zones
    into.rares = into.rares + b.rares
  end
  -- title by rank: Level > Quest > Zone > Rare
  bn.title = function(b)
    if b.level > 0 then
      return U.Fill(S().BONUS_LEVEL, { n = b.level })
    end
    if b.quests > 1 then
      return U.Fill(S().BONUS_QUESTS, { n = b.quests })
    end
    if b.quests == 1 then
      return S().BONUS_QUEST
    end
    if b.zones > 0 then
      return S().BONUS_ZONE
    end
    return S().BONUS_RARE
  end
  -- the head rolls the moment's gold in BN.ROLL (Main.OnUpdate reads J.GoldRoll)
  bn.release = function(gold)
    bn.held = math.max(0, bn.held - gold)
    local st = M().st
    local to = math.max(0, Mrgl.db.gold - st.goldHold - bn.held)
    st.goldFrom = st.goldShown
    st.goldT = 0
    st.goldTo = to
    st.goldTarget = to
    bn.rollT = BN.ROLL + 0.1
  end
  -- j1b G1 follow-up, j1c M1 sequential: swap 0..2 (0 = pips, 1 = empty, 2 = "+X"). The pips fade out in SWAP s, then
  -- "+X" fades in in SWAP s; at the end "+X" goes first, then the pips come back. Never both at once
  bn.swapAt = function(t)
    return math.max(0, math.min(2, t / BN.SWAP, (BN.PLUS - t) / BN.SWAP))
  end
  bn.swapSet = function(s)
    local w = W()
    local a = math.max(0, 1 - s)
    bn.plus:SetAlpha(math.max(0, s - 1))
    for i = 1, U.Len(w.pips) do
      U.At(w.pips, i):SetAlpha(a)
    end
    w.bossMark:SetAlpha(a)
    w.tideMark:SetAlpha(a) -- New Tide H: the TideMark stands at the pips' place and swaps like them
  end
  bn.showPlus = function(gold)
    if bn.plusT >= 0 then
      bn.plusGold = bn.plusGold + gold
      bn.plusT = bn.swapAt(bn.plusT) * BN.SWAP -- a merge keeps the swap where it is (no flicker) and holds again
    else
      bn.plusGold = gold
      bn.plusT = 0
    end
    bn.plus:SetText(U.Fill(S().PLUS, { v = U.Short(bn.plusGold) }))
    bn.swapSet(bn.swapAt(bn.plusT))
  end
  bn.plusUpdate = function(dt)
    if bn.plusT < 0 then
      return
    end
    bn.plusT = bn.plusT + dt
    if bn.plusT >= BN.PLUS or not bn.min() then
      bn.plusT = -1
      bn.swapSet(0)
      bn.plus:SetText("")
      return
    end
    bn.swapSet(bn.swapAt(bn.plusT))
  end
  -- a waiting or running moment takes more: still queued, or on screen for less than BN.BUNDLE s
  bn.alive = function(rec)
    if rec == nil then
      return false
    end
    if rec == hcur then
      return rec.phase ~= "out" and (rec.phase ~= "hold" or rec.life < BN.BUNDLE)
    end
    for i = 1, U.Len(hq) do
      if U.At(hq, i) == rec then
        return true
      end
    end
    return false
  end
  bn.play = function(b)
    bn.release(b.gold)
    if bn.min() then
      bn.showPlus(b.gold)
      return
    end
    local rec = bn.rec
    if bn.alive(rec) then
      local onScreen = rec == hcur and rec.phase == "hold"
      local from = rec.from
      if onScreen then
        from = bn.rewardShown(rec)
      end
      bn.merge(rec.b, b)
      rec.gold = rec.b.gold
      rec.text = bn.title(rec.b)
      if onScreen then
        rec.from = from
        rec.roll = 0
        rec.t = 0
        bn.sparksStop() -- j1c M2: sparks still in flight would cross the new count-up (not burst yet: they wait again)
        bn.layout(rec)
      end
      return
    end
    if ff.quiet() then
      return
    end -- tide1c C8: the gold is released (the head rolls), no line
    local nb = bn.newBundle()
    bn.merge(nb, b)
    bn.nextB = nb -- j4: read by J.Headline (the rank needs the bundle before the line queues)
    bn.rec = J.Headline("bonus", bn.title(nb), nb.gold)
    bn.nextB = nil
    if bn.rec ~= nil then
      bn.rec.b = nb
    end
  end
  -- a gold moment comes on screen (showHeadline): the sparks wait for the count-up (j1c M2: updateHeadline
  -- bursts them once rec.roll is past REWARD_ROLL, so they never cross a counting amount; a merge restarts the wait)
  bn.shown = function(rec)
    rec.spark = not calm()
  end
  -- 8 sparks once from the gap left of the final amount, in a half ring to the left (not in calm mode: rec.spark stays false)
  bn.burst = function()
    for i = 1, U.Len(bn.sparks) do
      local t = U.At(bn.sparks, i)
      t:ClearAllPoints()
      t:SetPoint("CENTER", hf, "LEFT", bn.ax, 0)
      K().Replay(t.anim)
    end
  end
  -- j1c M3: the optional shortName of a boss in Data.Routes (by its name; 15 bosses, once per win)
  bn.shortName = function(name)
    local R = Mrgl.Data.Routes
    local lists = { R.alliance, R.horde, R.shared }
    for j = 1, 3 do
      local list = lists[j]
      for i = 1, U.Len(list) do
        local z = U.At(list, i)
        if z.boss ~= nil and z.boss.name == name then
          return z.boss.shortName
        end
        if z.mini ~= nil and z.mini.name == name then
          return z.mini.shortName -- j1c: mini-bosses too
        end
        if z.rares ~= nil then
          -- enemies1 G9: the named rares too (Ma'ruk, Arnak, Vaelastrasz, Broodlord)
          for r = 1, U.Len(z.rares) do
            if U.At(z.rares, r).name == name then
              return U.At(z.rares, r).shortName
            end
          end
        end
      end
    end
    return nil
  end
  bn.sparksStop = function()
    for i = 1, U.Len(bn.sparks) do
      U.At(bn.sparks, i).anim:Stop()
    end
  end
  -- kind "rare" | "boss" | "quest" | "level" | "zone"; gold = the credited amount (already in db.gold);
  -- n = the new level for "level"; extra = { name } for "boss"
  J.Bonus = function(kind, gold, n, extra)
    if type(gold) ~= "number" or not (gold > 0) then
      return
    end
    if kind == "boss" then
      if not bn.canPlay() then
        return
      end -- the victory is an on-screen moment only (BOSS_WIN)
      bn.release(0)
      if bn.min() then
        bn.showPlus(gold)
        return
      end
      if ff.quiet() then
        return
      end -- tide1c C8: fast farming, the row is taken or a line came < 8 s ago: gold only
      -- j1c M3: "{name} defeated!", else "{shortName} defeated!", else "Victory!" (>= 13 px, >= 8 px margin)
      local short = bn.shortName(extra.name)
      local st2 = nil
      if short ~= nil then
        st2 = U.Fill(S().DEFEATED, { boss = short })
      end
      J.Headline("victory", U.Fill(S().DEFEATED, { boss = extra.name }), gold, S().VICTORY, st2)
      return
    end
    bn.held = bn.held + gold
    if bn.wait == nil then
      bn.wait = bn.newBundle()
    end
    bn.add(bn.wait, kind, gold, n)
    J.BonusTick(0)
  end
  -- every frame from the driver (runs while the window is hidden too): plays the waiting moment when it can
  J.BonusTick = function(dt)
    if bn.rollT > 0 then
      bn.rollT = math.max(0, bn.rollT - dt)
    end
    bn.plusUpdate(dt)
    if bn.wait == nil or not bn.canPlay() then
      return
    end
    local b = bn.wait
    bn.wait = nil
    bn.play(b)
  end
  J.HeldGold = function()
    return bn.held
  end
  J.GoldRoll = function()
    if bn.rollT > 0 then
      return BN.ROLL
    end
    return BN.ROLL_OLD
  end
  J.BonusHeadOnly = function()
    return bn.min() or ff.quiet() -- tide1c C8: also a quiet fast-farming win
  end
  -- j1b G1: the enemy icon is dimmed while a bonus moment stands (not the boss victory: the new enemy stays clear)
  J.EnemyDim = function()
    return hcur ~= nil and hcur.kind == "bonus" and hcur.phase == "hold"
  end
  bn.reset = function()
    bn.wait = nil
    bn.rec = nil
    bn.held = 0
    bn.rollT = 0
    bn.plusT = -1
    bn.swapSet(0)
    bn.plus:SetText("")
    for i = 1, U.Len(bn.sparks) do
      U.At(bn.sparks, i).anim:Stop()
    end
  end
  -- dev / test-ui: the waiting bundle, held gold, the minimized "+X", the enemy dim (j1b G1)
  J.BonusDebug = function()
    local out = { held = bn.held, waiting = 0, waitGold = 0, plus = "", plusAlpha = 0, reward = J.RewardText(), headline = J.HeadlineText(),
                  dim = J.EnemyDim(), iconAlpha = W().enemyIcon:GetAlpha(), counting = false }
    if hcur ~= nil and hcur.phase == "hold" and bn.isMoment(hcur) and hcur.roll <= REWARD_ROLL then
      out.counting = true -- j1c M2
    end
    if bn.wait ~= nil then
      out.waiting = 1
      out.waitGold = bn.wait.gold
    end
    if bn.plusT >= 0 then
      out.plus = bn.plus:GetText() or ""
      out.plusAlpha = bn.plus:GetAlpha()
    end
    return out
  end
  -- ------------------------------------------------------------ New Tide F: the tide moment (alpha only)
  -- 0.0 s the popup closes, the veil (dark blue-green, over the content, under the head row and the headline layer)
  -- fades 0 -> 0.35 (calm 0.25) in 0.3 s; 0.3 s T.Rise(path), the UI is rebuilt behind it (enemy without spawn animation,
  -- the zone tint at once, no zone headline) and the "tide" headline comes; 0.7 s the veil fades out in 0.6 s. Then one
  -- "tide" line per new milestone (a new companion and the Anyfin look come with theirs). No scale, no move, no sparks.
  -- Minimized, hidden or a new db: the veil goes at once, its headlines go; the reset happens all the same (not for a new
  -- db). rt.popup stays true from the popup until the reset. The helpers live in td (upvalue limits).
  local TD = { IN = 0.3, HOLD = 0.7, OUT = 0.6, A = 0.35, A_CALM = 0.25 }
  local td = { t = -1, path = "m", risen = false, debug = false, rising = false, autoMrgl = false }
  J.TD = TD
  td.build = function(f)
    td.veil = CreateFrame("Frame", "MrglSquadTideVeil", f)
    M().SetLevel(td.veil, M().LEVEL.coins + 1) -- between the content layers and the headline (+10)
    td.veil:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -26)
    td.veil:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    td.tex = td.veil:CreateTexture(nil, "ARTWORK")
    td.tex:SetAllPoints(td.veil)
    td.tex:SetColorTexture(0.10, 0.35, 0.45, 1)
    td.tex:SetAlpha(0)
    td.veil:Hide()
    td.veil:SetScript("OnUpdate", function(self, dt)
      td.update(dt)
    end)
    td.veil:SetScript("OnHide", function()
      J.TideAbort()
    end) -- the window hides (combat with "Hide in combat", close)
    td.veil:EnableMouse(true) -- tide1c C7: a second click on New Tide lands on the veil, not on ability 2 or the boss
  end
  td.alpha = function()
    local A = TD.A
    if calm() then
      A = TD.A_CALM
    end
    if td.t < TD.IN then
      return A * td.t / TD.IN
    end
    if td.t < TD.HOLD then
      return A
    end
    return math.max(0, A * (1 - (td.t - TD.HOLD) / TD.OUT))
  end
  td.update = function(dt)
    if td.t < 0 then
      return
    end
    td.t = td.t + dt
    if not td.risen and td.t >= TD.IN then
      td.rise()
    end
    if td.t >= TD.HOLD + TD.OUT then
      td.stop()
      return
    end
    td.tex:SetAlpha(td.alpha())
  end
  td.stop = function()
    td.t = -1
    td.tex:SetAlpha(0)
    td.veil:Hide()
    Core().rt.tideVeil = false -- tide1c C7: Boss.Start and the keys work again
  end
  -- the path's name for TIDE_HEAD
  td.pathName = function(id)
    return Core().Tide.Path(id).name
  end
  -- the reset (once); the TIDE / STAGE / ZONE events it fires are part of the moment (td.rising)
  td.rise = function()
    if td.risen then
      return
    end
    td.risen = true
    if td.debug then -- /mrgl debug tide: no reset, only the line
      if visible() and not bn.min() then
        J.Headline("tide", U.Fill(S().TIDE_HEAD, { path = td.pathName(td.path), n = Mrgl.db.prestige.paths[td.path] }))
      end
      return
    end
    -- a gold moment on screen stays; anything else gives way to the New Tide line
    if hcur == nil or not bn.isMoment(hcur) then
      clearHeadline()
    end
    td.rising = true
    Core().Tide.Rise(td.path, true) -- committed: combat that began under the veil does not cancel it
    td.rising = false
    Core().SetPopup(false)
    ff.reset() -- tide1c C1: a new run starts slow
    Core().Combat.TakeSquadDealt() -- no squad number of the old run after the reset
    fadeAllNumbers(0.1)
    -- behind the veil: the stage-1 enemy without spawn animation, the zone tint at once
    local w = W()
    M().LockEnemy(false)
    if J.die:IsPlaying() then
      J.die:Stop()
    end
    if J.spawn:IsPlaying() then
      J.spawn:Stop()
    end
    if J.punch:IsPlaying() then
      J.punch:Stop()
    end
    w.enemyBack:Hide()
    w.enemy:SetAlpha(1)
    local st = M().st
    st.zoneDefer = false
    st.zone = 0
    M().SetZone(true)
    M().SetEnemyLook()
    M().Refresh()
  end
  -- TIDE (from Rise): mark what is new (tab dot and edges); in the moment, queue the lines and hold the companions
  td.onTide = function(p)
    local P = Mrgl.UI.Panel
    local Td = Core().Tide
    local ms = p.milestones
    for i = 1, U.Len(ms) do
      P.MarkNew(U.At(ms, i))
    end
    if not td.rising or not visible() or bn.min() then
      return
    end
    J.Headline("tide", U.Fill(S().TIDE_HEAD, { path = td.pathName(p.path), n = p.new }))
    for k = 1, U.Len(ms) do
      local id = U.At(ms, k)
      if id == "first" then
        local D = Mrgl.Data.Tide.first
        for j = 1, U.Len(D) do
          td.line(U.At(D, j), "")
        end
      else
        td.line(Td.Def(id), id)
      end
    end
  end
  -- one milestone line: "{name} joins the squad." with a companion (held until the line shows), else "{name} unlocked."
  td.line = function(d, id)
    if d == nil then
      return
    end
    local rec
    if d.companion ~= nil then
      M().TideHold(d.companion)
      rec = J.Headline("tide", U.Fill(S().TIDE_JOIN, { name = d.name }))
      if rec ~= nil then
        rec.comp = d.companion
        rec.icon = d.icon
      end
      return
    end
    if id == "a50" then
      M().TideHold(0)
    end -- the Anyfin look of slot 1 switches with its line
    rec = J.Headline("tide", U.Fill(S().TIDE_MS_NEW, { name = d.name }))
    if rec ~= nil then
      rec.icon = d.icon
    end
    if rec ~= nil and id == "a50" then
      rec.comp = 0
    end
  end
  J.TideLine = function(d, id)
    td.line(d, id)
  end -- tests: one milestone line (with its icon)
  -- Popup.TideGo: the choice is made; debug = true plays the moment without the reset (/mrgl debug tide)
  J.TideMoment = function(path, debug)
    if td.t >= 0 then
      if debug == true then
        return false
      end
      J.TideAbort() -- a debug moment still running ends first
    end
    td.path = path
    td.debug = debug == true
    td.risen = false
    if not visible() or bn.min() then -- no window to play it in: only the reset
      td.rise()
      Core().rt.tideVeil = false
      return false
    end
    Core().rt.tideVeil = true -- tide1c C7: no boss start and no keys until the veil is gone
    td.t = 0
    td.tex:SetAlpha(0)
    td.veil:Show()
    return true
  end
  -- minimized / hidden / back after a long frame: the veil goes at once, the moment's lines go, the reset still happens
  J.TideAbort = function()
    if td.t < 0 then
      return
    end
    if not td.risen then
      td.rise()
    end
    td.stop()
    local keep = {}
    for i = 1, U.Len(hq) do
      local q = U.At(hq, i)
      if q.kind ~= "tide" then
        U.Insert(keep, q)
      end
    end
    hq = keep
    if hcur ~= nil and hcur.kind == "tide" then
      clearHeadline()
    end
    M().TideRelease()
  end
  -- a new db: no reset of the new state, nothing held
  td.reset = function()
    if td.t >= 0 then
      td.stop()
    end
    Core().rt.tideVeil = false
    ff.reset()
    td.autoMrgl = false
    M().TideRelease()
  end
  J.TideDebug = function()
    return { t = td.t, risen = td.risen, veil = td.veil:IsShown(), veilA = td.tex:GetAlpha(), headline = J.HeadlineText() }
  end
  -- T: the trophy line after the victory (queued behind it); never in catch-up, minimized, hidden, in combat or a popup
  td.onTrophy = function(p)
    Mrgl.UI.Panel.MarkNew(p.id)
    if Core().rt.quiet == true or not bn.canPlay() or bn.min() then
      return
    end
    J.Headline("tide", S().NEF_HEAD)
  end
  -- X: /mrgl debug tide | trophy (sandbox), MrglDev.tide() / trophy()
  J.DebugTide = function()
    if not visible() or bn.min() then
      return false
    end
    return J.TideMoment(Mrgl.db.prestige.last, true)
  end
  J.DebugTrophy = function()
    if not bn.canPlay() or bn.min() then
      return false
    end
    td.onTrophy({ id = "nef" })
    return true
  end
  -- ------------------------------------------------------------ pools: sparks, coins, whelps, rings
  local sparks = {  }; local sparkNext = 1
  J.sparkPool = sparks -- j1: read by the motion checks (row 6)
  local coins = {  }; local coinQ = {  }; local coinLast = -10; local coinRR = 0
  -- r4 L15 (coordinator): every coin starts >= 0.12 s after the previous one, and each pool coin has its own arc
  -- offset at the control point (Translation only), so three coins never read as a column
  local COIN_GAP = 0.12; local COIN_ARC = { 0, -4, -8, -2, -6, 0 } -- r5 C1: x shift left / down, all clear of the name row
  local COIN_MAX = 3; local COIN_EXTRA_GAP = 0.12; local COIN_QUEUE = 6; local COIN_LEG2 = 0.28; local COIN_FADE = 0.1 -- more waiting coins than 6 are dropped (fast kills)   // r3 L10: at most 3 in flight, click-kill extras 0.12 s apart
  local whelps = {  }
  local G = {} -- geometry from Main.GEO (window units, no GetCenter needed: W3)
  -- j1 A1 #6: kills have no sparks any more; only the gold moment (J.Bonus) bursts once: 8 sparks, 24 px, alpha 0.6 -> 0, 0.5 s
  local SPARK_N = 8; local SPARK_DIST = 24; local SPARK_A = 0.6; local SPARK_DUR = 0.5
  function buildSpark()
    local t = K().Glow(W().fx, "spark", 16, C().gold, "OVERLAY")
    t:SetPoint("CENTER", W().enemy, "CENTER", 0, 0)
    t:SetAlpha(0)
    t.anim = t:CreateAnimationGroup()
    t.move = K().AddMove(t.anim, SPARK_DIST, 0, SPARK_DUR, 0, 1, "OUT")
    K().AddAlpha(t.anim, SPARK_A, 0, SPARK_DUR, 0, 1, "IN")
    return t
  end
  -- L4: a WoW Path animation is not available in the canon, so the curve is ordered Translations.
  -- r5 C1: the coin goes round the name row on the right and never crosses it (name row y -31..-45, headline
  -- y -28..-48): enemy TOPRIGHT (-6,-6) -> P1 right of the row, below it (y -52 or lower) -> P2 straight up into
  -- the gap between the head row and the name row (y -26, coin 8 x 8 = -22..-30) -> P3 under the GoldIcon -> GoldIcon
  -- RIGHT (-4, 0). It never touches GoldText, the head buttons or Close (r3 L10). While a headline runs, no coin
  -- flies (updateCoins holds the queue, J.CoinsAbort at a new headline). r4 L15: ends inside the icon, fades 0.1 s.
  local COIN_SIZE = 8; local COIN_X = 228; local COIN_P1Y = -52; local COIN_GAPY = -26
  local COIN_T1 = 0.2; local COIN_T2 = 0.12; local COIN_T3 = 0.14; local COIN_T4 = 0.12
  function buildCoin(idx)
    local off = U.At(COIN_ARC, idx)
    local x = COIN_X + off
    local y1 = COIN_P1Y + math.min(0, off)
    local t = K().Icon(W().coins, Mrgl.Data.Icons.coin, "OVERLAY", 1)
    t:SetSize(COIN_SIZE, COIN_SIZE)
    t:SetPoint("CENTER", W().frame, "TOPLEFT", G.sx, G.sy)
    t:SetAlpha(0)
    t.anim = t:CreateAnimationGroup()
    K().AddMove(t.anim, x - G.sx, y1 - G.sy, COIN_T1, 0, 1)
    K().AddAlpha(t.anim, 1, 1, COIN_T1, 0, 1)
    K().AddMove(t.anim, 0, COIN_GAPY - y1, COIN_T2, 0, 2)
    K().AddAlpha(t.anim, 1, 1, COIN_T2, 0, 2)
    K().AddMove(t.anim, G.ex - x, 0, COIN_T3, 0, 3)
    K().AddAlpha(t.anim, 1, 1, COIN_T3, 0, 3)
    K().AddMove(t.anim, 0, G.ey - COIN_GAPY, COIN_T4, 0, 4, "OUT")
    K().AddAlpha(t.anim, 1, 1, COIN_T4 - COIN_FADE, 0, 4)
    K().AddAlpha(t.anim, 1, 0, COIN_FADE, COIN_T4 - COIN_FADE, 4)
    return t
  end
  -- r5 C1: a new headline stops coins in flight (they would cross it); the queue waits until it is gone
  J.CoinsAbort = function()
    for i = 1, U.Len(coins) do
      local c = U.At(coins, i)
      if c.anim:IsPlaying() then
        c.anim:Stop()
        c:SetAlpha(0)
      end
    end
  end
  -- r3 L11: 22 x 22 at the height of the enemy icon, from the left, 0.12 s apart; long enough that all 5 fly at 0.5 s.
  -- r4 L12: behind the enemy icon: regions of the surface frame (level Enemy - 1, OVERLAY over tint and spotlight).
  -- Centre from rel. x -97 (left edge at window x 12, rel. -108) to the right icon edge (rel. +40), where they fade
  -- out in 0.1 s: never to the boss button, never over the window edge.
  -- enemies1 N3: no movement any more: the whelps stand at x -97 (left of the enemy icon) and only fade in and out
  local WHELP_FLY = 1.0; local WHELP_IN = 0.15; local WHELP_OUT = 0.25; local WHELP_SIZE = 22; local WHELP_X0 = -108 + 11; local WHELP_FADE = 0.2
  function buildWhelp()
    local t = K().Icon(J.whelpFx, Mrgl.Data.Icons.whelp, "OVERLAY", 2)
    t:SetSize(WHELP_SIZE, WHELP_SIZE)
    t:SetAlpha(0)
    t.anim = t:CreateAnimationGroup()
    t.a1 = K().AddAlpha(t.anim, 0, 1, WHELP_IN, 0, 1)
    t.a2 = K().AddAlpha(t.anim, 1, 1, WHELP_FLY - WHELP_IN - WHELP_OUT, WHELP_IN, 1)
    t.a3 = K().AddAlpha(t.anim, 1, 0, WHELP_OUT, WHELP_FLY - WHELP_OUT, 1)
    return t
  end
  function ringFx(anchor, size, c, dur, to, a0)
    local t = K().Glow(W().fx, "ring", size, c, "OVERLAY")
    t:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    t:SetAlpha(0)
    t.anim = t:CreateAnimationGroup()
    K().AddScale(t.anim, 1, to, dur, 0, 1, "OUT")
    K().AddAlpha(t.anim, a0, 0, dur, 0, 1, "OUT")
    return t
  end
  function flashFx(anchor, size, from, dur)
    local t = K().Glow(W().fx, "glow", size, C().gold, "OVERLAY")
    t:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    t:SetAlpha(0)
    t.anim = t:CreateAnimationGroup()
    K().AddAlpha(t.anim, from, 0, dur, 0, 1, "OUT")
    return t
  end
  J.Build = function(f)
    local w = W()
    local geo = M().GEO
    G.sx = geo.enemyX + geo.enemyHalf - 6
    G.sy = geo.enemyY + geo.enemyHalf - 6 -- enemy TOPRIGHT (-6,-6)
    G.cx = geo.coinCtrlX
    G.cy = geo.coinCtrlY -- under the head row (L10)
    G.ex = geo.goldIconX + geo.goldIconHalf - 4
    G.ey = geo.goldIconY -- GoldIcon RIGHT (-4, 0), r4 L15
    local i
    for n = 1, 4 do
      local key = U.At(LANE_KEYS, n)
      LANES[key].list = {  }
      do
        i = 1
        while i <= LANES[key].pool do
          U.Insert(LANES[key].list, buildNumber(key, i))
          i = i + 1
        end
      end
    end
    do
      i = 1
      while i <= SPARK_N do
        U.Insert(sparks, buildSpark())
        i = i + 1
      end
    end
    do
      i = 1
      while i <= 6 do
        U.Insert(coins, buildCoin(i))
        i = i + 1
      end
    end
    -- j1c M5: the whelps fly in their own layer at the surface level, so a boss win can fade them out (0.2 s) by the
    -- layer alpha (their own groups own the region alpha)
    J.whelpFx = CreateFrame("Frame", "MrglSquadWhelps", w.surface)
    J.whelpFx:SetAllPoints(w.surface)
    M().SetLevel(J.whelpFx, M().LEVEL.surface)
    J.whelpOut = J.whelpFx:CreateAnimationGroup()
    K().AddAlpha(J.whelpOut, 1, 0, WHELP_FADE, 0, 1)
    J.whelpOut:SetToFinalAlpha(true)
    J.whelpOut:SetScript("OnFinished", function()
      J.WhelpsStop()
    end)
    J.whelpOut:SetScript("OnStop", function()
      J.WhelpsStop()
    end)
    do
      i = 1
      while i <= 5 do
        U.Insert(whelps, buildWhelp())
        i = i + 1
      end
    end
    -- hit flash over the enemy icon. r3 K2: a region of the enemy frame (OVERLAY), so the punch scales it with the
    -- icon and no full-size bright square stays behind a shrunken icon. j1 #3: gold vertex colour (no white), 0.10/0.15, 0.15 s
    J.flashTex = w.enemy:CreateTexture(nil, "OVERLAY", nil, 3)
    J.flashTex:SetAllPoints(w.enemyIcon)
    J.flashTex:SetTexture(Mrgl.Data.Icons.WHITE)
    K().SetVertex(J.flashTex, C().gold)
    J.flashTex:SetBlendMode("ADD")
    J.flashTex:SetAlpha(0)
    J.flash = J.flashTex:CreateAnimationGroup()
    J.flashA = K().AddAlpha(J.flash, 0.10, 0, 0.15, 0, 1, "OUT")
    -- portrait rings (first hire, milestone), ability unlock and ready flashes (W6). j1 #16 ring 1 -> 1.25, alpha 0.6 -> 0,
    -- 0.6 s; #12 unlock 0.4 -> 0 in 0.8 s; #13 ready 0.3 -> 0 in 0.5 s
    do
      i = 1
      while i <= 6 do
        local pt = U.At(w.squad, i)
        pt.fx = ringFx(pt, 40, C().gold, 0.6, 1.25, 0.6)
        pt.quietIn = K().FadeIn(pt, 0.25) -- New Tide C4: an auto-bought new portrait only fades in (no pop, no ring)
        i = i + 1
      end
    end
    do
      i = 1
      while i <= 4 do
        local b = U.At(w.ab, i)
        b.flash = flashFx(b, 70, 0.4, 0.8)
        b.readyFlash = flashFx(b, 56, 0.3, 0.5)
        i = i + 1
      end
    end
    -- boss ring (one-glow priority 1) and the auto-fight countdown ring (S5).
    -- r3 G1: both belong to the boss button (own child frame one level above it), so hiding the button takes them along
    w.bossFx = CreateFrame("Frame", "MrglSquadBossFx", w.boss)
    w.bossFx:SetAllPoints(w.boss)
    w.bossFx:SetFrameLevel(w.boss:GetFrameLevel() + 1)
    w.bossRing = K().Glow(w.bossFx, "ring", 56, C().good, "OVERLAY", 1)
    w.bossRing:SetPoint("CENTER", w.boss, "CENTER", 0, 0)
    w.bossRing:Hide()
    -- j1 #7: fades in once to 0.45 in 0.6 s and stays; no scale, no loop
    J.bossRing = w.bossRing:CreateAnimationGroup()
    K().AddAlpha(J.bossRing, 0, 0.45, 0.6, 0, 1, "OUT")
    w.bossCdRing = K().Glow(w.bossFx, "ring", 52, C().good, "OVERLAY", 2)
    w.bossCdRing:SetPoint("CENTER", w.boss, "CENTER", 0, 0)
    w.bossCdRing:Hide()
    J.cdRing = w.bossCdRing:CreateAnimationGroup()
    J.cdRingScale = K().AddScale(J.cdRing, 1.06, 1, 2, 0, 1) -- j1 #8
    -- r3 F2: boss silhouette during the victory (desaturated). j1 #25: alpha 0.2 -> 0 in 0.9 s, no scale
    J.sil = w.fx:CreateTexture(nil, "ARTWORK", nil, -1)
    J.sil:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    J.sil:SetSize(84, 84)
    J.sil:SetPoint("CENTER", w.enemy, "CENTER", 0, 0)
    J.sil:SetDesaturated(true)
    J.sil:SetAlpha(0)
    J.sil:Hide()
    J.silAnim = J.sil:CreateAnimationGroup()
    K().AddAlpha(J.silAnim, 0.2, 0, 0.9, 0, 1)
    J.silAnim:SetScript("OnFinished", function()
      J.sil:Hide()
    end)
    J.silAnim:SetScript("OnStop", function()
      J.sil:Hide()
    end)
    -- x2 over a portrait (numbers layer)
    J.msWrap = CreateFrame("Frame", "MrglSquadX2", w.numbers)
    M().SetLevel(J.msWrap, M().LEVEL.numbers)
    J.msWrap:SetSize(30, 16)
    J.msWrap:SetAlpha(0)
    local mt = K().Text(J.msWrap, K().FRIZ, 14, C().gold, "OUTLINE")
    mt:SetPoint("CENTER", J.msWrap, "CENTER", 0, 0)
    mt:SetText(S().TIMES2)
    J.msAnim = J.msWrap:CreateAnimationGroup()
    K().AddMove(J.msAnim, 0, 8, 0.8, 0, 1, "OUT") -- j1 #17
    K().AddAlpha(J.msAnim, 1, 1, 0.5, 0, 1)
    K().AddAlpha(J.msAnim, 1, 0, 0.3, 0.5, 1)
    -- headline (+10): name row TOP 0,-28, 220 x 20
    hf = CreateFrame("Frame", "MrglSquadHeadlineRow", w.headLayer)
    M().SetLevel(hf, M().LEVEL.headline)
    hf:SetSize(HL_W, 20)
    hf:SetPoint("TOP", f, "TOP", 0, -28)
    hf:SetAlpha(0)
    hfs = K().Text(hf, K().FRIZ, 16, C().gold, "OUTLINE")
    hfs:SetPoint("CENTER", hf, "CENTER", 0, 0)
    hfs:SetJustifyH("CENTER")
    -- F2 reward, shares the headline fades. j1b G1: in the row right of the title (bn.layout), FRIZ 18 OUTLINE gold
    hreward = K().Text(hf, K().FRIZ, 18, C().gold, "OUTLINE")
    hreward:SetPoint("LEFT", hf, "LEFT", 0, 0)
    hreward:SetJustifyH("LEFT")
    hreward:SetText("")
    hic.tex = K().Icon(hf, nil, "ARTWORK")
    hic.tex:SetSize(hic.size, hic.size)
    hic.tex:Hide()
    hic.fade = K().FadeIn(hic.tex, 0.4)
    hIn = hf:CreateAnimationGroup()
    K().AddAlpha(hIn, 0, 1, 0.2, 0, 1, "OUT") -- j1 #21: only alpha
    hIn:SetToFinalAlpha(true)
    hOut = hf:CreateAnimationGroup()
    K().AddAlpha(hOut, 1, 0, HL_OUT, 0, 1)
    hOut:SetToFinalAlpha(true)
    bn.build(f) -- j1 G
    td.build(f) -- New Tide F
    -- enemy groups. j1 #1: punch 1 -> 0.97 (crit 0.95) in 0.06 s and back in 0.10 s, no shift; #2: no shake any more
    local e = w.enemy
    J.punch = e:CreateAnimationGroup()
    J.punchScale1 = K().AddScale(J.punch, 1, 0.97, 0.06, 0, 1, "OUT")
    J.punchScale2 = K().AddScale(J.punch, 0.97, 1, 0.10, 0, 2, "IN")
    J.punch:SetScript("OnFinished", function()
      w.enemyBack:Hide()
    end)
    J.punch:SetScript("OnStop", function()
      w.enemyBack:Hide()
    end)
    -- j1 #4 die: 1 -> 1.05, alpha 1 -> 0, 0.12 s; #5 spawn: 0.95 -> 1, alpha 0 -> 1, 0.12 s
    J.die = e:CreateAnimationGroup()
    K().AddScale(J.die, 1, 1.05, 0.12, 0, 1, "OUT")
    K().AddAlpha(J.die, 1, 0, 0.12, 0, 1, "OUT")
    J.die:SetToFinalAlpha(true)
    J.spawn = e:CreateAnimationGroup()
    K().AddScale(J.spawn, 0.95, 1, 0.12, 0, 1, "OUT")
    K().AddAlpha(J.spawn, 0, 1, 0.12, 0, 1, "OUT")
    J.spawn:SetToFinalAlpha(true)
    -- onboarding ring behind the first enemy. j1 #9: fades in once to 0.5 in 0.6 s and stays
    J.onboard = w.onboardRing:CreateAnimationGroup()
    K().AddAlpha(J.onboard, 0, 0.5, 0.6, 0, 1, "OUT")
    w.fx:SetScript("OnUpdate", function(self, dt)
      J.OnUpdate(dt)
    end)
    J.Register()
  end
  -- ------------------------------------------------------------ effects
  function flash(a)
    if not J.FxOn("flash") then
      return
    end -- j1 B: /mrgl debug fx flash off
    local v = a
    if calm() then
      v = a / 2
    end -- L5: flash alpha halved
    J.flashA:SetFromAlpha(v)
    K().Replay(J.flash)
  end
  -- r4 J1: a punch only hits a living enemy: not locked (dying), no spawn running, no respawn pause.
  -- A click in the pause only shows its number (ManualClick).
  function canPunch()
    if Mrgl.db.boss.active and Core().rt.inCombat then
      return false
    end -- j2 A2: frozen boss, the click deals nothing
    return not M().st.enemyLocked and not J.die:IsPlaying() and not J.spawn:IsPlaying() and Core().rt.respawn <= 0
  end
  J.CanPunch = canPunch
  function punch()
    K().Replay(J.punch) -- OnStop of the replay hides the back first, so show it after
    W().enemyBack:Show()
  end
  J.Punch = function()
    if not visible() or not ff.punchOk() then -- j4 H2 (b)
      return
    end
    if not calm() then
      -- j1 A3: calm mode has no punch
      K().ScaleTo(J.punchScale1, 0.97, 0.97)
      K().ScaleFrom(J.punchScale2, 0.97, 0.97)
      punch()
    end
    flash(0.10)
  end
  -- L2: a click stored during the respawn pause shows its number at once (lane R)
  -- j5 K1+: every own click in the pause shows (also in the boss pause, and when the queue of CLICK_QUEUE is full: then
  -- the number only shows the click, it is not queued)
  J.ManualClick = function()
    if not visible() then
      return
    end
    local rt = Core().rt
    local db = Mrgl.db
    if rt.respawn <= 0 then
      return
    end
    if db.boss.active and rt.inCombat then
      return
    end
    number("R", Core().Combat.ClickDamage(), true)
    if rt.queued < Mrgl.Data.Balance.CLICK_QUEUE then
      shownQueued = shownQueued + 1
    end
  end
  -- j1 A1 #6: the one spark burst of the gold moment (J.Bonus may call J.Burst). n <= 8 sparks around anchor (+x, +y),
  -- 24 px out. j1 A3: none in calm mode; B: none with /mrgl debug fx sparks off
  function burst(n, c, anchor, x, y)
    if calm() or not J.FxOn("sparks") then
      return
    end
    local k = math.min(n, U.Len(sparks))
    local a = anchor
    if a == nil then
      a = W().enemy
    end
    for i = 1, k do
      local s = U.At(sparks, sparkNext)
      sparkNext = sparkNext % U.Len(sparks) + 1 -- nonneg
      local ang = i / k * 2 * math.pi + math.random() * 0.4
      s:ClearAllPoints()
      s:SetPoint("CENTER", a, "CENTER", x or 0, y or 0)
      s.move:SetOffset(math.cos(ang) * SPARK_DIST, math.sin(ang) * SPARK_DIST * 0.8)
      K().SetVertex(s, c)
      K().Replay(s.anim)
    end
  end
  J.Burst = burst
  -- r3 L10: kills queue coins; at most COIN_MAX fly at once, the rest wait (updateCoins, per frame)
  -- tide1d D3: in fast mode at most one coin at a time: a new one only when none flies or waits, nothing queues up
  function coinFlight(n, extra)
    local now = GetTime()
    if ff.check() then
      if coinsFlying() == 0 and U.Len(coinQ) == 0 then
        U.Insert(coinQ, { t = now, gap = 0 })
      end
      return
    end
    for i = 1, n do
      if U.Len(coinQ) < COIN_QUEUE then
        U.Insert(coinQ, { t = now + (i - 1) * COIN_GAP, gap = COIN_GAP })
      end
    end
    for k = 1, extra do
      if U.Len(coinQ) < COIN_QUEUE then
        U.Insert(coinQ, { t = now + k * COIN_EXTRA_GAP, gap = COIN_EXTRA_GAP })
      end
    end
  end
  function coinsFlying()
    local n = 0
    for i = 1, U.Len(coins) do
      if U.At(coins, i).anim:IsPlaying() then
        n = n + 1
      end
    end
    return n
  end
  J.CoinsFlying = function()
    return coinsFlying()
  end -- tide1d D3 (tests)
  function updateCoins()
    if U.Len(coinQ) == 0 then
      return
    end
    if hcur ~= nil then
      return
    end -- r5 C1: no coin flies while a headline runs
    local now = GetTime()
    local flying = coinsFlying()
    local cap = COIN_MAX
    if ff.check() then
      -- tide1d D3: one coin; what waited from the slow phase is dropped
      cap = 1
      while U.Len(coinQ) > 1 do
        U.Remove(coinQ, U.Len(coinQ))
      end
    end
    while U.Len(coinQ) > 0 and flying < cap do
      local e = U.At(coinQ, 1)
      if now < e.t or now - coinLast < e.gap then
        return
      end
      local use
      for i = 1, U.Len(coins) do
        -- round robin: the next coin has another arc
        local c = U.At(coins, (coinRR + i - 1) % U.Len(coins) + 1) -- nonneg
        if not c.anim:IsPlaying() then
          use = c
          coinRR = (coinRR + i) % U.Len(coins) -- nonneg
          break
        end
      end
      if use == nil then
        return
      end
      U.Remove(coinQ, 1)
      use.anim:Play()
      coinLast = now
      flying = flying + 1
    end
  end
  -- j1 A1 #20: the gold icon does not pop on arrival any more (the coin fades into it)
  -- L6/L11: 5 whelps, 0.12 s apart, at fixed heights in the icon; r4 L12: from x 12 to the right icon edge
  local WHELP_Y = { -16, -6, 4, 12, 20 }
  -- j1c M5: every whelp stops, the layer is opaque again (end of the win fade, OnShow)
  J.WhelpsStop = function()
    for i = 1, U.Len(whelps) do
      U.At(whelps, i).anim:Stop()
    end
    J.whelpFx:SetAlpha(1)
  end
  -- j1c M5: a boss win fades the whelps still in flight (0.2 s, alpha only)
  J.WhelpsOut = function()
    local any = false
    for i = 1, U.Len(whelps) do
      if U.At(whelps, i).anim:IsPlaying() then
        any = true
      end
    end
    if any and not J.whelpOut:IsPlaying() then
      K().Replay(J.whelpOut)
    end
  end
  function whelpFlight()
    if calm() then
      return
    end
    if J.whelpOut:IsPlaying() then
      J.whelpOut:Stop()
    end -- j1c M5: a new cast during the win fade starts clean
    local geo = M().GEO
    for i = 1, 5 do
      local t = U.At(whelps, i)
      if not t.anim:IsPlaying() then
        local d = (i - 1) * 0.12
        t:ClearAllPoints()
        t:SetPoint("CENTER", W().frame, "TOPLEFT", geo.enemyX + WHELP_X0, geo.enemyY + U.At(WHELP_Y, i))
        t.a1:SetStartDelay(d)
        t.a2:SetStartDelay(d + WHELP_IN)
        t.a3:SetStartDelay(d + WHELP_FLY - WHELP_OUT)
        t.anim:Play()
      end
    end
  end
  J.CountdownRing = function(left)
    local r = W().bossCdRing
    if left > 0 and visible() and W().boss:IsShown() then
      -- j1 #8: 1.06 -> 1 over the full delay, alpha 0.6
      K().ScaleFrom(J.cdRingScale, 1 + 0.06 * left / Mrgl.Data.Balance.AUTO_FIGHT_DELAY, 1 + 0.06 * left / Mrgl.Data.Balance.AUTO_FIGHT_DELAY)
      J.cdRingScale:SetDuration(left)
      r:SetAlpha(0.6)
      r:Show()
      K().Replay(J.cdRing)
    else
      if J.cdRing:IsPlaying() then
        J.cdRing:Stop()
      end
      r:SetAlpha(0)
      r:Hide()
    end
  end
  -- r3 G1: no ring may outlive the boss button (boss start by auto, click, key Q or opener; win; fail; button hidden)
  J.BossRingsOff = function()
    local w = W()
    if J.cdRing:IsPlaying() then
      J.cdRing:Stop()
    end
    w.bossCdRing:SetAlpha(0)
    w.bossCdRing:Hide()
    if J.bossRing:IsPlaying() then
      J.bossRing:Stop()
    end
    w.bossRing:SetAlpha(0)
    w.bossRing:Hide()
    if glowOwner == "boss" then
      glowOwner = nil
    end
  end
  J.BossRingsShown = function()
    local w = W()
    return w.bossCdRing:IsShown() or w.bossRing:IsShown() or glowOwner == "boss"
  end
  -- B5: "+n%" under the readiness bar when the squad grew since the last open or purchase
  local strBase = -1
  J.StrengthCheck = function()
    local cur = Core().Boss.Strength()
    local base = strBase
    strBase = cur
    if not visible() or base < 0 or base >= 1 or not Core().Combat.GateOpen() or Mrgl.db.boss.active then
      return
    end
    local d = (math.min(1, cur) - base) * 100
    if d >= 0.5 then
      M().GainText(W().bossGrow, d) -- r3 P1
      K().Replay(W().bossGrowAnim)
    end
  end
  -- chain juice (E1): one pop per rank
  local chainSlots = {}; local chainMs = {}
  function chainReset()
    chainSlots = {}
    chainMs = {}
  end
  function popPortrait(slot, first)
    local pt = U.At(W().squad, slot)
    if first then
      K().Replay(pt.popIn)
    end
    if J.FxOn("unlock") then
      K().Replay(pt.fx.anim)
    end
  end
  -- New Tide C4: an auto-bought murloc: no hop, no pop, no ring; a new portrait only fades in (0 -> 1 in 0.25 s)
  function quietIn(slot, first)
    if first then
      K().Replay(U.At(W().squad, slot).quietIn)
    end
  end
  function milestoneFx(slot)
    local pt = U.At(W().squad, slot)
    K().Replay(pt.fx.anim)
    J.msWrap:ClearAllPoints()
    J.msWrap:SetPoint("BOTTOM", pt, "TOP", 0, 2)
    K().Replay(J.msAnim)
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.FlashMurloc(slot)
    end
  end
  -- ------------------------------------------------------------ core events
  J.Register = function()
    local On = Core().On
    -- j1 W2: in-world gold (Core.World) also while the window is hidden: the moment waits (J.Bonus)
    On("WORLD_BONUS", function(p)
      J.Bonus(p.kind, p.gold, p.n)
    end)
    -- New Tide: TIDE from T.Rise (marks and lines), TROPHY after BOSS_WIN (the line queues behind the victory)
    On("TIDE", function(p)
      td.onTide(p)
    end)
    On("TROPHY", function(p)
      td.onTrophy(p)
    end)
    On("HIT", function(p)
      -- New Tide C4: auto clicks have no number, punch or flash of their own; the core adds them to the squad number
      if p.kind == "auto" or not visible() then
        return
      end
      if p.kind == "mrgl" or p.kind == "leeroy" then
        number("A", p.amount)
        if td.autoMrgl then
          td.autoMrgl = false
          return
        end -- C4: an auto-cast does not flash
        flash(0.15) -- j1 #3; #2: no shake
        return
      end
      -- tide1d D1: every whelp hit (tick bundle or queued single, crit or not, rush or not) goes silently to lane L:
      -- never a flash or a punch
      if p.kind == "whelp" then
        whelpSum = whelpSum + p.amount
        return
      end
      if p.crit then
        if p.kind == "click" and skipHits > 0 then
          skipHits = skipHits - 1
        end
        number("R", p.amount, p.kind == "click", true) -- j5 K5 (c), j5b P4: a crit is never on the face centre (side lane R)
        if not visible() or not ff.punchOk() then -- j4 H2 (b): not the killing hit, <= 1 per 0.6 s, none in fast mode
          return
        end
        flash(0.15) -- j1 #3
        if not calm() then
          -- j1 #1 crit punch 0.95; A3: none in calm mode
          K().ScaleTo(J.punchScale1, 0.95, 0.95)
          K().ScaleFrom(J.punchScale2, 0.95, 0.95)
          punch()
        end
        return
      end
      if p.kind == "click" and skipHits > 0 then
        skipHits = skipHits - 1
        return
      end -- shown when it was queued
      number("R", p.amount, p.kind == "click")
    end)
    On("KILL", function(p)
      ff.kill(p.boss, p.click) -- tide1c C1: counted while hidden too (j4 H2: a boss is no lifetime)
      if not visible() then
        return
      end
      local w = W()
      M().LockEnemy(true)
      if J.punch:IsPlaying() then
        J.punch:Stop()
      end
      w.enemyBack:Hide() -- r4 J1
      -- tide1c C1: fast farming: the face stays at full alpha until the next one swaps in (no die fade; bosses and rares
      -- too, the victory line still comes)
      if ff.swap then
        if J.die:IsPlaying() then
          J.die:Stop()
        end
        w.enemy:SetAlpha(1)
      else
        K().Replay(J.die)
      end
      -- j1 #29: 1 coin per kill, a click kill 1 more; #6: no kill sparks; #19: no pip pop (the pip only fills).
      -- A3 calm: no coins for normal kills
      local extra = 0
      if p.boss then
        bossPause = true
      end
      if p.click then
        extra = 1
      end
      if not calm() or p.boss or p.rare then
        coinFlight(1, extra)
      end
      if p.rare then
        J.Bonus("rare", p.gold, 1) -- j1 G: rare kill = gold moment; boss: BOSS_WIN
      end
    end)
    On("SPAWN", function()
      ff.spawn() -- j4 H2 (a): the lifetime starts
      bossPause = false
      W().enemyBack:Hide() -- r4 J1
      if not visible() then
        shownQueued = 0
        return
      end
      skipHits = math.min(shownQueued, Core().rt.queued)
      shownQueued = 0
      M().LockEnemy(false)
      M().SetEnemyLook()
      if J.die:IsPlaying() then
        J.die:Stop()
      end
      if ff.swap then -- tide1c C1: swap only
        if J.spawn:IsPlaying() then
          J.spawn:Stop()
        end
        W().enemy:SetAlpha(1)
        return
      end
      K().Replay(J.spawn)
    end)
    On("RARE_SPAWN", function()
      if not visible() then
        return
      end
      J.Headline("rare", S().RARE_HEAD) -- j1 #6: no sparks at the rare spawn
    end)
    On("STAGE", function(p)
      if not visible() then
        lastStage = p.stage
        return
      end
      if p.stage > lastStage and lastStage > 0 then
        K().Replay(W().stagePop)
      end
      lastStage = p.stage
      M().Refresh()
    end)
    On("ZONE", function(p)
      if not visible() or td.rising then
        return
      end -- New Tide F: the reset's zone change has no headline (tint at once)
      M().st.zoneDefer = true -- the tint changes with the zone headline (after the victory)
      if J.Headline("zone", p.name) == nil then -- tide1c C8: dropped, the tint changes at once
        M().st.zoneDefer = false
        M().SetZone(false)
      end
    end)
    On("BOSS_START", function(p)
      J.BossRingsOff() -- G1: also while the window is hidden
      if not visible() then
        return
      end
      local w = W()
      M().LockEnemy(false)
      if J.die:IsPlaying() then
        J.die:Stop()
      end
      w.enemy:SetAlpha(1)
      M().Refresh()
      if not ff.check() then
        K().Replay(J.spawn)
      end -- tide1c C1: fast farming, the boss swaps in
      w.timer:Show()
      w.timerText:Show()
      w.timer:SetAlpha(1)
      K().Replay(w.timerFill)
    end)
    -- j1 #15: the last 5 s of the boss timer have no pulse and no pop, only the colour (Main.Refresh)
    On("BOSS_WIN", function(p)
      J.BossRingsOff()
      if not visible() then
        ff.bossT = GetTime()
        return
      end
      if J.BonusHeadOnly() then
        J.Bonus("boss", p.gold, 0, { name = p.name })
        ff.bossT = GetTime()
        return
      end -- j1 W2: minimized, head only
      fadeAllNumbers(0.1) -- j1 #6: no win sparks here (the gold moment owns the one burst)
      J.WhelpsOut() -- j1c M5: whelps still in flight fade out (0.2 s)
      M().st.bossHide = true -- the boss button stays away during the victory headline
      J.silIcon = W().enemyIcon.mrglIcon -- r3 F2: the silhouette starts with the victory headline (shot 37)
      J.Bonus("boss", p.gold, 0, { name = p.name }) -- j1 G: "{boss} defeated!", +gold, sparks
      ff.bossT = GetTime() -- j4 H2 (d): after the victory line: the next 3 s count as fast mode
    end)
    On("BOSS_FAIL", function()
      J.BossRingsOff()
      if not visible() then
        return
      end
      local w = W()
      K().Replay(w.timerFade)
      M().st.bossHide = true -- then the yellow border and bar come back (L3)
      J.Headline("retreat", S().RETREAT)
    end)
    On("BUY", function(p)
      if not visible() then
        return
      end
      if Core().rt.chain then
        local e = chainSlots[p.slot]
        if e == nil then
          e = { first = false }
          chainSlots[p.slot] = e
        end
        if p.first then
          e.first = true
        end
        return
      end
      if p.auto == true then
        quietIn(p.slot, p.first)
        M().Refresh()
        return
      end -- New Tide C4: auto-buy, quiet
      popPortrait(p.slot, p.first)
      J.StrengthCheck()
      M().Refresh()
    end)
    On("MILESTONE", function(p)
      if not visible() then
        return
      end
      if Core().rt.chain then
        chainMs[p.slot] = true
        return
      end
      milestoneFx(p.slot)
    end)
    On("UPGRADE", function()
      if not visible() then
        return
      end
      if Core().rt.chain then
        return
      end
      J.StrengthCheck()
      M().Refresh()
    end)
    On("SELF_UP", function()
      if not visible() then
        return
      end
      if Core().rt.chain then
        return
      end
      J.StrengthCheck()
      M().Refresh()
    end)
    On("BUY_CHAIN", function(p)
      if not visible() then
        chainReset()
        return
      end
      local lastMs = 0
      for s = 1, 6 do
        local e = chainSlots[s]
        if chainMs[s] == true then
          lastMs = s
        end
        if e ~= nil then
          if p.auto == true then
            quietIn(s, e.first)
          else
            popPortrait(s, e.first)
          end
        end
      end
      if lastMs > 0 then
        milestoneFx(lastMs)
      end -- C4: the milestone "x2" stays for auto-buys too
      if p.n > 0 and p.auto ~= true then
        K().Replay(W().buyPop)
      end
      chainReset()
      J.StrengthCheck()
      M().Refresh()
    end)
    On("ABILITY_USE", function(p)
      if not visible() then
        return
      end
      local w = W()
      local b = U.At(w.ab, p.slot)
      -- New Tide C4: an auto-cast (War Drums) keeps its swipe and buff edge, but no punch, cheer, flash or headline
      -- (LEEROY keeps its headline: it is the boss moment)
      local auto = p.auto == true
      if not auto then
        K().Replay(b.punch)
      end
      if auto and p.id == "mrgl" then
        td.autoMrgl = true
      end
      if p.id == "mrgl" then
        -- j1 #32: the cheer runs one after another from the left, 0.1 s apart (A3: none in calm mode)
        if not calm() and not auto then
          local k = 0
          for i = 1, 6 do
            local pt = U.At(w.squad, i)
            if pt.hired == true then
              pt.cheerUp:SetStartDelay(k * 0.1)
              k = k + 1
              K().Replay(pt.cheer)
            end
          end
        end
      elseif p.id == "whelps" then
        whelpFlight()
      elseif p.id == "candle" then
        M().SpotLook()
      elseif p.id == "leeroy" then
        J.Headline("leeroy", S().LEEROY_BANNER)
      end
      M().Refresh()
    end)
    On("BUFF_END", function(p)
      if not visible() then
        return
      end
      if p.id == "candle" then
        M().SpotLook()
      end
      M().Refresh()
    end)
    On("ABILITY_UNLOCK", function(p)
      if not visible() then
        return
      end
      local b = U.At(W().ab, p.slot)
      if J.FxOn("unlock") then
        K().Replay(b.flash.anim)
      end -- j1 B: /mrgl debug fx unlock off
      M().Refresh()
    end)
    On("ABILITY_READY", function(p)
      if not visible() then
        return
      end
      local b = U.At(W().ab, p.slot)
      K().Replay(b.readyFlash.anim) -- W6: own ready flash, glow 56 ADD (j1 #13: 0.3 -> 0 in 0.5 s)
      M().Refresh()
    end)
    On("GATE_OPEN", function()
      if not visible() then
        return
      end
      M().Refresh()
    end)
    On("CATCHUP", function(p)
      Core().Combat.TakeSquadDealt()
      if not visible() then
        return
      end
      J.OnShow()
      -- S3: back after a long background without a popup: the same +X at the gold as after combat.
      -- r4 K1: a return is any catch-up from LONG_FRAME (5 s) on (driver: OnUpdate elapsed >= 5 s); shown at once
      if p.seconds >= J.LONG_FRAME and p.gold > 0 and not Core().rt.popup then
        J.GoldPlus(p.gold, true)
      end
    end)
  end
  function silhouette()
    local icon = J.silIcon
    J.silIcon = nil
    if icon == nil or not J.FxOn("sil") then
      return
    end
    -- j1 B4: a texture that does not load is never shown (SetTexture returns false in WoW)
    if J.sil:SetTexture(K().IconPath(icon)) == false then
      J.sil:Hide()
      return
    end
    J.sil:SetDesaturated(true)
    J.sil:Show()
    K().Replay(J.silAnim)
  end
  J.LONG_FRAME = 5 -- r4 K1: an OnUpdate elapsed from this on counts as a return (CATCHUP), see main.js
  J.GoldPlus = function(gold, instant)
    M().GoldPlus(gold, instant)
  end
  -- ------------------------------------------------------------ one-glow rule (plan 3.6, r2 B4, S4, E1, L6)
  J.GlowOwner = function()
    return glowOwner
  end
  local lastBuyKey = ""
  function buyKey()
    local ch = M().chain
    if ch == nil then
      return ""
    end
    local t = ch.first
    return t.kind .. "." .. U.Int(t.slot) .. "." .. U.Int(t.tier or 0)
  end
  function bossGlow()
    local db = Mrgl.db
    local st = M().st.bossState
    if st == "hidden" or st == "teaser" or st == "held" or st == "" then
      return false
    end
    if Core().Boss.AutoState().state == "countdown" then
      return false
    end -- the countdown ring shows instead
    if st == "greenAbil" then
      return true
    end
    if st == "green" and not db.settings.autofight then
      return true
    end
    return db.stats.bosses == 0 and db.boss.lostStage == 0 -- S4: the first gate of the game
  end
  function newAbility(maxAge)
    local db = Mrgl.db
    for i = 1, 4 do
      local d = U.At(Mrgl.Data.Abilities, i)
      local s = db.abilities[d.id]
      local age = M().UnlockAge(d.id)
      if s.unlocked and not s.used and age >= 0 and age < maxAge then
        return U.At(W().ab, i)
      end
    end
    return nil
  end
  -- r3 G2: the ring has the readiness colour of the border (grey -> gold, yellow -> warn, green -> good)
  function bossRingColor()
    local st = M().st.bossState
    local c = C().gold
    if st == "green" or st == "greenAbil" then
      c = C().good
    elseif st == "yellow" or st == "held" then
      c = C().warn
    end
    K().SetVertex(W().bossRing, c)
  end
  J.UpdateGlow = function()
    local db = Mrgl.db
    local w = W()
    local want
    if not db.onboarding.firstClick then
      want = "onboard"
    elseif bossGlow() then
      want = "boss"
    else
      want = newAbility(10)
      if want == nil and M().BuyWantsGlow() then
        want = "buy"
      end
      if want == nil then
        want = newAbility(120)
      end
    end
    if want == "boss" then
      bossRingColor()
    end
    -- j1 #10: a new Buy best target fades the glow in once more (then it stands still again)
    local bk = buyKey()
    if want == "buy" and glowOwner == "buy" and bk ~= lastBuyKey then
      K().Replay(w.buyGlow)
    end
    lastBuyKey = bk
    if want == glowOwner then
      return
    end
    if glowOwner == "onboard" then
      J.onboard:Stop()
      w.onboardRing:Hide()
    elseif glowOwner == "boss" then
      J.bossRing:Stop()
      w.bossRing:SetAlpha(0)
      w.bossRing:Hide()
    elseif glowOwner == "buy" then
      w.buyGlow:Stop()
      w.buyGlowFrame:Hide()
    elseif glowOwner ~= nil then
      glowOwner.glowPulse:Stop()
      glowOwner.glow:Hide()
    end
    glowOwner = want
    if want == "onboard" then
      w.onboardRing:Show()
      w.onboardRing:SetAlpha(0.5) -- j1 #9
      J.onboard:Play()
    elseif want == "boss" then
      w.bossRing:SetAlpha(0.45) -- j1 #7
      w.bossRing:Show()
      J.bossRing:Play()
    elseif want == "buy" then
      w.buyGlowFrame:Show()
      w.buyGlow:Play()
    elseif want ~= nil then
      want.glow:Show()
      want.glowPulse:Play()
    end
    if Mrgl.UI.Panel ~= nil then
      Mrgl.UI.Panel.Refresh()
    end
  end
  -- ------------------------------------------------------------ per frame (fx frame: runs only while visible)
  J.OnUpdate = function(dt)
    updateNumbers(dt)
    updateHeadline(dt)
    updateCoins()
    squadT = squadT + dt
    if squadT >= 1 then
      squadT = squadT - 1
      if squadT > 1 then
        squadT = 0
      end
      local dealt = Core().Combat.TakeSquadDealt()
      if dealt > 0 and not calm() then
        number("L", dealt)
      end -- L5: no lane L in calm mode
    end
    whelpT = whelpT + dt
    if whelpT >= 0.5 then
      whelpT = 0
      if whelpSum > 0 and not calm() then
        number("L", whelpSum)
      end
      whelpSum = 0
    end
  end
  -- Drops every running effect (window shown again, catch-up, new db). No stored animation runs on.
  J.OnShow = function()
    local i; local n
    J.TideAbort() -- New Tide F: a running moment ends (the reset is done)
    do
      n = 1
      while n <= 4 do
        local pool = LANES[U.At(LANE_KEYS, n)].list
        do
          i = 1
          while i <= U.Len(pool) do
            stopNumber(U.At(pool, i))
            i = i + 1
          end
        end
        n = n + 1
      end
    end
    do
      i = 1
      while i <= U.Len(sparks) do
        U.At(sparks, i).anim:Stop()
        i = i + 1
      end
    end
    do
      i = 1
      while i <= U.Len(coins) do
        U.At(coins, i).anim:Stop()
        i = i + 1
      end
    end
    do
      i = 1
      while i <= U.Len(whelps) do
        U.At(whelps, i).anim:Stop()
        i = i + 1
      end
    end
    J.whelpOut:Stop() -- j1c M5
    J.whelpFx:SetAlpha(1)
    coinQ = {  }
    J.silAnim:Stop()
    J.sil:Hide()
    J.msAnim:Stop()
    clearHeadline()
    J.die:Stop()
    J.spawn:Stop()
    J.punch:Stop()
    W().enemyBack:Hide()
    M().GoldPlusStop()
    W().enemy:SetAlpha(1)
    M().st.dimA = 1 -- j1b G1: no dim left over
    W().enemyIcon:SetAlpha(1)
    M().LockEnemy(false)
    bossPause = bossPause and Core().rt.respawn > 0
    shownQueued = 0
    skipHits = 0
    whelpSum = 0
    whelpT = 0
    squadT = 0
    chainReset()
    Core().Combat.TakeSquadDealt()
  end
  J.ResetPools = function()
    td.reset() -- New Tide F: before OnShow, so a new db is never reset by an old moment
    J.OnShow()
    bn.reset() -- j1 W2: a new db drops the waiting moment (OnShow keeps it: closed -> next open)
    bossPause = false
    strBase = Core().Boss.Strength()
    lastStage = Mrgl.db.stage
  end
  -- ------------------------------------------------------------ j1 B: debug switches (sandbox: /mrgl debug fx|victory|zone)
  -- Each effect group can be switched off alone to find the white area after a boss kill.
  J.FX = { "spot", "flash", "sparks", "sil", "zone", "unlock" }
  local fxOff = {}
  J.FxOn = function(name)
    return fxOff[name] ~= true
  end
  J.SetFx = function(name, on)
    local known = false
    for i = 1, U.Len(J.FX) do
      if U.At(J.FX, i) == name then
        known = true
      end
    end
    if not known then
      return false
    end
    fxOff[name] = not on
    local w = W()
    if name == "spot" then
      w.spot:SetShown(on)
    end
    if name == "zone" then
      w.zoneA:SetShown(on)
      w.zoneB:SetShown(on)
    end
    if name == "sil" and not on then
      J.silAnim:Stop()
      J.sil:Hide()
    end
    return true
  end
  -- the full victory: opens the next boss gate if needed, starts the fight and wins it with one click (real core path)
  J.DebugVictory = function()
    local db = Mrgl.db
    local Cb = Core().Combat
    if Core().rt.inCombat then
      return false
    end
    if not db.boss.active then
      if not Cb.GateOpen() then
        db.stage = Core().Formula.NextBossStage(db.stage + 1) - 1
        db.kills = Mrgl.Data.Balance.KILLS_PER_STAGE
        Core().rt.respawn = 0
      end
      if not Core().Boss.Start(false) then
        return false
      end
    end
    db.enemyHp = 1
    Core().rt.respawn = 0
    Core().rt.enemyAge = math.max(Core().rt.enemyAge, Mrgl.Data.Balance.MIN_LIFE) -- j5 K5: the debug win is at once
    M().Hit(true)
    return true
  end
  -- the zone tint crossfades to the next zone (1 s, as after a zone boss); the stage stays
  local dbgZone = 0
  J.DebugZoneNext = function()
    local B = Mrgl.Data.Balance
    if dbgZone == 0 then
      dbgZone = Core().Formula.ZoneIndex(Mrgl.db.stage)
    end
    dbgZone = dbgZone % B.ZONES + 1 -- nonneg
    local stage = (dbgZone - 1) * B.STAGES_PER_ZONE + 1
    M().ZoneTint(Core().Combat.Zone(stage).tint, false)
    return dbgZone
  end
  -- dev / test-ui: live numbers per lane, coins in flight, current headline
  J.Debug = function()
    local w = W()
    local wl = 0
    for k = 1, U.Len(whelps) do
      if U.At(whelps, k).anim:IsPlaying() then
        wl = wl + 1
      end
    end
    local out = { total = 0, lanes = { R = 0, L = 0, C = 0, A = 0 }, coins = coinsFlying(), coinsWaiting = U.Len(coinQ), headline = J.HeadlineText(), reward = J.RewardText(), silhouette = J.sil:IsShown(), back = w.enemyBack:IsVisible(), die = J.die:IsPlaying(), spawn = J.spawn:IsPlaying(), punch = J.punch:IsPlaying(), respawn = Core().rt.respawn > 0, whelps = wl, goldPlus = w.goldPlus:GetText(), goldPlusAlpha = w.goldPlus:GetAlpha() }
    -- r4 J1 / L12 / K1: punch square, enemy groups, respawn pause, whelps in flight, "+X" at the gold
    for n = 1, 4 do
      local key = U.At(LANE_KEYS, n)
      local pool = LANES[key].list
      for i = 1, U.Len(pool) do
        if U.At(pool, i).live then
          out.lanes[key] = out.lanes[key] + 1
          out.total = out.total + 1
        end
      end
    end
    return out
  end
end
