local ADDON, Mrgl = ...
Mrgl.UI = Mrgl.UI or {}
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
BINDING_NAME_MRGLSQUAD_MINIMIZE = "Minimize window"
local function MrglSquad_Usable()
  if Mrgl.UI.IsReady == nil or not Mrgl.UI.IsReady() then
    return false
  end
  local f = Mrgl.UI.Main.w.frame
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
end
