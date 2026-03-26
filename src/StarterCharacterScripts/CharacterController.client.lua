-- CharacterController.client.lua
-- Gravity switching (VectorForce + AlignOrientation), custom jump, hitscan combat,
-- screen shake on damage, floating damage numbers.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local RequestGravitySwitch = Events:WaitForChild("RequestGravitySwitch")
local GravitySwitched      = Events:WaitForChild("GravitySwitched")
local DamageEnemy          = Events:WaitForChild("DamageEnemy")
local DamageBoss           = Events:WaitForChild("DamageBoss")
local UpdateHUD            = Events:WaitForChild("UpdateHUD")
local PlayerDamaged        = Events:WaitForChild("PlayerDamaged")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

-- ── State ──────────────────────────────────────────────────────────────────
local GRAVITY_MAG     = workspace.Gravity
local gravDir         = Vector3.new(0, -1, 0)
local gravCooldown    = GameConfig.GRAVITY_SWITCH_COOLDOWN
local lastGravSwitch  = -999
local canDoubleJump   = false
local hasDoubleJumped = false
local currentWeapon   = "blaster"
local damageMult      = 1
local lastShootTime   = -999
local lastMeleeTime   = -999
local lastDashTime    = -999
local isDashing       = false

local GRAV_DIRS = {
    Vector3.new(0, -1, 0),
    Vector3.new(0,  1, 0),
    Vector3.new(-1, 0, 0),
    Vector3.new(1,  0, 0),
}
local gravIndex = 1

-- ── Physics constraints ────────────────────────────────────────────────────
local gravAttach = Instance.new("Attachment")
gravAttach.Name   = "GravAttach"
gravAttach.Parent = rootPart

local gravForce = Instance.new("VectorForce")
gravForce.Name        = "CustomGravity"
gravForce.Attachment0 = gravAttach
gravForce.RelativeTo  = Enum.ActuatorRelativeTo.World
gravForce.Force       = Vector3.new(0, 0, 0)
gravForce.Parent      = rootPart

local orientTarget = Instance.new("Attachment")
orientTarget.Name   = "GravOrientTarget"
orientTarget.Parent = workspace.Terrain

local alignOrient = Instance.new("AlignOrientation")
alignOrient.Attachment0     = gravAttach
alignOrient.Attachment1     = orientTarget
alignOrient.RigidityEnabled = false
alignOrient.MaxTorque       = 700000
alignOrient.Responsiveness  = 28
alignOrient.Parent          = rootPart

-- ── Gravity helpers ─────────────────────────────────────────────────────────
local function charMass()
    local m = 0
    for _, p in ipairs(character:GetDescendants()) do
        if p:IsA("BasePart") then m = m + p:GetMass() end
    end
    return math.max(m, 1)
end

local function applyGravForce()
    local mass = charMass()
    gravForce.Force = Vector3.new(0, GRAVITY_MAG * mass, 0) + gravDir * GRAVITY_MAG * mass
end

local function updateOrientation()
    local up   = -gravDir
    local look = rootPart.CFrame.LookVector
    look = (look - look:Dot(up) * up)
    if look.Magnitude < 0.01 then
        look = math.abs(up:Dot(Vector3.new(0,0,1))) < 0.9 and Vector3.new(0,0,-1) or Vector3.new(1,0,0)
        look = (look - look:Dot(up) * up)
    end
    look = look.Unit
    orientTarget.CFrame = CFrame.fromMatrix(rootPart.Position, look:Cross(up).Unit, up, -look)
end

local function setGravity(dir)
    gravDir = dir
    applyGravForce()
    updateOrientation()
end

-- ── Screen shake ───────────────────────────────────────────────────────────
local shakeTime      = 0
local shakeIntensity = 0

local function triggerShake(duration, intensity)
    shakeTime      = duration
    shakeIntensity = intensity
end

RunService.RenderStepped:Connect(function(dt)
    if shakeTime > 0 then
        shakeTime = shakeTime - dt
        local s   = shakeIntensity * math.max(0, shakeTime / GameConfig.SHAKE_DURATION)
        camera.CFrame = camera.CFrame
            * CFrame.new(math.random() * s*2 - s, math.random() * s*2 - s, 0)
            * CFrame.Angles(
                math.random() * s * 0.04 - s * 0.02,
                math.random() * s * 0.04 - s * 0.02, 0)
    end
end)

