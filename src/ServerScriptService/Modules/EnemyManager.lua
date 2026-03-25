-- EnemyManager.lua (ModuleScript)
-- Spawns enemies, runs server-side AI, handles damage, HP orb drops.

local Players   = game:GetService("Players")
local Debris    = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyData = require(ReplicatedStorage.Modules.EnemyData)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local EnemyManager = {}

-- Callbacks wired by GameManager
EnemyManager.onEnemyAttackPlayer = nil   -- function(ps, damage, dotInfo)
EnemyManager.onHPPickup          = nil   -- function(ps)
EnemyManager.onHazardDamage      = nil   -- function(player, damage)

-- Player state registry (for AI targeting)
EnemyManager.playerStates = {}

local activeEnemies  = {}
local deadEnemyNames = {}  -- [id] = { name, isElite } kept briefly for kill feed
local nextEnemyId    = 1

-- Elite data copy with boosted stats
local function makeEliteData(base)
    local d = {}
    for k, v in pairs(base) do d[k] = v end
    d.displayName  = "★ " .. base.displayName
    d.maxHp        = base.maxHp  * 2
    d.attackDamage = base.attackDamage * 1.5
    d.speed        = base.speed  * 1.25
    d.color        = Color3.fromRGB(
        math.min(255, math.floor(base.color.R * 255 + 70)),
        math.max(0,   math.floor(base.color.G * 255 - 40)),
        math.max(0,   math.floor(base.color.B * 255 - 40))
    )
    return d
end

local function newId()
    local id = "E" .. nextEnemyId; nextEnemyId = nextEnemyId + 1; return id
end

-- ── Visual builder ─────────────────────────────────────────────────────────
local function buildEnemyModel(data, position, folder)
    local model = Instance.new("Model")
    model.Name  = data.displayName

    local body = Instance.new("Part")
    body.Name        = "Body"
    body.Size        = data.bodySize
    body.Color       = data.color
    body.Material    = Enum.Material.SmoothPlastic
    body.Anchored    = true
    body.CanCollide  = true
    body.CastShadow  = false
    body.CFrame      = CFrame.new(position)
    body.Parent      = model
    model.PrimaryPart = body

    -- Eye glow
    local eye = Instance.new("Part")
    eye.Name        = "Eye"
    eye.Size        = Vector3.new(data.bodySize.X * 0.3, data.bodySize.Y * 0.15, 0.2)
    eye.Color       = Color3.fromRGB(255, 60, 60)
    eye.Material    = Enum.Material.Neon
    eye.Anchored    = true
    eye.CanCollide  = false
    eye.CastShadow  = false
    eye.CFrame      = body.CFrame * CFrame.new(0, data.bodySize.Y * 0.15, -data.bodySize.Z * 0.5)
    eye.Parent      = model

    local eyeLight = Instance.new("PointLight", eye)
    eyeLight.Color      = Color3.fromRGB(255, 80, 80)
    eyeLight.Brightness = 1.5
    eyeLight.Range      = 10

    -- Health bar billboard
    local bill = Instance.new("BillboardGui")
    bill.Size        = UDim2.new(0, 64, 0, 10)
    bill.StudsOffset = Vector3.new(0, data.bodySize.Y * 0.5 + 1.8, 0)
    bill.AlwaysOnTop = false
    bill.Parent      = body

    local bg = Instance.new("Frame", bill)
    bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20); bg.BorderSizePixel = 0

    local bar = Instance.new("Frame", bg)
    bar.Name = "Bar"; bar.Size = UDim2.new(1, 0, 1, 0); bar.BackgroundColor3 = Color3.fromRGB(60, 220, 60); bar.BorderSizePixel = 0

    model.Parent = folder
    return model
end

local function updateHPBar(model, hp, maxHp)
    local bar = model:FindFirstChild("Body")
                  and model.Body:FindFirstChildOfClass("BillboardGui")
                  and model.Body:FindFirstChildOfClass("BillboardGui"):FindFirstChild("Frame")
                  and model.Body:FindFirstChildOfClass("BillboardGui").Frame:FindFirstChild("Bar")
    if bar then
        local t = math.max(0, hp / maxHp)
        bar.Size = UDim2.new(t, 0, 1, 0)
        bar.BackgroundColor3 = Color3.fromRGB(
            math.floor(60 + (220-60) * (1-t)),
            math.floor(220 - (220-60) * (1-t)), 60)
    end
