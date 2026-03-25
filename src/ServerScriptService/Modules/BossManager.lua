-- BossManager.lua (ModuleScript)
-- Spawns and drives phase-based boss encounters.

local Players      = game:GetService("Players")
local Debris       = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossData = require(ReplicatedStorage.Modules.BossData)

local BossManager = {}
BossManager.onBossAttackPlayer = nil   -- function(ps, damage, dotInfo)
BossManager.onBossHPUpdate     = nil   -- function(boss, hp, maxHp)
BossManager.onPhaseChange      = nil   -- function(boss, newPhase)
BossManager.onSpawnMinions     = nil   -- function(pos, count)

local function buildBossModel(cfg, position, folder)
    local model = Instance.new("Model")
    model.Name  = cfg.displayName

    local body = Instance.new("Part")
    body.Name       = "Body"
    body.Size       = cfg.bodySize
    body.Color      = cfg.color
    body.Material   = Enum.Material.SmoothPlastic
    body.Anchored   = true
    body.CanCollide = true
    body.CFrame     = CFrame.new(position)
    body.Parent     = model
    model.PrimaryPart = body

    local tag = Instance.new("BoolValue"); tag.Name = "IsBoss"; tag.Value = true; tag.Parent = model

    -- Eyes
    for i, xOffset in ipairs({-0.2, 0.2}) do
        local e = Instance.new("Part")
        e.Name      = "Eye" .. i
        e.Size      = Vector3.new(cfg.bodySize.X * 0.14, cfg.bodySize.Y * 0.09, 0.3)
        e.Color     = Color3.fromRGB(255, 50, 50)
        e.Material  = Enum.Material.Neon
        e.Anchored  = true; e.CanCollide = false; e.CastShadow = false
        e.CFrame    = body.CFrame * CFrame.new(xOffset * cfg.bodySize.X, cfg.bodySize.Y * 0.22, -cfg.bodySize.Z * 0.5)
        e.Parent    = model
        local el = Instance.new("PointLight", e)
        el.Color = Color3.fromRGB(255, 80, 80); el.Brightness = 2; el.Range = 14
    end

    -- Body ambient glow
    local bodyLight = Instance.new("PointLight", body)
    bodyLight.Color = cfg.color; bodyLight.Brightness = 1; bodyLight.Range = 20

    -- HP billboard (large, always on top)
    local bill = Instance.new("BillboardGui")
    bill.Size        = UDim2.new(0, 240, 0, 28)
    bill.StudsOffset = Vector3.new(0, cfg.bodySize.Y * 0.5 + 4, 0)
    bill.AlwaysOnTop = true
    bill.Parent      = body

    local bg = Instance.new("Frame", bill)
    bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(15,15,15); bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local bar = Instance.new("Frame", bg)
    bar.Name = "Bar"; bar.Size = UDim2.new(1,0,1,0)
    bar.BackgroundColor3 = Color3.fromRGB(220, 40, 40); bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local nameLabel = Instance.new("TextLabel", bg)
    nameLabel.Size = UDim2.new(1,0,1,0); nameLabel.BackgroundTransparency = 1
    nameLabel.Text = cfg.displayName; nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextScaled = true

    model.Parent = folder
    return model
end

local function updateHPBar(boss)
    local bar = boss.model:FindFirstChild("Body")
                  and boss.model.Body:FindFirstChildOfClass("BillboardGui")
                  and boss.model.Body:FindFirstChildOfClass("BillboardGui"):FindFirstChild("Frame")
                  and boss.model.Body:FindFirstChildOfClass("BillboardGui").Frame:FindFirstChild("Bar")
    if bar then
        TweenService:Create(bar, TweenInfo.new(0.15), {
            Size = UDim2.new(math.max(0, boss.hp / boss.maxHp), 0, 1, 0)
        }):Play()
    end
end

local function getCurrentPhase(boss)
    local ratio = boss.hp / boss.maxHp
    local currentPhase, currentIdx = boss.cfg.phases[1], 1
    for i, phase in ipairs(boss.cfg.phases) do
        if ratio <= phase.hpRatio then
            currentPhase = phase; currentIdx = i
        end
    end
    return currentPhase, currentIdx
end

