-- HUD.client.lua
-- Builds and updates the in-game heads-up display.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ── Build ScreenGui ────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name          = "GameHUD"
gui.ResetOnSpawn  = false
gui.IgnoreGuiInset = true
gui.Parent        = player:WaitForChild("PlayerGui")

local function makeFrame(name, parent, size, pos, color, transparency)
    local f = Instance.new("Frame")
    f.Name              = name
    f.Size              = size
    f.Position          = pos
    f.BackgroundColor3  = color or Color3.new(0, 0, 0)
    f.BackgroundTransparency = transparency or 0
    f.BorderSizePixel   = 0
    f.Parent            = parent
    return f
end

local function makeLabel(name, parent, size, pos, text, textColor, fontSize)
    local l = Instance.new("TextLabel")
    l.Name              = name
    l.Size              = size
    l.Position          = pos
    l.Text              = text or ""
    l.TextColor3        = textColor or Color3.new(1, 1, 1)
    l.BackgroundTransparency = 1
    l.Font              = Enum.Font.GothamBold
    l.TextSize          = fontSize or 14
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.Parent            = parent
    return l
end

-- ── HP Bar ─────────────────────────────────────────────────────────────────
local hpContainer = makeFrame("HPContainer", gui,
    UDim2.new(0, 260, 0, 24),
    UDim2.new(0, 16, 1, -52),
    Color3.fromRGB(20, 20, 20), 0.3)

Instance.new("UICorner", hpContainer).CornerRadius = UDim.new(0, 6)

local hpBar = makeFrame("HPBar", hpContainer,
    UDim2.new(1, 0, 1, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(60, 220, 60), 0)
Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 6)

local shieldBar = makeFrame("ShieldBar", hpContainer,
    UDim2.new(0, 0, 1, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(80, 160, 255), 0)
Instance.new("UICorner", shieldBar).CornerRadius = UDim.new(0, 6)

local hpLabel = makeLabel("HPLabel", hpContainer,
    UDim2.new(1, 0, 1, 0), UDim2.new(0, 6, 0, 0),
    "100 / 100", Color3.new(1,1,1), 13)
hpLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ── Level / Score ──────────────────────────────────────────────────────────
local infoFrame = makeFrame("InfoFrame", gui,
    UDim2.new(0, 200, 0, 50),
    UDim2.new(0.5, -100, 0, 10),
    Color3.fromRGB(10, 10, 20), 0.45)
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 8)

local levelLabel = makeLabel("LevelLabel", infoFrame,
    UDim2.new(1, 0, 0.5, 0), UDim2.new(0, 0, 0, 0),
    "LEVEL 1", Color3.fromRGB(255, 220, 80), 16)
levelLabel.TextXAlignment = Enum.TextXAlignment.Center

local scoreLabel = makeLabel("ScoreLabel", infoFrame,
    UDim2.new(1, 0, 0.5, 0), UDim2.new(0, 0, 0.5, 0),
    "SCORE: 0", Color3.fromRGB(200, 200, 200), 13)
scoreLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ── Weapon indicator ───────────────────────────────────────────────────────
local weaponFrame = makeFrame("WeaponFrame", gui,
    UDim2.new(0, 160, 0, 40),
    UDim2.new(1, -176, 1, -56),
    Color3.fromRGB(10, 10, 20), 0.45)
Instance.new("UICorner", weaponFrame).CornerRadius = UDim.new(0, 8)

local weaponLabel = makeLabel("WeaponLabel", weaponFrame,
    UDim2.new(1, -8, 0.5, 0), UDim2.new(0, 8, 0, 0),
    "Plasma Blaster", Color3.fromRGB(255, 220, 60), 13)
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left

local weaponSub = makeLabel("WeaponSub", weaponFrame,
    UDim2.new(1, -8, 0.5, 0), UDim2.new(0, 8, 0.5, 0),
    "RANGED", Color3.fromRGB(160, 160, 160), 11)

-- ── Gravity indicator ──────────────────────────────────────────────────────
local gravFrame = makeFrame("GravFrame", gui,
    UDim2.new(0, 100, 0, 70),
    UDim2.new(1, -116, 0.5, -35),
    Color3.fromRGB(10, 10, 20), 0.45)
Instance.new("UICorner", gravFrame).CornerRadius = UDim.new(0, 8)

local gravTitle = makeLabel("GravTitle", gravFrame,
    UDim2.new(1,0,0.35,0), UDim2.new(0,0,0,0),
    "GRAVITY", Color3.fromRGB(140,140,160), 11)
gravTitle.TextXAlignment = Enum.TextXAlignment.Center

