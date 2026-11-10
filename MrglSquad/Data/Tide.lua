local ADDON, Mrgl = ...
Mrgl.Data = Mrgl.Data or {}
Mrgl.Data.Tide = {
  icon = "Spell_Frost_SummonWaterElemental",
  first = {
    { id = "quartermaster", icon = "INV_Crate_01", toggle = "autobuy",
      name = "Murloc Quartermaster", text = "Buy best runs by itself every 10 seconds." },
    { id = "murky", icon = "INV_Misc_Head_Murloc_01", companion = 1, tint = { 0.60, 0.85, 1.00 }, badge = "INV_Misc_Fish_02",
      name = "Murky", text = "Joins the squad and fights along." } },
  paths = {
    { id = "m", name = "Murlocs", icon = "INV_Misc_Head_Murloc_01", per = "Each point: ×300 murloc damage.", tag = "Best while away",
      ms = {
        { at = 1, id = "m10", icon = "INV_Misc_Shell_02", companion = 2, tint = { 1.00, 0.70, 0.80 }, badge = "INV_Misc_Shell_02",
          name = "Murloc Tidecaller",
          text = "Joins the squad. Your murlocs deal 50% more damage." },
        { at = 2, id = "m25", icon = "Spell_Holy_MindVision", name = "Coldlight Seer",
          text = "Offline gold: 75% (instead of 50%)." },
        { at = 3, id = "m50", icon = "INV_Misc_Coin_03", name = "Lushwater Murcenary",
          text = "Murlocs and their upgrades cost 25% less." },
        { at = 5, id = "m100", icon = "INV_Crown_01", companion = 3, tint = { 1.00, 0.88, 0.40 }, badge = "INV_Crown_01",
          name = "King Bagurgle",
          text = "Joins the squad. Your murlocs deal double damage." } } },
    { id = "s", name = "Self-Click", icon = "INV_Gauntlets_04", per = "Each point: ×300 click damage.", tag = "Best while clicking",
      ms = {
        { at = 1, id = "s10", icon = "INV_Fishingpole_02", toggle = "autoclick", name = "Strong Fishing Pole",
          text = "Your weapon swings by itself 3 times per second." },
        { at = 2, id = "s25", icon = "INV_Spear_04", name = "Barbed Harpoon", text = "+10% crit chance." },
        { at = 3, id = "s50", icon = "INV_Spear_06", name = "Tidal Trident", text = "Crit multiplier +3: a ×10 crit becomes ×13." },
        { at = 5, id = "s100", icon = "INV_Sword_39", name = "Thunderfury",
          text = "Double click damage, and your weapon swings 6 times per second." } } },
    { id = "a", name = "Spells", icon = "Ability_Warrior_BattleShout", per = "Each point: ×300 ability damage. Leftover damage hits the next enemies.", tag = "Best at bosses",
      ms = {
        { at = 1, id = "a10", icon = "INV_Misc_Drum_02", toggle = "autocast", name = "War Drums",
          text = "Abilities cast themselves when ready. At bosses, all of them, LEEROY included." },
        { at = 2, id = "a25", icon = "Spell_Nature_TimeStop", name = "Drums of the Deep",
          text = "Boss fights last 10 seconds longer." },
        { at = 3, id = "a50", icon = "Spell_Holy_Resurrection", name = "Anyfin Can Happen",
          text = "MRGLGLGL! becomes Anyfin Can Happen: 30 seconds of squad damage." },
        { at = 5, id = "a100", icon = "Spell_Nature_Bloodlust", name = "Everyfin is Awesome",
          text = "Abilities are three times as strong and buffs last twice as long." } } } },
  gold = "Every point, any path: +10% gold.",
  trophies = { { id = "nef", icon = "INV_Misc_Head_Dragon_01", name = "Head of Nefarian",
                need = "Defeat Nefarian (stage 110).", done = "Nefarian has fallen." } },
  coming = { { name = "Ahn'Qiraj", icon = "INV_Qiraj_HuskOldGod" }, { name = "Naxxramas", icon = "Spell_Frost_FrostWard" } }
}
