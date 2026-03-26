-- DifficultySelect.client.lua
-- Event-driven difficulty picker. Shown when the server fires ShowDifficultySelect
-- (triggered by touching the hub portal). Reusable across multiple runs.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events              = ReplicatedStorage:WaitForChild("Events")
local SetDifficulty       = Events:WaitForChild("SetDifficulty")
local ShowDifficultySelect = Events:WaitForChild("ShowDifficultySelect")

-- ── Difficulty data ─────────────────────────────────────────────────────────
local DIFFICULTIES = {
    {
        key         = "easy",
        label       = "EASY",
        subtitle    = "Relax and explore",
        color       = Color3.fromRGB(60, 220, 90),
        desc        = { "Enemies have 70% HP & damage", "Forgiving for first-timers" },
    },
    {
        key         = "normal",
        label       = "NORMAL",
        subtitle    = "The intended experience",
        color       = Color3.fromRGB(100, 180, 255),
        desc        = { "Balanced challenge", "Recommended for most players" },
    },
    {
        key         = "hard",
        label       = "HARD",
        subtitle    = "No mercy",
        color       = Color3.fromRGB(255, 80, 60),
        desc        = { "Enemies have 145% HP & damage", "Elite spawn rate increased" },
    },
}

-- ── Build & show the picker ─────────────────────────────────────────────────
local function showPicker()
    -- Destroy any leftover GUI from a previous invocation
    local old = playerGui:FindFirstChild("DifficultySelect")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name           = "DifficultySelect"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder   = 20
    gui.Parent         = playerGui

    -- ── Background ──────────────────────────────────────────────────────────
    local bg = Instance.new("Frame", gui)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(4, 4, 14)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel = 0

    -- Subtle scanline texture
    for i = 0, 40 do
        local line = Instance.new("Frame", bg)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 0, i * 20)
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BackgroundTransparency = 0.94
        line.BorderSizePixel = 0
    end

    -- ── Title ───────────────────────────────────────────────────────────────
    local titleLbl = Instance.new("TextLabel", bg)
    titleLbl.Size = UDim2.new(0, 600, 0, 60)
    titleLbl.Position = UDim2.new(0.5, -300, 0, 80)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "VOID RUNNER"
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 52
    titleLbl.TextColor3 = Color3.fromRGB(100, 180, 255)
    titleLbl.TextStrokeColor3 = Color3.fromRGB(0, 80, 200)
    titleLbl.TextStrokeTransparency = 0.3

    local subLbl = Instance.new("TextLabel", bg)
    subLbl.Size = UDim2.new(0, 600, 0, 28)
    subLbl.Position = UDim2.new(0.5, -300, 0, 140)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = "Select Difficulty"
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextSize = 20
    subLbl.TextColor3 = Color3.fromRGB(160, 160, 200)

    -- ── Card builder ────────────────────────────────────────────────────────
    local cardWidth   = 200
    local cardHeight  = 260
    local cardSpacing = 30
    local totalW = #DIFFICULTIES * cardWidth + (#DIFFICULTIES - 1) * cardSpacing

    local function animateOut()
        TweenService:Create(bg, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        for _, child in ipairs(bg:GetDescendants()) do
            if child:IsA("GuiObject") then
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
                else
                    TweenService:Create(child, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                end
            end
        end
        task.wait(0.45)
        gui:Destroy()
    end

    local function makeCard(diff, index)
        local card = Instance.new("Frame", bg)
        card.Size = UDim2.new(0, cardWidth, 0, cardHeight)
        card.Position = UDim2.new(0.5,
            -totalW/2 + (index - 1) * (cardWidth + cardSpacing),
            0.5, -cardHeight/2)
        card.BackgroundColor3 = Color3.fromRGB(12, 12, 28)
        card.BackgroundTransparency = 0.1
        card.BorderSizePixel = 0

        local corner = Instance.new("UICorner", card)
        corner.CornerRadius = UDim.new(0, 12)

        local stroke = Instance.new("UIStroke", card)
        stroke.Color     = diff.color
        stroke.Thickness = 2
        stroke.Transparency = 0.3

        -- Glow bar at top
        local topBar = Instance.new("Frame", card)
        topBar.Size = UDim2.new(1, 0, 0, 5)
        topBar.Position = UDim2.new(0, 0, 0, 0)
        topBar.BackgroundColor3 = diff.color
        topBar.BackgroundTransparency = 0
        topBar.BorderSizePixel = 0
        Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

        -- Label
        local lbl = Instance.new("TextLabel", card)
        lbl.Size = UDim2.new(1, 0, 0, 44)
        lbl.Position = UDim2.new(0, 0, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.Text = diff.label
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 28
        lbl.TextColor3 = diff.color
        lbl.TextXAlignment = Enum.TextXAlignment.Center

        local sublbl = Instance.new("TextLabel", card)
        sublbl.Size = UDim2.new(1, -16, 0, 22)
        sublbl.Position = UDim2.new(0, 8, 0, 56)
        sublbl.BackgroundTransparency = 1
        sublbl.Text = diff.subtitle
        sublbl.Font = Enum.Font.Gotham
        sublbl.TextSize = 13
        sublbl.TextColor3 = Color3.fromRGB(180, 180, 210)
        sublbl.TextXAlignment = Enum.TextXAlignment.Center
        sublbl.TextWrapped = true

        -- Divider
        local div = Instance.new("Frame", card)
        div.Size = UDim2.new(0.8, 0, 0, 1)
        div.Position = UDim2.new(0.1, 0, 0, 86)
        div.BackgroundColor3 = diff.color
        div.BackgroundTransparency = 0.6
        div.BorderSizePixel = 0

        -- Description lines
        for i, line in ipairs(diff.desc) do
            local dl = Instance.new("TextLabel", card)
            dl.Size = UDim2.new(1, -20, 0, 18)
            dl.Position = UDim2.new(0, 10, 0, 96 + (i - 1) * 22)
            dl.BackgroundTransparency = 1
            dl.Text = "· " .. line
            dl.Font = Enum.Font.Gotham
            dl.TextSize = 11
            dl.TextColor3 = Color3.fromRGB(150, 160, 190)
            dl.TextXAlignment = Enum.TextXAlignment.Left
            dl.TextWrapped = true
        end

        -- Select button
        local btn = Instance.new("TextButton", card)
        btn.Size = UDim2.new(0.75, 0, 0, 38)
        btn.Position = UDim2.new(0.125, 0, 1, -52)
        btn.BackgroundColor3 = diff.color
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Text = "SELECT"
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        -- Hover effect
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {
                BackgroundTransparency = 0,
                Size = UDim2.new(0.82, 0, 0, 40),
                Position = UDim2.new(0.09, 0, 1, -53),
            }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0 }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {
                BackgroundTransparency = 0.2,
                Size = UDim2.new(0.75, 0, 0, 38),
                Position = UDim2.new(0.125, 0, 1, -52),
            }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0.3 }):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            SetDifficulty:FireServer(diff.key)
            animateOut()
        end)

        -- Animate card in staggered
        local targetY = card.Position.Y.Offset
        card.Position = UDim2.new(card.Position.X.Scale, card.Position.X.Offset,
            card.Position.Y.Scale, targetY + 40)
        card.BackgroundTransparency = 1
        task.delay(0.1 + (index - 1) * 0.1, function()
            TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
                Position = UDim2.new(card.Position.X.Scale, card.Position.X.Offset,
                    card.Position.Y.Scale, targetY),
                BackgroundTransparency = 0.1,
            }):Play()
        end)
    end

    for i, d in ipairs(DIFFICULTIES) do
        makeCard(d, i)
    end

    -- Fade in title
    titleLbl.TextTransparency = 1
    subLbl.TextTransparency   = 1
    TweenService:Create(titleLbl, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    task.delay(0.15, function()
        TweenService:Create(subLbl, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    end)
end

-- ── Listen for server event ─────────────────────────────────────────────────
ShowDifficultySelect.OnClientEvent:Connect(showPicker)

print("[DifficultySelect] Ready – waiting for ShowDifficultySelect event.")
