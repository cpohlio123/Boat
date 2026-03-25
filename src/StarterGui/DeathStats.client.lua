-- DeathStats.client.lua
-- Full run-statistics screen shown on death. Fades in, displays stats,
-- then fades out when the player respawns.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ── Build ScreenGui ────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name            = "DeathStats"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.DisplayOrder    = 50
gui.Enabled         = false
gui.Parent          = player:WaitForChild("PlayerGui")

-- Dark overlay
local overlay = Instance.new("Frame", gui)
overlay.Size = UDim2.new(1,0,1,0); overlay.BackgroundColor3 = Color3.new(0,0,0)
overlay.BackgroundTransparency = 0.5; overlay.BorderSizePixel = 0

-- Main panel
local panel = Instance.new("Frame", gui)
panel.Size     = UDim2.new(0, 440, 0, 420)
panel.Position = UDim2.new(0.5, -220, 0.5, -210)
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
local pc = Instance.new("UICorner", panel); pc.CornerRadius = UDim.new(0, 14)

-- Red top border
local topBorder = Instance.new("Frame", panel)
topBorder.Size = UDim2.new(1,0,0,4); topBorder.Position = UDim2.new(0,0,0,0)
topBorder.BackgroundColor3 = Color3.fromRGB(220, 40, 40); topBorder.BorderSizePixel = 0

-- Title
local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1,0,0,60); title.Position = UDim2.new(0,0,0,10)
title.BackgroundTransparency = 1; title.Text = "RUN OVER"
title.TextColor3 = Color3.fromRGB(255, 80, 80)
title.Font = Enum.Font.GothamBold; title.TextSize = 36
title.TextXAlignment = Enum.TextXAlignment.Center

-- Subtitle
local subtitle = Instance.new("TextLabel", panel)
subtitle.Size = UDim2.new(1,0,0,24); subtitle.Position = UDim2.new(0,0,0,62)
subtitle.BackgroundTransparency = 1; subtitle.Text = "Better luck next time, soldier."
subtitle.TextColor3 = Color3.fromRGB(160, 140, 180)
subtitle.Font = Enum.Font.Gotham; subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Center

-- Divider
local div = Instance.new("Frame", panel)
div.Size = UDim2.new(0.85,0,0,1); div.Position = UDim2.new(0.075,0,0,94)
div.BackgroundColor3 = Color3.fromRGB(80,50,100); div.BorderSizePixel = 0

-- Stats container
local statsFrame = Instance.new("Frame", panel)
statsFrame.Size = UDim2.new(1,-40,0,240); statsFrame.Position = UDim2.new(0,20,0,104)
statsFrame.BackgroundTransparency = 1; statsFrame.BorderSizePixel = 0

local statsLayout = Instance.new("UIListLayout", statsFrame)
statsLayout.FillDirection = Enum.FillDirection.Vertical
statsLayout.Padding = UDim.new(0, 4)

-- Stat row builder
local function statRow(parent, statName, value, color)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = Color3.fromRGB(20,16,36)
    row.BackgroundTransparency = 0.4; row.BorderSizePixel = 0
    local rc = Instance.new("UICorner", row); rc.CornerRadius = UDim.new(0,6)

    local nameL = Instance.new("TextLabel", row)
    nameL.Size = UDim2.new(0.55,0,1,0); nameL.Position = UDim2.new(0,10,0,0)
    nameL.BackgroundTransparency = 1; nameL.Text = statName
    nameL.TextColor3 = Color3.fromRGB(180,170,200)
    nameL.Font = Enum.Font.Gotham; nameL.TextSize = 13
    nameL.TextXAlignment = Enum.TextXAlignment.Left

    local valL = Instance.new("TextLabel", row)
    valL.Size = UDim2.new(0.45,-10,1,0); valL.Position = UDim2.new(0.55,0,0,0)
    valL.BackgroundTransparency = 1; valL.Text = tostring(value)
    valL.TextColor3 = color or Color3.fromRGB(255, 220, 80)
    valL.Font = Enum.Font.GothamBold; valL.TextSize = 14
    valL.TextXAlignment = Enum.TextXAlignment.Right

    return row, valL
end

