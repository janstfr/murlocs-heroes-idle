local ADDON, Mrgl = ...
-- Mrgl Squad - Data/Balance.lua equivalent. Literal numbers only (plan 5.3).
Mrgl.Data = Mrgl.Data or {}

Mrgl.Data.Balance = {
  TICK = 0.1,
  MAX_STEPS = 600,            -- more open steps than this -> Advance() in 1-s steps
  KILLS_PER_STAGE = 10,
  BOSS_EVERY = 5,
  BOSS_HP_MULT = 5,
  BOSS_GOLD_MULT = 5,
  BOSS_TIMER = 30,
  HP_BASE = 10, HP_GROWTH = 1.30, HP_LIN = 10,
  GOLD_LIN = 0.4, GOLD_DIV = 600, GOLD_PLUS = 1,   -- tuned with tools/balance.mjs (plan 0.5/120); j4 H3 (Jan 09.11.): 0.25/570 -> 0.4/600, more gold at stages 16-35 (review/economy/gold-feel.md)
  RESPAWN = 0.15,   -- j1 T1 (was 0.3; GOLD_DIV 540 -> 570 balances the pace)
  BOSS_RESPAWN = 1.0,         -- j1 T1 (was 1.75); the headline keeps running over the new enemy
  ADVANCE_MAX = 3600,         -- catch-up simulates at most 1 h, longer sleeps pay offline gold
  MINIBOSS_HP_MULT = 4,       -- x5 stages; zone bosses (x0) keep BOSS_HP_MULT (r2 B6)
  MINIBOSS_HP_MULT_MID = 3.5, -- r4 B23: mini bosses S35/S45
  BOSS_HP_MULT_MID = 3.5,     -- r3 B18: zone bosses S30/S40/S50
  CLICK_KILL_GOLD = 2.5,      -- a kill whose last hit is a real click pays 2.5x (r2 B2, r3 B16)
  LEEROY_HEADLINE = 1.0, LEEROY_DELAY = 0.3, LEEROY_CRIT_SEC = 10, LEEROY_RUSH_WHELPS = true,
  ENEMY_TIP_DELAY = 0.8,
  BUYBEST_CHAIN_MAX = 100, BESTBUY_MIN_GAIN = 0.5, NEWRANK_SEC = 180, RANKPULL = 1.5,   -- r3 B17, E10
  NEXTJUMP_SEC = 900, NEXTJUMP_MIN = 0.05,   -- r4 E15: "Next:" looks 15 min of income ahead, shows jumps >= 5 points
  BESTBUY_SAVE_SEC = 20,      -- r2 E4: save for the best target when it is <= 20 s away (r4 B20: was lost in a comment)
  CLICK_QUEUE = 3,
  RARE_CHANCE = 0.025, RARE_GOLD = 5,
  COST_GROWTH = 1.07,
  MILESTONE_FIRST = 10, MILESTONE_SECOND = 25, MILESTONE_STEP = 25,
  UPG_AT = {10, 25, 50},
  UPG_COST_MULT = {10, 120, 1500},
  UPG_DPS_MULT = 2,
  ORACLE_AURA = 0.10, WARLEADER_AURA = 0.25, MURKEYE_PER = 0.01,
  TINYFIN_ECHO = 0.01, RAIDER_GOLD = 0.10, TIDE_TIMER = 5,
  CLICK_COST_BASE = 10, CLICK_COST_GROWTH = 1.15, CLICK_DOUBLE_EVERY = 25,
  ECHO_STEP = 0.04,
  ECHO_COSTS = {150, 1500, 50000, 500000, 5000000},   -- r3 B12
  CRIT_BASE = 0.05, CRIT_STEP = 0.01, CRIT_MAX = 20,
  CRIT_COST_BASE = 100, CRIT_COST_GROWTH = 1.6,
  CRITM_BASE = 3, CRITM_STEP = 0.5, CRITM_MAX = 14,
  CRITM_COST_BASE = 250, CRITM_COST_GROWTH = 1.8,
  SELF_CRIT_STAGE = 10,
  READY_GREEN = 1.2, READY_YELLOW = 0.8,
  OFFLINE_RATE = 0.5, OFFLINE_MAX = 28800, OFFLINE_POPUP_MIN = 60,
  SAVE_EVERY = 30,
  START_GOLD = 0,
  AUTO_FIGHT_DEFAULT = true, AUTO_FIGHT_DELAY = 2, AUTO_RETRY_DPS = 1.15,   -- r4 B22
  CLICK_WINDOW = 30,          -- seconds of measured clicks
  BESTBUY_CLICK_SHARE = 0.7, BESTBUY_CLICK_CAP = 8, BESTBUY_MIN_SHARE = 0.5,
  BESTBUY_GLOW_MIN = 3,       -- Buy best only pulses for a gain of at least 3 %

  OPENER_GAP = 0.35,
  WHELPS_CPS = 10,
  CANDLE_CRIT = 0.5,
  MRGL_DPS_SEC = 5,
  LEEROY_CLICKS = 5, LEEROY_DPS_SEC = 20, LEEROY_GOLD = 3,
  TEASER_SHARE = 0.25,        -- squad teaser shows at 25% of its price
  ZONES = 11,                 -- New Tide D: zone 11 = Blackwing Lair (was 10)
  STAGES_PER_ZONE = 10,
  -- New Tide (ngplus-plan C1): 1 point per New Tide in one path; Total() = 0 keeps every factor at 1
  TIDE_STAGE = 100,           -- unlock: Ragnaros reached
  TIDE_FLOOD_DMG = 1.0, TIDE_FLOOD_GOLD = 0.5,   -- "the tide": +100% murloc damage, +50% gold per point, every path
  TIDE_MURLOC = 0.5, TIDE_CLICK = 1.0, TIDE_SPELL = 2.0,   -- per path point: murloc damage, click damage, ability power
  TIDE_MILESTONES = {10, 25, 50, 100},
  TIDE_AUTOBUY_SEC = 10,      -- Quartermaster: Buy best every 10 game seconds
  TIDE_AUTOCLICK_CPS = 1, TIDE_AUTOCLICK_CPS_MAX = 2,   -- Self-Click 10 / 100
  TIDE_TIMER_PLUS = 10,       -- Spells 25: boss fight +10 s
  TIDE_OFFLINE_RATE = 0.75,   -- Murlocs 25 (else OFFLINE_RATE)
  TIDE_DISCOUNT = 0.25,       -- Murlocs 50
  TIDE_ANYFIN_SEC = 30,       -- Spells 50: Anyfin Can Happen deals 30 s of squad damage (MRGL_DPS_SEC stays 5)
  SCALE_MIN = 0.7, SCALE_MAX = 1.4, SCALE_STEP = 0.05,   -- r3 S6: 0.7-1.4
  -- j1 W1: in-world gold = max(KILLS x kill gold, SEC x idle income) at the farm stage
  WORLD_QUEST_KILLS = 3, WORLD_QUEST_SEC = 15, WORLD_LEVEL_KILLS = 30, WORLD_LEVEL_SEC = 240, WORLD_ZONE_KILLS = 5, WORLD_ZONE_SEC = 30,
  WORLD_QUEST_MAX = 12, WORLD_QUEST_WINDOW = 3600, WORLD_QUEST_LOCK = 5,   -- 12 counted quests per rolling hour, same questID once in 5 s
  VERSION = 1
}
