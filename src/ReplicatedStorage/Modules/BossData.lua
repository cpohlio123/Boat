-- BossData.lua
-- Boss definitions indexed by level number (every 5th level)

local BossData = {
    -- Level 5
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
                hpRatio    = 1.0,   -- starts at full HP
                attacks    = { "laser_sweep", "rocket_volley" },
                cooldown   = 3.0,
                speedMult  = 1.0,
            },
            {
                hpRatio    = 0.5,   -- activates below 50%
                attacks    = { "laser_sweep", "rocket_volley", "gravity_pulse" },
                cooldown   = 2.0,
                speedMult  = 1.4,
                enraged    = true,
            },
        },
    },

    -- Level 10
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

    -- Level 15
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
}

-- Cycle bosses for levels beyond 15
local function getBossForLevel(level)
    if BossData[level] then return BossData[level] end
    -- Cycle: 20→5-equivalent, 25→10-equivalent, etc.
    local cycle = { 5, 10, 15 }
    local idx   = ((math.floor(level / 5) - 1) % #cycle) + 1
    local base  = BossData[cycle[idx]]
    -- Scale HP
    local scaled = {}
    for k, v in pairs(base) do scaled[k] = v end
    scaled.maxHp = base.maxHp * (1 + (level - cycle[idx]) * 0.15)
    scaled.score = math.floor(base.score * (1 + (level - cycle[idx]) * 0.2))
    return scaled
end

BossData.getForLevel = getBossForLevel

return BossData
