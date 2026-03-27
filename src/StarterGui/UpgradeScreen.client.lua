-- UpgradeScreen.client.lua
-- Shows 3 upgrade cards after each level. Player clicks one to continue.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name           = "UpgradeScreen"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Enabled        = false
gui.Parent         = player:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame", gui)
overlay.Size                 = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3     = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel      = 0

local title = Instance.new("TextLabel", gui)
title.Size              = UDim2.new(0, 500, 0, 50)
title.Position          = UDim2.new(0.5, -250, 0.08, 0)
title.BackgroundTransparency = 1
title.Text              = "CHOOSE AN UPGRADE"
title.TextColor3        = Color3.fromRGB(255, 220, 80)
title.Font              = Enum.Font.GothamBold
title.TextSize          = 28
title.TextXAlignment    = Enum.TextXAlignment.Center

local subtitle = Instance.new("TextLabel", gui)
subtitle.Size           = UDim2.new(0, 500, 0, 30)
subtitle.Position       = UDim2.new(0.5, -250, 0.16, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text           = ""
subtitle.TextColor3     = Color3.fromRGB(160, 160, 200)
subtitle.Font           = Enum.Font.Gotham
subtitle.TextSize       = 16
subtitle.TextXAlignment = Enum.TextXAlignment.Center

local cardsFrame = Instance.new("Frame", gui)
cardsFrame.Size             = UDim2.new(0, 860, 0, 300)
cardsFrame.Position         = UDim2.new(0.5, -430, 0.5, -150)
cardsFrame.BackgroundTransparency = 1

local cardLayout = Instance.new("UIListLayout", cardsFrame)
cardLayout.FillDirection  = Enum.FillDirection.Horizontal
cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
cardLayout.Padding        = UDim.new(0, 20)

local rarityColors = {
    common   = Color3.fromRGB(160, 160, 160),
    uncommon = Color3.fromRGB(80, 200, 120),
    rare     = Color3.fromRGB(100, 140, 255),
    epic     = Color3.fromRGB(200, 80, 255),
}
local rarityGlow = {
    common   = Color3.fromRGB(40, 40, 50),
    uncommon = Color3.fromRGB(20, 60, 30),
    rare     = Color3.fromRGB(20, 30, 80),
    epic     = Color3.fromRGB(60, 10, 80),
}
local typeIcons = {
    weapon     = "sword",
    passive    = "shield",
    consumable = "heart",
}

local Events         = ReplicatedStorage:WaitForChild("Events")
local ShowUpgrades   = Events:WaitForChild("ShowUpgrades")
local SelectUpgrade  = Events:WaitForChild("SelectUpgrade")

local function makeCard(upgrade, index)
    local rarity = upgrade.rarity or "common"
    local cardBG = Instance.new("Frame", cardsFrame)
    cardBG.Name             = "Card_" .. index
    cardBG.Size             = UDim2.new(0, 260, 0, 290)
    cardBG.BackgroundColor3 = rarityGlow[rarity] or Color3.fromRGB(20, 20, 30)
    cardBG.BorderSizePixel  = 0
    Instance.new("UICorner", cardBG).CornerRadius = UDim.new(0, 12)

    local border = Instance.new("UIStroke", cardBG)
    border.Color     = rarityColors[rarity] or Color3.fromRGB(100, 100, 100)
    border.Thickness = 2

    local iconLabel = Instance.new("TextLabel", cardBG)
    iconLabel.Size              = UDim2.new(1, 0, 0, 40)
    iconLabel.Position          = UDim2.new(0, 0, 0, 14)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text              = typeIcons[upgrade.type] or "?"
    iconLabel.TextColor3        = rarityColors[rarity]
    iconLabel.Font              = Enum.Font.GothamBold
    iconLabel.TextSize          = 28
    iconLabel.TextXAlignment    = Enum.TextXAlignment.Center

    local nameLabel = Instance.new("TextLabel", cardBG)
    nameLabel.Size              = UDim2.new(1, -16, 0, 32)
    nameLabel.Position          = UDim2.new(0, 8, 0, 60)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text              = upgrade.name
    nameLabel.TextColor3        = Color3.new(1, 1, 1)
    nameLabel.Font              = Enum.Font.GothamBold
    nameLabel.TextSize          = 16
    nameLabel.TextWrapped       = true
    nameLabel.TextXAlignment    = Enum.TextXAlignment.Center

    local rarityLabel = Instance.new("TextLabel", cardBG)
    rarityLabel.Size            = UDim2.new(1, 0, 0, 18)
    rarityLabel.Position        = UDim2.new(0, 0, 0, 96)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text            = string.upper(rarity) .. " · " .. string.upper(upgrade.type or "")
    rarityLabel.TextColor3      = rarityColors[rarity]
    rarityLabel.Font            = Enum.Font.Gotham
    rarityLabel.TextSize        = 11
    rarityLabel.TextXAlignment  = Enum.TextXAlignment.Center

    local div = Instance.new("Frame", cardBG)
    div.Size             = UDim2.new(0.8, 0, 0, 1)
    div.Position         = UDim2.new(0.1, 0, 0, 120)
    div.BackgroundColor3 = rarityColors[rarity]
    div.BackgroundTransparency = 0.6
    div.BorderSizePixel  = 0

    local descLabel = Instance.new("TextLabel", cardBG)
    descLabel.Size          = UDim2.new(1, -20, 0, 110)
    descLabel.Position      = UDim2.new(0, 10, 0, 130)
    descLabel.BackgroundTransparency = 1
    descLabel.Text          = upgrade.description or ""
    descLabel.TextColor3    = Color3.fromRGB(200, 200, 210)
    descLabel.Font          = Enum.Font.Gotham
    descLabel.TextSize      = 13
    descLabel.TextWrapped   = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Center
    descLabel.TextYAlignment = Enum.TextYAlignment.Top

    local btn = Instance.new("TextButton", cardBG)
    btn.Name            = "SelectBtn"
    btn.Size            = UDim2.new(0.8, 0, 0, 36)
    btn.Position        = UDim2.new(0.1, 0, 1, -46)
    btn.BackgroundColor3 = rarityColors[rarity]
    btn.Text            = "SELECT"
    btn.TextColor3      = Color3.new(0, 0, 0)
    btn.Font            = Enum.Font.GothamBold
    btn.TextSize        = 14
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseEnter:Connect(function()
        TweenService:Create(cardBG, TweenInfo.new(0.15), {
            BackgroundColor3 = (rarityColors[rarity] or Color3.fromRGB(80,80,100)):Lerp(Color3.new(0,0,0), 0.5),
        }):Play()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            Size = UDim2.new(0.85, 0, 0, 38),
            Position = UDim2.new(0.075, 0, 1, -47),
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(cardBG, TweenInfo.new(0.15), {
            BackgroundColor3 = rarityGlow[rarity] or Color3.fromRGB(20, 20, 30),
        }):Play()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            Size = UDim2.new(0.8, 0, 0, 36),
            Position = UDim2.new(0.1, 0, 1, -46),
        }):Play()
    end)

    return cardBG, btn
end

local function showScreen(upgrades)
    for _, c in ipairs(cardsFrame:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for i, upgrade in ipairs(upgrades) do
        local card, btn = makeCard(upgrade, i)
        card.BackgroundTransparency = 1
        task.delay(i * 0.08, function()
            TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
                BackgroundTransparency = 0,
            }):Play()
        end)
        btn.Activated:Connect(function()
            SelectUpgrade:FireServer(upgrade.id)
            gui.Enabled = false
        end)
    end
    gui.Enabled = true
end

ShowUpgrades.OnClientEvent:Connect(function(upgradeList)
    if upgradeList and #upgradeList > 0 then
        subtitle.Text = "Choose one upgrade to carry into the next level."
        showScreen(upgradeList)
    end
end)

Events:WaitForChild("GameOver").OnClientEvent:Connect(function()
    gui.Enabled = false
end)

print("[UpgradeScreen] Loaded.")