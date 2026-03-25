-- BossManager.lua (ModuleScript)
-- Spawns and drives boss encounters.

local Players   = game:GetService("Players")
local Debris    = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossData  = require(ReplicatedStorage.Modules.BossData)

local BossManager = {}

-- Callback set by GameManager
BossManager.onBossAttackPlayer = nil  -- function(playerState, damage)

local function buildBossModel(cfg, position, folder)
    local model = Instance.new("Model")
    model.Name  = cfg.displayName

    -- Main body
    local body = Instance.new("Part")
    body.Name     = "Body"
    body.Size     = cfg.bodySize
    body.Color    = cfg.color
    body.Material = Enum.Material.SmoothPlastic
    body.Anchored = true
    body.CanCollide = true
    body.CFrame   = CFrame.new(position)
    body.Parent   = model
    model.PrimaryPart = body

    -- IsBoss tag for client detection
    local tag = Instance.new("BoolValue")
    tag.Name   = "IsBoss"
    tag.Value  = true
    tag.Parent = model

    -- Glowing eyes
    local eye1 = Instance.new("Part")
    eye1.Name = "Eye1"
    eye1.Size = Vector3.new(cfg.bodySize.X * 0.15, cfg.bodySize.Y * 0.1, 0.3)
    eye1.Color = Color3.fromRGB(255, 50, 50)
    eye1.Material = Enum.Material.Neon
    eye1.Anchored = true
    eye1.CanCollide = false
    eye1.CastShadow = false
    eye1.CFrame = body.CFrame * CFrame.new(-cfg.bodySize.X * 0.2, cfg.bodySize.Y * 0.2, -cfg.bodySize.Z * 0.5)
    eye1.Parent = model

    local eye2 = eye1:Clone()
    eye2.Name = "Eye2"
    eye2.CFrame = body.CFrame * CFrame.new(cfg.bodySize.X * 0.2, cfg.bodySize.Y * 0.2, -cfg.bodySize.Z * 0.5)
    eye2.Parent = model

    -- HP billboard
    local bill = Instance.new("BillboardGui")
    bill.Size         = UDim2.new(0, 200, 0, 20)
    bill.StudsOffset  = Vector3.new(0, cfg.bodySize.Y * 0.5 + 3, 0)
    bill.AlwaysOnTop  = true
    bill.Parent       = body

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bg.BorderSizePixel  = 0
    bg.Parent = bill

    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    bar.BorderSizePixel  = 0
    bar.Parent = bg

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextScaled = true
    nameLabel.Text = cfg.displayName
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = bg

    model.Parent = folder
    return model
end

local function updateHPBar(boss)
    local bar = boss.model:FindFirstChild("Body")
                    and boss.model.Body:FindFirstChild("BillboardGui")
                    and boss.model.Body.BillboardGui:FindFirstChild("Frame")
                    and boss.model.Body.BillboardGui.Frame:FindFirstChild("Bar")
    if bar then
        bar.Size = UDim2.new(math.max(0, boss.hp / boss.maxHp), 0, 1, 0)
    end
end

local function getCurrentPhase(boss)
    local ratio = boss.hp / boss.maxHp
    for i = #boss.cfg.phases, 1, -1 do
        local phase = boss.cfg.phases[i]
        if ratio <= phase.hpRatio then
            return phase, i
        end
    end
    return boss.cfg.phases[1], 1
end

