-- HubBuilder.lua (ModuleScript)
-- Builds a dark, atmospheric lobby hub with vendors, customization, and run portal.

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
    lbl.TextStrokeColor3 = Color3.new(0,0,0); lbl.TextStrokeTransparency = 0.2
    return bill, lbl
end

function HubBuilder.build(parent)
    local folder = Instance.new("Folder")
    folder.Name = "Hub"; folder.Parent = parent

    local ox, oy, oz = HUB_ORIGIN.X, HUB_ORIGIN.Y, HUB_ORIGIN.Z

    -- ── SpawnLocation (invisible, so players spawn in hub) ──────────────────
    local spawn = Instance.new("SpawnLocation")
    spawn.Size       = Vector3.new(8, 1, 8)
    spawn.CFrame     = CFrame.new(ox, oy + 0.5, oz - 20)
    spawn.Anchored   = true
    spawn.CanCollide = true
    spawn.Transparency = 1
    spawn.Enabled    = true
    spawn.Duration   = 0
    spawn.Name       = "HubSpawn"
    spawn.Parent     = folder

    -- ── Main floor — dark stone ─────────────────────────────────────────────
    local floor = makePart(Vector3.new(120, 4, 120), Color3.fromRGB(12, 10, 18),
        Enum.Material.Slate, folder)
    floor.CFrame = CFrame.new(ox, oy - 2, oz); floor.Name = "HubFloor"

    -- Cracked accent border — deep red glow
    for _, off in ipairs({-60, 60}) do
        local s = makePart(Vector3.new(1.5, 0.4, 120), Color3.fromRGB(120, 20, 30), Enum.Material.Neon, folder)
        s.CFrame = CFrame.new(ox + off, oy + 0.2, oz); s.CanCollide = false
    end
    for _, off in ipairs({-60, 60}) do
        local s = makePart(Vector3.new(120, 0.4, 1.5), Color3.fromRGB(120, 20, 30), Enum.Material.Neon, folder)
        s.CFrame = CFrame.new(ox, oy + 0.2, oz + off); s.CanCollide = false
    end

    -- Floor veins — faint red cracks in the floor
    for g = -50, 50, 12 do
        local vein = makePart(Vector3.new(0.2, 0.08, 120), Color3.fromRGB(80, 15, 25), Enum.Material.Neon, folder)
        vein.CFrame = CFrame.new(ox + g, oy + 0.02, oz); vein.CanCollide = false; vein.Transparency = 0.5
        local vein2 = makePart(Vector3.new(120, 0.08, 0.2), Color3.fromRGB(80, 15, 25), Enum.Material.Neon, folder)
        vein2.CFrame = CFrame.new(ox, oy + 0.02, oz + g); vein2.CanCollide = false; vein2.Transparency = 0.5
    end

    -- ── Fog floor (translucent layer hovering above ground) ─────────────────
    local fog = makePart(Vector3.new(120, 0.5, 120), Color3.fromRGB(20, 10, 30),
        Enum.Material.SmoothPlastic, folder)
    fog.CFrame = CFrame.new(ox, oy + 0.5, oz)
    fog.CanCollide = false; fog.Transparency = 0.75
    TweenService:Create(fog,
        TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.88 }
    ):Play()

    -- ── Invisible boundary walls ────────────────────────────────────────────
    for _, wall in ipairs({
        { size = Vector3.new(1, 30, 120), pos = Vector3.new(ox - 61, oy + 15, oz) },
        { size = Vector3.new(1, 30, 120), pos = Vector3.new(ox + 61, oy + 15, oz) },
        { size = Vector3.new(120, 30, 1), pos = Vector3.new(ox, oy + 15, oz - 61) },
        { size = Vector3.new(120, 30, 1), pos = Vector3.new(ox, oy + 15, oz + 61) },
    }) do
        local w = makePart(wall.size, Color3.new(0,0,0), Enum.Material.SmoothPlastic, folder)
        w.CFrame = CFrame.new(wall.pos); w.Transparency = 1
    end

    -- ── Dark sky ceiling (prevents seeing void above) ───────────────────────
    local ceiling = makePart(Vector3.new(130, 2, 130), Color3.fromRGB(5, 3, 8),
        Enum.Material.SmoothPlastic, folder)
    ceiling.CFrame = CFrame.new(ox, oy + 35, oz); ceiling.Transparency = 0.2; ceiling.CanCollide = false

    -- ── Central Portal — ominous void gate ──────────────────────────────────
    local portalBase = makePart(Vector3.new(16, 2, 16), Color3.fromRGB(8, 4, 14),
        Enum.Material.Slate, folder)
    portalBase.CFrame = CFrame.new(ox, oy + 1, oz)

    -- Runic circle on base
    local runeRing = makePart(Vector3.new(12, 0.15, 12), Color3.fromRGB(140, 30, 60),
        Enum.Material.Neon, folder)
    runeRing.CFrame = CFrame.new(ox, oy + 2.1, oz); runeRing.CanCollide = false
    TweenService:Create(runeRing,
        TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Color = Color3.fromRGB(80, 10, 120), Transparency = 0.5 }
    ):Play()
    -- Slow rotate the rune ring
    local runeAngle = 0
    RunService.Heartbeat:Connect(function(dt)
        if not runeRing.Parent then return end
        runeAngle = runeAngle + dt * 0.4
        runeRing.CFrame = CFrame.new(ox, oy + 2.1, oz) * CFrame.Angles(0, runeAngle, 0)
    end)

    -- Inner void glow
    local innerGlow = makePart(Vector3.new(8, 0.2, 8), Color3.fromRGB(160, 20, 80),
        Enum.Material.Neon, folder)
    innerGlow.CFrame = CFrame.new(ox, oy + 2.15, oz); innerGlow.CanCollide = false
    TweenService:Create(innerGlow,
        TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Color = Color3.fromRGB(200, 50, 255), Transparency = 0.6 }
    ):Play()

    -- Portal arch pillars — jagged dark stone
    for _, sx in ipairs({ -6, 6 }) do
        local pillar = makePart(Vector3.new(3, 18, 3), Color3.fromRGB(14, 10, 22),
            Enum.Material.Slate, folder)
        pillar.CFrame = CFrame.new(ox + sx, oy + 9, oz)

        -- Red vein strips on pillars
        local vein = makePart(Vector3.new(0.2, 18, 0.2), Color3.fromRGB(120, 20, 40),
            Enum.Material.Neon, folder)
        vein.CFrame = CFrame.new(ox + sx + (sx > 0 and -1.3 or 1.3), oy + 9, oz - 1.3)
        vein.CanCollide = false; vein.Transparency = 0.3

        -- Spike caps on pillars
        local spike = makePart(Vector3.new(2, 4, 2), Color3.fromRGB(10, 6, 16),
            Enum.Material.Slate, folder)
        spike.CFrame = CFrame.new(ox + sx, oy + 20, oz)
            * CFrame.Angles(0, 0, math.rad(sx > 0 and -8 or 8))
    end

    -- Top beam — cracked archway
    local topBeam = makePart(Vector3.new(15, 3, 3), Color3.fromRGB(14, 10, 22),
        Enum.Material.Slate, folder)
    topBeam.CFrame = CFrame.new(ox, oy + 19, oz)

    -- Pulsing energy in the arch opening
    local archEnergy = makePart(Vector3.new(9, 14, 1), Color3.fromRGB(100, 10, 60),
        Enum.Material.Neon, folder)
    archEnergy.CFrame = CFrame.new(ox, oy + 10, oz); archEnergy.CanCollide = false
    archEnergy.Transparency = 0.4
    TweenService:Create(archEnergy,
        TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.7, Color = Color3.fromRGB(160, 30, 200) }
    ):Play()

    -- Portal trigger zone
    local portalTrigger = makePart(Vector3.new(10, 14, 5), Color3.fromRGB(0,0,0),
        Enum.Material.SmoothPlastic, folder)
    portalTrigger.Name = "RunPortal"; portalTrigger.Transparency = 1; portalTrigger.CanCollide = false
    portalTrigger.CFrame = CFrame.new(ox, oy + 7, oz)
    local portalTag = Instance.new("BoolValue"); portalTag.Name = "IsRunPortal"; portalTag.Parent = portalTrigger

    -- Portal light — dim, ominous
    local pLight = Instance.new("PointLight", innerGlow)
    pLight.Color = Color3.fromRGB(140, 20, 80); pLight.Range = 35; pLight.Brightness = 2

    -- Portal text
    makeLabel(topBeam, UDim2.new(0,320,0,50), Vector3.new(0,4,0),
        "ENTER THE VOID", Color3.fromRGB(200, 60, 100), 24)

    -- Title — eerie glow
    local _, titleLbl = makeLabel(topBeam, UDim2.new(0,600,0,90), Vector3.new(0,10,0),
        "VOID RUNNER", Color3.fromRGB(180, 40, 80), 48)

    -- ── Weapons Vendor (left) — shadowy alcove ─────────────────────────────
    local vx, vz = ox - 35, oz + 12

    -- Raised platform
    local vendFloor1 = makePart(Vector3.new(18, 1.5, 14), Color3.fromRGB(16, 12, 24),
        Enum.Material.Slate, folder)
    vendFloor1.CFrame = CFrame.new(vx, oy + 0.75, vz)

    -- Back wall
    local vendWall1 = makePart(Vector3.new(18, 12, 2), Color3.fromRGB(10, 8, 16),
        Enum.Material.Slate, folder)
    vendWall1.CFrame = CFrame.new(vx, oy + 6, vz + 7)

    -- Counter
    local counter1 = makePart(Vector3.new(14, 4, 3), Color3.fromRGB(18, 14, 28),
        Enum.Material.Slate, folder)
    counter1.Name  = "WeaponsCounter"
    counter1.CFrame = CFrame.new(vx, oy + 2, vz + 4)

    local counterTop1 = makePart(Vector3.new(15, 0.4, 4), Color3.fromRGB(30, 20, 45),
        Enum.Material.SmoothPlastic, folder)
    counterTop1.CFrame = CFrame.new(vx, oy + 4.2, vz + 4)

    -- NPC body — hooded figure
    local npc1B = makePart(Vector3.new(2.5, 5, 2), Color3.fromRGB(20, 15, 35),
        Enum.Material.SmoothPlastic, folder)
    npc1B.CFrame = CFrame.new(vx, oy + 2.5, vz + 6); npc1B.CanCollide = false
    -- Hood
    local npc1Hood = makePart(Vector3.new(2, 2, 2), Color3.fromRGB(15, 10, 25),
        Enum.Material.SmoothPlastic, folder)
    npc1Hood.CFrame = CFrame.new(vx, oy + 5.5, vz + 6); npc1Hood.CanCollide = false
    -- Glowing eyes
    local eye1 = makePart(Vector3.new(0.3, 0.2, 0.1), Color3.fromRGB(255, 40, 40),
        Enum.Material.Neon, folder)
    eye1.CFrame = CFrame.new(vx - 0.4, oy + 5.3, vz + 5); eye1.CanCollide = false
    local eye2 = makePart(Vector3.new(0.3, 0.2, 0.1), Color3.fromRGB(255, 40, 40),
        Enum.Material.Neon, folder)
    eye2.CFrame = CFrame.new(vx + 0.4, oy + 5.3, vz + 5); eye2.CanCollide = false

    makeLabel(npc1B, UDim2.new(0,220,0,40), Vector3.new(0,6,0), "ARMS DEALER",
        Color3.fromRGB(255, 80, 60), 20)

    -- Weapon display — glowing items on dark shelves
    local weapColors = {
        { Color3.fromRGB(255, 60, 40),   "Blaster" },
        { Color3.fromRGB(255, 140, 20),  "Shotgun" },
        { Color3.fromRGB(100, 200, 255), "Sniper"  },
    }
    for i, wc in ipairs(weapColors) do
        local shelf = makePart(Vector3.new(3, 0.3, 2), Color3.fromRGB(14, 10, 22),
            Enum.Material.Slate, folder)
        shelf.CFrame = CFrame.new(vx - 5 + i * 3.5, oy + 2, vz)
        local gun = makePart(Vector3.new(2, 0.4, 0.4), wc[1], Enum.Material.Neon, folder)
        gun.CFrame = CFrame.new(vx - 5 + i * 3.5, oy + 2.5, vz); gun.CanCollide = false
        local gLight = Instance.new("PointLight", gun)
        gLight.Color = wc[1]; gLight.Range = 8; gLight.Brightness = 1.5
        makeLabel(shelf, UDim2.new(0,80,0,20), Vector3.new(0,-0.8,0), wc[2],
            Color3.fromRGB(160, 140, 170), 10)
    end

    -- ── Upgrades Vendor (right) — mystic shrine ────────────────────────────
    local ux, uz = ox + 35, oz + 12

    local vendFloor2 = makePart(Vector3.new(18, 1.5, 14), Color3.fromRGB(12, 16, 14),
        Enum.Material.Slate, folder)
    vendFloor2.CFrame = CFrame.new(ux, oy + 0.75, uz)

    local vendWall2 = makePart(Vector3.new(18, 12, 2), Color3.fromRGB(8, 12, 10),
        Enum.Material.Slate, folder)
    vendWall2.CFrame = CFrame.new(ux, oy + 6, uz + 7)

    local counter2 = makePart(Vector3.new(14, 4, 3), Color3.fromRGB(14, 20, 16),
        Enum.Material.Slate, folder)
    counter2.Name  = "UpgradesCounter"
    counter2.CFrame = CFrame.new(ux, oy + 2, uz + 4)

    local counterTop2 = makePart(Vector3.new(15, 0.4, 4), Color3.fromRGB(22, 35, 28),
        Enum.Material.SmoothPlastic, folder)
    counterTop2.CFrame = CFrame.new(ux, oy + 4.2, uz + 4)

    -- NPC — shrouded mystic
    local npc2B = makePart(Vector3.new(2.5, 5, 2), Color3.fromRGB(15, 28, 20),
        Enum.Material.SmoothPlastic, folder)
    npc2B.CFrame = CFrame.new(ux, oy + 2.5, uz + 6); npc2B.CanCollide = false
    local npc2Hood = makePart(Vector3.new(2, 2, 2), Color3.fromRGB(10, 20, 14),
        Enum.Material.SmoothPlastic, folder)
    npc2Hood.CFrame = CFrame.new(ux, oy + 5.5, uz + 6); npc2Hood.CanCollide = false
    local eye3 = makePart(Vector3.new(0.3, 0.2, 0.1), Color3.fromRGB(40, 255, 80),
        Enum.Material.Neon, folder)
    eye3.CFrame = CFrame.new(ux - 0.4, oy + 5.3, uz + 5); eye3.CanCollide = false
    local eye4 = makePart(Vector3.new(0.3, 0.2, 0.1), Color3.fromRGB(40, 255, 80),
        Enum.Material.Neon, folder)
    eye4.CFrame = CFrame.new(ux + 0.4, oy + 5.3, uz + 5); eye4.CanCollide = false

    makeLabel(npc2B, UDim2.new(0,220,0,40), Vector3.new(0,6,0), "VOID ORACLE",
        Color3.fromRGB(60, 255, 120), 20)

    -- Upgrade orbs — floating, eerie glow
    local orbColors = {
        Color3.fromRGB(140, 40, 200),
        Color3.fromRGB(200, 20, 60),
        Color3.fromRGB(40, 200, 120),
    }
    for i, col in ipairs(orbColors) do
        local pedestal = makePart(Vector3.new(2.5, 3, 2.5), Color3.fromRGB(12, 18, 14),
            Enum.Material.Slate, folder)
        pedestal.CFrame = CFrame.new(ux - 5 + i * 3.5, oy + 1.5, uz)
        local orb = Instance.new("Part")
        orb.Size = Vector3.new(1.4, 1.4, 1.4); orb.Shape = Enum.PartType.Ball
        orb.Color = col; orb.Material = Enum.Material.Neon
        orb.Anchored = true; orb.CanCollide = false; orb.CastShadow = false
        orb.Transparency = 0.2
        orb.CFrame = CFrame.new(ux - 5 + i * 3.5, oy + 3.8, uz)
        orb.Parent = folder
        local oLight = Instance.new("PointLight", orb)
        oLight.Color = col; oLight.Range = 12; oLight.Brightness = 2
        -- Float + spin
        local angle = i * 2
        local baseY = oy + 3.8
        RunService.Heartbeat:Connect(function(dt)
            if not orb.Parent then return end
            angle = angle + dt * 1.2
            local yOff = math.sin(angle * 0.8) * 0.4
            orb.CFrame = CFrame.new(ux - 5 + i * 3.5, baseY + yOff, uz) * CFrame.Angles(0, angle, 0)
        end)
    end

    -- ── Customization Area (back) — dark ritual platform ────────────────────
    local cz = oz - 30

    local custFloor = makePart(Vector3.new(22, 1.5, 16), Color3.fromRGB(14, 10, 24),
        Enum.Material.Slate, folder)
    custFloor.CFrame = CFrame.new(ox, oy + 0.75, cz)

    local pedestal = makePart(Vector3.new(6, 2.5, 6), Color3.fromRGB(18, 12, 30),
        Enum.Material.Slate, folder)
    pedestal.CFrame = CFrame.new(ox, oy + 2.75, cz)

    -- Ritual circle
    local custRing = makePart(Vector3.new(9, 0.15, 9), Color3.fromRGB(120, 40, 180),
        Enum.Material.Neon, folder)
    custRing.CFrame = CFrame.new(ox, oy + 1.6, cz); custRing.CanCollide = false
    TweenService:Create(custRing,
        TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Color = Color3.fromRGB(60, 10, 100), Transparency = 0.5 }
    ):Play()

    -- Dark mirror — cracked, reflective
    local mirrorFrame = makePart(Vector3.new(10, 12, 1.5), Color3.fromRGB(12, 8, 20),
        Enum.Material.Slate, folder)
    mirrorFrame.CFrame = CFrame.new(ox, oy + 6, cz - 7)
    local mirror = makePart(Vector3.new(8, 10, 0.3), Color3.fromRGB(30, 15, 50),
        Enum.Material.Glass, folder)
    mirror.CFrame = CFrame.new(ox, oy + 6, cz - 6.3); mirror.Reflectance = 0.4
    mirror.Transparency = 0.3; mirror.CanCollide = false
    -- Eerie glow behind mirror
    local mirrorGlow = Instance.new("PointLight", mirror)
    mirrorGlow.Color = Color3.fromRGB(100, 30, 140); mirrorGlow.Range = 15; mirrorGlow.Brightness = 1.5

    makeLabel(pedestal, UDim2.new(0,220,0,40), Vector3.new(0,4,0), "CUSTOMIZE",
        Color3.fromRGB(180, 80, 220), 20)

    -- ── Info / Controls Board (front) ───────────────────────────────────────
    local iz = oz + 35

    local infoBoard = makePart(Vector3.new(18, 12, 2), Color3.fromRGB(10, 8, 16),
        Enum.Material.Slate, folder)
    infoBoard.CFrame = CFrame.new(ox, oy + 6, iz)

    local infoBill = Instance.new("BillboardGui")
    infoBill.Size = UDim2.new(0, 340, 0, 260)
    infoBill.StudsOffset = Vector3.new(0, 0, -1.5)
    infoBill.AlwaysOnTop = false; infoBill.Parent = infoBoard

    local infoTitle = Instance.new("TextLabel", infoBill)
    infoTitle.Size = UDim2.new(1,0,0.12,0); infoTitle.BackgroundTransparency = 1
    infoTitle.Text = "SURVIVAL PROTOCOLS"
    infoTitle.TextColor3 = Color3.fromRGB(200, 60, 80)
    infoTitle.Font = Enum.Font.GothamBold; infoTitle.TextSize = 22

    local infoBody = Instance.new("TextLabel", infoBill)
    infoBody.Size = UDim2.new(1,-16,0.85,0); infoBody.Position = UDim2.new(0,8,0.15,0)
    infoBody.BackgroundTransparency = 1; infoBody.TextWrapped = true
    infoBody.TextYAlignment = Enum.TextYAlignment.Top
    infoBody.TextXAlignment = Enum.TextXAlignment.Left
    infoBody.Text = "WASD — Move\nSpace — Jump\nG — Switch Gravity\nShift — Dash\nMouse1 — Shoot\nMouse2 / E / F — Melee\n\n• Eliminate all enemies to open the exit\n• Every 5 levels a boss guards the way\n• Choose upgrades between levels\n• Chain kills for score multipliers\n• The deeper you go, the darker it gets..."
    infoBody.TextColor3 = Color3.fromRGB(140, 130, 160)
    infoBody.Font = Enum.Font.Gotham; infoBody.TextSize = 12

    -- ── Ambient Lighting — dim and foreboding ──────────────────────────────
    -- Very dim overhead lights with red/purple tones
    local lightData = {
        { pos = Vector3.new(ox, oy + 20, oz),      color = Color3.fromRGB(60, 15, 40),  bright = 1.5, range = 60 },
        { pos = Vector3.new(ox - 50, oy + 12, oz - 50), color = Color3.fromRGB(40, 10, 30), bright = 1.0, range = 35 },
        { pos = Vector3.new(ox + 50, oy + 12, oz - 50), color = Color3.fromRGB(40, 10, 30), bright = 1.0, range = 35 },
        { pos = Vector3.new(ox - 50, oy + 12, oz + 50), color = Color3.fromRGB(40, 10, 30), bright = 1.0, range = 35 },
        { pos = Vector3.new(ox + 50, oy + 12, oz + 50), color = Color3.fromRGB(40, 10, 30), bright = 1.0, range = 35 },
    }
    for _, ld in ipairs(lightData) do
        local lamp = makePart(Vector3.new(0.5,0.5,0.5), ld.color, Enum.Material.Neon, folder)
        lamp.Transparency = 0.8; lamp.CFrame = CFrame.new(ld.pos); lamp.CanCollide = false
        local light = Instance.new("PointLight", lamp)
        light.Color = ld.color; light.Range = ld.range; light.Brightness = ld.bright
    end

    -- ── Corner monoliths — tall dark pillars ────────────────────────────────
    for _, corner in ipairs({
        Vector3.new(ox - 55, oy + 8, oz - 55),
        Vector3.new(ox + 55, oy + 8, oz - 55),
        Vector3.new(ox - 55, oy + 8, oz + 55),
        Vector3.new(ox + 55, oy + 8, oz + 55),
    }) do
        local p = makePart(Vector3.new(4, 16, 4), Color3.fromRGB(10, 8, 16),
            Enum.Material.Slate, folder)
        p.CFrame = CFrame.new(corner)
        -- Faint red glow strip
        local glow = makePart(Vector3.new(0.3, 16, 0.3), Color3.fromRGB(100, 20, 30),
            Enum.Material.Neon, folder)
        glow.CFrame = CFrame.new(corner); glow.CanCollide = false; glow.Transparency = 0.4
    end

    -- ── Scattered debris / broken pillars ───────────────────────────────────
    local debrisPositions = {
        { pos = Vector3.new(ox - 20, oy + 1.5, oz - 40), size = Vector3.new(3, 3, 3), rot = 15 },
        { pos = Vector3.new(ox + 25, oy + 2, oz - 35),   size = Vector3.new(4, 4, 2), rot = -20 },
        { pos = Vector3.new(ox - 40, oy + 1, oz + 20),   size = Vector3.new(2, 2, 5), rot = 30 },
        { pos = Vector3.new(ox + 40, oy + 1.5, oz - 10), size = Vector3.new(3, 3, 3), rot = -10 },
        { pos = Vector3.new(ox - 15, oy + 1, oz + 35),   size = Vector3.new(5, 2, 3), rot = 22 },
        { pos = Vector3.new(ox + 18, oy + 2.5, oz + 30), size = Vector3.new(2, 5, 2), rot = -5 },
    }
    for _, d in ipairs(debrisPositions) do
        local rock = makePart(d.size, Color3.fromRGB(16, 12, 24), Enum.Material.Slate, folder)
        rock.CFrame = CFrame.new(d.pos) * CFrame.Angles(0, math.rad(d.rot), math.rad(d.rot * 0.3))
    end

    -- ── Floating embers / particles (small neon parts drifting upward) ──────
    for i = 1, 15 do
        local ember = Instance.new("Part")
        ember.Size = Vector3.new(0.2, 0.2, 0.2)
        ember.Shape = Enum.PartType.Ball
        ember.Color = Color3.fromRGB(
            math.random(140, 220),
            math.random(10, 40),
            math.random(30, 80)
        )
        ember.Material = Enum.Material.Neon
        ember.Anchored = true; ember.CanCollide = false; ember.CastShadow = false
        local ex = ox + (math.random() - 0.5) * 80
        local ey = oy + 1 + math.random() * 3
        local ez = oz + (math.random() - 0.5) * 80
        ember.CFrame = CFrame.new(ex, ey, ez)
        ember.Parent = folder

        local driftSpeed = 0.3 + math.random() * 0.5
        local phase = math.random() * math.pi * 2
        RunService.Heartbeat:Connect(function(dt)
            if not ember.Parent then return end
            phase = phase + dt * driftSpeed
            local ny = oy + 1 + (math.sin(phase) + 1) * 5
            local nx = ex + math.sin(phase * 0.7) * 2
            ember.CFrame = CFrame.new(nx, ny, ez)
            ember.Transparency = 0.3 + math.sin(phase * 2) * 0.3
        end)
    end

    return folder
end

HubBuilder.HUB_ORIGIN = HUB_ORIGIN
HubBuilder.SPAWN_POS  = Vector3.new(0, 3, -170)

return HubBuilder
