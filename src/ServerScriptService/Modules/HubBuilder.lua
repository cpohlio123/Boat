-- HubBuilder.lua (ModuleScript)
-- Builds the lobby hub area with vendors, customization, and run portal.

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local HubBuilder = {}

local HUB_ORIGIN = Vector3.new(0, 0, -150)

local function makePart(size, color, material, parent)
    local p = Instance.new("Part")
    p.Size     = size; p.Color    = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = true; p.CastShadow = false
    p.Parent   = parent
    return p
end

local function makeLabel(parent, size, offset, text, color, fontSize)
    local bill = Instance.new("BillboardGui")
    bill.Size = size; bill.StudsOffset = offset
    bill.AlwaysOnTop = false; bill.Parent = parent
    local lbl = Instance.new("TextLabel", bill)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = fontSize or 18
    lbl.TextStrokeColor3 = Color3.new(0,0,0); lbl.TextStrokeTransparency = 0.3
    return bill, lbl
end

function HubBuilder.build(parent)
    local folder = Instance.new("Folder")
    folder.Name = "Hub"; folder.Parent = parent

    local ox, oy, oz = HUB_ORIGIN.X, HUB_ORIGIN.Y, HUB_ORIGIN.Z

    -- ── Main floor ───────────────────────────────────────────────────────────
    local floor = makePart(Vector3.new(100, 3, 100), Color3.fromRGB(22, 25, 42),
        Enum.Material.SmoothPlastic, folder)
    floor.CFrame = CFrame.new(ox, oy - 1.5, oz); floor.Name = "HubFloor"

    -- Accent border strips
    for _, off in ipairs({-50, 50}) do
        local s = makePart(Vector3.new(2, 0.5, 100), Color3.fromRGB(60,140,255), Enum.Material.Neon, folder)
        s.CFrame = CFrame.new(ox + off, oy + 0.25, oz); s.CanCollide = false
    end
    for _, off in ipairs({-50, 50}) do
        local s = makePart(Vector3.new(100, 0.5, 2), Color3.fromRGB(60,140,255), Enum.Material.Neon, folder)
        s.CFrame = CFrame.new(ox, oy + 0.25, oz + off); s.CanCollide = false
    end

    -- Floor grid lines (subtle)
    for g = -40, 40, 10 do
        local lineX = makePart(Vector3.new(0.15, 0.1, 100), Color3.fromRGB(40,50,80), Enum.Material.Neon, folder)
        lineX.CFrame = CFrame.new(ox + g, oy + 0.05, oz); lineX.CanCollide = false; lineX.Transparency = 0.6
        local lineZ = makePart(Vector3.new(100, 0.1, 0.15), Color3.fromRGB(40,50,80), Enum.Material.Neon, folder)
        lineZ.CFrame = CFrame.new(ox, oy + 0.05, oz + g); lineZ.CanCollide = false; lineZ.Transparency = 0.6
    end

    -- Invisible walls (keep players inside)
    for _, wall in ipairs({
        { size = Vector3.new(1, 20, 100), pos = Vector3.new(ox - 51, oy + 10, oz) },
        { size = Vector3.new(1, 20, 100), pos = Vector3.new(ox + 51, oy + 10, oz) },
        { size = Vector3.new(100, 20, 1), pos = Vector3.new(ox, oy + 10, oz - 51) },
        { size = Vector3.new(100, 20, 1), pos = Vector3.new(ox, oy + 10, oz + 51) },
    }) do
        local w = makePart(wall.size, Color3.new(0,0,0), Enum.Material.SmoothPlastic, folder)
        w.CFrame = CFrame.new(wall.pos); w.Transparency = 1
    end

    -- ── Central Portal ───────────────────────────────────────────────────────
    local portalBase = makePart(Vector3.new(14, 1.5, 14), Color3.fromRGB(12, 8, 35),
        Enum.Material.SmoothPlastic, folder)
    portalBase.CFrame = CFrame.new(ox, oy + 0.75, oz)

    -- Inner glow ring
    local innerRing = makePart(Vector3.new(10, 0.3, 10), Color3.fromRGB(120, 70, 255),
        Enum.Material.Neon, folder)
    innerRing.CFrame = CFrame.new(ox, oy + 1.65, oz); innerRing.CanCollide = false
    TweenService:Create(innerRing,
        TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Color = Color3.fromRGB(200, 140, 255), Transparency = 0.5 }
    ):Play()

    -- Portal arch (two pillars + top beam)
    for _, sx in ipairs({ -5, 5 }) do
        local pillar = makePart(Vector3.new(2, 14, 2), Color3.fromRGB(30, 25, 60),
            Enum.Material.SmoothPlastic, folder)
        pillar.CFrame = CFrame.new(ox + sx, oy + 7, oz)
        -- Neon edge strip
        local edge = makePart(Vector3.new(0.3, 14, 0.3), Color3.fromRGB(120, 80, 255),
            Enum.Material.Neon, folder)
        edge.CFrame = CFrame.new(ox + sx + (sx > 0 and -1.1 or 1.1), oy + 7, oz - 1.1)
        edge.CanCollide = false
    end
    local topBeam = makePart(Vector3.new(12, 2, 2), Color3.fromRGB(30, 25, 60),
        Enum.Material.SmoothPlastic, folder)
    topBeam.CFrame = CFrame.new(ox, oy + 15, oz)
    local topGlow = makePart(Vector3.new(10, 0.5, 0.5), Color3.fromRGB(120, 80, 255),
        Enum.Material.Neon, folder)
    topGlow.CFrame = CFrame.new(ox, oy + 14, oz - 1.1); topGlow.CanCollide = false

    -- Portal trigger zone (invisible, touch-triggered)
    local portalTrigger = makePart(Vector3.new(8, 10, 4), Color3.fromRGB(0,0,0),
        Enum.Material.SmoothPlastic, folder)
    portalTrigger.Name = "RunPortal"; portalTrigger.Transparency = 1; portalTrigger.CanCollide = false
    portalTrigger.CFrame = CFrame.new(ox, oy + 5, oz)
    local portalTag = Instance.new("BoolValue"); portalTag.Name = "IsRunPortal"; portalTag.Parent = portalTrigger

    -- Portal light
    local pLight = Instance.new("PointLight", innerRing)
    pLight.Color = Color3.fromRGB(120, 80, 255); pLight.Range = 30; pLight.Brightness = 3

    -- Portal text
    local _, portalLbl = makeLabel(topBeam, UDim2.new(0,280,0,50), Vector3.new(0,3,0),
        "ENTER THE VOID", Color3.fromRGB(200,160,255), 22)

    -- Title above portal
    local _, titleLbl = makeLabel(topBeam, UDim2.new(0,500,0,80), Vector3.new(0,8,0),
        "VOID RUNNER", Color3.fromRGB(100,180,255), 42)

    -- ── Weapons Vendor (left side) ───────────────────────────────────────────
    local vx, vz = ox - 30, oz + 8

    local booth1 = makePart(Vector3.new(14, 0.6, 10), Color3.fromRGB(30, 32, 50),
        Enum.Material.SmoothPlastic, folder)
    booth1.CFrame = CFrame.new(vx, oy + 0.3, vz)

    local counter1 = makePart(Vector3.new(12, 4, 3), Color3.fromRGB(38, 42, 60),
        Enum.Material.SmoothPlastic, folder)
    counter1.CFrame = CFrame.new(vx, oy + 2, vz + 3)

    local counterTop1 = makePart(Vector3.new(13, 0.5, 4), Color3.fromRGB(50, 55, 75),
        Enum.Material.SmoothPlastic, folder)
    counterTop1.CFrame = CFrame.new(vx, oy + 4.25, vz + 3)

    -- NPC
    local npc1B = makePart(Vector3.new(2, 4, 1.5), Color3.fromRGB(70, 120, 210),
        Enum.Material.SmoothPlastic, folder)
    npc1B.CFrame = CFrame.new(vx, oy + 2, vz + 5.5); npc1B.CanCollide = false
    local npc1H = makePart(Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(255, 200, 150),
        Enum.Material.SmoothPlastic, folder)
    npc1H.CFrame = CFrame.new(vx, oy + 4.8, vz + 5.5); npc1H.CanCollide = false

    makeLabel(npc1B, UDim2.new(0,180,0,40), Vector3.new(0,5,0), "WEAPONS",
        Color3.fromRGB(255,200,60), 20)

    -- Weapon display items
    local weapColors = {
        { Color3.fromRGB(255,220,60),  "Blaster" },
        { Color3.fromRGB(255,160,60),  "Shotgun" },
        { Color3.fromRGB(120,220,255), "Sniper"  },
    }
    for i, wc in ipairs(weapColors) do
        local shelf = makePart(Vector3.new(3, 0.3, 2), Color3.fromRGB(30,33,50),
            Enum.Material.SmoothPlastic, folder)
        shelf.CFrame = CFrame.new(vx - 5 + i * 3, oy + 2, vz)
        local gun = makePart(Vector3.new(1.8, 0.4, 0.4), wc[1], Enum.Material.Neon, folder)
        gun.CFrame = CFrame.new(vx - 5 + i * 3, oy + 2.5, vz); gun.CanCollide = false
        makeLabel(shelf, UDim2.new(0,80,0,20), Vector3.new(0,-0.5,0), wc[2],
            Color3.fromRGB(180,190,220), 10)
    end

    -- ── Upgrades Vendor (right side) ─────────────────────────────────────────
    local ux, uz = ox + 30, oz + 8

    local booth2 = makePart(Vector3.new(14, 0.6, 10), Color3.fromRGB(28, 35, 32),
        Enum.Material.SmoothPlastic, folder)
    booth2.CFrame = CFrame.new(ux, oy + 0.3, uz)

    local counter2 = makePart(Vector3.new(12, 4, 3), Color3.fromRGB(35, 48, 40),
        Enum.Material.SmoothPlastic, folder)
    counter2.CFrame = CFrame.new(ux, oy + 2, uz + 3)

    local counterTop2 = makePart(Vector3.new(13, 0.5, 4), Color3.fromRGB(48, 65, 55),
        Enum.Material.SmoothPlastic, folder)
    counterTop2.CFrame = CFrame.new(ux, oy + 4.25, uz + 3)

    -- NPC
    local npc2B = makePart(Vector3.new(2, 4, 1.5), Color3.fromRGB(55, 190, 95),
        Enum.Material.SmoothPlastic, folder)
    npc2B.CFrame = CFrame.new(ux, oy + 2, uz + 5.5); npc2B.CanCollide = false
    local npc2H = makePart(Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(255, 200, 150),
        Enum.Material.SmoothPlastic, folder)
    npc2H.CFrame = CFrame.new(ux, oy + 4.8, uz + 5.5); npc2H.CanCollide = false

    makeLabel(npc2B, UDim2.new(0,180,0,40), Vector3.new(0,5,0), "UPGRADES",
        Color3.fromRGB(80,255,160), 20)

    -- Upgrade orbs on pedestals
    local orbColors = {
        Color3.fromRGB(80,160,255),
        Color3.fromRGB(255,200,60),
        Color3.fromRGB(200,80,255),
    }
    for i, col in ipairs(orbColors) do
        local pedestal = makePart(Vector3.new(2.5, 3, 2.5), Color3.fromRGB(30, 42, 35),
            Enum.Material.SmoothPlastic, folder)
        pedestal.CFrame = CFrame.new(ux - 5 + i * 3, oy + 1.5, uz)
        local orb = Instance.new("Part")
        orb.Size = Vector3.new(1.2, 1.2, 1.2); orb.Shape = Enum.PartType.Ball
        orb.Color = col; orb.Material = Enum.Material.Neon
        orb.Anchored = true; orb.CanCollide = false; orb.CastShadow = false
        orb.CFrame = CFrame.new(ux - 5 + i * 3, oy + 3.6, uz)
        orb.Parent = folder
        -- Slow spin
        local angle = i * 2
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if not orb.Parent then conn:Disconnect(); return end
            angle = angle + dt * 1.5
            orb.CFrame = CFrame.new(orb.Position) * CFrame.Angles(0, angle, 0)
        end)
    end

    -- ── Customization Area (back) ────────────────────────────────────────────
    local cz = oz - 28

    local custFloor = makePart(Vector3.new(20, 1.5, 14), Color3.fromRGB(32, 28, 52),
        Enum.Material.SmoothPlastic, folder)
    custFloor.CFrame = CFrame.new(ox, oy + 0.75, cz)

    local pedestal = makePart(Vector3.new(5, 2, 5), Color3.fromRGB(45, 40, 70),
        Enum.Material.SmoothPlastic, folder)
    pedestal.CFrame = CFrame.new(ox, oy + 2.5, cz)

    -- Neon ring
    local custRing = makePart(Vector3.new(7, 0.3, 7), Color3.fromRGB(180, 100, 255),
        Enum.Material.Neon, folder)
    custRing.CFrame = CFrame.new(ox, oy + 1.65, cz); custRing.CanCollide = false
    TweenService:Create(custRing,
        TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Color = Color3.fromRGB(120, 60, 200), Transparency = 0.4 }
    ):Play()

    -- Mirror frame
    local mirrorFrame = makePart(Vector3.new(8, 10, 1), Color3.fromRGB(40, 35, 65),
        Enum.Material.SmoothPlastic, folder)
    mirrorFrame.CFrame = CFrame.new(ox, oy + 5, cz - 6)
    local mirror = makePart(Vector3.new(6.5, 8.5, 0.3), Color3.fromRGB(80, 120, 200),
        Enum.Material.Glass, folder)
    mirror.CFrame = CFrame.new(ox, oy + 5, cz - 5.6); mirror.Reflectance = 0.6
    mirror.Transparency = 0.3; mirror.CanCollide = false

    makeLabel(pedestal, UDim2.new(0,200,0,40), Vector3.new(0,4,0), "CUSTOMIZE",
        Color3.fromRGB(200,140,255), 20)

    -- ── Info / Controls Board (front) ────────────────────────────────────────
    local iz = oz + 30

    local infoBoard = makePart(Vector3.new(16, 10, 1.5), Color3.fromRGB(18, 20, 35),
        Enum.Material.SmoothPlastic, folder)
    infoBoard.CFrame = CFrame.new(ox, oy + 5, iz)

    local infoBill = Instance.new("BillboardGui")
    infoBill.Size = UDim2.new(0, 320, 0, 220)
    infoBill.StudsOffset = Vector3.new(0, 0, -1)
    infoBill.AlwaysOnTop = false; infoBill.Parent = infoBoard

    local infoTitle = Instance.new("TextLabel", infoBill)
    infoTitle.Size = UDim2.new(1,0,0.15,0); infoTitle.BackgroundTransparency = 1
    infoTitle.Text = "HOW TO PLAY"
    infoTitle.TextColor3 = Color3.fromRGB(100,180,255)
    infoTitle.Font = Enum.Font.GothamBold; infoTitle.TextSize = 22

    local infoBody = Instance.new("TextLabel", infoBill)
    infoBody.Size = UDim2.new(1,-16,0.82,0); infoBody.Position = UDim2.new(0,8,0.18,0)
    infoBody.BackgroundTransparency = 1; infoBody.TextWrapped = true
    infoBody.TextYAlignment = Enum.TextYAlignment.Top
    infoBody.TextXAlignment = Enum.TextXAlignment.Left
    infoBody.Text = "WASD — Move\nSpace — Jump (double-jump unlockable)\nG — Switch Gravity\nShift — Dash\nMouse1 — Shoot\nMouse2 / E / F — Melee\n\n• Clear all enemies to open the exit portal\n• Every 5 levels a boss awaits\n• Collect upgrades between levels\n• Combo kills for score multipliers"
    infoBody.TextColor3 = Color3.fromRGB(160,170,200)
    infoBody.Font = Enum.Font.Gotham; infoBody.TextSize = 12

    -- ── Ambient Lighting ─────────────────────────────────────────────────────
    local lightPositions = {
        Vector3.new(ox - 45, oy + 10, oz - 45),
        Vector3.new(ox + 45, oy + 10, oz - 45),
        Vector3.new(ox - 45, oy + 10, oz + 45),
        Vector3.new(ox + 45, oy + 10, oz + 45),
        Vector3.new(ox, oy + 15, oz),
    }
    for _, lpos in ipairs(lightPositions) do
        local lamp = makePart(Vector3.new(1,1,1), Color3.fromRGB(80,160,255), Enum.Material.Neon, folder)
        lamp.Transparency = 0.7; lamp.CFrame = CFrame.new(lpos); lamp.CanCollide = false
        local light = Instance.new("PointLight", lamp)
        light.Color = Color3.fromRGB(80,160,255); light.Range = 50; light.Brightness = 2.5
    end

    -- Corner pillars
    for _, corner in ipairs({
        Vector3.new(ox - 48, oy + 5, oz - 48),
        Vector3.new(ox + 48, oy + 5, oz - 48),
        Vector3.new(ox - 48, oy + 5, oz + 48),
        Vector3.new(ox + 48, oy + 5, oz + 48),
    }) do
        local p = makePart(Vector3.new(3, 10, 3), Color3.fromRGB(30, 33, 55),
            Enum.Material.SmoothPlastic, folder)
        p.CFrame = CFrame.new(corner)
        local glow = makePart(Vector3.new(1, 10, 1), Color3.fromRGB(60, 120, 255),
            Enum.Material.Neon, folder)
        glow.CFrame = CFrame.new(corner + Vector3.new(0, 0, 0))
        glow.CanCollide = false; glow.Transparency = 0.3
    end

    return folder
end

HubBuilder.HUB_ORIGIN = HUB_ORIGIN
HubBuilder.SPAWN_POS  = Vector3.new(0, 3, -170)

return HubBuilder