PlayerDamaged.OnClientEvent:Connect(function(data)
    if not data.isDot then
        triggerShake(GameConfig.SHAKE_DURATION, GameConfig.SHAKE_INTENSITY)
    end
end)

-- ── Floating damage numbers ────────────────────────────────────────────────
local function showDamageNumber(worldPos, amount, color, isCrit)
    local hud = playerGui:FindFirstChild("GameHUD")
    if not hud then return end
    local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
    if not onScreen then return end

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(0, 80, 0, isCrit and 36 or 28)
    lbl.Position          = UDim2.new(0, screenPos.X - 40, 0, screenPos.Y - (isCrit and 18 or 14))
    lbl.BackgroundTransparency = 1
    lbl.Text              = (isCrit and "⚡ " or "") .. math.ceil(amount)
    lbl.TextColor3        = isCrit and Color3.fromRGB(255, 240, 40) or (color or Color3.fromRGB(255,220,60))
    lbl.Font              = Enum.Font.GothamBold
    lbl.TextSize          = isCrit and 26 or 20
    lbl.TextStrokeColor3  = Color3.new(0,0,0)
    lbl.TextStrokeTransparency = 0.4
    lbl.ZIndex            = 20
    lbl.Parent            = hud

    TweenService:Create(lbl, TweenInfo.new(isCrit and 1.0 or 0.75, Enum.EasingStyle.Quint), {
        Position         = UDim2.new(0, screenPos.X - 40, 0, screenPos.Y - (isCrit and 80 or 65)),
        TextTransparency = 1,
        TextSize         = isCrit and 14 or 13,
    }):Play()
    Debris:AddItem(lbl, isCrit and 1.05 or 0.8)
end

-- ── Dash ───────────────────────────────────────────────────────────────────
local function doDash()
    local now = tick()
    if now - lastDashTime < GameConfig.DASH_COOLDOWN then return end
    if isDashing then return end
    lastDashTime = now
    isDashing    = true
    player:SetAttribute("LastDash",    now)
    player:SetAttribute("DashCooldown", GameConfig.DASH_COOLDOWN)

    -- Dash in look direction (projected onto gravity plane)
    local up   = -gravDir
    local look = rootPart.CFrame.LookVector
    look = (look - look:Dot(up) * up)
    if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
    look = look.Unit

    local bv = Instance.new("BodyVelocity")
    bv.Velocity  = look * GameConfig.DASH_SPEED
    bv.MaxForce  = Vector3.new(1e6, 1e6, 1e6)
    bv.Parent    = rootPart

    -- Ghost afterimages
    local function spawnGhost()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                local g = part:Clone()
                g.Anchored   = true; g.CanCollide = false
                g.CastShadow = false
                g.Material   = Enum.Material.Neon
                g.Color      = Color3.fromRGB(80, 160, 255)
                g.Transparency = 0.55
                g.Parent     = workspace
                TweenService:Create(g, TweenInfo.new(0.28), { Transparency = 1 }):Play()
                Debris:AddItem(g, 0.32)
            end
        end
    end
    spawnGhost()
    task.delay(0.06, spawnGhost)
    task.delay(0.12, spawnGhost)

    Debris:AddItem(bv, GameConfig.DASH_DURATION)
    task.delay(GameConfig.DASH_DURATION + 0.05, function() isDashing = false end)
end

-- ── Critical hit ────────────────────────────────────────────────────────────
local function applyCrit(damage)
    local chance = GameConfig.CRIT_CHANCE + (player:GetAttribute("CritBonus") or 0)
    if math.random() < chance then
        return damage * GameConfig.CRIT_MULT, true
    end
    return damage, false
end

-- ── Gravity switch ─────────────────────────────────────────────────────────
local function doGravitySwitch()
    local now = tick()
    if now - lastGravSwitch < gravCooldown then return end
    lastGravSwitch = now
    gravIndex = (gravIndex % #GRAV_DIRS) + 1
    local newDir = GRAV_DIRS[gravIndex]
    setGravity(newDir)
    RequestGravitySwitch:FireServer(newDir)
    hasDoubleJumped = false
    -- Store timestamp for HUD cooldown radial
    player:SetAttribute("LastGravSwitch", now)
    player:SetAttribute("GravCooldown",   gravCooldown)
end

GravitySwitched.OnClientEvent:Connect(function(dir)
    for i, d in ipairs(GRAV_DIRS) do if d == dir then gravIndex = i; break end end
    setGravity(dir)
    hasDoubleJumped = false
end)

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.weapon          then currentWeapon = data.weapon end
    if data.gravityCooldown then gravCooldown = data.gravityCooldown; player:SetAttribute("GravCooldown", gravCooldown) end
    if data.doubleJump      then canDoubleJump = data.doubleJump end
    if data.damageMult      then damageMult    = data.damageMult end
    if data.critBonus       then player:SetAttribute("CritBonus",  data.critBonus) end
    if data.damageReduction then player:SetAttribute("DmgReduce",  data.damageReduction) end
    if data.berserkThreshold then player:SetAttribute("BerserkHP", data.berserkThreshold) end
    if data.dashCooldown    then
        player:SetAttribute("DashCooldown", data.dashCooldown)
    end
end)