end

-- ── Target finder ──────────────────────────────────────────────────────────
local function findTarget(position, range)
    local best, bestDist = nil, range
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - position).Magnitude
                if d < bestDist then best = root; bestDist = d end
            end
        end
    end
    return best, bestDist
end

-- ── HP Orb drop ────────────────────────────────────────────────────────────
local function dropHPOrb(position, folder)
    local orb = Instance.new("Part")
    orb.Name        = "HPOrb"
    orb.Shape       = Enum.PartType.Ball
    orb.Size        = Vector3.new(1.4, 1.4, 1.4)
    orb.Color       = Color3.fromRGB(60, 255, 120)
    orb.Material    = Enum.Material.Neon
    orb.Anchored    = false
    orb.CanCollide  = false
    orb.CastShadow  = false
    orb.CFrame      = CFrame.new(position + Vector3.new(0, 2, 0))
    orb.Parent      = folder

    local light = Instance.new("PointLight", orb)
    light.Color = Color3.fromRGB(60, 255, 120); light.Range = 10; light.Brightness = 2

    local bv = Instance.new("BodyVelocity", orb)
    bv.Velocity  = Vector3.new(0, 8, 0)
    bv.MaxForce  = Vector3.new(0, 1e6, 0)

    -- Settle into a hover after 0.6s
    task.delay(0.6, function()
        if not orb.Parent then return end
        bv:Destroy()
        orb.Anchored = true
        orb.CFrame   = CFrame.new(orb.Position)
    end)

    -- Slow spin
    local angle = 0
    local spinConn
    spinConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if not orb.Parent then spinConn:Disconnect(); return end
        if orb.Anchored then
            angle = angle + dt * 2
            orb.CFrame = CFrame.new(orb.Position) * CFrame.Angles(0, angle, 0)
        end
    end)

    Debris:AddItem(orb, 18)

    -- Touch pickup
    local conn
    conn = orb.Touched:Connect(function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character == char then
                local ps = EnemyManager.playerStates[player.UserId]
                if ps and EnemyManager.onHPPickup then
                    EnemyManager.onHPPickup(ps)
                    spinConn:Disconnect()
                    conn:Disconnect()
                    orb:Destroy()
                end
                return
            end
        end
    end)
end

-- ── Enemy projectile ────────────────────────────────────────────────────────
local function fireProjectile(origin, targetPos, speed, damage, dotInfo, folder, attackerPS)
    local dir  = (targetPos - origin).Unit
    local proj = Instance.new("Part")
    proj.Name      = "EProj"
    proj.Size      = Vector3.new(0.5, 0.5, 0.5)
    proj.Color     = Color3.fromRGB(255, 100, 100)
    proj.Material  = Enum.Material.Neon
    proj.Anchored  = false
    proj.CanCollide = false
    proj.CastShadow = false
    proj.CFrame    = CFrame.new(origin)
    proj.Parent    = folder

    local bv = Instance.new("BodyVelocity", proj)
    bv.Velocity  = dir * speed
    bv.MaxForce  = Vector3.new(1e6, 1e6, 1e6)

    Debris:AddItem(proj, 4)

    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        if not proj.Parent then conn:Disconnect(); return end
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - proj.Position).Magnitude < 3 then
                    proj:Destroy(); conn:Disconnect()
                    if EnemyManager.onEnemyAttackPlayer and attackerPS then
                        EnemyManager.onEnemyAttackPlayer(attackerPS, damage, dotInfo)
                    end
                    return
                end
            end
        end
    end)
end

