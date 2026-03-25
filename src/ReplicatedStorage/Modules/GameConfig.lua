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
    },
}

return GameConfig
