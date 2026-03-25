-- CharacterController.client.lua
-- Handles gravity switching, custom jump, shooting (hitscan), and melee.
-- All input lives here; fires RemoteEvents to the server for authoritative damage.

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

-- Wait for server-created events
local Events = ReplicatedStorage:WaitForChild("Events")
local RequestGravitySwitch = Events:WaitForChild("RequestGravitySwitch")
local GravitySwitched      = Events:WaitForChild("GravitySwitched")
local DamageEnemy          = Events:WaitForChild("DamageEnemy")
local DamageBoss           = Events:WaitForChild("DamageBoss")
local UpdateHUD            = Events:WaitForChild("UpdateHUD")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

-- ── State ──────────────────────────────────────────────────────────────────
local GRAVITY_MAG = workspace.Gravity   -- 196.2

local gravDir         = Vector3.new(0, -1, 0)
local gravCooldown    = GameConfig.GRAVITY_SWITCH_COOLDOWN
local lastGravSwitch  = -999

local canDoubleJump   = false
local hasDoubleJumped = false

local currentWeapon   = "blaster"
local damageMult      = 1
local lastShootTime   = -999
local lastMeleeTime   = -999

-- Gravity direction cycle (press G to advance)
local GRAV_DIRS = {
    Vector3.new(0, -1, 0),   -- floor
    Vector3.new(0,  1, 0),   -- ceiling
    Vector3.new(-1, 0, 0),   -- left wall
    Vector3.new(1,  0, 0),   -- right wall
}
local gravIndex = 1

-- ── Physics objects ────────────────────────────────────────────────────────
local gravAttach = Instance.new("Attachment")
gravAttach.Name  = "GravAttach"
gravAttach.Parent = rootPart

local gravForce = Instance.new("VectorForce")
gravForce.Name        = "CustomGravity"
gravForce.Attachment0 = gravAttach
gravForce.RelativeTo  = Enum.ActuatorRelativeTo.World
gravForce.Force       = Vector3.new(0, 0, 0)
gravForce.Parent      = rootPart

-- Orientation target lives in Terrain so it persists
local orientTarget = Instance.new("Attachment")
orientTarget.Name  = "GravOrientTarget"
orientTarget.Parent = workspace.Terrain

local alignOrient = Instance.new("AlignOrientation")
alignOrient.Attachment0      = gravAttach
alignOrient.Attachment1      = orientTarget
alignOrient.RigidityEnabled  = false
alignOrient.MaxTorque        = 600000
alignOrient.Responsiveness   = 25
alignOrient.Parent           = rootPart

-- ── Helpers ────────────────────────────────────────────────────────────────
local function charMass()
    local m = 0
    for _, p in ipairs(character:GetDescendants()) do
        if p:IsA("BasePart") then m = m + p:GetMass() end
    end
    return math.max(m, 1)
end

local function applyGravForce()
    local mass = charMass()
    -- Cancel default downward gravity; apply gravDir gravity
    gravForce.Force = Vector3.new(0, GRAVITY_MAG * mass, 0) + gravDir * GRAVITY_MAG * mass
end

local function updateOrientation()
    local up   = -gravDir
    local look = rootPart.CFrame.LookVector
    look = (look - look:Dot(up) * up)
    if look.Magnitude < 0.01 then
        look = math.abs(up:Dot(Vector3.new(0,0,1))) < 0.9
               and Vector3.new(0, 0, -1)
               or  Vector3.new(1, 0, 0)
        look = (look - look:Dot(up) * up)
    end
    look = look.Unit
    local right = look:Cross(up).Unit
    orientTarget.CFrame = CFrame.fromMatrix(rootPart.Position, right, up, -look)
end

local function setGravity(dir)
    gravDir = dir
    applyGravForce()
    updateOrientation()
end

