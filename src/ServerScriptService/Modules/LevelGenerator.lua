-- LevelGenerator.lua (ModuleScript)
-- Generates a tunnel-corridor level similar to "Run".
-- The tunnel runs along the +Z axis.
-- Four platform faces: floor (y=0), ceiling (y=TOP), left wall (x=-HALF), right wall (x=HALF).
-- Gaps on every face force gravity switching.

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local LevelGenerator = {}

local HALF    = GameConfig.TUNNEL_HALF      -- 14
local DEPTH   = GameConfig.SECTION_DEPTH    -- 10
local SECTIONS= GameConfig.LEVEL_SECTIONS   -- 30
local COLS    = GameConfig.PLATFORM_COLS    -- 3
local FSIZE   = GameConfig.FLOOR_PLATFORM_SIZE
local WSIZE   = GameConfig.WALL_PLATFORM_SIZE

-- Column X offsets for floor/ceiling (3 lanes: left, center, right)
local COL_X = { -HALF * 0.55, 0, HALF * 0.55 }
-- Column Y offsets for left/right walls (3 lanes: bottom, mid, top)
local COL_Y = { -(HALF * 0.55), 0, HALF * 0.55 }

local function makePart(size, color, material, parent)
    local p = Instance.new("Part")
    p.Size     = size
    p.Color    = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = true
    p.CastShadow = false
    p.Parent   = parent
    return p
end

local function addGlowStrip(part, accentColor, parent)
    local strip = makePart(
        Vector3.new(part.Size.X * 0.3, 0.1, part.Size.Z * 0.3),
        accentColor,
        Enum.Material.Neon,
        parent
    )
    strip.CanCollide = false
    strip.CFrame = part.CFrame * CFrame.new(0, part.Size.Y * 0.5 + 0.05, 0)
end

-- Build tunnel boundary walls (non-collidable visual shells)
local function buildTunnelShell(totalZ, zone, folder)
    local shellColor = zone.wallColor
    local thickness  = 2
    local height     = HALF * 2 + thickness * 2
    local length     = totalZ + DEPTH * 2

    -- Left wall
    local lw = makePart(Vector3.new(thickness, height, length), shellColor, Enum.Material.SmoothPlastic, folder)
    lw.Name = "TunnelLeft"
    lw.CFrame = CFrame.new(-HALF - thickness * 0.5, 0, totalZ * 0.5)
    lw.CanCollide = false

    -- Right wall
    local rw = makePart(Vector3.new(thickness, height, length), shellColor, Enum.Material.SmoothPlastic, folder)
    rw.Name = "TunnelRight"
    rw.CFrame = CFrame.new(HALF + thickness * 0.5, 0, totalZ * 0.5)
    rw.CanCollide = false

    -- Ceiling shell
    local cs = makePart(Vector3.new(HALF * 2, thickness, length), shellColor, Enum.Material.SmoothPlastic, folder)
    cs.Name = "TunnelCeiling"
    cs.CFrame = CFrame.new(0, HALF + thickness * 0.5, totalZ * 0.5)
    cs.CanCollide = false

    -- Floor shell
    local fs = makePart(Vector3.new(HALF * 2, thickness, length), shellColor, Enum.Material.SmoothPlastic, folder)
    fs.Name = "TunnelFloor"
    fs.CFrame = CFrame.new(0, -HALF - thickness * 0.5, totalZ * 0.5)
    fs.CanCollide = false
end

-- Creates the end portal marker
local function buildEndPortal(z, folder)
    local portal = makePart(Vector3.new(HALF * 2, HALF * 2, 2), Color3.fromRGB(100, 220, 255), Enum.Material.Neon, folder)
    portal.Name        = "EndPortal"
    portal.CanCollide  = false
    portal.Transparency = 0.5
    portal.CFrame      = CFrame.new(0, 0, z + DEPTH)

    -- Tag so the server knows to detect player overlap
    local tag = Instance.new("BoolValue")
    tag.Name   = "IsEndPortal"
    tag.Parent = portal
end

-- Generate one level.
-- Returns (levelFolder, enemySpawnList)
-- enemySpawnList: array of { position, enemyType }
function LevelGenerator.generate(levelNumber, parent)
    local zone = GameConfig.ZONES[((levelNumber - 1) % #GameConfig.ZONES) + 1]
    local rng  = Random.new(levelNumber * 31337)

    local folder = Instance.new("Folder")
    folder.Name  = "Level_" .. levelNumber
    folder.Parent = parent

    -- Gap probability scales with level (max 45%)
    local gapChance = math.min(0.08 + levelNumber * 0.018, 0.45)

    local enemySpawns = {}
    local totalZ = SECTIONS * DEPTH

    buildTunnelShell(totalZ, zone, folder)

    for i = 0, SECTIONS do
        local z    = i * DEPTH
        local safe = (i <= 1 or i >= SECTIONS - 1)  -- always solid near start/end

        -- ── FLOOR platforms (y = -HALF + FSIZE.Y*0.5) ─────────────────
        for _, x in ipairs(COL_X) do
            if safe or rng:NextNumber() > gapChance then
                local p = makePart(FSIZE, zone.floorColor, Enum.Material.SmoothPlastic, folder)
                p.CFrame = CFrame.new(x, -HALF + FSIZE.Y * 0.5, z)
                addGlowStrip(p, zone.accentColor, folder)
                -- Enemy spawn (not on first/last 3 sections)
                if i > 2 and i < SECTIONS - 2 and rng:NextNumber() < GameConfig.ENEMY_SPAWN_CHANCE then
                    local types = zone.enemies
                    table.insert(enemySpawns, {
                        position  = Vector3.new(x, -HALF + FSIZE.Y + 2, z),
                        enemyType = types[rng:NextInteger(1, #types)],
                    })
                end
            end
        end

        -- ── CEILING platforms (y = HALF - FSIZE.Y*0.5) ─────────────────
        for _, x in ipairs(COL_X) do
            if safe or rng:NextNumber() > gapChance + 0.1 then
                local p = makePart(FSIZE, zone.wallColor, Enum.Material.SmoothPlastic, folder)
                p.CFrame = CFrame.new(x, HALF - FSIZE.Y * 0.5, z)
            end
        end

        -- ── LEFT WALL platforms (x = -HALF + WSIZE.X*0.5) ─────────────
        for _, y in ipairs(COL_Y) do
            if safe or rng:NextNumber() > gapChance + 0.05 then
                local p = makePart(WSIZE, zone.wallColor, Enum.Material.SmoothPlastic, folder)
                p.CFrame = CFrame.new(-HALF + WSIZE.X * 0.5, y, z)
            end
        end

        -- ── RIGHT WALL platforms (x = HALF - WSIZE.X*0.5) ─────────────
        for _, y in ipairs(COL_Y) do
            if safe or rng:NextNumber() > gapChance + 0.05 then
                local p = makePart(WSIZE, zone.wallColor, Enum.Material.SmoothPlastic, folder)
                p.CFrame = CFrame.new(HALF - WSIZE.X * 0.5, y, z)
            end
        end
    end

    buildEndPortal(totalZ, folder)

    return folder, enemySpawns
end

return LevelGenerator
