-- HUD.client.lua
-- Full in-game heads-up display: HP, shield, gravity cooldown radial,
-- combo counter, boss health bar, heal flash, zone banner.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ── Build root ScreenGui ────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name            = "GameHUD"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.DisplayOrder    = 5
gui.Parent          = player:WaitForChild("PlayerGui")

-- ── Helpers ─────────────────────────────────────────────────────────────────
local function frame(name, parent, size, pos, bg, alpha)
    local f = Instance.new("Frame")
    f.Name = name; f.Size = size; f.Position = pos
    f.BackgroundColor3 = bg or Color3.new(0,0,0)
    f.BackgroundTransparency = alpha or 0; f.BorderSizePixel = 0
    f.Parent = parent; return f
end
local function label(name, parent, size, pos, text, col, sz, align)
    local l = Instance.new("TextLabel")
    l.Name = name; l.Size = size; l.Position = pos; l.Text = text or ""
    l.TextColor3 = col or Color3.new(1,1,1)
    l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
    l.TextSize = sz or 14; l.BorderSizePixel = 0
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Parent = parent; return l
end
local function corner(parent, px)
    local c = Instance.new("UICorner", parent); c.CornerRadius = UDim.new(0, px or 6); return c
end

-- ── HP Bar ──────────────────────────────────────────────────────────────────
local hpContainer = frame("HPBar", gui,
    UDim2.new(0, 280, 0, 22),
    UDim2.new(0, 14, 1, -50),
    Color3.fromRGB(15, 15, 20), 0.35)
corner(hpContainer, 5)

local hpFill = frame("Fill", hpContainer, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.fromRGB(60,220,60), 0)
corner(hpFill, 5)

local shieldFill = frame("Shield", hpContainer, UDim2.new(0,0,1,0), UDim2.new(0,0,0,0),
    Color3.fromRGB(80,160,255), 0)
corner(shieldFill, 5)

local hpText = label("Text", hpContainer,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    "100 / 100", Color3.new(1,1,1), 12, Enum.TextXAlignment.Center)

-- ── Level / Score ────────────────────────────────────────────────────────────
local infoBox = frame("Info", gui,
    UDim2.new(0, 190, 0, 48),
    UDim2.new(0.5, -95, 0, 8),
    Color3.fromRGB(8, 8, 20), 0.45)
corner(infoBox, 8)

local lvlLabel   = label("Level", infoBox, UDim2.new(1,0,0.5,0), UDim2.new(0,0,0,0),
    "LEVEL 1", Color3.fromRGB(255,220,80), 16, Enum.TextXAlignment.Center)
local scoreLabel = label("Score", infoBox, UDim2.new(1,0,0.5,0), UDim2.new(0,0,0.5,0),
    "SCORE: 0", Color3.fromRGB(190,190,210), 12, Enum.TextXAlignment.Center)

-- ── Weapon ───────────────────────────────────────────────────────────────────
local weapBox = frame("Weapon", gui,
    UDim2.new(0, 170, 0, 38),
    UDim2.new(1, -184, 1, -54),
    Color3.fromRGB(8, 8, 20), 0.45)
corner(weapBox, 8)
local weapName = label("Name", weapBox, UDim2.new(1,-8,0.5,0), UDim2.new(0,8,0,0),
    "Plasma Blaster", Color3.fromRGB(255,220,60), 13)
local weapSub  = label("Sub", weapBox, UDim2.new(1,-8,0.5,0), UDim2.new(0,8,0.5,0),
    "RANGED", Color3.fromRGB(150,150,160), 10)

-- ── Gravity indicator + cooldown radial ─────────────────────────────────────
local gravBox = frame("GravBox", gui,
    UDim2.new(0, 110, 0, 80),
    UDim2.new(1, -126, 0.5, -40),
    Color3.fromRGB(8,8,20), 0.45)
corner(gravBox, 8)

label("GTitle", gravBox, UDim2.new(1,0,0.3,0), UDim2.new(0,0,0,0),
    "GRAVITY  [G]", Color3.fromRGB(130,130,150), 10, Enum.TextXAlignment.Center)

local gravDirLabel = label("GDir", gravBox, UDim2.new(1,0,0.4,0), UDim2.new(0,0,0.3,0),
    "▼ DOWN", Color3.fromRGB(100,200,255), 15, Enum.TextXAlignment.Center)

