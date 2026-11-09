local ADDON, Mrgl = ...
-- Mrgl Squad - Core/Util.lua (port of web/core/Util.js, line-close). The only Core file that changes when porting
-- (1-based list access, string building, number formatting). Pure Lua 5.1, no WoW API.
-- Number to text (port-plan 2.2): never Lua's own number-to-string for values that can reach 1e14 (Lua 5.1 prints
-- 1e+15). U.Int writes whole numbers ("%.0f"), U.Str stands wherever the JS wrote "" + n (same text as JS String(n)).
-- No integer printf conversion (C long is 32 bit on Windows).
Mrgl.Core = Mrgl.Core or {}
Mrgl.U = Mrgl.U or {}

local floor, ceil, abs, log = math.floor, math.ceil, math.abs, math.log
local format, sub, find = string.format, string.sub, string.find

-- 1-based list access: At(list, 1) is the first element.
Mrgl.U.At = function(list, i)
  return list[i]
end
Mrgl.U.Len = function(list)
  return #list
end
Mrgl.U.Set = function(list, i, v)
  list[i] = v
end
Mrgl.U.Insert = function(list, v)
  table.insert(list, v)
end
Mrgl.U.Remove = function(list, i)
  return table.remove(list, i)
end

-- true for a table. (JS: typeof v === "object" && v !== null)
Mrgl.U.IsTable = function(v)
  return type(v) == "table"
end