-- Execute one boss attack pattern
local function doAttack(boss, attackName, folder)
    local body = boss.model:FindFirstChild("Body")
    if not body then return end
    local pos  = body.Position

    -- Find nearest player
    local target = nil
    local bestDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - pos).Magnitude
                if d < bestDist then
                    target = root
                    bestDist = d
                end
            end
        end
    end
    if not target then return end

    if attackName == "laser_sweep" or attackName == "beam_sweep" then
        -- Visual sweep beam
        local beamPart = Instance.new("Part")
        beamPart.Size     = Vector3.new(1, 1, bestDist)
        beamPart.Color    = Color3.fromRGB(255, 80, 80)
        beamPart.Material = Enum.Material.Neon
        beamPart.Anchored = true
        beamPart.CanCollide = false
        beamPart.CFrame   = CFrame.new((pos + target.Position) / 2, target.Position)
        beamPart.Parent   = folder
        Debris:AddItem(beamPart, 0.4)

        if bestDist < 30 then
            -- Hits player
            if BossManager.onBossAttackPlayer then
                for _, player in ipairs(Players:GetPlayers()) do
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") == target then
                        local ps = BossManager.playerStates and BossManager.playerStates[player.UserId]
                        if ps then BossManager.onBossAttackPlayer(ps, 20) end
                        break
                    end
                end
            end
        end

    elseif attackName == "rocket_volley" or attackName == "homing_missiles" then
        -- Fire 3 homing-ish projectiles
        for i = 1, 3 do
            task.delay(i * 0.3, function()
                if not boss.alive then return end
                local proj = Instance.new("Part")
                proj.Size     = Vector3.new(0.8, 0.8, 1.5)
                proj.Color    = Color3.fromRGB(255, 160, 40)
                proj.Material = Enum.Material.Neon
                proj.Anchored = false
                proj.CanCollide = false
                proj.CFrame   = CFrame.new(pos)
                proj.Parent   = folder

                local tgt = target.Position + Vector3.new(
                    math.random(-3, 3), math.random(-2, 2), 0)
                local dir = (tgt - pos).Unit
                local bv  = Instance.new("BodyVelocity")
                bv.Velocity  = dir * 60
                bv.MaxForce  = Vector3.new(1e6, 1e6, 1e6)
                bv.Parent    = proj
                Debris:AddItem(proj, 3)

                local conn
                conn = game:GetService("RunService").Heartbeat:Connect(function()
                    if not proj.Parent then conn:Disconnect() return end
                    if (proj.Position - target.Position).Magnitude < 4 then
                        proj:Destroy()
                        conn:Disconnect()
                        if BossManager.onBossAttackPlayer then
                            for _, player in ipairs(Players:GetPlayers()) do
                                local char = player.Character
                                if char and char:FindFirstChild("HumanoidRootPart") == target then
                                    local ps = BossManager.playerStates
                                             and BossManager.playerStates[player.UserId]
                                    if ps then BossManager.onBossAttackPlayer(ps, 18) end
                                    break
                                end
                            end
                        end
                    end
                end)
            end)
        end

    elseif attackName == "acid_spit" or attackName == "acid_spray" or attackName == "energy_burst" then
        local count = attackName == "acid_spray" and 6 or 1
        for i = 1, count do
            local spread = Vector3.new(math.random(-4,4), math.random(-2,2), 0)
            local dir = (target.Position + spread - pos).Unit
            local proj = Instance.new("Part")
            proj.Size     = Vector3.new(0.7, 0.7, 0.7)
            proj.Color    = attackName == "energy_burst"
                            and Color3.fromRGB(200, 80, 255)
                            or  Color3.fromRGB(80, 255, 80)
            proj.Material = Enum.Material.Neon
            proj.Anchored = false
            proj.CanCollide = false
            proj.CFrame   = CFrame.new(pos)
            proj.Parent   = folder
            local bv = Instance.new("BodyVelocity")
            bv.Velocity  = dir * 50
            bv.MaxForce  = Vector3.new(1e6,1e6,1e6)
            bv.Parent    = proj
            Debris:AddItem(proj, 3)
            local conn
            conn = game:GetService("RunService").Heartbeat:Connect(function()
                if not proj.Parent then conn:Disconnect() return end
                if (proj.Position - target.Position).Magnitude < 3 then
                    proj:Destroy()
                    conn:Disconnect()
                    if BossManager.onBossAttackPlayer then
                        for _, player in ipairs(Players:GetPlayers()) do
                            local char = player.Character
                            if char and char:FindFirstChild("HumanoidRootPart") == target then
                                local ps = BossManager.playerStates
                                         and BossManager.playerStates[player.UserId]
                                if ps then
                                    BossManager.onBossAttackPlayer(ps, 15,
                                        attackName ~= "energy_burst" and {damage=5,duration=3} or nil)
                                end
                                break
                            end
                        end
                    end
                end
            end)
        end

    elseif attackName == "leap_slam" then
        -- Boss jumps toward player, deals AoE on landing
        if body then
            local leapTarget = target.Position
            local startCF = body.CFrame
            local midCF   = CFrame.new((pos + leapTarget)/2 + Vector3.new(0, 15, 0))
            local endCF   = CFrame.new(leapTarget + Vector3.new(0, boss.cfg.bodySize.Y*0.5, 0))

            task.spawn(function()
                for t = 0, 1, 0.05 do
                    if not boss.alive or not body.Parent then return end
                    local cf = startCF:Lerp(t < 0.5 and midCF or endCF, (t < 0.5) and t*2 or (t-0.5)*2)
                    body.CFrame = cf
                    task.wait(0.03)
                end
                -- Shockwave
                if BossManager.onBossAttackPlayer then
                    for _, player in ipairs(Players:GetPlayers()) do
                        local char = player.Character
                        if char then
                            local root = char:FindFirstChild("HumanoidRootPart")
                            if root and (root.Position - leapTarget).Magnitude < 12 then
                                local ps = BossManager.playerStates
                                         and BossManager.playerStates[player.UserId]
                                if ps then BossManager.onBossAttackPlayer(ps, 30) end
                            end
                        end
                    end
                end
            end)
        end

    elseif attackName == "spawn_minions" then
        -- Summon 2 Crawlers near the boss
        -- GameManager handles actual enemy spawning via callback
        if BossManager.onSpawnMinions then
            BossManager.onSpawnMinions(pos, 2)
        end

    elseif attackName == "gravity_pulse" or attackName == "gravity_invert" then
        -- Visual only here; actual gravity handled client-side via RemoteEvent from GameManager
        if BossManager.onGravityPulse then
            BossManager.onGravityPulse()
        end
    end