-- ── Hitscan helpers ────────────────────────────────────────────────────────
local function shootRay(origin, dir, range)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(origin, dir * range, params)
end

local function createTracer(from, to, color)
    local mid = (from + to) / 2
    local len = (to - from).Magnitude
    local t   = Instance.new("Part")
    t.Size       = Vector3.new(0.1, 0.1, len)
    t.Color      = color
    t.Material   = Enum.Material.Neon
    t.Anchored   = true
    t.CanCollide = false
    t.CastShadow = false
    t.CFrame     = CFrame.new(mid, to)
    t.Parent     = workspace
    TweenService:Create(t, TweenInfo.new(0.12), { Transparency = 1 }):Play()
    Debris:AddItem(t, 0.14)
end

local function hitModel(instance, damage, damageType)
    if not instance then return false end
    local m = instance:FindFirstAncestorOfClass("Model")
    if not m then return false end
    local eid = m:FindFirstChild("EnemyId")
    if eid then DamageEnemy:FireServer(eid.Value, damage, damageType); return true end
    if m:FindFirstChild("IsBoss") then DamageBoss:FireServer(damage); return true end
    return false
end

-- ── Weapon tables ──────────────────────────────────────────────────────────
-- CD=0 for melee weapons means use MELEE_COOLDOWN
local WEAPON_CD    = {
    blaster=0.25, shotgun=0.70, sniper=1.60, sword=0,
    flamethrower=0.07, grenade_launcher=1.2,
    void_blade=0, throwing_knives=0.5, scythe=0, war_hammer=0,
    chain_lightning=0.85, plasma_cannon=2.6, cryo_blaster=0.45, flare_gun=2.2,
}
local WEAPON_DMG   = {
    blaster=25, shotgun=14, sniper=90, sword=0, flamethrower=10, grenade_launcher=70,
    void_blade=0, throwing_knives=20, scythe=0, war_hammer=0,
    chain_lightning=38, plasma_cannon=210, cryo_blaster=22, flare_gun=12,
}
local WEAPON_RANGE = {
    blaster=200, shotgun=80, sniper=350, sword=0, flamethrower=20, grenade_launcher=120,
    void_blade=0, throwing_knives=150, scythe=0, war_hammer=0,
    chain_lightning=130, plasma_cannon=200, cryo_blaster=140, flare_gun=90,
}
local WEAPON_COLOR = {
    blaster          = Color3.fromRGB(255, 220, 60),
    shotgun          = Color3.fromRGB(255, 160, 60),
    sniper           = Color3.fromRGB(120, 220, 255),
    flamethrower     = Color3.fromRGB(255, 80, 20),
    grenade_launcher = Color3.fromRGB(180, 255, 80),
    throwing_knives  = Color3.fromRGB(220, 200, 255),
    chain_lightning  = Color3.fromRGB(180, 140, 255),
    plasma_cannon    = Color3.fromRGB(255, 100, 255),
    cryo_blaster     = Color3.fromRGB(100, 220, 255),
    flare_gun        = Color3.fromRGB(255, 120, 20),
}
local MELEE_WEAPONS = { sword=true, void_blade=true, scythe=true, war_hammer=true }

local function createSlash(pos, look, range)
    local s = Instance.new("Part")
    s.Size        = Vector3.new(range*1.4, 0.15, range*0.65)
    s.Color       = Color3.fromRGB(180, 240, 255)
    s.Material    = Enum.Material.Neon
    s.Transparency = 0.2
    s.Anchored    = true
    s.CanCollide  = false
    s.CastShadow  = false
    s.CFrame      = CFrame.new(pos + look * range*0.4, pos + look * range)
    s.Parent      = workspace
    TweenService:Create(s, TweenInfo.new(0.18), { Transparency = 1 }):Play()
    Debris:AddItem(s, 0.2)
