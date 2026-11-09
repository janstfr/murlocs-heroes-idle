local ADDON, Mrgl = ...
-- Mrgl Squad - self lines and abilities (plan 4.3, 4.4). Literal tables only.
Mrgl.Data = Mrgl.Data or {}

Mrgl.Data.Self = {
  { id = "click", name = "Click Power", icon = "INV_Gauntlets_04", max = 0,
    text = "Your clicks hit harder. Doubles every 25 ranks." },
  { id = "echo", name = "Echo", icon = "Spell_Holy_PowerInfusion", max = 5,
    text = "Every click also deals a share of your squad's damage." },
  { id = "crit", name = "Crit Chance", icon = "Ability_CriticalStrike", max = 20,
    text = "Chance for a click to crit." },
  { id = "critdmg", name = "Crit Damage", icon = "INV_Axe_09", max = 14,
    text = "How hard your crits hit." }
}

Mrgl.Data.Abilities = {
  { id = "mrgl", name = "MRGLGLGL!", icon = "Ability_Warrior_BattleShout", stage = 3, cd = 30, dur = 0,
    text = "Instantly deals one click plus 5 seconds of squad damage.",
    key = "1",
    -- New Tide N: Spells 50 turns slot 1 into Anyfin Can Happen (A.Power("MRGL_DPS_SEC") = TIDE_ANYFIN_SEC)
    alt = { name = "Anyfin Can Happen", icon = "Spell_Holy_Resurrection",
           text = "Instantly deals one click plus 30 seconds of squad damage." } },
  { id = "whelps", name = "Many Whelps!", icon = "INV_Misc_Head_Dragon_Black", stage = 10, cd = 120, dur = 10,
    text = "10 automatic clicks per second for 10 seconds.",
    key = "2" },
  { id = "candle", name = "You no take candle!", icon = "INV_Misc_Candle_01", stage = 20, cd = 180, dur = 15,
    text = "+50% crit chance for 15 seconds.",
    key = "3" },
  { id = "leeroy", name = "LEEROY!", icon = "Ability_Warrior_Charge", stage = 30, cd = 300, dur = 10,
    text = "Charges in: 5 critical clicks plus 20 seconds of squad damage, then every click crits for 10 seconds. A kill pays triple gold.",
    key = "4" }
}

-- Boss opener order (plan 4.4): Candle -> Whelps -> LEEROY -> MRGLGLGL
Mrgl.Data.OpenerOrder = {"candle", "whelps", "leeroy", "mrgl"}