-- Cooldown bar (fills left-to-right as cooldown recharges)
local cdBG = frame("CdBG", gravBox,
    UDim2.new(0.85,0,0.2,0), UDim2.new(0.075,0,0.8,0),
    Color3.fromRGB(30,30,40), 0.3)
corner(cdBG, 3)
local cdFill = frame("CdFill", cdBG,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.fromRGB(100,200,255), 0)
corner(cdFill, 3)

local GRAV_NAMES = {
    [tostring(Vector3.new(0,-1,0))] = "▼ DOWN",
    [tostring(Vector3.new(0, 1,0))] = "▲ UP",
    [tostring(Vector3.new(-1,0,0))] = "◄ LEFT",
    [tostring(Vector3.new( 1,0,0))] = "► RIGHT",
}

-- Update cooldown bar every frame
RunService.RenderStepped:Connect(function()
    local last = player:GetAttribute("LastGravSwitch") or 0
    local cd   = player:GetAttribute("GravCooldown")   or 1.5
    local prog = math.min(1, (tick() - last) / cd)
    cdFill.Size = UDim2.new(prog, 0, 1, 0)
    cdFill.BackgroundColor3 = prog >= 1
        and Color3.fromRGB(100, 200, 255)
        or  Color3.fromRGB(60, 80, 140)

    -- Infer current gravity from VectorForce on character
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local gf = root:FindFirstChild("CustomGravity")
            if gf then
                local dirs = {
                    { v = Vector3.new(0,-1,0), n = "▼ DOWN"  },
                    { v = Vector3.new(0, 1,0), n = "▲ UP"    },
                    { v = Vector3.new(-1,0,0), n = "◄ LEFT"  },
                    { v = Vector3.new( 1,0,0), n = "► RIGHT" },
                }
                local best, bestDot = dirs[1], -2
                for _, d in ipairs(dirs) do
                    local dot = gf.Force:Dot(d.v)
                    if dot > bestDot then best = d; bestDot = dot end
                end
                gravDirLabel.Text = best.n
            end
        end
    end
end)

-- ── Level progress bar ───────────────────────────────────────────────────────
local progressBG = frame("ProgressBG", gui,
    UDim2.new(0, 280, 0, 8),
    UDim2.new(0, 14, 1, -60),
    Color3.fromRGB(20, 20, 35), 0.3)
corner(progressBG, 4)

local progressFill = frame("Fill", progressBG, UDim2.new(0, 0, 1, 0), UDim2.new(0,0,0,0),
    Color3.fromRGB(100, 200, 255), 0)
corner(progressFill, 4)

local progressLabel = label("ProgressLbl", gui,
    UDim2.new(0, 280, 0, 14),
    UDim2.new(0, 14, 1, -73),
    "Progress", Color3.fromRGB(130, 130, 160), 10)

local _levelSections = 30
local _sectionDepth  = 10
local _levelStartZ   = 0

-- ── Dash cooldown indicator ───────────────────────────────────────────────────
local dashBox = frame("DashBox", gui,
    UDim2.new(0, 110, 0, 46),
    UDim2.new(1, -126, 0.5, 42),
    Color3.fromRGB(8,8,20), 0.45)
corner(dashBox, 8)

label("DTitle", dashBox, UDim2.new(1,0,0.35,0), UDim2.new(0,0,0,0),
    "DASH  [Shift]", Color3.fromRGB(130,130,150), 10, Enum.TextXAlignment.Center)

local dashCdBG = frame("DashCdBG", dashBox,
    UDim2.new(0.85,0,0.28,0), UDim2.new(0.075,0,0.65,0),
    Color3.fromRGB(30,30,40), 0.3)
corner(dashCdBG, 3)
local dashCdFill = frame("DashCdFill", dashCdBG,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.fromRGB(120,180,255), 0)
corner(dashCdFill, 3)

-- Poll dash cooldown
RunService.RenderStepped:Connect(function()
    local last = player:GetAttribute("LastDash")    or 0
    local cd   = player:GetAttribute("DashCooldown") or 1.4
    local prog = math.min(1, (tick() - last) / cd)
    dashCdFill.Size = UDim2.new(prog, 0, 1, 0)
    dashCdFill.BackgroundColor3 = prog >= 1
        and Color3.fromRGB(120, 180, 255)
        or  Color3.fromRGB(50, 70, 140)

    -- Progress bar: poll character Z position
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local zTravel = math.max(0, root.Position.Z - _levelStartZ)
            local total   = _levelSections * _sectionDepth
            local pct     = math.min(1, zTravel / total)
            progressFill.Size = UDim2.new(pct, 0, 1, 0)
            progressLabel.Text = "Progress: " .. math.floor(pct * 100) .. "%"
        end
    end
end)

