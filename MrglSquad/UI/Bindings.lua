local ADDON, Mrgl = ...
-- Mrgl Squad - key bindings (plan 3.8). In WoW: Bindings.xml + these globals, all keys unbound by default.
-- <Bindings>
--   <Binding name="MRGLSQUAD_HIT" header="MRGLSQUAD">MrglSquad_Hit()</Binding>
--   <Binding name="MRGLSQUAD_ABILITY1">MrglSquad_Ability(1)</Binding> ... ABILITY4
--   <Binding name="MRGLSQUAD_BUYBEST">MrglSquad_BuyBest()</Binding>
--   <Binding name="MRGLSQUAD_BOSS">MrglSquad_Boss()</Binding>
--   <Binding name="MRGLSQUAD_PANEL">MrglSquad_Panel()</Binding>
--   <Binding name="MRGLSQUAD_TOGGLE">MrglSquad_Toggle()</Binding>
--   <Binding name="MRGLSQUAD_MINIMIZE">MrglSquad_Minimize()</Binding>
-- </Bindings>
-- Only Bindings.xml is used (SetOverrideBindingClick does not work in combat on Forever).
Mrgl.UI = Mrgl.UI or {}

-- globals read by the key binding UI (port-plan 1: allowed globals)
BINDING_HEADER_MRGLSQUAD = "Murlocs Heroes Idle"
BINDING_NAME_MRGLSQUAD_HIT = "Hit"
BINDING_NAME_MRGLSQUAD_ABILITY1 = "Ability 1"
BINDING_NAME_MRGLSQUAD_ABILITY2 = "Ability 2"
BINDING_NAME_MRGLSQUAD_ABILITY3 = "Ability 3"
BINDING_NAME_MRGLSQUAD_ABILITY4 = "Ability 4"
BINDING_NAME_MRGLSQUAD_BUYBEST = "Buy best"
BINDING_NAME_MRGLSQUAD_BOSS = "Fight boss"
BINDING_NAME_MRGLSQUAD_PANEL = "Toggle shop"
BINDING_NAME_MRGLSQUAD_TOGGLE = "Toggle window"
BINDING_NAME_MRGLSQUAD_MINIMIZE = "Minimize window" -- j1 M4

-- MrglSquad_Usable is not on the allowed-globals list, so it stays local
local function MrglSquad_Usable()
  -- port p2: uiReady first (a failed start leaves a half-built frame)
  if Mrgl.UI.IsReady == nil or not Mrgl.UI.IsReady() then
    return false
  end
  local f = Mrgl.UI.Main.w.frame
  -- tide1c C7: no keys under the New Tide veil either (a boss or ability 2 would start behind it)
  return f ~= nil and f:IsShown() and not Mrgl.UI.Popup.IsOpen() and Mrgl.Core.rt.tideVeil ~= true
end
function MrglSquad_Hit()
  if not MrglSquad_Usable() then
    return
  end
  Mrgl.UI.Main.Hit(true)
end
function MrglSquad_Ability(i)
  if not MrglSquad_Usable() then
    return
  end
  Mrgl.UI.Main.UseAbility(i)
end
function MrglSquad_BuyBest()
  if not MrglSquad_Usable() then
    return
  end
  Mrgl.UI.Main.BuyBest()
end
function MrglSquad_Boss()
  if not MrglSquad_Usable() then
    return
  end
  Mrgl.UI.Main.FightBoss()
end
function MrglSquad_Panel()
  if not MrglSquad_Usable() then
    return
  end
  Mrgl.UI.Panel.Toggle()
end
function MrglSquad_Toggle()
  Mrgl.UI.Toggle()
end
-- j1 M4: minimize / restore (only while the window is shown and no popup is open, like the other keys)
function MrglSquad_Minimize()
  if not MrglSquad_Usable() then
    return
  end
  Mrgl.UI.Main.SetMinimized(not Mrgl.UI.Main.IsMinimized())
end
function MrglSquad_OnCompartmentClick()
  Mrgl.UI.Toggle()
end
do
  local Bd = {}
  Mrgl.UI.Bindings = Bd
  -- [browser] SetupBrowser (stand-in for Bindings.xml and browser default keys) is not ported.
end