-- ── AI loop ─────────────────────────────────────────────────────────────────
local function startAI(record, folder)
    local data = record.data
    task.spawn(function()
        local lastAttack = 0
        while record.alive and record.model and record.model.Parent do
            task.wait(0.1)
            if not record.alive then break end

            local body = record.model:FindFirstChild("Body")
            if not body then break end

            local pos    = body.Position
            local target, dist = findTarget(pos, data.detectionRange)

            if target then
                local now = tick()

                -- Smooth approach: lerp toward target if outside attack range
                if dist > data.attackRange then
                    local dir    = (target.Position - pos).Unit
                    local newPos = pos + dir * math.min(data.speed * 0.1, dist - data.attackRange)

                    -- Clamp to spawn face so enemy doesn't leave its platform
                    if record.face == "floor" or record.face == "ceiling" then
                        newPos = Vector3.new(newPos.X, pos.Y, newPos.Z)
                    elseif record.face == "left" or record.face == "right" then
                        newPos = Vector3.new(pos.X, newPos.Y, newPos.Z)
                    end

                    -- Lerp for smoothness
                    local smoothPos = pos:Lerp(newPos, 0.7)
                    body.CFrame  = CFrame.new(smoothPos, smoothPos + dir)
                    local eye = record.model:FindFirstChild("Eye")
                    if eye then
                        eye.CFrame = body.CFrame
                            * CFrame.new(0, data.bodySize.Y * 0.15, -data.bodySize.Z * 0.5)
                    end
                end

                -- Attack
                if now - lastAttack >= data.attackCooldown then
                    lastAttack = now
                    local finalDmg = data.attackDamage * (record.dmgMult or 1)
                    if data.attackType == "melee" and dist <= data.attackRange + 1 then
                        for _, player in ipairs(Players:GetPlayers()) do
                            local char = player.Character
                            if char and char:FindFirstChild("HumanoidRootPart") == target then
                                local ps = EnemyManager.playerStates[player.UserId]
                                if ps and EnemyManager.onEnemyAttackPlayer then
                                    EnemyManager.onEnemyAttackPlayer(ps, finalDmg, nil)
                                end
                                break
                            end
                        end
                    elseif data.attackType == "ranged" then
                        local dotInfo = data.dotDamage
                            and { damage = data.dotDamage, duration = data.dotDuration }
                            or  nil
                        local attackerPS = nil
                        for _, player in ipairs(Players:GetPlayers()) do
                            local char = player.Character
                            if char and char:FindFirstChild("HumanoidRootPart") == target then
                                attackerPS = EnemyManager.playerStates[player.UserId]
                                break
                            end
                        end
                        fireProjectile(pos, target.Position, data.projectileSpeed,
                                       finalDmg, dotInfo, folder, attackerPS)
                    end
                end

            end -- if target
        end -- while
    end)
end

-- ── Public API ──────────────────────────────────────────────────────────────
function EnemyManager.spawnEnemies(playerState, spawnList, folder, opts)
    opts = opts or {}
    local hpMult  = opts.enemyHpMult  or 1
    local dmgMult = opts.enemyDmgMult or 1
    local level   = opts.level or 1

    EnemyManager.playerStates[playerState.player.UserId] = playerState

    for _, spawnInfo in ipairs(spawnList) do
        local baseData = EnemyData[spawnInfo.enemyType]
        if not baseData then continue end

        -- Elite chance increases with level (cap at 40%)
        local eliteChance = level >= 3
            and math.min(GameConfig.ELITE_CHANCE + (level - 3) * 0.01, 0.40)
            or 0
        local isElite = math.random() < eliteChance
        local data    = isElite and makeEliteData(baseData) or baseData

        local id    = newId()
        local model = buildEnemyModel(data, spawnInfo.position, folder)

        -- Elite visual: red outline via SelectionBox
        if isElite then
            local sb = Instance.new("SelectionBox")
            sb.Color3         = Color3.fromRGB(255, 30, 30)
            sb.LineThickness  = 0.06
            sb.SurfaceColor3  = Color3.fromRGB(255, 30, 30)
            sb.SurfaceTransparency = 0.85
            sb.Adornee        = model:FindFirstChild("Body")
            sb.Parent         = model

            -- Crown gem above head
            local gem = Instance.new("Part")
            gem.Name = "EliteCrown"; gem.Size = Vector3.new(0.6,0.6,0.6)
            gem.Shape = Enum.PartType.Ball
            gem.Color = Color3.fromRGB(255, 200, 30); gem.Material = Enum.Material.Neon
            gem.Anchored = true; gem.CanCollide = false; gem.CastShadow = false
            gem.CFrame = model.Body.CFrame * CFrame.new(0, data.bodySize.Y * 0.55, 0)
            gem.Parent = model
            local gl = Instance.new("PointLight", gem); gl.Color = Color3.fromRGB(255,200,30); gl.Range = 8; gl.Brightness = 2
        end

        local idTag = Instance.new("StringValue")
        idTag.Name = "EnemyId"; idTag.Value = id; idTag.Parent = model

        local record = {
            id      = id,
            data    = data,
            model   = model,
            hp      = math.floor(data.maxHp * hpMult),
            maxHp   = math.floor(data.maxHp * hpMult),
            alive   = true,
            face    = spawnInfo.face or "floor",
            isElite = isElite,
            dmgMult = dmgMult * (isElite and 1.5 or 1),
            score   = (baseData.score or 0) * (isElite and 2 or 1),
        }
        activeEnemies[id] = record
        table.insert(playerState.enemies, id)
        startAI(record, folder)
    end