end

-- ── AoE hit helper ─────────────────────────────────────────────────────────
local function aoeHit(center, radius, dmg, color, falloff)
    local params = OverlapParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local near = workspace:GetPartBoundsInRadius(center, radius, params)
    local done = {}
    for _, p in ipairs(near) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m then
            local eid = m:FindFirstChild("EnemyId")
            if eid and not done[eid.Value] then
                done[eid.Value] = true
                local dist = (m:GetModelCFrame().Position - center).Magnitude
                local scale = falloff and math.max(0.35, 1 - dist / radius) or 1
                local fd, isCrit = applyCrit(dmg * scale)
                DamageEnemy:FireServer(eid.Value, fd, "ranged")
                showDamageNumber(p.Position, fd, color, isCrit)
            end
            if m:FindFirstChild("IsBoss") then DamageBoss:FireServer(dmg * 0.5) end
        end
    end
end

local function makeExplosion(pos, size, color)
    local exp = Instance.new("Part")
    exp.Size = Vector3.new(size,size,size); exp.Shape = Enum.PartType.Ball
    exp.Color = color; exp.Material = Enum.Material.Neon
    exp.Anchored = true; exp.CanCollide = false; exp.CastShadow = false
    exp.CFrame = CFrame.new(pos); exp.Parent = workspace
    TweenService:Create(exp, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(0.5,0.5,0.5) }):Play()
    Debris:AddItem(exp, 0.28)
end

