local ADDON, Mrgl = ...
-- Mrgl Squad - New Tide paths, milestones, companions, trophies (ngplus-plan N). Literal tables only.
-- Every New Tide adds 1 point to one path, forever. companion = slot right of the squad (K), toggle = settings key (R2/R3).
-- tide1b T3: a companion is a murloc head tinted `tint` with `badge` (like the squad heads); T6: icon = a wave (both clients)
Mrgl.Data = Mrgl.Data or {}

Mrgl.Data.Tide = {
  icon = "Spell_Frost_SummonWaterElemental",
  first = {
    { id = "quartermaster", icon = "INV_Crate_01", toggle = "autobuy",
      name = "Murloc Quartermaster", text = "Buy best runs by itself every 10 seconds." },
    { id = "murky", icon = "INV_Misc_Head_Murloc_01", companion = 1, tint = { 0.60, 0.85, 1.00 }, badge = "INV_Misc_Fish_02",
      name = "Murky", text = "Joins the squad and fights along." } }, -- enemies1 N1: no flavour (C14)
  paths = {
    { id = "m", name = "Murlocs", icon = "INV_Misc_Head_Murloc_01", per = "Each point: +50% murloc damage.", tag = "Best while away",
      ms = {
        { at = 10, id = "m10", icon = "INV_Misc_Shell_02", companion = 2, tint = { 1.00, 0.70, 0.80 }, badge = "INV_Misc_Shell_02",
          name = "Murloc Tidecaller",
          text = "Joins the squad. Your murlocs deal 50% more damage." },
        { at = 25, id = "m25", icon = "Spell_Holy_MindVision", name = "Coldlight Seer",
          text = "Offline gold: 75% (instead of 50%)." },
        { at = 50, id = "m50", icon = "INV_Misc_Coin_03", name = "Lushwater Murcenary",
          text = "Murlocs and their upgrades cost 25% less." },
        { at = 100, id = "m100", icon = "INV_Crown_01", companion = 3, tint = { 1.00, 0.88, 0.40 }, badge = "INV_Crown_01",
          name = "King Bagurgle",
          text = "Joins the squad. Your murlocs deal double damage." } } },
    { id = "s", name = "Self-Click", icon = "INV_Gauntlets_04", per = "Each point: +100% click damage.", tag = "Best while clicking",
      ms = {
        { at = 10, id = "s10", icon = "INV_Fishingpole_02", toggle = "autoclick", name = "Strong Fishing Pole",
          text = "Your weapon swings by itself once per second." },
        { at = 25, id = "s25", icon = "INV_Spear_04", name = "Barbed Harpoon", text = "+10% crit chance." },
        { at = 50, id = "s50", icon = "INV_Spear_06", name = "Tidal Trident", text = "Crit multiplier +3: a ×10 crit becomes ×13." },
        { at = 100, id = "s100", icon = "INV_Sword_39", name = "Thunderfury",
          text = "Double click damage, and your weapon swings twice per second." } } },
    { id = "a", name = "Spells", icon = "Ability_Warrior_BattleShout", per = "Each point: +200% ability power.", tag = "Best at bosses",
      ms = {
        { at = 10, id = "a10", icon = "INV_Misc_Drum_02", toggle = "autocast", name = "War Drums",
          text = "Abilities cast themselves when ready. At bosses, all of them, LEEROY included." },
        { at = 25, id = "a25", icon = "Spell_Nature_TimeStop", name = "Drums of the Deep",
          text = "Boss fights last 10 seconds longer." },
        { at = 50, id = "a50", icon = "Spell_Holy_Resurrection", name = "Anyfin Can Happen",
          text = "MRGLGLGL! becomes Anyfin Can Happen: 30 seconds of squad damage." },
        { at = 100, id = "a100", icon = "Spell_Nature_Bloodlust", name = "Everyfin is Awesome",
          text = "Abilities are three times as strong and buffs last twice as long." } } } },
  flood = "Every New Tide: +100% murloc damage and +50% gold, whatever path you pick.",
  trophies = { { id = "nef", icon = "INV_Misc_Head_Dragon_01", name = "Head of Nefarian",
                need = "Defeat Nefarian (stage 110).", done = "Nefarian has fallen." } },
  coming = { { name = "Ahn'Qiraj", icon = "INV_Qiraj_HuskOldGod" }, { name = "Naxxramas", icon = "Spell_Frost_FrostWard" } }
}
