local ADDON, Mrgl = ...
-- Mrgl Squad - icon names (Interface\Icons\<name>) and own textures (plan 2.1, 4.6).
-- All icons exist in the Classic client 1.13.2 and 1.15.9 (checked by the planner's research).
Mrgl.Data = Mrgl.Data or {}

Mrgl.Data.Icons = {
  ICON_PATH = "Interface\\Icons\\",
  MEDIA_PATH = "Interface\\AddOns\\MrglSquad\\Media\\",
  WHITE = "Interface\\Buttons\\WHITE8X8",
  ROUND_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
  coin = "INV_Misc_Coin_01",
  skull = "INV_Misc_Bone_HumanSkull_01",
  watch = "INV_Misc_PocketWatch_01",
  question = "INV_Misc_QuestionMark",
  gear = "INV_Misc_Gear_01",
  tabSquad = "INV_Misc_Head_Murloc_01",
  tabUpgrades = "INV_Hammer_20",
  tabSelf = "INV_Gauntlets_04",
  statDps = "INV_Misc_Head_Murloc_01",
  statClick = "INV_Gauntlets_04",
  whelp = "INV_Misc_Head_Dragon_Black",
  glow = "glow",
  ring = "ring",
  spark = "spark",
  close = "close",
  chevron = "chevron",
  minimize = "minimize", -- j1 M1
  restore = "restore",
  ringThin = "ring-thin",
  tooltipBorder = "tooltip-border",
  -- R1 frame border: BackdropTemplate + SetBackdrop({ bgFile = TOOLTIP_BG, edgeFile = TOOLTIP_BORDER, edgeSize = 12, insets = 3 })
  TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
  TOOLTIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
}