-- Direction arrows (N/S/E/W = Up/Down/Left/Right)
local gravArrow = makeLabel("GravArrow", gravFrame,
    UDim2.new(1,0,0.65,0), UDim2.new(0,0,0.35,0),
    "▼ DOWN", Color3.fromRGB(100, 200, 255), 15)
gravArrow.TextXAlignment = Enum.TextXAlignment.Center

-- Cooldown overlay (dims when on cooldown)
local gravCDBar = makeFrame("CooldownBar", gravFrame,
    UDim2.new(1,0,0.08,0), UDim2.new(0,0,0.92,0),
    Color3.fromRGB(100, 200, 255), 0)
gravCDBar.BackgroundTransparency = 1  -- shown as line when cooling down

-- ── Passive icons ──────────────────────────────────────────────────────────
local passiveFrame = makeFrame("Passives", gui,
    UDim2.new(0, 300, 0, 28),
    UDim2.new(0, 16, 1, -80),
    Color3.new(0,0,0), 1)  -- transparent container

local passiveList = Instance.new("UIListLayout", passiveFrame)
passiveList.FillDirection = Enum.FillDirection.Horizontal
passiveList.Padding       = UDim.new(0, 4)

-- ── Damage flash ───────────────────────────────────────────────────────────
local dmgFlash = makeFrame("DamageFlash", gui,
    UDim2.new(1, 0, 1, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(255, 30, 30), 1)
dmgFlash.ZIndex = 10

-- ── Banner (level start / level complete) ─────────────────────────────────
local banner = makeFrame("Banner", gui,
    UDim2.new(0, 500, 0, 70),
    UDim2.new(0.5, -250, 0.3, 0),
    Color3.fromRGB(10, 10, 30), 0.3)
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 10)
banner.Visible = false

local bannerMain = makeLabel("Main", banner,
    UDim2.new(1,0,0.6,0), UDim2.new(0,0,0,0),
    "", Color3.fromRGB(255, 255, 100), 22)
bannerMain.TextXAlignment = Enum.TextXAlignment.Center

local bannerSub = makeLabel("Sub", banner,
    UDim2.new(1,0,0.4,0), UDim2.new(0,0,0.6,0),
    "", Color3.fromRGB(180, 180, 220), 14)
bannerSub.TextXAlignment = Enum.TextXAlignment.Center