Mrgl.U.Clamp = function(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end
Mrgl.U.Round = function(v)
  return floor(v + 0.5)
end

-- Shallow copy of a table (order does not matter)
Mrgl.U.Copy = function(t)
  local c = {}
  for k, v in pairs(t) do
    c[k] = v
  end
  return c
end

-- Whole number as text without exponent: string.format("%.0f") after math.floor (port-plan 2.2). -0 -> "0" as in JS.
Mrgl.U.Int = function(n)
  n = floor(n)
  if n == 0 then
    return "0"
  end
  return format("%.0f", n)
end
local Int = Mrgl.U.Int

-- JS String(n) for a number: whole numbers below 1e21 as digits, else the shortest text that reads back as the same
-- double, in JS notation (fixed for 1e-6 <= |n| < 1e21, otherwise "1.5e+21" / "1e-7"). Used where the JS wrote "" + n.
Mrgl.U.Str = function(n)
  if type(n) == "boolean" then
    if n then
      return "true"
    end
    return "false"
  end
  if type(n) ~= "number" then
    return n
  end
  if n ~= n then
    return "NaN"
  end
  if n == math.huge then
    return "Infinity"
  end
  if n == -math.huge then
    return "-Infinity"
  end
  if n == 0 then
    return "0"
  end
  local a = abs(n)
  if n == floor(n) and a < 1e15 then
    return format("%.0f", n)
  end
  -- shortest round-trip digits: d.ddde+XX
  local e
  for p = 1, 17 do
    e = format("%." .. (p - 1) .. "e", a)
    if tonumber(e) == a then
      break
    end
  end
  local mant, ex = string.match(e, "^([0-9.]+)e([-+][0-9]+)$")
  local digits = sub(mant, 1, 1) .. sub(mant, 3)   -- "d.ddd" -> "dddd" ("d" alone stays)
  local x = tonumber(ex)   -- a = 0.digits * 10^(x + 1)
  local k = #digits
  local nn = x + 1         -- JS: n with 10^(nn-1) <= a < 10^nn
  local out
  if k <= nn and nn <= 21 then
    out = digits .. string.rep("0", nn - k)
  elseif 0 < nn and nn <= 21 then
    out = sub(digits, 1, nn) .. "." .. sub(digits, nn + 1)
  elseif -6 < nn and nn <= 0 then
    out = "0." .. string.rep("0", -nn) .. digits
  else
    local es = "+"
    if nn - 1 < 0 then
      es = "-"
    end
    out = sub(digits, 1, 1)
    if k > 1 then
      out = out .. "." .. sub(digits, 2)
    end
    out = out .. "e" .. es .. Int(abs(nn - 1))
  end
  if n < 0 then
    out = "-" .. out
  end
  return out
end
local Str = Mrgl.U.Str

-- Park-Miller LCG, exact in doubles. Seed lives in Mrgl.db.rng.
Mrgl.U.Rand = function()
  local db = Mrgl.db
  local s = db.rng
  if not (s > 0) or s >= 2147483647 then
    s = 12345
  end
  s = (s * 16807) % 2147483647   -- nonneg (s > 0), exact below 2^53
  db.rng = s
  return s / 2147483647
end

-- Decimal digits without trailing zeros: Dec(1.2, 2) -> "1.2"
Mrgl.U.Dec = function(v, digits)
  local m = 10 ^ digits
  local n = floor(v * m + 1e-7)
  local ip = floor(n / m)
  local fp = n - ip * m
  if fp <= 0 then
    return Str(ip)
  end
  local s = Str(fp)
  while #s < digits do
    s = "0" .. s
  end
  while #s > 0 and sub(s, -1) == "0" do
    s = sub(s, 1, -2)
  end
  return Str(ip) .. "." .. s
end

Mrgl.U.SUFFIX = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- Number format (plan 1.3 #10): 7.5 · 999 · 1.23K · 12.3K · 123K · ... · 1.23e45
Mrgl.U.Short = function(n)
  if n ~= n then
    return "0"
  end
  if n < 0 then
    return "-" .. Mrgl.U.Short(-n)
  end
  if n < 10 then
    return Mrgl.U.Dec(n, 1)
  end
  if n < 1000 then
    return Str(floor(n + 1e-7))
  end
  if n >= 1e36 then
    local e = floor(log(n) / log(10))
    if 10 ^ (e + 1) <= n then
      e = e + 1
    end
    if 10 ^ e > n then
      e = e - 1
    end
    return Mrgl.U.Dec(n / 10 ^ e, 2) .. "e" .. Str(e)
  end
  local t = floor(log(n) / log(1000))
  if 1000 ^ (t + 1) <= n then
    t = t + 1
  end
  if t > 1 and 1000 ^ t > n then
    t = t - 1
  end
  local v = n / 1000 ^ t
  local s
  if v < 10 then
    s = Mrgl.U.Dec(v, 2)
  elseif v < 100 then
    s = Mrgl.U.Dec(v, 1)
  else
    s = Str(floor(v + 1e-7))
  end
  return s .. Mrgl.U.SUFFIX[t]
end

-- Fixed decimals like string.format("%." .. d .. "f", v) for d = 0 or 1 (round half away from zero on the
-- scaled value; exact binary ties are the only place printf could differ and never occur for gains we show).
Mrgl.U.Fmt = function(v, d)
  local m = 1
  if d == 1 then
    m = 10
  end
  local neg = v < 0
  local n = floor(abs(v) * m + 0.5)
  local ip = floor(n / m)
  local out = Str(ip)
  if d == 1 then
    out = out .. "." .. Str(n - ip * m)
  end
  if neg and n > 0 then
    out = "-" .. out
  end
  return out
end

-- r3 P1: one honest percent rule, always rounded DOWN, never shown bigger than it is.
-- U.Pct(p) -> number text: 1 <= p < 10 one decimal without ".0" ("3", "3.4"), p >= 10 whole number; p < 1 -> "<1".
Mrgl.U.Pct = function(p)
  if p ~= p or p < 1 then
    return "<1"
  end
  if p < 10 then
    local t = floor(p * 10 + 1e-9)
    local ip = floor(t / 10)
    if t - ip * 10 == 0 then
      return Str(ip)
    end
    return Str(ip) .. "." .. Str(t - ip * 10)
  end
  if p >= 1000 then
    return Mrgl.U.ShortDown(floor(p + 1e-9))
  end
  return Str(floor(p + 1e-9))
end

-- Short form rounded down with at most one decimal: 1251 -> "1.2K", 13600 -> "13K"
Mrgl.U.ShortDown = function(n)
  if n < 1000 then
    return Str(floor(n + 1e-9))
  end
  local t = floor(log(n) / log(1000))
  if 1000 ^ (t + 1) <= n then
    t = t + 1
  end
  if 1000 ^ t > n then
    t = t - 1
  end
  local v = n / 1000 ^ t
  local s
  if v < 10 then
    local d = floor(v * 10 + 1e-9)
    local ip = floor(d / 10)
    s = Str(ip)
    if d - ip * 10 > 0 then
      s = Str(ip) .. "." .. Str(d - ip * 10)
    end
  else
    s = Str(floor(v + 1e-9))
  end
  return s .. Mrgl.U.SUFFIX[t]
end

-- r3 P1: the whole gain token. p < 1 -> "<1%" (muted), up to 999 % -> "+3.4%", "+87%", from 1000 % a factor "×136", "×1.2K".
Mrgl.U.Gain = function(p)
  if p ~= p or p < 1 then
    return "<1%"
  end
  if p >= 1000 then
    local f = floor(1 + p / 100 + 1e-9)
    if f <= 999 then
      return "×" .. Str(f)
    end
    return "×" .. Mrgl.U.ShortDown(f)
  end
  return "+" .. Mrgl.U.Pct(p) .. "%"
end
-- true when the gain token is the muted "<1%"
Mrgl.U.GainLow = function(p)
  return p ~= p or p < 1
end
-- r3 P2: a share 0..1 as "{n}%", rounded down, capped at 100 %
Mrgl.U.Share = function(x)
  local p = 100 * x
  if p > 100 then
    p = 100
  end
  return Mrgl.U.Pct(p) .. "%"
end

-- r2 E6: prices round UP at the shown precision (gold rounds down), so "affordable" never looks wrong
Mrgl.U.ShortUp = function(n)
  if n ~= n then
    return "0"
  end
  if n < 10 then
    return Mrgl.U.Short(ceil(n * 10 - 1e-7) / 10)
  end
  if n < 1000 then
    return Mrgl.U.Short(ceil(n - 1e-7))
  end
  if n >= 1e36 then
    return Mrgl.U.Short(n)
  end
  local t = floor(log(n) / log(1000))
  if 1000 ^ (t + 1) <= n then
    t = t + 1
  end
  if t > 1 and 1000 ^ t > n then
    t = t - 1
  end
  local p = 1000 ^ t
  local v = n / p
  local f = 1
  if v < 10 then
    f = 100
  elseif v < 100 then
    f = 10
  end
  return Mrgl.U.Short(ceil(v * f - 1e-7) / f * p + 1e-9 * p)
end

-- r2 T3: tooltip numbers exact with thousands separators up to 999,999, above that Short
Mrgl.U.Exact = function(n)
  if n ~= n then
    return "0"
  end
  if n >= 1e6 then
    return Mrgl.U.Short(n)
  end
  if n < 10 and n ~= floor(n) then
    return Mrgl.U.Dec(n, 1)
  end
  local v = floor(n + 1e-7)
  local out = ""
  while v >= 1000 do
    local r = v % 1000   -- nonneg (v >= 1000)
    local pad = Str(r)
    if r < 10 then
      pad = "00" .. Str(r)
    elseif r < 100 then
      pad = "0" .. Str(r)
    end
    out = "," .. pad .. out
    v = floor(v / 1000)
  end
  return Str(v) .. out
end

Mrgl.U.Pad2 = function(n)
  if n < 10 then
    return "0" .. Str(n)
  end
  return Str(n)
end

-- Durations: 45 · 2:05 · 4h 12m
Mrgl.U.Clock = function(s)
  s = math.max(0, floor(s))
  if s < 60 then
    return Str(s)
  end
  if s < 3600 then
    return Str(floor(s / 60)) .. ":" .. Mrgl.U.Pad2(math.fmod(s, 60))   -- fmod = JS % (exact also for huge s)
  end
  return Str(floor(s / 3600)) .. "h " .. Str(floor(math.fmod(s, 3600) / 60)) .. "m"   -- fmod = JS %
end
-- Wait time on Buy best: 0:12 · 2:05 · >1h (r3 P3)
Mrgl.U.Wait = function(s)
  s = math.max(0, ceil(s))
  if s < 3600 then
    return Str(floor(s / 60)) .. ":" .. Mrgl.U.Pad2(math.fmod(s, 60))   -- fmod = JS %
  end
  return ">1h" -- r3 P3: "Affordable in >1h"
end
-- Cooldown text on an ability: 45 · 2m
Mrgl.U.CD = function(s)
  s = math.max(0, ceil(s))
  if s < 60 then
    return Str(s)
  end
  return Str(ceil(s / 60)) .. "m"
end
-- Long cooldown text for tooltips: 30 sec · 2 min · 5 min
Mrgl.U.CDLong = function(s)
  if s < 60 then
    return Str(s) .. " sec"
  end
  return Mrgl.U.Dec(s / 60, 1) .. " min"
end

-- Fill "{key}" placeholders from a table. Plain find/sub, no gsub (a "%" in a value must stay literal).
Mrgl.U.Fill = function(tpl, t)
  local out = ""
  local i = 1
  local len = #tpl
  while i <= len do
    local a = find(tpl, "{", i, true)
    if a == nil then
      out = out .. sub(tpl, i)
      break
    end
    local b = find(tpl, "}", a, true)
    if b == nil then
      out = out .. sub(tpl, i)
      break
    end
    local key = sub(tpl, a + 1, b - 1)
    local v = t[key]
    if v == nil then
      out = out .. sub(tpl, i, a - 1) .. "{" .. key .. "}"
    else
      out = out .. sub(tpl, i, a - 1) .. Str(v)   -- numbers like JS String(n), strings as they are
    end
    i = b + 1
  end
  return out
end

-- Roman tier numbers for upgrades
Mrgl.U.ROMAN = { "I", "II", "III", "IV", "V" }
Mrgl.U.Roman = function(n)
  return Mrgl.U.ROMAN[n]
end

-- Color code for inline coloring (|cffRRGGBB ... |r)
Mrgl.U.Hex2 = function(v)
  local d = "0123456789abcdef"
  local n = Mrgl.U.Clamp(floor(v * 255 + 0.5), 0, 255)
  local hi = floor(n / 16)
  local lo = n % 16   -- nonneg (0..255)
  return sub(d, hi + 1, hi + 1) .. sub(d, lo + 1, lo + 1)
end
Mrgl.U.Color = function(c, text)
  return "|cff" .. Mrgl.U.Hex2(c[1]) .. Mrgl.U.Hex2(c[2]) .. Mrgl.U.Hex2(c[3]) .. text .. "|r"
end
