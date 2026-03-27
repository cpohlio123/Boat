-- LevelGenerator.lua (ModuleScript)
-- Generates a tunnel-corridor level with gaps, moving platforms,
-- hazard tiles, obstacle pillars, and ambient lighting.

local GameConfig   = require(game:GetService("ReplicatedStorage").Modules.GameConfig)
local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")
local Debris       = game:GetService("Debris")

local LevelGenerator = {}
LevelGenerator.onHazardDamage = nil

local HALF    = GameConfig.TUNNEL_HALF
local DEPTH   = GameConfig.SECTION_DEPTH
local SECTIONS= GameConfig.LEVEL_SECTIONS
local COLS    = GameConfig.PLATFORM_COLS
local FSIZE   = GameConfig.FLOOR_PLATFORM_SIZE
local WSIZE   = GameConfig.WALL_PLATFORM_SIZE

local COL_X = { -HALF * 0.55, 0, HALF * 0.55 }
local COL_Y = { -(HALF * 0.55), 0, HALF * 0.55 }

local function makePart(size, color, material, parent)
    local p = Instance.new("Part")
    p.Size       = size
    p.Color      = color
    p.Material   = material or Enum.Material.SmoothPlastic
    p.Anchored   = true
    p.CanCollide = true
    p.CastShadow = false
    p.Parent     = parent
    return p
end

local function addGlowStrip(part, accentColor, parent)
    local strip = makePart(Vector3.new(part.Size.X * 0.3, 0.1, part.Size.Z * 0.3), accentColor, Enum.Material.Neon, parent)
    strip.CanCollide = false
    strip.CFrame     = part.CFrame * CFrame.new(0, part.Size.Y * 0.5 + 0.05, 0)
end

local function addPointLight(part, color, brightness)
    local light = Instance.new("PointLight")
    light.Color      = color
    light.Brightness = brightness or 1.5
    light.Range      = 18
    light.Shadows    = false
    light.Parent     = part
end

local function makeHazardPlatform(pos, folder)
    local p = makePart(FSIZE, Color3.fromRGB(190, 30, 20), Enum.Material.SmoothPlastic, folder)
    p.Name = "HazardPlatform"; p.CFrame = CFrame.new(pos); p.Transparency = 0.15
    local warning = makePart(Vector3.new(FSIZE.X * 0.7, 0.15, FSIZE.Z * 0.7), Color3.fromRGB(255, 80, 0), Enum.Material.Neon, folder)
    warning.CanCollide = false; warning.CastShadow = false
    warning.CFrame = CFrame.new(pos) * CFrame.new(0, FSIZE.Y * 0.5 + 0.08, 0)
    addPointLight(warning, Color3.fromRGB(255, 80, 20), 2)
    TweenService:Create(warning, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 }):Play()
    local lastDmg = {}
    p.Touched:Connect(function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character == char then
                local uid = player.UserId; local now = tick()
                if not lastDmg[uid] or now - lastDmg[uid] >= 0.5 then
                    lastDmg[uid] = now
                    if LevelGenerator.onHazardDamage then LevelGenerator.onHazardDamage(player, GameConfig.HAZARD_DAMAGE) end
                end
            end
        end
    end)
end

local function makeMovingPlatform(startPos, endPos, size, color, accentColor, folder)
    local p = makePart(size, color, Enum.Material.SmoothPlastic, folder)
    p.Name = "MovingPlatform"; p.CFrame = CFrame.new(startPos)
    addGlowStrip(p, accentColor, folder)
    local dist = (endPos - startPos).Magnitude
    TweenService:Create(p, TweenInfo.new(dist / GameConfig.MOVER_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = CFrame.new(endPos) }):Play()
    return p
end

local function makePillar(z, yCenter, folder, wallColor)
    local height = HALF * 0.7
    local pillar = makePart(Vector3.new(2, height, 2), wallColor, Enum.Material.SmoothPlastic, folder)
    pillar.Name = "Pillar"; pillar.CFrame = CFrame.new(0, yCenter, z)
    local band = makePart(Vector3.new(2.2, 0.5, 2.2), Color3.fromRGB(80, 180, 255), Enum.Material.Neon, folder)
    band.CanCollide = false; band.CFrame = CFrame.new(0, yCenter, z)
    addPointLight(band, Color3.fromRGB(80, 180, 255), 1.2)
