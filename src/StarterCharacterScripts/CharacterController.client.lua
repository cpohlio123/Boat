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
local function showDamageNumber(worldPos, amount, color)
    local hud = playerGui:FindFirstChild("GameHUD")
    if not hud then return end
    local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
    if not onScreen then return end

    local label = Instance.new("TextLabel")
    label.Size               = UDim2.new(0, 70, 0, 28)
    label.Position           = UDim2.new(0, screenPos.X - 35, 0, screenPos.Y - 14)
    label.BackgroundTransparency = 1
    label.Text               = tostring(math.ceil(amount))
    label.TextColor3         = color or Color3.fromRGB(255, 220, 60)
    label.Font               = Enum.Font.GothamBold
    label.TextSize           = 20
    label.TextStrokeColor3   = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.5
    label.ZIndex             = 20
    label.Parent             = hud

    TweenService:Create(label, TweenInfo.new(0.75, Enum.EasingStyle.Quint), {
        Position        = UDim2.new(0, screenPos.X - 35, 0, screenPos.Y - 65),
        TextTransparency = 1,
        TextSize        = 13,
    }):Play()
    Debris:AddItem(label, 0.8)
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
    if data.weapon         then currentWeapon = data.weapon end
    if data.gravityCooldown then gravCooldown = data.gravityCooldown; player:SetAttribute("GravCooldown", gravCooldown) end
    if data.doubleJump     then canDoubleJump = data.doubleJump end
    if data.damageMult     then damageMult    = data.damageMult end
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
local WEAPON_CD    = { blaster=0.25, shotgun=0.70, sniper=1.60, sword=0, flamethrower=0.07, grenade_launcher=1.2 }
local WEAPON_DMG   = { blaster=25,  shotgun=14,   sniper=90,   sword=0, flamethrower=10,   grenade_launcher=70  }
local WEAPON_RANGE = { blaster=200, shotgun=80,   sniper=350,  sword=0, flamethrower=20,   grenade_launcher=120 }
local WEAPON_COLOR = {
    blaster          = Color3.fromRGB(255, 220, 60),
    shotgun          = Color3.fromRGB(255, 160, 60),
    sniper           = Color3.fromRGB(120, 220, 255),
    flamethrower     = Color3.fromRGB(255, 80, 20),
    grenade_launcher = Color3.fromRGB(180, 255, 80),
}

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

-- ── Shoot ──────────────────────────────────────────────────────────────────
local function doShoot()
    if currentWeapon == "sword" then return end
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
                hitModel(hit.Instance, dmg, "ranged")
                showDamageNumber(ep, dmg, color)
            end
        end

    elseif currentWeapon == "grenade_launcher" then
        local hit = shootRay(origin, dir, range)
        local ep  = hit and hit.Position or (origin + dir*range)
        createTracer(origin, ep, color)
        -- AoE
        local params = OverlapParams.new()
        params.FilterDescendantsInstances = { character }
        params.FilterType = Enum.RaycastFilterType.Exclude
        local near = workspace:GetPartBoundsInRadius(ep, 8, params)
        local done = {}
        for _, p in ipairs(near) do
            local m = p:FindFirstAncestorOfClass("Model")
            if m then
                local eid = m:FindFirstChild("EnemyId")
                if eid and not done[eid.Value] then
                    done[eid.Value] = true
                    DamageEnemy:FireServer(eid.Value, dmg, "ranged")
                    showDamageNumber(p.Position, dmg, color)
                end
                if m:FindFirstChild("IsBoss") then DamageBoss:FireServer(dmg * 0.6) end
            end
        end
        local exp = Instance.new("Part")
        exp.Size = Vector3.new(6,6,6); exp.Shape = Enum.PartType.Ball
        exp.Color = Color3.fromRGB(255,160,40); exp.Material = Enum.Material.Neon
        exp.Anchored = true; exp.CanCollide = false; exp.CFrame = CFrame.new(ep); exp.Parent = workspace
        TweenService:Create(exp, TweenInfo.new(0.22), { Transparency = 1, Size = Vector3.new(1,1,1) }):Play()
        Debris:AddItem(exp, 0.25)

    else
        local hit = shootRay(origin, dir, range)
        local ep  = hit and hit.Position or (origin + dir*range)
        createTracer(origin, ep, color)
        if hit then
            hitModel(hit.Instance, dmg, "ranged")
            showDamageNumber(ep, dmg, color)
            -- Sniper pierce
            if currentWeapon == "sniper" then
                local hit2 = shootRay(hit.Position + dir*0.5, dir, range - (hit.Position-origin).Magnitude)
                if hit2 then
                    hitModel(hit2.Instance, dmg * 0.55, "ranged")
                    showDamageNumber(hit2.Position, dmg*0.55, color)
                end
            end
        end
    end
end

-- ── Melee ──────────────────────────────────────────────────────────────────
local function doMelee()
    local now = tick()
    local cd  = currentWeapon == "sword" and GameConfig.MELEE_COOLDOWN * 0.8 or GameConfig.MELEE_COOLDOWN
    if now - lastMeleeTime < cd then return end
    lastMeleeTime = now

    local range = currentWeapon == "sword" and GameConfig.MELEE_RANGE * 1.25 or GameConfig.MELEE_RANGE
    local dmg   = (currentWeapon == "sword" and 55 or GameConfig.MELEE_DAMAGE) * damageMult
    local look  = rootPart.CFrame.LookVector
    createSlash(rootPart.Position, look, range)

    local params = OverlapParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local center = rootPart.Position + look * range * 0.5
    local hits   = workspace:GetPartBoundsInRadius(center, range * 0.65, params)
    local done   = {}
    for _, p in ipairs(hits) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m then
            local eid = m:FindFirstChild("EnemyId")
            if eid and not done[eid.Value] then
                done[eid.Value] = true
                DamageEnemy:FireServer(eid.Value, dmg, "melee")
                showDamageNumber(p.Position, dmg, Color3.fromRGB(220, 180, 255))
            end
            if m:FindFirstChild("IsBoss") then DamageBoss:FireServer(dmg) end
        end
    end
end

-- ── Input ──────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.G then doGravitySwitch() end
    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.F then doMelee() end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if currentWeapon == "sword" then doMelee() else doShoot() end
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

-- Auto-fire
RunService.Heartbeat:Connect(function()
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        if currentWeapon == "blaster" or currentWeapon == "flamethrower" then doShoot() end
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
