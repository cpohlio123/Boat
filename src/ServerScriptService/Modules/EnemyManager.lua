-- EnemyManager.lua (ModuleScript)
-- Spawns enemies, runs server-side AI loops, handles damage.

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local Debris         = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyData      = require(ReplicatedStorage.Modules.EnemyData)

local EnemyManager   = {}

-- Callback set by GameManager to handle player damage
EnemyManager.onEnemyAttackPlayer = nil  -- function(playerState, damage, dotInfo)

-- Active enemy registry: [enemyId] = enemyRecord
local activeEnemies = {}
local nextEnemyId   = 1

local function newId()
    local id = "E" .. nextEnemyId
    nextEnemyId = nextEnemyId + 1
    return id
end

-- Build the visual body for an enemy
local function buildEnemyModel(data, position, folder)
    local model = Instance.new("Model")
    model.Name  = data.displayName

    local body = Instance.new("Part")
    body.Name        = "Body"
    body.Size        = data.bodySize
    body.Color       = data.color
    body.Material    = Enum.Material.SmoothPlastic
    body.Anchored    = true       -- we move via CFrame
    body.CanCollide  = true
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
    eye.CFrame      = body.CFrame * CFrame.new(0, data.bodySize.Y * 0.2, -data.bodySize.Z * 0.5)
    eye.Parent      = model

    -- Health billboard
    local bill = Instance.new("BillboardGui")
    bill.Name           = "HealthBar"
    bill.Size           = UDim2.new(0, 60, 0, 10)
    bill.StudsOffset    = Vector3.new(0, data.bodySize.Y * 0.5 + 1.5, 0)
    bill.AlwaysOnTop    = false
    bill.Parent         = body

    local bg = Instance.new("Frame")
    bg.Name            = "BG"
    bg.Size            = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bg.BorderSizePixel = 0
    bg.Parent          = bill

    local bar = Instance.new("Frame")
    bar.Name            = "Bar"
    bar.Size            = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
    bar.BorderSizePixel = 0
    bar.Parent          = bg

    model.Parent = folder
    return model
end

local function updateHealthBar(model, hp, maxHp)
    local bar = model:FindFirstChild("Body")
                  and model.Body:FindFirstChild("HealthBar")
                  and model.Body.HealthBar:FindFirstChild("BG")
                  and model.Body.HealthBar.BG:FindFirstChild("Bar")
    if bar then
        bar.Size = UDim2.new(math.max(0, hp / maxHp), 0, 1, 0)
        local t  = hp / maxHp
        bar.BackgroundColor3 = Color3.fromRGB(
            math.floor(60 + (220 - 60) * (1 - t)),
            math.floor(220 - (220 - 60) * (1 - t)),
            60
        )
    end
end

-- Find the closest player character RootPart
local function findTarget(position, detectionRange)
    local best, bestDist = nil, detectionRange
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - position).Magnitude
                if d < bestDist then
                    best     = root
                    bestDist = d
                end
            end
        end
    end
    return best, bestDist
end

-- Spawn a server-side projectile toward a target
local function fireProjectile(origin, targetPos, speed, damage, dotInfo, folder, attackerPS)
    local dir = (targetPos - origin).Unit
    local proj = Instance.new("Part")
    proj.Name        = "EnemyProjectile"
    proj.Size        = Vector3.new(0.5, 0.5, 0.5)
    proj.Color       = Color3.fromRGB(255, 100, 100)
    proj.Material    = Enum.Material.Neon
    proj.Anchored    = false
    proj.CanCollide  = false
    proj.CastShadow  = false
    proj.CFrame      = CFrame.new(origin)
    proj.Parent      = folder

    local bv = Instance.new("BodyVelocity")
    bv.Velocity   = dir * speed
    bv.MaxForce   = Vector3.new(1e6, 1e6, 1e6)
    bv.Parent     = proj

    Debris:AddItem(proj, 4)

    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        if not proj.Parent then conn:Disconnect() return end
        -- Check if projectile is near any player
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - proj.Position).Magnitude < 3 then
                    proj:Destroy()
                    conn:Disconnect()
                    if EnemyManager.onEnemyAttackPlayer and attackerPS then
                        EnemyManager.onEnemyAttackPlayer(attackerPS, damage, dotInfo)
                    end
                    return
                end
            end
        end
    end)
end