local function showBanner(main, sub, duration)
    bannerMain.Text = main
    bannerSub.Text  = sub or ""
    banner.Visible  = true
    banner.Position = UDim2.new(0.5, -250, 0.3, -40)
    banner.BackgroundTransparency = 1
    bannerMain.TextTransparency = 1
    bannerSub.TextTransparency  = 1

    TweenService:Create(banner, TweenInfo.new(0.4), {
        Position = UDim2.new(0.5, -250, 0.3, 0),
        BackgroundTransparency = 0.3,
    }):Play()
    TweenService:Create(bannerMain, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
    TweenService:Create(bannerSub,  TweenInfo.new(0.4), { TextTransparency = 0 }):Play()

    task.delay(duration or 2.5, function()
        TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(bannerMain, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        TweenService:Create(bannerSub,  TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        task.wait(0.45)
        banner.Visible = false
    end)
end

-- ── Weapon name lookup ─────────────────────────────────────────────────────
local weaponNames = {
    blaster          = { name = "Plasma Blaster",    sub = "RANGED" },
    shotgun          = { name = "Scatter Cannon",     sub = "RANGED" },
    sniper           = { name = "Rail Rifle",         sub = "RANGED · PIERCE" },
    sword            = { name = "Plasma Blade",       sub = "MELEE" },
    flamethrower     = { name = "Inferno Torch",      sub = "RANGED · FIRE" },
    grenade_launcher = { name = "Grenade Launcher",   sub = "RANGED · AOE" },
}

local gravNames = {
    [tostring(Vector3.new(0,-1,0))] = "▼ DOWN",
    [tostring(Vector3.new(0, 1,0))] = "▲ UP",
    [tostring(Vector3.new(-1,0,0))] = "◄ LEFT",
    [tostring(Vector3.new( 1,0,0))] = "► RIGHT",
}

-- ── Update functions ───────────────────────────────────────────────────────
local function updateHPBar(hp, maxHp, shield)
    local ratio = math.max(0, hp / maxHp)
    TweenService:Create(hpBar, TweenInfo.new(0.15), {
        Size = UDim2.new(ratio, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(
            math.floor(60 + (220-60) * (1-ratio)),
            math.floor(220 - (220-60) * (1-ratio)),
            60
        ),
    }):Play()

    local shieldRatio = math.min(shield / maxHp, 1)
    shieldBar.Size = UDim2.new(shieldRatio, 0, 1, 0)
    hpLabel.Text   = math.ceil(hp) .. " / " .. maxHp
                     .. (shield > 0 and ("  🛡 " .. math.ceil(shield)) or "")
end

local function updateWeapon(weaponId)
    local w = weaponNames[weaponId] or { name = weaponId, sub = "" }
    weaponLabel.Text = w.name
    weaponSub.Text   = w.sub
end

local function rebuildPassives(passiveList, passives)
    for _, c in ipairs(passiveList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for _, pid in ipairs(passives) do
        local icon = makeFrame(pid, passiveList,
            UDim2.new(0, 24, 0, 24),
            UDim2.new(0, 0, 0, 0),
            Color3.fromRGB(40, 40, 60), 0.2)
        Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 4)
        local lbl = Instance.new("TextLabel", icon)
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.upper(string.sub(pid, 1, 2))
        lbl.TextColor3 = Color3.fromRGB(200, 200, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Center
    end
end

-- ── Event listeners ────────────────────────────────────────────────────────
local Events = ReplicatedStorage:WaitForChild("Events")

Events:WaitForChild("UpdateHUD").OnClientEvent:Connect(function(data)
    if data.hp and data.maxHp then
        updateHPBar(data.hp, data.maxHp, data.shield or 0)
    end
    if data.level then
        levelLabel.Text = "LEVEL " .. data.level
    end
    if data.score then
        scoreLabel.Text = "SCORE: " .. data.score
    end
    if data.weapon then
        updateWeapon(data.weapon)
    end
    if data.passives then
        rebuildPassives(passiveFrame, data.passives)
    end
end)

Events:WaitForChild("PlayerDamaged").OnClientEvent:Connect(function(data)
    if data.isDot then return end  -- no flash for DoT ticks
    dmgFlash.BackgroundTransparency = 0.5
    TweenService:Create(dmgFlash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end)

Events:WaitForChild("LevelStart").OnClientEvent:Connect(function(data)
    if data.zone then
        showBanner("LEVEL " .. (data.level or "?"), data.zone)
    end
    if data.portalOpen then
        showBanner("ALL CLEAR", "Reach the portal →", 2)
    end
end)

Events:WaitForChild("LevelComplete").OnClientEvent:Connect(function(data)
    showBanner("LEVEL COMPLETE", "Score: " .. (data.score or 0))
end)

Events:WaitForChild("BossSpawned").OnClientEvent:Connect(function(data)
    showBanner("⚠ BOSS", data.name .. "\n" .. (data.subtitle or ""), 3)
end)

Events:WaitForChild("BossDefeated").OnClientEvent:Connect(function(data)
    showBanner("BOSS DEFEATED", "Score: " .. (data.score or 0))
end)

Events:WaitForChild("GameOver").OnClientEvent:Connect(function(data)
    showBanner("YOU DIED",
        "Level " .. (data.level or 1) .. "  ·  Score: " .. (data.score or 0),
        5)
end)

-- Gravity arrow update (hook from CharacterController via a BindableEvent would be ideal;
-- for now we poll the grav index via a shared attribute on the character)
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                -- Read gravity direction from the VectorForce if present
                local gf = root:FindFirstChild("CustomGravity")
                if gf then
                    -- Approximate current direction from force
                    local f    = gf.Force
                    local mass = 1  -- approximate
                    -- direction is (Force - upCancel) / GRAVITY_MAG / mass
                    -- Simpler: infer from which component dominates
                    local dirs = {
                        { v = Vector3.new(0,-1,0), n = "▼ DOWN"  },
                        { v = Vector3.new(0, 1,0), n = "▲ UP"    },
                        { v = Vector3.new(-1,0,0), n = "◄ LEFT"  },
                        { v = Vector3.new( 1,0,0), n = "► RIGHT" },
                    }
                    -- Actual direction: total force points in grav direction + cancel
                    -- Force = (0, Grav*m, 0) + gravDir*Grav*m
                    -- When gravDir=(0,-1,0): Force=(0,0,0)
                    -- When gravDir=(0,1,0): Force=(0,2Grav*m,0)
                    -- When gravDir=(-1,0,0): Force=(0,Grav*m,0)+(-Grav*m,0,0)
                    -- Dominant non-cancel axis = gravDir
                    local best, bestDot = dirs[1], -2
                    for _, d in ipairs(dirs) do
                        local dot = f:Dot(d.v)
                        if dot > bestDot then best = d; bestDot = dot end
                    end
                    gravArrow.Text = best.n
                end
            end
        end
    end
end)

print("[HUD] Loaded.")