-- ── Kill feed ─────────────────────────────────────────────────────────────────
local killFeedFrame = frame("KillFeed", gui,
    UDim2.new(0, 220, 0, 200),
    UDim2.new(1, -234, 0, 120),
    Color3.new(0,0,0), 1)

local killFeedLayout = Instance.new("UIListLayout", killFeedFrame)
killFeedLayout.FillDirection    = Enum.FillDirection.Vertical
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.Padding          = UDim.new(0, 2)
killFeedLayout.SortOrder        = Enum.SortOrder.LayoutOrder

local killFeedEntries = {}

local function addKillFeedEntry(data)
    local isElite = data.isElite
    local name    = data.name or "Enemy"
    local score   = data.score or 0

    local row = Instance.new("Frame", killFeedFrame)
    row.Size  = UDim2.new(1, 0, 0, 20)
    row.BackgroundColor3 = Color3.fromRGB(8, 8, 20)
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    corner(row, 4)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -4, 1, 0)
    lbl.Position = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = (isElite and "★ " or "✦ ") .. name .. "  +" .. score
    lbl.TextColor3 = isElite and Color3.fromRGB(255, 160, 50) or Color3.fromRGB(180, 220, 255)

    -- Fade out after 3 seconds
    table.insert(killFeedEntries, row)
    task.delay(2.8, function()
        TweenService:Create(row, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        task.wait(0.45)
        row:Destroy()
    end)

    -- Cap feed at 6 entries
    if #killFeedEntries > 6 then
        local oldest = table.remove(killFeedEntries, 1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end
end

-- ── Passive icons ────────────────────────────────────────────────────────────
local passivesRow = frame("Passives", gui,
    UDim2.new(0, 300, 0, 26),
    UDim2.new(0, 14, 1, -80),
    Color3.new(0,0,0), 1)
local passiveLayout = Instance.new("UIListLayout", passivesRow)
passiveLayout.FillDirection = Enum.FillDirection.Horizontal
passiveLayout.Padding = UDim.new(0, 3)

-- ── Combo display ────────────────────────────────────────────────────────────
local comboFrame = frame("Combo", gui,
    UDim2.new(0, 200, 0, 50),
    UDim2.new(0.5, -100, 0.62, 0),
    Color3.new(0,0,0), 1)
comboFrame.Visible = false

local comboLabel = label("ComboText", comboFrame,
    UDim2.new(1,0,0.6,0), UDim2.new(0,0,0,0),
    "×5 COMBO", Color3.fromRGB(255,200,40), 28, Enum.TextXAlignment.Center)

local multLabel = label("MultText", comboFrame,
    UDim2.new(1,0,0.4,0), UDim2.new(0,0,0.6,0),
    "2.0× SCORE", Color3.fromRGB(255,160,60), 13, Enum.TextXAlignment.Center)

-- ── Boss HP bar ──────────────────────────────────────────────────────────────
local bossPanel = frame("BossPanel", gui,
    UDim2.new(0, 500, 0, 50),
    UDim2.new(0.5, -250, 0, 10),
    Color3.fromRGB(8,8,20), 0.4)
corner(bossPanel, 8)
bossPanel.Visible = false

local bossNameLabel = label("BossName", bossPanel,
    UDim2.new(1,0,0.45,0), UDim2.new(0,0,0,0),
    "BOSS", Color3.fromRGB(255,80,80), 14, Enum.TextXAlignment.Center)

local bossBarBG = frame("BarBG", bossPanel,
    UDim2.new(0.92,0,0.35,0), UDim2.new(0.04,0,0.55,0),
    Color3.fromRGB(30,10,10), 0.2)
corner(bossBarBG, 4)

local bossBar = frame("Bar", bossBarBG,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.fromRGB(220,40,40), 0)
corner(bossBar, 4)

local bossHPLabel = label("HPNum", bossBarBG,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    "", Color3.new(1,1,1), 11, Enum.TextXAlignment.Center)

-- ── Damage flash overlay ─────────────────────────────────────────────────────
local dmgFlash = frame("DamageFlash", gui,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.fromRGB(255,30,30), 1)
dmgFlash.ZIndex = 18

-- ── Heal flash overlay ───────────────────────────────────────────────────────
local healFlash = frame("HealFlash", gui,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.fromRGB(60,255,120), 1)
healFlash.ZIndex = 17

-- ── Banner (level start / zone name) ─────────────────────────────────────────
local banner = frame("Banner", gui,
    UDim2.new(0, 520, 0, 68),
    UDim2.new(0.5,-260, 0.28, 0),
    Color3.fromRGB(8,8,28), 0.3)
corner(banner, 10)
banner.Visible = false

local bannerMain = label("Main", banner, UDim2.new(1,0,0.6,0), UDim2.new(0,0,0,0),
    "", Color3.fromRGB(255,255,100), 24, Enum.TextXAlignment.Center)
local bannerSub  = label("Sub", banner, UDim2.new(1,0,0.4,0), UDim2.new(0,0,0.6,0),
    "", Color3.fromRGB(180,180,220), 14, Enum.TextXAlignment.Center)

local function showBanner(main, sub, duration)
    bannerMain.Text = main; bannerSub.Text = sub or ""
    banner.Visible = true
    banner.BackgroundTransparency = 1; bannerMain.TextTransparency = 1; bannerSub.TextTransparency = 1
    TweenService:Create(banner, TweenInfo.new(0.35), { BackgroundTransparency = 0.3 }):Play()
    TweenService:Create(bannerMain, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
    TweenService:Create(bannerSub,  TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
    task.delay(duration or 2.5, function()
        TweenService:Create(banner, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(bannerMain, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
        TweenService:Create(bannerSub,  TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
        task.wait(0.4); banner.Visible = false
    end)
end

-- ── Weapon name table ────────────────────────────────────────────────────────
local WEAPON_NAMES = {
    blaster          = { n = "Plasma Blaster",  s = "RANGED" },
    shotgun          = { n = "Scatter Cannon",  s = "RANGED" },
    sniper           = { n = "Rail Rifle",       s = "RANGED · PIERCE" },
    sword            = { n = "Plasma Blade",     s = "MELEE" },
    flamethrower     = { n = "Inferno Torch",    s = "RANGED · FIRE" },
    grenade_launcher = { n = "Grenade Launcher", s = "RANGED · AOE" },
}

-- ── Update functions ─────────────────────────────────────────────────────────
local function updateHP(hp, maxHp, shield)
    local ratio = math.max(0, hp / maxHp)
    TweenService:Create(hpFill, TweenInfo.new(0.14), {
        Size = UDim2.new(ratio, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(
            math.floor(60  + (220-60)  * (1-ratio)),
            math.floor(220 - (220-60) * (1-ratio)), 60),
    }):Play()
    local shRatio = math.min((shield or 0) / maxHp, 1)
    shieldFill.Size = UDim2.new(shRatio, 0, 1, 0)
    hpText.Text = math.ceil(hp) .. " / " .. maxHp
                  .. (shield > 0 and (" · ⬡" .. math.ceil(shield)) or "")
end

local function rebuildPassives(passives)
    for _, c in ipairs(passivesRow:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for _, pid in ipairs(passives) do
        local ic = Instance.new("Frame", passivesRow)
        ic.Name = pid; ic.Size = UDim2.new(0,24,0,24)
        ic.BackgroundColor3 = Color3.fromRGB(30,30,55)
        ic.BackgroundTransparency = 0.25; ic.BorderSizePixel = 0
        corner(ic, 4)
        local l2 = Instance.new("TextLabel", ic)
        l2.Size = UDim2.new(1,0,1,0); l2.BackgroundTransparency = 1
        l2.Text = string.upper(string.sub(pid,1,2))
        l2.TextColor3 = Color3.fromRGB(180,200,255)
        l2.Font = Enum.Font.GothamBold; l2.TextSize = 9
        l2.TextXAlignment = Enum.TextXAlignment.Center
    end
end

-- ── Event wiring ─────────────────────────────────────────────────────────────
local Events = ReplicatedStorage:WaitForChild("Events")

Events:WaitForChild("UpdateHUD").OnClientEvent:Connect(function(d)
    if d.hp and d.maxHp then updateHP(d.hp, d.maxHp, d.shield or 0) end
    if d.level then lvlLabel.Text = "LEVEL " .. d.level end
    if d.score then scoreLabel.Text = "SCORE: " .. d.score end
    if d.weapon then
        local w = WEAPON_NAMES[d.weapon] or { n = d.weapon, s = "" }
        weapName.Text = w.n; weapSub.Text = w.s
    end
    if d.passives then rebuildPassives(d.passives) end
end)

Events:WaitForChild("PlayerDamaged").OnClientEvent:Connect(function(d)
    if d.isDot then return end
    dmgFlash.BackgroundTransparency = 0.5
    TweenService:Create(dmgFlash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end)

Events:WaitForChild("HealPickup").OnClientEvent:Connect(function(d)
    if d.hp and d.maxHp then updateHP(d.hp, d.maxHp, 0) end
    healFlash.BackgroundTransparency = 0.65
    TweenService:Create(healFlash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
    showBanner("+" .. (d.amount or 20) .. " HP", "", 1.2)
end)

Events:WaitForChild("ComboUpdate").OnClientEvent:Connect(function(d)
    if (d.combo or 0) <= 1 then
        TweenService:Create(comboFrame, TweenInfo.new(0.2), {}):Play()
        comboFrame.Visible = false
    else
        comboFrame.Visible = true
        comboLabel.Text = "×" .. d.combo .. " COMBO"
        multLabel.Text  = string.format("%.1f× SCORE", d.mult or 1)
        -- Pop animation
        TweenService:Create(comboLabel, TweenInfo.new(0.08), { TextSize = 32 }):Play()
        task.delay(0.09, function()
            TweenService:Create(comboLabel, TweenInfo.new(0.15), { TextSize = 28 }):Play()
        end)
        -- Color by tier
        local col = d.mult >= 3 and Color3.fromRGB(255,80,80)
                 or d.mult >= 2 and Color3.fromRGB(255,160,40)
                 or Color3.fromRGB(255,200,40)
        comboLabel.TextColor3 = col
        multLabel.TextColor3  = col
    end
end)

Events:WaitForChild("LevelStart").OnClientEvent:Connect(function(d)
    if d.zone then showBanner("LEVEL " .. (d.level or "?"), d.zone) end
    if d.portalOpen then showBanner("ALL CLEAR", "Reach the portal!", 2) end
    -- Reset progress bar origin
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then _levelStartZ = root.Position.Z end
    end
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    if d.sections then _levelSections = d.sections end
end)

Events:WaitForChild("KillFeed").OnClientEvent:Connect(function(d)
    addKillFeedEntry(d)
end)

Events:WaitForChild("LevelComplete").OnClientEvent:Connect(function(d)
    showBanner("LEVEL COMPLETE", "Score: " .. (d.score or 0))
end)

Events:WaitForChild("BossSpawned").OnClientEvent:Connect(function(d)
    bossNameLabel.Text = (d.name or "BOSS")
    bossBar.Size = UDim2.new(1, 0, 1, 0)
    bossHPLabel.Text = ""
    bossPanel.Visible = true
    showBanner("⚠ BOSS", (d.name or "") .. "\n" .. (d.subtitle or ""), 3)
end)

Events:WaitForChild("BossHPUpdate").OnClientEvent:Connect(function(d)
    local ratio = math.max(0, d.ratio or 0)
    TweenService:Create(bossBar, TweenInfo.new(0.15), {
        Size = UDim2.new(ratio, 0, 1, 0),
        BackgroundColor3 = ratio > 0.5 and Color3.fromRGB(220,40,40)
                        or ratio > 0.25 and Color3.fromRGB(255,120,20)
                        or Color3.fromRGB(255,220,20),
    }):Play()
    if d.hp then
        bossHPLabel.Text = math.ceil(d.hp) .. " / " .. (d.maxHp or 0)
    end
end)

Events:WaitForChild("BossPhaseWarning").OnClientEvent:Connect(function(d)
    showBanner("PHASE " .. (d.phase or 2) .. "!", "Boss enraged!", 2)
    -- Red flash
    dmgFlash.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    dmgFlash.BackgroundTransparency = 0.3
    TweenService:Create(dmgFlash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
    task.delay(0.7, function() dmgFlash.BackgroundColor3 = Color3.fromRGB(255,30,30) end)
end)

Events:WaitForChild("BossDefeated").OnClientEvent:Connect(function(d)
    bossPanel.Visible = false
    showBanner("BOSS DEFEATED!", "Score: " .. (d.score or 0))
end)

Events:WaitForChild("GameOver").OnClientEvent:Connect(function()
    bossPanel.Visible  = false
    comboFrame.Visible = false
end)

print("[HUD] Loaded.")