-- ── Attack patterns ────────────────────────────────────────────────────────
local function doAttack(boss, attackName, folder)
    local body = boss.model:FindFirstChild("Body")
    if not body then return end
    local pos = body.Position

    -- Find nearest player
    local target, bestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - pos).Magnitude
                if d < bestDist then target = root; bestDist = d end
            end
        end
    end
    if not target then return end

    local function dealDamage(damage, dot)
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") == target then
                local ps = BossManager.playerStates and BossManager.playerStates[player.UserId]
                if ps and BossManager.onBossAttackPlayer then
                    BossManager.onBossAttackPlayer(ps, damage, dot)
                end
                break
            end
        end
    end

    -- ── Laser sweep ──────────────────────────────────────────────────────
    if attackName == "laser_sweep" or attackName == "beam_sweep" then
        local beam = Instance.new("Part")
        beam.Size = Vector3.new(1.5, 1.5, bestDist)
        beam.Color = Color3.fromRGB(255, 60, 60); beam.Material = Enum.Material.Neon
        beam.Anchored = true; beam.CanCollide = false; beam.CastShadow = false
        beam.CFrame = CFrame.new((pos + target.Position)/2, target.Position)
        beam.Parent = folder
        TweenService:Create(beam, TweenInfo.new(0.35), { Transparency = 1 }):Play()
        Debris:AddItem(beam, 0.4)
        if bestDist < 35 then dealDamage(22, nil) end

    -- ── Rocket volley ─────────────────────────────────────────────────────
    elseif attackName == "rocket_volley" or attackName == "homing_missiles" then
        for i = 1, 3 do
            task.delay(i * 0.25, function()
                if not boss.alive then return end
                local proj = Instance.new("Part")
                proj.Size = Vector3.new(0.9,0.9,1.6); proj.Color = Color3.fromRGB(255,150,30)
                proj.Material = Enum.Material.Neon; proj.Anchored = false
                proj.CanCollide = false; proj.CFrame = CFrame.new(pos)
                proj.Parent = folder
                local aim = target.Position + Vector3.new(math.random(-3,3), math.random(-1,1), 0)
                local bv  = Instance.new("BodyVelocity", proj)
                bv.Velocity = (aim - pos).Unit * 65; bv.MaxForce = Vector3.new(1e6,1e6,1e6)
                Debris:AddItem(proj, 3)
                local conn
                conn = game:GetService("RunService").Heartbeat:Connect(function()
                    if not proj.Parent then conn:Disconnect(); return end
                    if (proj.Position - target.Position).Magnitude < 4 then
                        proj:Destroy(); conn:Disconnect(); dealDamage(20, nil)
                    end
                end)
            end)
        end

    -- ── Acid / energy projectiles ─────────────────────────────────────────
    elseif attackName == "acid_spit" or attackName == "acid_spray"
        or attackName == "energy_burst" then
        local count  = attackName == "acid_spray" and 6 or 1
        local isAcid = attackName ~= "energy_burst"
        local col    = isAcid and Color3.fromRGB(80,255,60) or Color3.fromRGB(200,80,255)
        for _ = 1, count do
            local spread = Vector3.new(math.random(-4,4), math.random(-2,2), 0)
            local dir    = (target.Position + spread - pos).Unit
            local proj   = Instance.new("Part")
            proj.Size = Vector3.new(0.7,0.7,0.7); proj.Color = col
            proj.Material = Enum.Material.Neon; proj.Anchored = false
            proj.CanCollide = false; proj.CFrame = CFrame.new(pos); proj.Parent = folder
            local bv = Instance.new("BodyVelocity", proj)
            bv.Velocity = dir * 52; bv.MaxForce = Vector3.new(1e6,1e6,1e6)
            Debris:AddItem(proj, 3)
            local conn
            conn = game:GetService("RunService").Heartbeat:Connect(function()
                if not proj.Parent then conn:Disconnect(); return end
                if (proj.Position - target.Position).Magnitude < 3 then
                    proj:Destroy(); conn:Disconnect()
                    local dot = isAcid and { damage = 5, duration = 3 } or nil
                    dealDamage(16, dot)
                end
            end)
        end

    -- ── Leap slam ─────────────────────────────────────────────────────────
    elseif attackName == "leap_slam" then
        local leapTarget = target.Position
        local startCF    = body.CFrame
        local midCF      = CFrame.new((pos + leapTarget)/2 + Vector3.new(0, 18, 0))
        local endCF      = CFrame.new(leapTarget + Vector3.new(0, boss.cfg.bodySize.Y*0.5, 0))
        task.spawn(function()
            for t = 0, 1, 0.06 do
                if not boss.alive or not body.Parent then return end
                body.CFrame = startCF:Lerp(t < 0.5 and midCF or endCF, t < 0.5 and t*2 or (t-0.5)*2)
                task.wait(0.03)
            end
            -- Shockwave
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root and (root.Position - leapTarget).Magnitude < 14 then
                        local ps = BossManager.playerStates and BossManager.playerStates[player.UserId]
                        if ps and BossManager.onBossAttackPlayer then
                            BossManager.onBossAttackPlayer(ps, 28, nil)
                        end
                    end
                end
            end
        end)

    -- ── Spawn minions ─────────────────────────────────────────────────────
    elseif attackName == "spawn_minions" then
        if BossManager.onSpawnMinions then BossManager.onSpawnMinions(pos, 2) end

    -- ── Gravity pulse ─────────────────────────────────────────────────────
    elseif attackName == "gravity_pulse" or attackName == "gravity_invert" then
        -- Damage only; actual gravity inversion is client-side cosmetic
        dealDamage(12, nil)
    end