-- Placeholder rows (updated when event fires)
local _, levelVal   = statRow(statsFrame, "LEVEL REACHED",    "—", Color3.fromRGB(255,220,80))
local _, scoreVal   = statRow(statsFrame, "FINAL SCORE",      "—", Color3.fromRGB(255,200,40))
local _, killsVal   = statRow(statsFrame, "ENEMIES KILLED",   "—", Color3.fromRGB(80, 220, 120))
local _, dmgVal     = statRow(statsFrame, "DAMAGE DEALT",     "—", Color3.fromRGB(255,120,60))
local _, timeVal    = statRow(statsFrame, "TIME SURVIVED",    "—", Color3.fromRGB(120,180,255))
local _, weapVal    = statRow(statsFrame, "FINAL WEAPON",     "—", Color3.fromRGB(200,160,255))
local _, passivesVal= statRow(statsFrame, "UPGRADES COLLECTED","—", Color3.fromRGB(160,220,255))

-- Divider 2
local div2 = Instance.new("Frame", panel)
div2.Size = UDim2.new(0.85,0,0,1); div2.Position = UDim2.new(0.075,0,0,360)
div2.BackgroundColor3 = Color3.fromRGB(80,50,100); div2.BorderSizePixel = 0

-- Respawn hint
local hint = Instance.new("TextLabel", panel)
hint.Size = UDim2.new(1,0,0,30); hint.Position = UDim2.new(0,0,0,368)
hint.BackgroundTransparency = 1; hint.Text = "Respawning automatically..."
hint.TextColor3 = Color3.fromRGB(120,120,140)
hint.Font = Enum.Font.Gotham; hint.TextSize = 12
hint.TextXAlignment = Enum.TextXAlignment.Center

-- ── Animate in ─────────────────────────────────────────────────────────────
local function showScreen(data)
    -- Fill stat values
    levelVal.Text    = tostring(data.level or 1)
    scoreVal.Text    = tostring(data.score or 0)
    killsVal.Text    = tostring(data.kills or 0)
    dmgVal.Text      = tostring(data.damageDealt or 0)
    timeVal.Text     = string.format("%d:%02d", math.floor((data.timeAlive or 0)/60), (data.timeAlive or 0) % 60)
    weapVal.Text     = (data.weapon or "blaster"):gsub("_", " "):upper()

    local passiveCount = data.passives and #data.passives or 0
    passivesVal.Text = tostring(passiveCount)

    -- Animate
    panel.Position = UDim2.new(0.5, -220, 0.5, -190)
    gui.Enabled    = true
    overlay.BackgroundTransparency = 1
    panel.BackgroundTransparency   = 1

    -- Fade all children transparent initially
    for _, c in ipairs(panel:GetDescendants()) do
        if c:IsA("TextLabel") then c.TextTransparency = 1 end
        if c:IsA("Frame")     then c.BackgroundTransparency = 1 end
    end
    topBorder.BackgroundTransparency = 0

    TweenService:Create(overlay, TweenInfo.new(0.5), { BackgroundTransparency = 0.5 }):Play()
    TweenService:Create(panel,   TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
        Position = UDim2.new(0.5,-220,0.5,-210),
        BackgroundTransparency = 0.15,
    }):Play()
    task.wait(0.3)
    for _, c in ipairs(panel:GetDescendants()) do
        if c:IsA("TextLabel") then
            TweenService:Create(c, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
        end
        if c:IsA("Frame") and c ~= topBorder then
            TweenService:Create(c, TweenInfo.new(0.4), {
                BackgroundTransparency = c:GetAttribute("OrigAlpha") or 0.4,
            }):Play()
        end
    end
end

-- ── Event wiring ────────────────────────────────────────────────────────────
local Events = ReplicatedStorage:WaitForChild("Events")

Events:WaitForChild("GameOver").OnClientEvent:Connect(function(data)
    showScreen(data or {})
end)

-- Hide when player respawns (new character)
player.CharacterAdded:Connect(function()
    if not gui.Enabled then return end
    TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(panel,   TweenInfo.new(0.4), {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5,-220,0.5,-170),
    }):Play()
    task.wait(0.45)
    gui.Enabled = false
end)

print("[DeathStats] Loaded.")