-- ── Shoot ──────────────────────────────────────────────────────────────────
local function doShoot()
    if MELEE_WEAPONS[currentWeapon] then return end
    local now = tick()
    local cd  = WEAPON_CD[currentWeapon] or 0.25
    if now - lastShootTime < cd then return end
    lastShootTime = now

    local mouse  = player:GetMouse()
    local origin = rootPart.Position + Vector3.new(0, 0.5, 0)
    local target = mouse.Hit.Position
    local dir    = (target - origin).Unit
    local range  = WEAPON_RANGE[currentWeapon] or 200
    local dmg    = (WEAPON_DMG[currentWeapon] or 25) * damageMult
    local color  = WEAPON_COLOR[currentWeapon] or Color3.fromRGB(255, 220, 60)

    if currentWeapon == "shotgun" then
        for _ = 1, 5 do
            local sp  = Vector3.new(math.random()*0.36-0.18, math.random()*0.36-0.18, math.random()*0.36-0.18)
            local sd  = (dir + sp).Unit
            local hit = shootRay(origin, sd, range)
            local ep  = hit and hit.Position or (origin + sd*range)
            createTracer(origin, ep, color)
            if hit then
                local fd, isCrit = applyCrit(dmg)
                hitModel(hit.Instance, fd, "ranged")
                showDamageNumber(ep, fd, color, isCrit)
            end
        end

    elseif currentWeapon == "throwing_knives" then
        -- 3-knife burst with slight spread
        for k = -1, 1 do
            local sp  = Vector3.new(k * 0.06, 0, 0)
            local sd  = (dir + sp).Unit
            local hit = shootRay(origin, sd, range)
            local ep  = hit and hit.Position or (origin + sd * range)
            createTracer(origin, ep, Color3.fromRGB(220, 200, 255))
            if hit then
                local fd, isCrit = applyCrit(dmg)
                hitModel(hit.Instance, fd, "ranged")
                showDamageNumber(ep, fd, color, isCrit)
            end
        end

    elseif currentWeapon == "chain_lightning" then
        -- Arc up to 4 enemies, each 75% of previous damage
        local hit = shootRay(origin, dir, range)
        if hit then
            local ep = hit.Position
            createTracer(origin, ep, color)
            local chainDmg = dmg
            local prevPos  = ep
            local chained  = {}
            for _ = 1, 4 do
                local fd, isCrit = applyCrit(chainDmg)
                hitModel(hit.Instance, fd, "ranged")
                showDamageNumber(ep, fd, color, isCrit)
                -- Find next nearest enemy within 20 studs
                local params2 = OverlapParams.new()
                params2.FilterDescendantsInstances = { character }
                params2.FilterType = Enum.RaycastFilterType.Exclude
                local near = workspace:GetPartBoundsInRadius(ep, 20, params2)
                local nextHit, nextEp, nextInst = nil, nil, nil
                local bestDist = 999
                for _, p in ipairs(near) do
                    local m = p:FindFirstAncestorOfClass("Model")
                    if m then
                        local eid = m:FindFirstChild("EnemyId")
                        if eid and not chained[eid.Value] then
                            local d = (m:GetModelCFrame().Position - ep).Magnitude
                            if d < bestDist then
                                bestDist = d; nextEp = m:GetModelCFrame().Position; nextInst = p
                                chained[eid.Value] = true
                            end
                        end
                    end
                end
                if nextEp then
                    createTracer(prevPos, nextEp, color)
                    prevPos = nextEp; ep = nextEp; chainDmg = chainDmg * 0.75
                    hit = { Instance = nextInst, Position = nextEp }
                else break end
            end
        else
            createTracer(origin, origin + dir * range, color)
        end

    elseif currentWeapon == "plasma_cannon" then
        local hit = shootRay(origin, dir, range)
        local ep  = hit and hit.Position or (origin + dir * range)
        createTracer(origin, ep, color)
        makeExplosion(ep, 10, color)
        aoeHit(ep, 12, dmg, color, true)

    elseif currentWeapon == "cryo_blaster" then
        local hit = shootRay(origin, dir, range)
        local ep  = hit and hit.Position or (origin + dir * range)
        createTracer(origin, ep, color)
        if hit then
            local fd, isCrit = applyCrit(dmg)
            hitModel(hit.Instance, fd, "ranged")
            showDamageNumber(ep, fd, color, isCrit)
            -- Cryo burst visual
            local frost = Instance.new("Part")
            frost.Size = Vector3.new(3,3,3); frost.Shape = Enum.PartType.Ball
            frost.Color = color; frost.Material = Enum.Material.Neon
            frost.Anchored = true; frost.CanCollide = false
            frost.CFrame = CFrame.new(ep); frost.Parent = workspace
            TweenService:Create(frost, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.5,0.5,0.5) }):Play()
            Debris:AddItem(frost, 0.35)
        end

    elseif currentWeapon == "flare_gun" then
        local hit = shootRay(origin, dir, range)
        local ep  = hit and hit.Position or (origin + dir * range)
        createTracer(origin, ep, Color3.fromRGB(255, 120, 20))
        -- Persistent fire zone — damage repeatedly for 4s
        local flare = Instance.new("Part")
        flare.Size = Vector3.new(6,0.5,6); flare.Shape = Enum.PartType.Cylinder
        flare.Color = Color3.fromRGB(255, 80, 10); flare.Material = Enum.Material.Neon
        flare.Anchored = true; flare.CanCollide = false
        flare.CFrame = CFrame.new(ep); flare.Parent = workspace
        TweenService:Create(flare,
            TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
            { Transparency = 1, Size = Vector3.new(0.5,0.5,0.5) }
        ):Play()
        Debris:AddItem(flare, 4.1)
        task.spawn(function()
            for _ = 1, 8 do
                task.wait(0.5)
                if not flare.Parent then break end
                aoeHit(ep, 7, dmg, Color3.fromRGB(255, 100, 20), false)
            end
        end)

    elseif currentWeapon == "grenade_launcher" then
        local hit = shootRay(origin, dir, range)
        local ep  = hit and hit.Position or (origin + dir*range)
        createTracer(origin, ep, color)
        makeExplosion(ep, 6, Color3.fromRGB(255,160,40))
        aoeHit(ep, 8, dmg, color, false)

    else
        local hit = shootRay(origin, dir, range)
        local ep  = hit and hit.Position or (origin + dir*range)
        createTracer(origin, ep, color)
        if hit then
            local fd, isCrit = applyCrit(dmg)
            hitModel(hit.Instance, fd, "ranged")
            showDamageNumber(ep, fd, color, isCrit)
            -- Sniper pierce
            if currentWeapon == "sniper" then
                local hit2 = shootRay(hit.Position + dir*0.5, dir, range - (hit.Position-origin).Magnitude)
                if hit2 then
                    local fd2, isCrit2 = applyCrit(dmg * 0.55)
                    hitModel(hit2.Instance, fd2, "ranged")
                    showDamageNumber(hit2.Position, fd2, color, isCrit2)
                end
            end
        end
    end
end