end

-- AI loop for boss
local function startBossAI(boss, folder)
    task.spawn(function()
        local lastAttack = 0
        local phase, phaseIdx = getCurrentPhase(boss)

        while boss.alive and boss.model and boss.model.Parent do
            task.wait(0.15)
            if not boss.alive then break end

            local body = boss.model:FindFirstChild("Body")
            if not body then break end

            -- Re-evaluate phase
            phase, phaseIdx = getCurrentPhase(boss)

            -- Move toward nearest player (slow)
            local target, dist = nil, math.huge
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local d = (root.Position - body.Position).Magnitude
                        if d < dist then target = root; dist = d end
                    end
                end
            end

            if target then
                local spd = boss.cfg.speed * phase.speedMult * 0.15
                local dir = (target.Position - body.Position).Unit
                body.CFrame = CFrame.new(body.Position + dir * spd, body.Position + dir * 2)
                -- Update eyes
                for _, eyePart in ipairs({"Eye1","Eye2"}) do
                    local e = boss.model:FindFirstChild(eyePart)
                    if e then
                        e.CFrame = body.CFrame
                            * (eyePart == "Eye1"
                               and CFrame.new(-boss.cfg.bodySize.X*0.2, boss.cfg.bodySize.Y*0.2, -boss.cfg.bodySize.Z*0.5)
                               or  CFrame.new( boss.cfg.bodySize.X*0.2, boss.cfg.bodySize.Y*0.2, -boss.cfg.bodySize.Z*0.5))
                    end
                end
            end

            -- Attack
            local now = tick()
            if target and now - lastAttack >= phase.cooldown then
                lastAttack = now
                local attacks = phase.attacks
                local atk = attacks[math.random(1, #attacks)]
                doAttack(boss, atk, folder)
            end
        end
    end)
end

-- Public API ----------------------------------------------------------------

function BossManager.spawnBoss(levelNumber, folder)
    local cfg = BossData.getForLevel(levelNumber)
    if not cfg then return nil end

    -- Boss spawns at the end of the level corridor
    local spawnPos = Vector3.new(0, 0, (30 + 1) * 10)  -- just past last section

    local model = buildBossModel(cfg, spawnPos, folder)

    local boss = {
        cfg    = cfg,
        model  = model,
        hp     = cfg.maxHp,
        maxHp  = cfg.maxHp,
        alive  = true,
        displayName = cfg.displayName,
        subtitle    = cfg.subtitle,
    }

    startBossAI(boss, folder)
    return boss
end

-- Returns true if boss died
function BossManager.damageBoss(boss, damage)
    if not boss or not boss.alive then return false end
    boss.hp = boss.hp - damage
    updateHPBar(boss)

    -- Phase transition flash
    local newPhase, idx = getCurrentPhase(boss)
    if idx ~= boss.lastPhaseIdx then
        boss.lastPhaseIdx = idx
        local body = boss.model:FindFirstChild("Body")
        if body then
            local origColor = body.Color
            body.Color    = Color3.new(1, 1, 1)
            body.Material = Enum.Material.Neon
            task.delay(0.4, function()
                if body and body.Parent then
                    body.Color    = origColor
                    body.Material = Enum.Material.SmoothPlastic
                end
            end)
        end
    end

    if boss.hp <= 0 then
        boss.alive = false
        -- Death explosion effect
        local body = boss.model:FindFirstChild("Body")
        if body then
            for i = 1, 5 do
                task.delay(i * 0.15, function()
                    local exp = Instance.new("Part")
                    exp.Size     = Vector3.new(boss.cfg.bodySize.X * 0.6, boss.cfg.bodySize.Y * 0.6, boss.cfg.bodySize.Z * 0.6)
                    exp.Color    = Color3.fromRGB(255, 160, 30)
                    exp.Material = Enum.Material.Neon
                    exp.Anchored = true
                    exp.CanCollide = false
                    if body and body.Parent then
                        exp.CFrame = body.CFrame
                    else
                        exp.CFrame = CFrame.new(0, 0, 0)
                    end
                    exp.Parent = workspace
                    Debris:AddItem(exp, 0.3)
                end)
            end
            task.delay(0.8, function()
                if boss.model and boss.model.Parent then
                    boss.model:Destroy()
                end
            end)
        end
        return true
    end
    return false
end

return BossManager
