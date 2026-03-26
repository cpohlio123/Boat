-- VendorShop.client.lua
-- Vendor shop UI — opens when server fires OpenVendor, lets player spend
-- accumulated score on weapons and upgrades between runs.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events        = ReplicatedStorage:WaitForChild("Events")
local OpenVendor    = Events:WaitForChild("OpenVendor")
local BuyVendorItem = Events:WaitForChild("BuyVendorItem")

local RARITY_COLOR = {
    common   = Color3.fromRGB(180, 180, 190),
    uncommon = Color3.fromRGB(60,  200, 80),
    rare     = Color3.fromRGB(80,  140, 255),
    epic     = Color3.fromRGB(200, 80,  255),
}

local currentGui = nil

local function closeShop()
    if currentGui then
        TweenService:Create(currentGui, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        task.delay(0.28, function()
            if currentGui then currentGui:Destroy(); currentGui = nil end
        end)
    end
end

local function openShop(data)
    if currentGui then currentGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name           = "VendorShop"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder   = 25
    gui.Parent         = playerGui
    currentGui         = gui

    -- Dim overlay
    local overlay = Instance.new("Frame", gui)
    overlay.Size = UDim2.new(1,0,1,0); overlay.BackgroundColor3 = Color3.new(0,0,0)
    overlay.BackgroundTransparency = 0.55; overlay.BorderSizePixel = 0

    -- Close on click outside
    local closeBtn = Instance.new("TextButton", overlay)
    closeBtn.Size = UDim2.new(1,0,1,0); closeBtn.BackgroundTransparency = 1
    closeBtn.Text = ""; closeBtn.ZIndex = 1
    closeBtn.MouseButton1Click:Connect(closeShop)

    -- Main panel
    local panel = Instance.new("Frame", gui)
    panel.Size = UDim2.new(0, 680, 0, 500)
    panel.Position = UDim2.new(0.5, -340, 0.5, -250)
    panel.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0; panel.ZIndex = 2
    local pCorner = Instance.new("UICorner", panel); pCorner.CornerRadius = UDim.new(0, 12)
    local pStroke = Instance.new("UIStroke", panel)
    pStroke.Color = Color3.fromRGB(100, 30, 60); pStroke.Thickness = 2; pStroke.Transparency = 0.2

    -- Header
    local header = Instance.new("Frame", panel)
    header.Size = UDim2.new(1,0,0,52); header.Position = UDim2.new(0,0,0,0)
    header.BackgroundColor3 = Color3.fromRGB(18, 10, 28); header.BorderSizePixel = 0
    local hCorner = Instance.new("UICorner", header); hCorner.CornerRadius = UDim.new(0,12)

    local typeLabel = data.vendorType == "weapon" and "ARMS DEALER" or "VOID ORACLE"
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(0.7,0,1,0); title.Position = UDim2.new(0,16,0,0)
    title.BackgroundTransparency = 1; title.Text = typeLabel
    title.Font = Enum.Font.GothamBold; title.TextSize = 22
    title.TextColor3 = Color3.fromRGB(220, 80, 120); title.TextXAlignment = Enum.TextXAlignment.Left

    local scoreLabel = Instance.new("TextLabel", header)
    scoreLabel.Name = "ScoreLabel"
    scoreLabel.Size = UDim2.new(0.3,-16,1,0); scoreLabel.Position = UDim2.new(0.7,0,0,0)
    scoreLabel.BackgroundTransparency = 1
    scoreLabel.Text = "⬡ " .. (data.score or 0) .. " SCORE"
    scoreLabel.Font = Enum.Font.GothamBold; scoreLabel.TextSize = 14
    scoreLabel.TextColor3 = Color3.fromRGB(255, 220, 80); scoreLabel.TextXAlignment = Enum.TextXAlignment.Right

    -- Close X button
    local xBtn = Instance.new("TextButton", panel)
    xBtn.Size = UDim2.new(0,32,0,32); xBtn.Position = UDim2.new(1,-40,0,10)
    xBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 30); xBtn.BorderSizePixel = 0
    xBtn.Text = "✕"; xBtn.Font = Enum.Font.GothamBold; xBtn.TextSize = 16
    xBtn.TextColor3 = Color3.fromRGB(220, 120, 140); xBtn.ZIndex = 5
    local xCorner = Instance.new("UICorner", xBtn); xCorner.CornerRadius = UDim.new(0,6)
    xBtn.MouseButton1Click:Connect(closeShop)

    -- Scroll frame for items
    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Size = UDim2.new(1,-16,1,-68); scroll.Position = UDim2.new(0,8,0,60)
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 40, 80)
    scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.ZIndex = 3

    local layout = Instance.new("UIGridLayout", scroll)
    layout.CellSize = UDim2.new(0, 196, 0, 130)
    layout.CellPadding = UDim2.new(0, 10, 0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local padding = Instance.new("UIPadding", scroll)
    padding.PaddingLeft = UDim.new(0,4); padding.PaddingTop = UDim.new(0,4)

    local function buildCard(item)
        local rCol = RARITY_COLOR[item.rarity] or Color3.fromRGB(180,180,190)

        local card = Instance.new("Frame", scroll)
        card.BackgroundColor3 = Color3.fromRGB(16, 12, 26)
        card.BackgroundTransparency = 0.1; card.BorderSizePixel = 0
        local cCorner = Instance.new("UICorner", card); cCorner.CornerRadius = UDim.new(0,10)
        local cStroke = Instance.new("UIStroke", card)
        cStroke.Color = rCol; cStroke.Thickness = 1.5; cStroke.Transparency = 0.4

        -- Rarity bar
        local bar = Instance.new("Frame", card)
        bar.Size = UDim2.new(1,0,0,3); bar.BackgroundColor3 = rCol; bar.BorderSizePixel = 0
        local bCorner = Instance.new("UICorner", bar); bCorner.CornerRadius = UDim.new(0,10)

        -- Rarity tag
        local rar = Instance.new("TextLabel", card)
        rar.Size = UDim2.new(1,-8,0,16); rar.Position = UDim2.new(0,4,0,5)
        rar.BackgroundTransparency = 1; rar.Text = string.upper(item.rarity or "")
        rar.Font = Enum.Font.GothamBold; rar.TextSize = 10
        rar.TextColor3 = rCol; rar.TextXAlignment = Enum.TextXAlignment.Left

        -- Name
        local nm = Instance.new("TextLabel", card)
        nm.Size = UDim2.new(1,-8,0,22); nm.Position = UDim2.new(0,4,0,20)
        nm.BackgroundTransparency = 1; nm.Text = item.name or ""
        nm.Font = Enum.Font.GothamBold; nm.TextSize = 13; nm.TextWrapped = true
        nm.TextColor3 = Color3.fromRGB(230,220,240); nm.TextXAlignment = Enum.TextXAlignment.Left

        -- Description
        local desc = Instance.new("TextLabel", card)
        desc.Size = UDim2.new(1,-8,0,38); desc.Position = UDim2.new(0,4,0,44)
        desc.BackgroundTransparency = 1; desc.Text = item.desc or ""
        desc.Font = Enum.Font.Gotham; desc.TextSize = 10; desc.TextWrapped = true
        desc.TextColor3 = Color3.fromRGB(150,140,170); desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextYAlignment = Enum.TextYAlignment.Top

        -- Buy button
        local buyBtn = Instance.new("TextButton", card)
        buyBtn.Size = UDim2.new(1,-8,0,24); buyBtn.Position = UDim2.new(0,4,1,-28)
        buyBtn.BackgroundColor3 = rCol; buyBtn.BackgroundTransparency = 0.3
        buyBtn.BorderSizePixel = 0; buyBtn.ZIndex = 4
        buyBtn.Text = "⬡ " .. (item.price or 0); buyBtn.Font = Enum.Font.GothamBold
        buyBtn.TextSize = 12; buyBtn.TextColor3 = Color3.new(1,1,1)
        local bCorner2 = Instance.new("UICorner", buyBtn); bCorner2.CornerRadius = UDim.new(0,6)

        buyBtn.MouseEnter:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
        end)
        buyBtn.MouseLeave:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundTransparency = 0.3 }):Play()
        end)

        buyBtn.MouseButton1Click:Connect(function()
            BuyVendorItem:FireServer(item.id)
        end)

        return card
    end

    for _, item in ipairs(data.items or {}) do
        buildCard(item)
    end

    -- Auto-fit canvas height
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end)

    -- Fade in
    panel.BackgroundTransparency = 1
    overlay.BackgroundTransparency = 1
    TweenService:Create(panel,   TweenInfo.new(0.25), { BackgroundTransparency = 0.05 }):Play()
    TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.55 }):Play()
end

OpenVendor.OnClientEvent:Connect(function(data)
    if data.purchased then
        -- Purchase confirmed — update score label and flash confirmation
        if currentGui then
            local sl = currentGui:FindFirstChild("VendorShop", true)
            -- Just refresh score label
            local label = currentGui:FindFirstChildWhichIsA("TextLabel", true)
            if label and label.Name == "ScoreLabel" then
                label.Text = "⬡ " .. (data.score or 0) .. " SCORE"
            end
        end
        -- Flash HUD
        return
    end
    openShop(data)
end)

print("[VendorShop] Ready.")