-- AI loop for one enemy
local function startAI(record, folder)
    local data   = record.data
    local lastAttack = 0

    task.spawn(function()
        while record.alive and record.model and record.model.Parent do
            task.wait(0.1)
            if not record.alive then break end

            local bodyPart = record.model:FindFirstChild("Body")
            if not bodyPart then break end

            local pos  = bodyPart.Position
            local target, dist = findTarget(pos, data.detectionRange)

            if target then
                local now = tick()

                -- Move toward target if outside attack range
                if dist > data.attackRange then
                    local dir     = (target.Position - pos).Unit
                    local newPos  = pos + dir * data.speed * 0.1
                    -- Keep on the same "face" (clamp one axis based on starting face)
                    if record.face == "floor" then
                        newPos = Vector3.new(newPos.X, pos.Y, newPos.Z)
                    elseif record.face == "ceiling" then
                        newPos = Vector3.new(newPos.X, pos.Y, newPos.Z)
                    elseif record.face == "left" then
                        newPos = Vector3.new(pos.X, newPos.Y, newPos.Z)
                    elseif record.face == "right" then
                        newPos = Vector3.new(pos.X, newPos.Y, newPos.Z)
                    end
                    bodyPart.CFrame  = CFrame.new(newPos, newPos + dir)
                    record.model.Eye.CFrame = bodyPart.CFrame
                                          * CFrame.new(0, data.bodySize.Y * 0.2, -data.bodySize.Z * 0.5)
                end

                -- Attack
                if now - lastAttack >= data.attackCooldown then
                    lastAttack = now

                    if data.attackType == "melee" then
                        if dist <= data.attackRange + 1 then
                            if EnemyManager.onEnemyAttackPlayer then
                                -- Find which player state owns this target
                                for _, player in ipairs(Players:GetPlayers()) do
                                    local char = player.Character
                                    if char and char:FindFirstChild("HumanoidRootPart") == target then
                                        local ps = EnemyManager.playerStates and EnemyManager.playerStates[player.UserId]
                                        if ps then
                                            EnemyManager.onEnemyAttackPlayer(ps, data.attackDamage, nil)
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    elseif data.attackType == "ranged" then
                        local dotInfo = nil
                        if data.dotDamage then
                            dotInfo = { damage = data.dotDamage, duration = data.dotDuration }
                        end
                        -- Find player state for damage callback
                        local attackerPS = nil
                        for _, player in ipairs(Players:GetPlayers()) do
                            local char = player.Character
                            if char and char:FindFirstChild("HumanoidRootPart") == target then
                                attackerPS = EnemyManager.playerStates and EnemyManager.playerStates[player.UserId]
                                break
                            end
                        end
                        fireProjectile(pos, target.Position, data.projectileSpeed,
                                       data.attackDamage, dotInfo, folder, attackerPS)
                    end
                end
            end
        end
    end)
end

-- Public API ----------------------------------------------------------------

function EnemyManager.spawnEnemies(playerState, spawnList, folder)
    EnemyManager.playerStates = EnemyManager.playerStates or {}
    EnemyManager.playerStates[playerState.player.UserId] = playerState

    for _, spawnInfo in ipairs(spawnList) do
        local data = EnemyData[spawnInfo.enemyType]
        if not data then continue end

        local id    = newId()
        local model = buildEnemyModel(data, spawnInfo.position, folder)

        -- Tag model for client hit detection
        local idTag = Instance.new("StringValue")
        idTag.Name  = "EnemyId"
        idTag.Value = id
        idTag.Parent = model

        local record = {
            id     = id,
            data   = data,
            model  = model,
            hp     = data.maxHp,
            maxHp  = data.maxHp,
            alive  = true,
            face   = spawnInfo.face or "floor",
        }
        activeEnemies[id] = record
        table.insert(playerState.enemies, id)

        startAI(record, folder)
    end
end

-- Returns true if the enemy died
function EnemyManager.damageEnemy(playerState, enemyId, damage, damageType)
    local rec = activeEnemies[enemyId]
    if not rec or not rec.alive then return false end

    -- Armor reduction
    if rec.data.armorReduction and damageType == "ranged" then
        damage = damage * (1 - rec.data.armorReduction)
    end

    rec.hp = rec.hp - damage
    updateHealthBar(rec.model, rec.hp, rec.maxHp)

    if rec.hp <= 0 then
        rec.alive = false
        -- Death effect: flash and remove
        if rec.model and rec.model.Parent then
            local body = rec.model:FindFirstChild("Body")
            if body then
                body.Color    = Color3.fromRGB(255, 255, 255)
                body.Material = Enum.Material.Neon
            end
            Debris:AddItem(rec.model, 0.3)
        end
        activeEnemies[enemyId] = nil
        -- Remove from player's list
        for i, eid in ipairs(playerState.enemies) do
            if eid == enemyId then
                table.remove(playerState.enemies, i)
                break
            end
        end
        return true, rec.data.score
    end
    return false, 0
end

function EnemyManager.getEnemyScore(enemyId)
    -- Already removed by the time we check; score returned from damageEnemy
    return 0
end

function EnemyManager.allEnemiesDefeated(playerState)
    return #playerState.enemies == 0
end

function EnemyManager.damageNearby(playerState, position, radius, damage)
    for enemyId, rec in pairs(activeEnemies) do
        if rec.alive and rec.model then
            local body = rec.model:FindFirstChild("Body")
            if body then
                local dist = (body.Position - position).Magnitude
                if dist <= radius then
                    EnemyManager.damageEnemy(playerState, enemyId, damage, "aoe")
                end
            end
        end
    end
end

function EnemyManager.clearEnemies(playerState)
    if playerState and playerState.enemies then
        for _, enemyId in ipairs(playerState.enemies) do
            local rec = activeEnemies[enemyId]
            if rec then
                rec.alive = false
                if rec.model and rec.model.Parent then
                    rec.model:Destroy()
                end
                activeEnemies[enemyId] = nil
            end
        end
        playerState.enemies = {}
    end
end

return EnemyManager
