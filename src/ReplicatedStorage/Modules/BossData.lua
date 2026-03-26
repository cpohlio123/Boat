-- BossData.lua
-- Boss definitions indexed by level number (every 5th level)

local BossData = {
    -- ── Level 5: Guardian MK-I ────────────────────────────────────────────────
    [5] = {
        id          = "GuardianMk1",
        displayName = "Guardian MK-I",
        subtitle    = "Station Defense System",
        maxHp       = 600,
        speed       = 8,
        color       = Color3.fromRGB(70, 110, 200),
        bodySize    = Vector3.new(10, 12, 10),
        score       = 1000,
        phases = {
            {
                hpRatio   = 1.0,
                attacks   = { "laser_sweep", "rocket_volley" },
                cooldown  = 3.0,
                speedMult = 1.0,
            },
            {
                hpRatio   = 0.5,
                attacks   = { "laser_sweep", "rocket_volley", "gravity_pulse" },
                cooldown  = 2.0,
                speedMult = 1.4,
                enraged   = true,
            },
        },
    },

    -- ── Level 10: Brood Queen ─────────────────────────────────────────────────
    [10] = {
        id          = "QueenBrood",
        displayName = "Brood Queen",
        subtitle    = "Hive Mother",
        maxHp       = 1000,
        speed       = 10,
        color       = Color3.fromRGB(50, 200, 70),
        bodySize    = Vector3.new(12, 9, 14),
        score       = 1800,
        phases = {
            {
                hpRatio  = 1.0,
                attacks  = { "acid_spit", "spawn_minions" },
                cooldown = 2.5,
                speedMult= 1.0,
            },
            {
                hpRatio  = 0.6,
                attacks  = { "acid_spit", "spawn_minions", "leap_slam" },
                cooldown = 2.0,
                speedMult= 1.3,
            },
            {
                hpRatio  = 0.3,
                attacks  = { "acid_spray", "spawn_minions", "leap_slam" },
                cooldown = 1.5,
                speedMult= 1.6,
                enraged  = true,
            },
        },
    },

    -- ── Level 15: OMEGA CORE ──────────────────────────────────────────────────
    [15] = {
        id          = "OmegaCore",
        displayName = "OMEGA CORE",
        subtitle    = "Rogue AI Construct",
        maxHp       = 1600,
        speed       = 14,
        color       = Color3.fromRGB(220, 70, 255),
        bodySize    = Vector3.new(14, 14, 14),
        score       = 2800,
        phases = {
            {
                hpRatio  = 1.0,
                attacks  = { "energy_burst", "homing_missiles" },
                cooldown = 2.0,
                speedMult= 1.0,
            },
            {
                hpRatio  = 0.67,
                attacks  = { "energy_burst", "homing_missiles", "gravity_invert" },
                cooldown = 1.5,
                speedMult= 1.3,
            },
            {
                hpRatio  = 0.33,
                attacks  = { "energy_burst", "homing_missiles", "gravity_invert", "beam_sweep" },
                cooldown = 1.0,
                speedMult= 1.6,
                enraged  = true,
            },
        },
    },

    -- ── Level 20: Void Titan ──────────────────────────────────────────────────
    [20] = {
        id          = "VoidTitan",
        displayName = "Void Titan",
        subtitle    = "Ancient Machine of Destruction",
        maxHp       = 2400,
        speed       = 7,
        color       = Color3.fromRGB(30, 20, 80),
        bodySize    = Vector3.new(18, 20, 18),
        score       = 4000,
        phases = {
            {
                hpRatio  = 1.0,
                attacks  = { "gravity_slam", "shield_pulse", "stomp_shockwave" },
                cooldown = 2.5,
                speedMult= 1.0,
            },
            {
                hpRatio  = 0.65,
                attacks  = { "gravity_slam", "void_orbs", "stomp_shockwave", "laser_beam" },
                cooldown = 2.0,
                speedMult= 1.25,
            },
            {
                hpRatio  = 0.3,
                attacks  = { "void_orbs", "gravity_slam", "laser_beam", "shield_pulse" },
                cooldown = 1.2,
                speedMult= 1.6,
                enraged  = true,
            },
        },
    },

    -- ── Level 25: Plague Bringer ──────────────────────────────────────────────
    [25] = {
        id          = "PlagueBringer",
        displayName = "Plague Bringer",
        subtitle    = "Corrupted Hive Oracle",
        maxHp       = 3200,
        speed       = 11,
        color       = Color3.fromRGB(90, 200, 30),
        bodySize    = Vector3.new(14, 11, 16),
        score       = 5500,
        phases = {
            {
                hpRatio  = 1.0,
                attacks  = { "plague_cloud", "spawn_swarms", "toxic_lunge" },
                cooldown = 2.2,
                speedMult= 1.0,
            },
            {
                hpRatio  = 0.6,
                attacks  = { "plague_cloud", "spawn_swarms", "toxic_lunge", "spore_burst" },
                cooldown = 1.8,
                speedMult= 1.3,
            },
            {
                hpRatio  = 0.25,
                attacks  = { "plague_nova", "spawn_swarms", "toxic_lunge", "spore_burst" },
                cooldown = 1.2,
                speedMult= 1.8,
                enraged  = true,
            },
        },
    },

    -- ── Level 30: Iron Colossus ───────────────────────────────────────────────
    [30] = {
        id          = "IronColossus",
        displayName = "Iron Colossus",
        subtitle    = "War Engine Prototype",
        maxHp       = 4500,
        speed       = 5,
        color       = Color3.fromRGB(160, 90, 30),
        bodySize    = Vector3.new(22, 26, 22),
        score       = 7500,
        phases = {
            {
                hpRatio  = 1.0,
                attacks  = { "stomp_shockwave", "missile_barrage" },
                cooldown = 3.0,
                speedMult= 1.0,
            },
            {
                hpRatio  = 0.75,
                attacks  = { "stomp_shockwave", "missile_barrage", "laser_sweep" },
                cooldown = 2.2,
                speedMult= 1.15,
            },
            {
                hpRatio  = 0.45,
                attacks  = { "stomp_shockwave", "missile_barrage", "laser_sweep", "self_repair" },
                cooldown = 1.8,
                speedMult= 1.3,
            },
            {
                hpRatio  = 0.2,
                attacks  = { "stomp_shockwave", "missile_barrage", "laser_sweep", "overdrive" },
                cooldown = 1.0,
                speedMult= 1.7,
                enraged  = true,
            },
        },
    },

    -- ── Level 35: The Singularity ─────────────────────────────────────────────
    [35] = {
        id          = "TheSingularity",
        displayName = "THE SINGULARITY",
        subtitle    = "End of All Things",
        maxHp       = 6500,
        speed       = 16,
        color       = Color3.fromRGB(255, 20, 120),
        bodySize    = Vector3.new(16, 16, 16),
        score       = 12000,
        phases = {
            {
                hpRatio  = 1.0,
                attacks  = { "void_pull", "reality_fracture" },
                cooldown = 2.0,
                speedMult= 1.0,
            },
            {
                hpRatio  = 0.75,
                attacks  = { "void_pull", "reality_fracture", "phase_shift" },
                cooldown = 1.6,
                speedMult= 1.25,
            },
            {
                hpRatio  = 0.45,
                attacks  = { "void_pull", "oblivion_beam", "phase_shift", "gravity_invert" },
                cooldown = 1.2,
                speedMult= 1.5,
            },
            {
                hpRatio  = 0.15,
                attacks  = { "oblivion_beam", "void_pull", "reality_fracture", "phase_shift", "gravity_invert" },
                cooldown = 0.8,
                speedMult= 2.0,
                enraged  = true,
            },
        },
    },
}

-- ── Level lookup ─────────────────────────────────────────────────────────────
local BOSS_LEVELS = { 5, 10, 15, 20, 25, 30, 35 }

local function getBossForLevel(level)
    if BossData[level] then return BossData[level] end
    -- Cycle through all bosses for levels beyond 35
    local idx  = ((math.floor(level / 5) - 1) % #BOSS_LEVELS) + 1
    local base = BossData[BOSS_LEVELS[idx]]
    local extra = math.floor(level / 5) - #BOSS_LEVELS   -- how many cycles past the last boss
    local scaled = {}
    for k, v in pairs(base) do scaled[k] = v end
    scaled.maxHp = math.floor(base.maxHp * (1 + extra * 0.25))
    scaled.score = math.floor(base.score * (1 + extra * 0.30))
    return scaled
end

BossData.getForLevel = getBossForLevel

return BossData
