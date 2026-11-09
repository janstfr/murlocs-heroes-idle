local ADDON, Mrgl = ...
-- Mrgl Squad - 6 murlocs, 3 upgrades each (plan 4.2). Literal tables only.
Mrgl.Data = Mrgl.Data or {}

Mrgl.Data.Murlocs = {
  { id = "tinyfin", name = "Murloc Tinyfin", icon = "INV_Misc_Head_Murloc_01", tint = {1, 1, 1}, natural = true, badge = "", ring = {0.45, 0.85, 0.80}, cost = 10, dps = 1,
    upgrades = {
      { name = "Sharp Pebbles", cost = 100 },
      { name = "Group Hug", cost = 500 },
      { name = "Tiny but Many", cost = 15000, special = "echo",
        text = "Every click also deals 1% of your squad's damage.", sub = "+1% echo" } } },
  { id = "raider", name = "Murloc Raider", icon = "INV_Misc_Head_Murloc_01", tint = {1.00, 0.50, 0.40}, badge = "INV_Spear_02", cost = 100, dps = 9,
    upgrades = {
      { name = "Rusty Spears", cost = 1000 },
      { name = "Raiding Party", cost = 3000 },
      { name = "Shiny Loot", cost = 150000, special = "gold",
        text = "Kills drop 10% more gold.", sub = "+10% gold" } } },
  { id = "tidehunter", name = "Murloc Tidehunter", icon = "INV_Misc_Head_Murloc_01", tint = {0.40, 0.60, 1.00}, badge = "Ability_Druid_AquaticForm", cost = 600, dps = 48,
    upgrades = {
      { name = "Riptide", cost = 6000 },
      { name = "High Tide", cost = 72000 },
      { name = "Endless Tide", cost = 900000, special = "timer",
        text = "Boss fights last 5 seconds longer.", sub = "+5 sec bosses" } } },
  { id = "oracle", name = "Grimscale Oracle", icon = "INV_Misc_Head_Murloc_01", tint = {0.80, 0.50, 1.00}, badge = "Spell_Nature_CrystalBall", cost = 1300, dps = 144,
    upgrades = {
      { name = "Glowing Pearls", cost = 13000 },
      { name = "Deep Visions", cost = 156000 },
      { name = "Brainy Murloc", cost = 1950000, special = "aura",
        text = "Your other murlocs deal 10% more damage.", sub = "+10% others" } } },
  { id = "warleader", name = "Murloc Warleader", icon = "INV_Misc_Head_Murloc_01", tint = {1.00, 0.80, 0.30}, badge = "INV_Banner_03", cost = 3800, dps = 450,
    upgrades = {
      { name = "War Paint", cost = 38000 },
      { name = "Battle Cry", cost = 456000 },
      { name = "Rally the Squad", cost = 5700000, special = "aura",
        text = "Your other murlocs deal 25% more damage.", sub = "+25% others" } } },
  { id = "murkeye", name = "Old Murk-Eye", icon = "INV_Misc_Head_Murloc_01", tint = {0.95, 0.95, 0.90}, badge = "INV_Misc_Eye_01", cost = 25000, dps = 2700,
    upgrades = {
      { name = "Old Tricks", cost = 250000 },
      { name = "Murky Depths", cost = 3000000 },
      { name = "Legend of the Coast", cost = 10000000, special = "murk",
        text = "Old Murk-Eye deals 1% more damage for every murloc you have hired.", sub = "+1% per murloc" } } }
}

-- Prepared for later (not in MVP): guest workers, prestige. Kept empty on purpose.
Mrgl.Data.Guests = {}