-- ── Melee ──────────────────────────────────────────────────────────────────
local MELEE_STATS = {
    sword      = { cd = GameConfig.MELEE_COOLDOWN * 0.8, range = GameConfig.MELEE_RANGE * 1.25, dmg = 55  },
    void_blade = { cd = 0.35, range = 11,  dmg = 48  },
    scythe     = { cd = 0.75, range = 14,  dmg = 70  },
    war_hammer = { cd = 1.4,  range = 9,   dmg = 130 },
}
local function doMelee()
    local now = tick()
    local ms  = MELEE_STATS[currentWeapon]
    local cd  = ms and ms.cd or GameConfig.MELEE_COOLDOWN
    if now - lastMeleeTime < cd then return end
    lastMeleeTime = now

    local range = ms and ms.range or GameConfig.MELEE_RANGE
    local dmg   = (ms and ms.dmg or GameConfig.MELEE_DAMAGE) * damageMult
    local look  = rootPart.CFrame.LookVector
    createSlash(rootPart.Position, look, range)

    local params = OverlapParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Exclude

    -- Scythe = 360° spin around player; war_hammer = wide shockwave AoE; others = frontal cone
    local hitCenter, hitRadius
    if currentWeapon == "scythe" then
        hitCenter = rootPart.Position; hitRadius = range
        -- 360 spin visual
        for angle = 0, 300, 60 do
            local adir = CFrame.Angles(0, math.rad(angle), 0) * look
            createSlash(rootPart.Position, adir, range * 0.8)
        end
    elseif currentWeapon == "war_hammer" then
        hitCenter = rootPart.Position + look * range * 0.5; hitRadius = range * 1.2
        -- Shockwave ring
        local wave = Instance.new("Part")
        wave.Size = Vector3.new(range*2.4, 0.4, range*2.4); wave.Shape = Enum.PartType.Cylinder
        wave.Color = Color3.fromRGB(200, 160, 80); wave.Material = Enum.Material.Neon
        wave.Anchored = true; wave.CanCollide = false
        wave.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0,0,math.rad(90))
        wave.Parent = workspace
        TweenService:Create(wave, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(range*4,0.1,range*4) }):Play()
        Debris:AddItem(wave, 0.45)
    else
        hitCenter = rootPart.Position + look * range * 0.5; hitRadius = range * 0.65
    end

    local hits = workspace:GetPartBoundsInRadius(hitCenter, hitRadius, params)
    local done = {}
    for _, p in ipairs(hits) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m then
            local eid = m:FindFirstChild("EnemyId")
            if eid and not done[eid.Value] then
                done[eid.Value] = true
                local fd, isCrit = applyCrit(dmg)
                DamageEnemy:FireServer(eid.Value, fd, "melee")
                showDamageNumber(p.Position, fd, Color3.fromRGB(220, 180, 255), isCrit)
            end
            if m:FindFirstChild("IsBoss") then DamageBoss:FireServer(dmg) end
        end
    end
end

-- ── Input ──────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.G then doGravitySwitch() end
    if input.KeyCode == Enum.KeyCode.LeftShift then doDash() end
    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.F then doMelee() end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if MELEE_WEAPONS[currentWeapon] then doMelee() else doShoot() end
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then doMelee() end

    -- Double jump
    if input.KeyCode == Enum.KeyCode.Space then
        local state = humanoid:GetState()
        if (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)
            and canDoubleJump and not hasDoubleJumped then
            hasDoubleJumped = true
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = (-gravDir) * GameConfig.BASE_JUMP_POWER
            bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bv.Parent   = rootPart
            Debris:AddItem(bv, 0.15)
        end
    end
end)

-- Auto-fire weapons
local AUTO_FIRE = { blaster = true, flamethrower = true, chain_lightning = false }
RunService.Heartbeat:Connect(function()
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        if AUTO_FIRE[currentWeapon] then doShoot() end
    end
end)

humanoid.StateChanged:Connect(function(_, new)
    if new == Enum.HumanoidStateType.Landed then hasDoubleJumped = false end
end)

-- ── Gravity force maintenance ───────────────────────────────────────────────
local massTimer = 0
RunService.Heartbeat:Connect(function(dt)
    massTimer = massTimer + dt
    if massTimer >= 1 then massTimer = 0; applyGravForce() end
end)

applyGravForce()
updateOrientation()
player:SetAttribute("GravCooldown",   gravCooldown)
player:SetAttribute("LastGravSwitch", 0)

print("[CharacterController] Loaded for", player.Name)