end

-- ── Boss AI loop ────────────────────────────────────────────────────────────
local function startBossAI(boss, folder)
    task.spawn(function()
        local lastAttack = 0
        boss.lastPhaseIdx = 1

        while boss.alive and boss.model and boss.model.Parent do
            task.wait(0.15)
            if not boss.alive then break end
            local body = boss.model:FindFirstChild("Body")
            if not body then break end

            local phase, phaseIdx = getCurrentPhase(boss)
            boss.currentPhase = phase

            -- Phase transition
            if phaseIdx ~= boss.lastPhaseIdx then
                boss.lastPhaseIdx = phaseIdx
                -- Flash white briefly
                body.Color    = Color3.new(1, 1, 1)
                body.Material = Enum.Material.Neon
                task.delay(0.5, function()
                    if body and body.Parent then
                        body.Color    = boss.cfg.color
                        body.Material = Enum.Material.SmoothPlastic
                    end
                end)
                if BossManager.onPhaseChange then BossManager.onPhaseChange(boss, phaseIdx) end
            end

            -- Move toward nearest player
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
                local spd = boss.cfg.speed * (phase.speedMult or 1) * 0.15
                local dir = (target.Position - body.Position).Unit
                local newPos = body.Position:Lerp(body.Position + dir * spd, 0.8)
                body.CFrame = CFrame.new(newPos, newPos + dir)
                for i = 1, 2 do
                    local e = boss.model:FindFirstChild("Eye" .. i)
                    local xo = (i == 1) and -0.2 or 0.2
                    if e then
                        e.CFrame = body.CFrame * CFrame.new(xo * boss.cfg.bodySize.X, boss.cfg.bodySize.Y * 0.22, -boss.cfg.bodySize.Z * 0.5)
                    end
                end

                local now = tick()
                if now - lastAttack >= (phase.cooldown or 2) then
                    lastAttack = now
                    local attacks = phase.attacks
                    doAttack(boss, attacks[math.random(1, #attacks)], folder)
                end
            end
        end
    end)
end

-- ── Public API ──────────────────────────────────────────────────────────────
function BossManager.spawnBoss(levelNumber, folder)
    local cfg = BossData.getForLevel(levelNumber)
    if not cfg then return nil end

    local spawnPos = Vector3.new(0, 0, (GameConfig and GameConfig.LEVEL_SECTIONS + 1 or 31) * 10)
    local model    = buildBossModel(cfg, spawnPos, folder)

    local boss = {
        cfg          = cfg,
        model        = model,
        hp           = cfg.maxHp,
        maxHp        = cfg.maxHp,
        alive        = true,
        lastPhaseIdx = 1,
        currentPhase = cfg.phases[1],
        displayName  = cfg.displayName,
        subtitle     = cfg.subtitle,
    }

    BossManager.playerStates = BossManager.playerStates or {}

    startBossAI(boss, folder)
    return boss
end

-- Returns (died, phaseChanged, newPhaseIdx)
function BossManager.damageBoss(boss, damage)
    if not boss or not boss.alive then return false, false, 1 end
    boss.hp = boss.hp - damage
    updateHPBar(boss)

    local _, newIdx = getCurrentPhase(boss)
    local phaseChanged = newIdx ~= boss.lastPhaseIdx

    if boss.hp <= 0 then
        boss.alive = false
        -- Death explosions
        local body = boss.model:FindFirstChild("Body")
        for i = 1, 6 do
            task.delay(i * 0.18, function()
                local exp = Instance.new("Part")
                exp.Size = boss.cfg.bodySize * 0.5; exp.Shape = Enum.PartType.Ball
                exp.Color = (i % 2 == 0) and Color3.fromRGB(255,160,30) or Color3.fromRGB(255,255,100)
                exp.Material = Enum.Material.Neon; exp.Anchored = true; exp.CanCollide = false
                if body and body.Parent then exp.CFrame = body.CFrame else exp.CFrame = CFrame.new(0,0,0) end
                exp.Parent = workspace
                TweenService:Create(exp, TweenInfo.new(0.3), { Transparency = 1, Size = exp.Size * 0.1 }):Play()
                game:GetService("Debris"):AddItem(exp, 0.35)
            end)
        end
        task.delay(1.1, function()
            if boss.model and boss.model.Parent then boss.model:Destroy() end
        end)
        return true, phaseChanged, newIdx
    end
    return false, phaseChanged, newIdx
end

return BossManager