end

function EnemyManager.getEnemyName(enemyId)
    local r = activeEnemies[enemyId] or deadEnemyNames[enemyId]
    return r and (r.data and r.data.displayName or r.name) or "Enemy"
end

function EnemyManager.wasElite(enemyId)
    local r = activeEnemies[enemyId] or deadEnemyNames[enemyId]
    return r and r.isElite or false
end

-- Returns (died, score)
function EnemyManager.damageEnemy(playerState, enemyId, damage, damageType)
    local rec = activeEnemies[enemyId]
    if not rec or not rec.alive then return false, 0 end

    if rec.data.armorReduction and damageType == "ranged" then
        damage = damage * (1 - rec.data.armorReduction)
    end

    rec.hp = rec.hp - damage
    updateHPBar(rec.model, rec.hp, rec.maxHp)

    if rec.hp <= 0 then
        rec.alive = false
        local deathPos = rec.model:FindFirstChild("Body")
                         and rec.model.Body.Position
                         or Vector3.new(0, 0, 0)

        -- Death flash
        if rec.model and rec.model.Parent then
            local body = rec.model:FindFirstChild("Body")
            if body then
                body.Color    = Color3.new(1, 1, 1)
                body.Material = Enum.Material.Neon
            end
            game:GetService("Debris"):AddItem(rec.model, 0.35)
        end

        -- HP orb drop
        local folder = rec.model and rec.model.Parent
        if folder and math.random() < GameConfig.HP_DROP_CHANCE then
            dropHPOrb(deathPos, folder)
        end

        -- Keep name for kill feed query
        deadEnemyNames[enemyId] = { name = rec.data.displayName, isElite = rec.isElite }
        task.delay(5, function() deadEnemyNames[enemyId] = nil end)

        activeEnemies[enemyId] = nil
        for i, eid in ipairs(playerState.enemies) do
            if eid == enemyId then table.remove(playerState.enemies, i); break end
        end
        return true, rec.score or rec.data.score or 0
    end
    return false, 0
end

function EnemyManager.allEnemiesDefeated(playerState)
    return #playerState.enemies == 0
end

function EnemyManager.damageNearby(playerState, position, radius, damage)
    for enemyId, rec in pairs(activeEnemies) do
        if rec.alive and rec.model then
            local body = rec.model:FindFirstChild("Body")
            if body and (body.Position - position).Magnitude <= radius then
                EnemyManager.damageEnemy(playerState, enemyId, damage, "aoe")
            end
        end
    end
end

function EnemyManager.clearEnemies(playerState)
    if not playerState or not playerState.enemies then return end
    for _, enemyId in ipairs(playerState.enemies) do
        local rec = activeEnemies[enemyId]
        if rec then
            rec.alive = false
            if rec.model and rec.model.Parent then rec.model:Destroy() end
            activeEnemies[enemyId] = nil
        end
    end
    playerState.enemies = {}
end

return EnemyManager