-- ── Gravity switch ─────────────────────────────────────────────────────────
local function doGravitySwitch()
    local now = tick()
    if now - lastGravSwitch < gravCooldown then return end
    lastGravSwitch = now

    gravIndex = (gravIndex % #GRAV_DIRS) + 1
    local newDir = GRAV_DIRS[gravIndex]

    setGravity(newDir)
    RequestGravitySwitch:FireServer(newDir)   -- server handles slam damage
    hasDoubleJumped = false
end

-- Server confirms gravity change (e.g. boss gravity pulse)
GravitySwitched.OnClientEvent:Connect(function(dir)
    -- Find index
    for i, d in ipairs(GRAV_DIRS) do
        if d == dir then gravIndex = i; break end
    end
    setGravity(dir)
    hasDoubleJumped = false
end)

-- ── HUD data ────────────────────────────────────────────────────────────────
UpdateHUD.OnClientEvent:Connect(function(data)
    if data.weapon         then currentWeapon = data.weapon end
    if data.gravityCooldown then gravCooldown = data.gravityCooldown end
    if data.doubleJump     then canDoubleJump = data.doubleJump end
    if data.damageMult     then damageMult    = data.damageMult end
end)

-- ── Combat helpers ─────────────────────────────────────────────────────────
local function createTracer(from, to, color)
    local mid    = (from + to) / 2
    local length = (to - from).Magnitude
    local t = Instance.new("Part")
    t.Size        = Vector3.new(0.12, 0.12, length)
    t.Color       = color or Color3.fromRGB(255, 220, 60)
    t.Material    = Enum.Material.Neon
    t.Anchored    = true
    t.CanCollide  = false
    t.CastShadow  = false
    t.CFrame      = CFrame.new(mid, to)
    t.Parent      = workspace
    TweenService:Create(t, TweenInfo.new(0.12), { Transparency = 1 }):Play()
    Debris:AddItem(t, 0.15)
end

local function createSlashEffect(pos, look, range)
    local s = Instance.new("Part")
    s.Size        = Vector3.new(range * 1.4, 0.15, range * 0.7)
    s.Color       = Color3.fromRGB(180, 240, 255)
    s.Material    = Enum.Material.Neon
    s.Transparency = 0.25
    s.Anchored    = true
    s.CanCollide  = false
    s.CFrame      = CFrame.new(pos + look * range * 0.4, pos + look * range)
    s.Parent      = workspace
    TweenService:Create(s, TweenInfo.new(0.18), { Transparency = 1 }):Play()
    Debris:AddItem(s, 0.2)
end

local function getMouse3D()
    local mouse = player:GetMouse()
    return mouse.Hit.Position
end

local function shootRaycast(origin, dir, range)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(origin, dir * range, params)
end

local function hitEnemy(hit, damage)
    if not hit then return false end
    local model = hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model")
    if not model then return false end
    local eid = model:FindFirstChild("EnemyId")
    if eid then
        DamageEnemy:FireServer(eid.Value, damage, "ranged")
        return true
    end
    if model:FindFirstChild("IsBoss") then
        DamageBoss:FireServer(damage)
        return true
    end
    return false
end

-- ── Shoot ──────────────────────────────────────────────────────────────────
local weaponCooldowns = {
    blaster   = 0.25,
    shotgun   = 0.70,
    sniper    = 1.60,
    sword     = 0,      -- melee only
    flamethrower = 0.07,
    grenade_launcher = 1.2,
}
local weaponDamage = {
    blaster   = 25,
    shotgun   = 14,
    sniper    = 90,
    sword     = 0,
    flamethrower = 10,
    grenade_launcher = 70,
}
local weaponRange = {
    blaster   = 200,
    shotgun   = 80,
    sniper    = 350,
    sword     = 0,
    flamethrower = 20,
    grenade_launcher = 120,
}
local weaponColor = {
    blaster   = Color3.fromRGB(255, 220, 60),
    shotgun   = Color3.fromRGB(255, 160, 60),
    sniper    = Color3.fromRGB(120, 220, 255),
    flamethrower = Color3.fromRGB(255, 80, 20),
    grenade_launcher = Color3.fromRGB(180, 255, 80),
}

local function doShoot()
    if currentWeapon == "sword" then return end
    local now = tick()
    local cd  = weaponCooldowns[currentWeapon] or 0.25
    if now - lastShootTime < cd then return end
    lastShootTime = now

    local origin = rootPart.Position + Vector3.new(0, 0.5, 0)
    local target = getMouse3D()
    local dir    = (target - origin).Unit
    local range  = weaponRange[currentWeapon] or 200
    local dmg    = (weaponDamage[currentWeapon] or 25) * damageMult
    local color  = weaponColor[currentWeapon] or Color3.fromRGB(255, 220, 60)

    if currentWeapon == "shotgun" then
        for _ = 1, 5 do
            local spread = Vector3.new(
                math.random() * 0.36 - 0.18,
                math.random() * 0.36 - 0.18,
                math.random() * 0.36 - 0.18
            )
            local sDir = (dir + spread).Unit
            local hit = shootRaycast(origin, sDir, range)
            local endPt = hit and hit.Position or (origin + sDir * range)
            createTracer(origin, endPt, color)
            hitEnemy(hit, dmg)
        end
    elseif currentWeapon == "flamethrower" then
        local spread = Vector3.new(
            math.random() * 0.5 - 0.25,
            math.random() * 0.5 - 0.25,
            math.random() * 0.5 - 0.25
        )
        local sDir = (dir + spread).Unit
        local hit = shootRaycast(origin, sDir, range)
        local endPt = hit and hit.Position or (origin + sDir * range)
        createTracer(origin, endPt, color)
        hitEnemy(hit, dmg)
    elseif currentWeapon == "grenade_launcher" then
        -- Visual arc
        local hit = shootRaycast(origin, dir, range)
        local endPt = hit and hit.Position or (origin + dir * range)
        createTracer(origin, endPt, color)
        -- AoE damage (3 closest enemies in radius around impact)
        local impactParams = OverlapParams.new()
        impactParams.FilterDescendantsInstances = { character }
        impactParams.FilterType = Enum.RaycastFilterType.Exclude
        local near = workspace:GetPartBoundsInRadius(endPt, 8, impactParams)
        local hit2enemies = {}
        for _, p in ipairs(near) do
            local m = p:FindFirstAncestorOfClass("Model")
            if m then
                local eid = m:FindFirstChild("EnemyId")
                if eid and not hit2enemies[eid.Value] then
                    hit2enemies[eid.Value] = true
                    DamageEnemy:FireServer(eid.Value, dmg, "ranged")
                end
                if m:FindFirstChild("IsBoss") then
                    DamageBoss:FireServer(dmg * 0.6)
                end
            end
        end
        -- Explosion flash
        local exp = Instance.new("Part")
        exp.Size = Vector3.new(5,5,5); exp.Shape = Enum.PartType.Ball
        exp.Color = Color3.fromRGB(255,160,40); exp.Material = Enum.Material.Neon
        exp.Anchored = true; exp.CanCollide = false; exp.CFrame = CFrame.new(endPt)
        exp.Parent = workspace
        TweenService:Create(exp, TweenInfo.new(0.2), {Transparency=1, Size=Vector3.new(1,1,1)}):Play()
        Debris:AddItem(exp, 0.25)
    else
        -- Default single hitscan
        local hit = shootRaycast(origin, dir, range)
        local endPt = hit and hit.Position or (origin + dir * range)
        createTracer(origin, endPt, color)
        if currentWeapon == "sniper" then
            -- Piercing: check further along
            hitEnemy(hit, dmg)
            if hit then
                local hit2 = shootRaycast(hit.Position + dir * 0.5, dir, range - (hit.Position - origin).Magnitude)
                hitEnemy(hit2, dmg * 0.6)
            end
        else
            hitEnemy(hit, dmg)
        end
    end
end

-- ── Melee ──────────────────────────────────────────────────────────────────
local function doMelee()
    local now = tick()
    local cd  = currentWeapon == "sword"
                and (GameConfig.MELEE_COOLDOWN * 0.85)
                or  GameConfig.MELEE_COOLDOWN
    if now - lastMeleeTime < cd then return end
    lastMeleeTime = now

    local range = currentWeapon == "sword"
                  and (GameConfig.MELEE_RANGE * 1.2)
                  or  GameConfig.MELEE_RANGE
    local dmg   = (currentWeapon == "sword" and 55 or GameConfig.MELEE_DAMAGE) * damageMult

    local look   = rootPart.CFrame.LookVector
    local center = rootPart.Position + look * range * 0.5
    createSlashEffect(rootPart.Position, look, range)

    local params = OverlapParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hits = workspace:GetPartBoundsInRadius(center, range * 0.65, params)

    local hitEnemies = {}
    for _, p in ipairs(hits) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m then
            local eid = m:FindFirstChild("EnemyId")
            if eid and not hitEnemies[eid.Value] then
                hitEnemies[eid.Value] = true
                DamageEnemy:FireServer(eid.Value, dmg, "melee")
            end
            if m:FindFirstChild("IsBoss") then
                DamageBoss:FireServer(dmg)
            end
        end
    end
end

-- ── Input ──────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.G then
        doGravitySwitch()

    elseif input.KeyCode == Enum.KeyCode.E
        or input.KeyCode == Enum.KeyCode.F then
        doMelee()

    elseif input.KeyCode == Enum.KeyCode.Space then
        -- Double jump
        local state = humanoid:GetState()
        if (state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.Jumping)
           and canDoubleJump and not hasDoubleJumped then
            hasDoubleJumped = true
            local upDir = -gravDir
            local bv = Instance.new("BodyVelocity")
            bv.Velocity   = upDir * GameConfig.BASE_JUMP_POWER
            bv.MaxForce   = Vector3.new(1e6, 1e6, 1e6)
            bv.Parent     = rootPart
            Debris:AddItem(bv, 0.15)
        end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if currentWeapon == "sword" then
            doMelee()
        else
            doShoot()
        end
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        doMelee()
    end
end)

-- Auto-fire for rapid weapons
RunService.Heartbeat:Connect(function()
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local autoFire = currentWeapon == "blaster"
                      or currentWeapon == "flamethrower"
        if autoFire then doShoot() end
    end
end)

-- Reset double jump on landing
humanoid.StateChanged:Connect(function(_, new)
    if new == Enum.HumanoidStateType.Landed then
        hasDoubleJumped = false
    end
end)

-- ── Gravity force loop ─────────────────────────────────────────────────────
-- Re-apply every second (mass rarely changes, but accessories can add mass)
local massTimer = 0
RunService.Heartbeat:Connect(function(dt)
    massTimer = massTimer + dt
    if massTimer >= 1 then
        massTimer = 0
        applyGravForce()
    end
end)

-- Initialize
applyGravForce()
updateOrientation()

print("[CharacterController] Loaded for", player.Name)
