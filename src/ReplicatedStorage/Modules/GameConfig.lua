-- GameConfig.lua
-- Central constants for VoidRunner

local GameConfig = {
    -- Tunnel dimensions (studs)
    TUNNEL_HALF   = 14,   -- half-width/height of the tunnel
    SECTION_DEPTH = 10,   -- Z spacing between platform rows
    LEVEL_SECTIONS = 30,  -- rows per level

    -- Platform sizes
    FLOOR_PLATFORM_SIZE = Vector3.new(8, 1, 8),   -- horizontal (floor/ceiling)
    WALL_PLATFORM_SIZE  = Vector3.new(1, 8, 8),   -- vertical  (left/right walls)
    PLATFORM_COLS       = 3,                       -- platforms per row per face

    -- Level
    BOSS_EVERY_N   = 5,
    UPGRADES_COUNT = 3,   -- upgrade choices offered

    -- Player base stats
    BASE_MAX_HP      = 100,
    BASE_MOVE_SPEED  = 22,
    BASE_JUMP_POWER  = 55,

    -- Gravity
    GRAVITY_MAG              = 196.2,  -- matches workspace.Gravity default
    GRAVITY_SWITCH_COOLDOWN  = 1.5,

    -- Combat
    SHOOT_DAMAGE   = 25,
    SHOOT_SPEED    = 200,   -- studs/s (hitscan range)
    SHOOT_COOLDOWN = 0.25,
    MELEE_DAMAGE   = 40,
    MELEE_RANGE    = 8,
    MELEE_COOLDOWN = 0.45,
    BULLET_LIFETIME = 0.15,  -- seconds tracer is visible

    -- Enemy
    ENEMY_SPAWN_CHANCE = 0.14,  -- per floor section

    -- Combo system
    COMBO_WINDOW = 3.0,         -- seconds between kills to keep combo alive
    COMBO_TIERS  = {            -- min kills → score multiplier
        { kills = 2,  mult = 1.5  },
        { kills = 5,  mult = 2.0  },
        { kills = 10, mult = 3.0  },
        { kills = 20, mult = 5.0  },
    },

    -- HP drops
    HP_DROP_CHANCE  = 0.28,     -- chance an enemy drops an HP orb on death
    HP_DROP_AMOUNT  = 20,       -- HP restored by picking up an orb

    -- Level hazards / dynamics
    HAZARD_CHANCE           = 0.09,   -- chance a floor tile is a hazard
    HAZARD_DAMAGE           = 8,      -- damage per 0.5s of standing on hazard
    MOVING_PLATFORM_CHANCE  = 0.18,   -- chance a platform is a mover
    MOVER_SPEED             = 5,      -- studs per second travel speed

    -- Dash
    DASH_COOLDOWN  = 1.4,
    DASH_SPEED     = 60,
    DASH_DURATION  = 0.16,

    -- Critical hits
    CRIT_CHANCE = 0.15,
    CRIT_MULT   = 2.0,

    -- Elite enemies (activate at level 3+)
    ELITE_CHANCE = 0.22,

    -- Crumbling platforms
    CRUMBLE_CHANCE  = 0.10,
    CRUMBLE_WARN    = 1.2,   -- seconds of flashing before falling
    CRUMBLE_RESPAWN = 5.0,   -- seconds before reappearing

    -- Screen shake (applied client-side on damage)
    SHAKE_DURATION  = 0.45,
    SHAKE_INTENSITY = 0.45,

    -- Zone themes
    ZONES = {
        {
            name       = "Derelict Station",
            floorColor = Color3.fromRGB(55, 60, 78),
            wallColor  = Color3.fromRGB(40, 44, 60),
            accentColor= Color3.fromRGB(80, 140, 255),
            enemies    = { "Scout", "Drone" },
        },
        {
            name       = "Alien Jungle",
            floorColor = Color3.fromRGB(28, 78, 42),
            wallColor  = Color3.fromRGB(18, 58, 30),
            accentColor= Color3.fromRGB(80, 255, 140),
            enemies    = { "Crawler", "Spitter" },
        },
        {
            name       = "Robot Factory",
            floorColor = Color3.fromRGB(82, 58, 38),
            wallColor  = Color3.fromRGB(62, 44, 28),
            accentColor= Color3.fromRGB(255, 160, 60),
            enemies    = { "Grunt", "Heavy" },
        },
        {
            name       = "The Void",
            floorColor = Color3.fromRGB(22, 18, 46),
            wallColor  = Color3.fromRGB(14, 10, 36),
            accentColor= Color3.fromRGB(200, 80, 255),
            enemies    = { "Scout", "Crawler", "Grunt" },
        },
        {
            name       = "Frozen Wastes",
            floorColor = Color3.fromRGB(155, 195, 230),
            wallColor  = Color3.fromRGB(110, 155, 200),
            accentColor= Color3.fromRGB(190, 240, 255),
            enemies    = { "Phantom", "SniperBot", "RazorWing" },
            stalactites = true,
        },
        {
            name       = "Deep Space Station",
            floorColor = Color3.fromRGB(22, 26, 44),
            wallColor  = Color3.fromRGB(15, 18, 34),
            accentColor= Color3.fromRGB(55, 195, 255),
            enemies    = { "Drone", "Bomber", "Turret", "VoidStalker" },
        },
        {
            name       = "Ancient Ruins",
            floorColor = Color3.fromRGB(52, 76, 42),
            wallColor  = Color3.fromRGB(38, 58, 30),
            accentColor= Color3.fromRGB(125, 255, 95),
            enemies    = { "AcidCrawler", "Swarm", "Berserker", "CrystalGolem" },
            ruinPillars = true,
        },
        {
            name       = "Reactor Core",
            floorColor = Color3.fromRGB(68, 28, 18),
            wallColor  = Color3.fromRGB(50, 20, 12),
            accentColor= Color3.fromRGB(255, 85, 18),
            enemies    = { "Turret", "Juggernaut", "SpiderMine" },
            hazardMult = 2.2,
        },
        {
            name       = "Shadow Realm",
            floorColor = Color3.fromRGB(18, 10, 28),
            wallColor  = Color3.fromRGB(12, 6, 20),
            accentColor= Color3.fromRGB(160, 40, 220),
            enemies    = { "ShadowWraith", "VoidStalker", "Necromancer" },
            hazardMult = 1.5,
        },
        {
            name       = "Corrupted Citadel",
            floorColor = Color3.fromRGB(40, 30, 55),
            wallColor  = Color3.fromRGB(28, 20, 42),
            accentColor= Color3.fromRGB(220, 80, 140),
            enemies    = { "MechKnight", "Shielder", "ShadowWraith", "Necromancer" },
            ruinPillars = true,
        },
    },
}

return GameConfig
