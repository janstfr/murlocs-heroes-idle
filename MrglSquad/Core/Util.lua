local ADDON, Mrgl = ...
Mrgl.Core = Mrgl.Core or {}
Mrgl.U = Mrgl.U or {}
local floor, ceil, abs, log = math.floor, math.ceil, math.abs, math.log
local format, sub, find = string.format, string.sub, string.find
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
Mrgl.U.IsTable = function(v)
  return type(v) == "table"
end
Mrgl.U.Clamp = function(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end
Mrgl.U.Round = function(v)
  return floor(v + 0.5)
end
Mrgl.U.Copy = function(t)
  local c = {}
  for k, v in pairs(t) do
    c[k] = v
  end
  return c
end
Mrgl.U.Int = function(n)
  n = floor(n)
  if n == 0 then
    return "0"
  end
  return format("%.0f", n)
end
local Int = Mrgl.U.Int
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
  local e
  for p = 1, 17 do
    e = format("%." .. (p - 1) .. "e", a)
    if tonumber(e) == a then
      break
    end
  end
  local mant, ex = string.match(e, "^([0-9.]+)e([-+][0-9]+)$")
  local digits = sub(mant, 1, 1) .. sub(mant, 3)
  local x = tonumber(ex)
  local k = #digits
  local nn = x + 1
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
Mrgl.U.Rand = function()
  local db = Mrgl.db
  local s = db.rng
  if not (s > 0) or s >= 2147483647 then
    s = 12345
  end
  s = (s * 16807) % 2147483647
  db.rng = s
  return s / 2147483647
end
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
Mrgl.U.GainLow = function(p)
  return p ~= p or p < 1
end
Mrgl.U.Share = function(x)
  local p = 100 * x
  if p > 100 then
    p = 100
  end
  return Mrgl.U.Pct(p) .. "%"
end
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
    local r = v % 1000
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
Mrgl.U.Clock = function(s)
  s = math.max(0, floor(s))
  if s < 60 then
    return Str(s)
  end
  if s < 3600 then
    return Str(floor(s / 60)) .. ":" .. Mrgl.U.Pad2(math.fmod(s, 60))
  end
  return Str(floor(s / 3600)) .. "h " .. Str(floor(math.fmod(s, 3600) / 60)) .. "m"
end
Mrgl.U.Wait = function(s)
  s = math.max(0, ceil(s))
  if s < 3600 then
    return Str(floor(s / 60)) .. ":" .. Mrgl.U.Pad2(math.fmod(s, 60))
  end
  return ">1h"
end
Mrgl.U.CD = function(s)
  s = math.max(0, ceil(s))
  if s < 60 then
    return Str(s)
  end
  return Str(ceil(s / 60)) .. "m"
end
Mrgl.U.CDLong = function(s)
  if s < 60 then
    return Str(s) .. " sec"
  end
  return Mrgl.U.Dec(s / 60, 1) .. " min"
end
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
      out = out .. sub(tpl, i, a - 1) .. Str(v)
    end
    i = b + 1
  end
  return out
end
Mrgl.U.ROMAN = { "I", "II", "III", "IV", "V" }
Mrgl.U.Roman = function(n)
  return Mrgl.U.ROMAN[n]
end
Mrgl.U.Hex2 = function(v)
  local d = "0123456789abcdef"
  local n = Mrgl.U.Clamp(floor(v * 255 + 0.5), 0, 255)
  local hi = floor(n / 16)
  local lo = n % 16
  return sub(d, hi + 1, hi + 1) .. sub(d, lo + 1, lo + 1)
end
Mrgl.U.Color = function(c, text)
  return "|cff" .. Mrgl.U.Hex2(c[1]) .. Mrgl.U.Hex2(c[2]) .. Mrgl.U.Hex2(c[3]) .. text .. "|r"
end