end

local function makeCrumblingPlatform(pos, folder, zone)
    local p = makePart(FSIZE, zone.floorColor:Lerp(Color3.fromRGB(200, 140, 70), 0.35), Enum.Material.SmoothPlastic, folder)
    p.Name = "CrumblingPlatform"; p.CFrame = CFrame.new(pos)
    local cracks = makePart(Vector3.new(FSIZE.X * 0.75, 0.12, FSIZE.Z * 0.75), Color3.fromRGB(55, 35, 18), Enum.Material.SmoothPlastic, folder)
    cracks.CanCollide = false; cracks.CFrame = CFrame.new(pos) * CFrame.new(0, FSIZE.Y * 0.5 + 0.06, 0)
    local crumbling = false
    p.Touched:Connect(function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character == char then
                if crumbling then return end
                crumbling = true
                task.spawn(function()
                    local origColor = p.Color
                    local ticks = math.floor(GameConfig.CRUMBLE_WARN / 0.14)
                    for _ = 1, ticks do
                        if not p.Parent then return end
                        p.Color = Color3.fromRGB(255, 80, 20); task.wait(0.07)
                        p.Color = origColor; task.wait(0.07)
                    end
                    if not p.Parent then return end
                    p.Transparency = 0.5; cracks.Transparency = 0.5; p.CanCollide = false
                    task.wait(0.2)
                    p.Transparency = 1; cracks.Transparency = 1
                    task.wait(GameConfig.CRUMBLE_RESPAWN)
                    if not p.Parent then return end
                    p.Transparency = 0; cracks.Transparency = 0; p.CanCollide = true; p.Color = origColor; crumbling = false
                end)
                return
            end
        end
    end)
end

local function buildTunnelShell(totalZ, zone, folder)
    local thickness = 2; local height = HALF * 2 + thickness * 2; local length = totalZ + DEPTH * 2
    local sides = {
        { name = "TLeft",    size = Vector3.new(thickness, height, length), pos = Vector3.new(-HALF - thickness*0.5, 0, totalZ*0.5) },
        { name = "TRight",   size = Vector3.new(thickness, height, length), pos = Vector3.new( HALF + thickness*0.5, 0, totalZ*0.5) },
        { name = "TCeiling", size = Vector3.new(HALF*2, thickness, length), pos = Vector3.new(0,  HALF + thickness*0.5, totalZ*0.5) },
        { name = "TFloor",   size = Vector3.new(HALF*2, thickness, length), pos = Vector3.new(0, -HALF - thickness*0.5, totalZ*0.5) },
    }
    for _, s in ipairs(sides) do
        local p = makePart(s.size, zone.wallColor, Enum.Material.SmoothPlastic, folder)
        p.Name = s.name; p.CFrame = CFrame.new(s.pos); p.CanCollide = false
    end
end

local function buildEndPortal(z, accentColor, folder)
    local portal = makePart(Vector3.new(HALF * 2, HALF * 2, 2), accentColor, Enum.Material.Neon, folder)
    portal.Name = "EndPortal"; portal.CanCollide = false; portal.Transparency = 0.45
    portal.CFrame = CFrame.new(0, 0, z + DEPTH)
    addPointLight(portal, accentColor, 3)
    TweenService:Create(portal, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
    local tag = Instance.new("BoolValue"); tag.Name = "IsEndPortal"; tag.Parent = portal
end

local function makeStalactite(z, folder, color)
    local height = HALF * 0.45 + math.random() * HALF * 0.25
    local spike = makePart(Vector3.new(1.5, height, 1.5), color, Enum.Material.SmoothPlastic, folder)
    spike.Name = "Stalactite"; spike.CanCollide = true
    spike.CFrame = CFrame.new((math.random() - 0.5) * HALF * 1.2, HALF - height * 0.5, z)
end

local function makeRuinArch(z, folder, color)
    local h = HALF * 0.6
    for _, sx in ipairs({ -HALF * 0.65, HALF * 0.65 }) do
        local p = makePart(Vector3.new(2.5, h, 2.5), color, Enum.Material.SmoothPlastic, folder)
        p.Name = "RuinArch"; p.CFrame = CFrame.new(sx, -HALF + h * 0.5, z)
        local cap = makePart(Vector3.new(3.2, 1, 3.2), color:Lerp(Color3.new(1,1,1), 0.15), Enum.Material.SmoothPlastic, folder)
        cap.CanCollide = false; cap.CFrame = CFrame.new(sx, -HALF + h + 0.5, z)
    end
end

function LevelGenerator.generate(levelNumber, parent)
    local zone = GameConfig.ZONES[((levelNumber - 1) % #GameConfig.ZONES) + 1]
    local rng  = Random.new(levelNumber * 31337)
    local folder = Instance.new("Folder")
    folder.Name = "Level_" .. levelNumber; folder.Parent = parent

    local effectiveHazardChance = GameConfig.HAZARD_CHANCE * (zone.hazardMult or 1.0)
    local gapChance    = math.min(0.08 + levelNumber * 0.018, 0.48)
    local enemySpawns  = {}
    local totalZ       = SECTIONS * DEPTH

    buildTunnelShell(totalZ, zone, folder)

    -- Spawn pad is 4 studs thick so characters can NEVER clip through it.
    -- Top surface is at Y = -HALF + 4, matching the teleport target in GameManager.
    local PAD_THICK = 4
    local spawnPadY = -HALF + PAD_THICK * 0.5
    local spawnPad = makePart(Vector3.new(HALF * 2, PAD_THICK, DEPTH * 4), zone.floorColor, Enum.Material.SmoothPlastic, folder)
    spawnPad.Name = "SpawnPad"; spawnPad.CFrame = CFrame.new(0, spawnPadY, DEPTH * 2)

    local spawnAccent = makePart(Vector3.new(HALF * 2, 0.12, DEPTH * 4), zone.accentColor, Enum.Material.Neon, folder)
    spawnAccent.CFrame = CFrame.new(0, spawnPadY + PAD_THICK * 0.5 + 0.06, DEPTH * 2)
    spawnAccent.CanCollide = false; spawnAccent.Transparency = 0.7

    local anchor = makePart(Vector3.new(0.1,0.1,0.1), Color3.new(0,0,0), Enum.Material.SmoothPlastic, folder)
    anchor.CanCollide = false; anchor.Transparency = 1; anchor.CFrame = CFrame.new(0, 0, -5)
    local startLight = Instance.new("PointLight", anchor)
    startLight.Color = zone.accentColor; startLight.Brightness = 2; startLight.Range = 30

    for i = 0, SECTIONS do
        local z    = i * DEPTH
        local safe = (i <= 1 or i >= SECTIONS - 1)

        for _, x in ipairs(COL_X) do
            if safe or rng:NextNumber() > gapChance then
                local isHazard  = not safe and rng:NextNumber() < effectiveHazardChance
                local isMover   = not safe and not isHazard and rng:NextNumber() < GameConfig.MOVING_PLATFORM_CHANCE
                local isCrumble = not safe and not isHazard and not isMover and rng:NextNumber() < GameConfig.CRUMBLE_CHANCE
                if isHazard then
                    makeHazardPlatform(Vector3.new(x, -HALF + FSIZE.Y * 0.5, z), folder)
                elseif isCrumble then
                    makeCrumblingPlatform(Vector3.new(x, -HALF + FSIZE.Y * 0.5, z), folder, zone)
                elseif isMover then
                    local offset = rng:NextNumber() * 6 - 3
                    makeMovingPlatform(Vector3.new(x - offset, -HALF + FSIZE.Y * 0.5, z), Vector3.new(x + offset, -HALF + FSIZE.Y * 0.5, z), FSIZE, zone.floorColor, zone.accentColor, folder)
                else
                    local p = makePart(FSIZE, zone.floorColor, Enum.Material.SmoothPlastic, folder)
                    p.CFrame = CFrame.new(x, -HALF + FSIZE.Y * 0.5, z)
                    if i % 4 == 0 then addGlowStrip(p, zone.accentColor, folder) end
                    if i % 8 == 0 then addPointLight(p, zone.accentColor, 1.0) end
                end
                if i > 4 and i < SECTIONS - 2 and rng:NextNumber() < GameConfig.ENEMY_SPAWN_CHANCE then
                    local types = zone.enemies
                    table.insert(enemySpawns, { position = Vector3.new(x, -HALF + FSIZE.Y + 2.5, z), enemyType = types[rng:NextInteger(1, #types)], face = "floor" })
                end
            end
        end

        for _, x in ipairs(COL_X) do
            if safe or rng:NextNumber() > gapChance + 0.08 then
                if not safe and rng:NextNumber() < GameConfig.MOVING_PLATFORM_CHANCE * 0.5 then
                    local off = rng:NextNumber() * 4 - 2
                    makeMovingPlatform(Vector3.new(x - off, HALF - FSIZE.Y * 0.5, z), Vector3.new(x + off, HALF - FSIZE.Y * 0.5, z), FSIZE, zone.wallColor, zone.accentColor, folder)
                else
                    local p = makePart(FSIZE, zone.wallColor, Enum.Material.SmoothPlastic, folder)
                    p.CFrame = CFrame.new(x, HALF - FSIZE.Y * 0.5, z)
                end
            end
        end

        for _, y in ipairs(COL_Y) do
            if safe or rng:NextNumber() > gapChance + 0.04 then
                if not safe and rng:NextNumber() < GameConfig.MOVING_PLATFORM_CHANCE * 0.6 then
                    local off = rng:NextNumber() * 3 - 1.5
                    makeMovingPlatform(Vector3.new(-HALF + WSIZE.X * 0.5, y - off, z), Vector3.new(-HALF + WSIZE.X * 0.5, y + off, z), WSIZE, zone.wallColor, zone.accentColor, folder)
                else
                    local p = makePart(WSIZE, zone.wallColor, Enum.Material.SmoothPlastic, folder)
                    p.CFrame = CFrame.new(-HALF + WSIZE.X * 0.5, y, z)
                end
            end
        end

        for _, y in ipairs(COL_Y) do
            if safe or rng:NextNumber() > gapChance + 0.04 then
                if not safe and rng:NextNumber() < GameConfig.MOVING_PLATFORM_CHANCE * 0.6 then
                    local off = rng:NextNumber() * 3 - 1.5
                    makeMovingPlatform(Vector3.new(HALF - WSIZE.X * 0.5, y - off, z), Vector3.new(HALF - WSIZE.X * 0.5, y + off, z), WSIZE, zone.wallColor, zone.accentColor, folder)
                else
                    local p = makePart(WSIZE, zone.wallColor, Enum.Material.SmoothPlastic, folder)
                    p.CFrame = CFrame.new(HALF - WSIZE.X * 0.5, y, z)
                end
            end
        end

        if i > 4 and i < SECTIONS - 2 and i % 7 == 0 and rng:NextNumber() < 0.55 then
            makePillar(z, 0, folder, zone.wallColor)
        end

        if i > 2 and i < SECTIONS - 1 then
            if zone.stalactites and i % 3 == 0 and rng:NextNumber() < 0.60 then
                makeStalactite(z, folder, zone.accentColor:Lerp(Color3.new(1,1,1), 0.4))
            end
            if zone.ruinPillars and i % 9 == 0 and rng:NextNumber() < 0.65 then
                makeRuinArch(z, folder, zone.floorColor:Lerp(Color3.new(0,0,0), 0.2))
            end
        end
    end

    buildEndPortal(totalZ, zone.accentColor, folder)
    return folder, enemySpawns
end

return LevelGenerator