-- GameManager.server.lua
-- Orchestrates game flow: hub lobby, level generation, enemy spawning, boss
-- fights, upgrade selection, combo system, HP pickups, and run statistics.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules        = script.Parent:WaitForChild("Modules")
local LevelGenerator = require(Modules.LevelGenerator)
local EnemyManager   = require(Modules.EnemyManager)
local BossManager    = require(Modules.BossManager)
local HubBuilder     = require(Modules.HubBuilder)

local GameConfig  = require(ReplicatedStorage.Modules.GameConfig)
local UpgradeData = require(ReplicatedStorage.Modules.UpgradeData)

-- ── Remote Events ──────────────────────────────────────────────────────────
local Events = Instance.new("Folder")
Events.Name   = "Events"
Events.Parent = ReplicatedStorage

local function makeEvent(name)
    local e = Instance.new("RemoteEvent"); e.Name = name; e.Parent = Events; return e
end

local RequestGravitySwitch = makeEvent("RequestGravitySwitch")
local GravitySwitched      = makeEvent("GravitySwitched")
local DamageEnemy          = makeEvent("DamageEnemy")
local DamageBoss           = makeEvent("DamageBoss")
local PlayerDamaged        = makeEvent("PlayerDamaged")
local LevelStart           = makeEvent("LevelStart")
local LevelComplete        = makeEvent("LevelComplete")
local ShowUpgrades         = makeEvent("ShowUpgrades")
local SelectUpgrade        = makeEvent("SelectUpgrade")
local BossSpawned          = makeEvent("BossSpawned")
local BossDefeated         = makeEvent("BossDefeated")
local BossHPUpdate         = makeEvent("BossHPUpdate")
local BossPhaseWarning     = makeEvent("BossPhaseWarning")
local GameOverEvent        = makeEvent("GameOver")
local UpdateHUD            = makeEvent("UpdateHUD")
local ComboUpdate          = makeEvent("ComboUpdate")
local HealPickup           = makeEvent("HealPickup")
local KillFeed             = makeEvent("KillFeed")
local SetDifficulty        = makeEvent("SetDifficulty")
local ShowDifficultySelect = makeEvent("ShowDifficultySelect")
local OpenVendor           = makeEvent("OpenVendor")
local BuyVendorItem        = makeEvent("BuyVendorItem")

-- ── States ─────────────────────────────────────────────────────────────────
local STATE = {
    HUB       = "hub",
    SELECTING = "selecting",
    PLAYING   = "playing",
    BOSS      = "boss",
    UPGRADES  = "upgrades",
    DEAD      = "dead",
}

-- ── Build hub (once) ──────────────────────────────────────────────────────
local hubFolder = HubBuilder.build(workspace)

-- ── Per-player state ──────────────────────────────────────────────────────
local playerStates = {}

local function newPlayerState(player, prevScore)
    return {
        player          = player,
        state           = STATE.HUB,
        level           = 1,
        score           = prevScore or 0,
        hp              = GameConfig.BASE_MAX_HP,
        maxHp           = GameConfig.BASE_MAX_HP,
        shield          = 0,
        moveSpeed       = GameConfig.BASE_MOVE_SPEED,
        damageMult      = 1,
        gravityCooldown = GameConfig.GRAVITY_SWITCH_COOLDOWN,
        doubleJump      = false,
        gravitySlamDamage = 0,
        killHeal        = 0,
        weapon          = "blaster",
        passives        = {},
        currentLevel    = nil,
        enemies         = {},
        boss            = nil,
        -- Combo
        comboKills      = 0,
        comboMult       = 1.0,
        lastKillTime    = 0,
        -- Stats
        totalKills      = 0,
        damageDealt     = 0,
        runStartTime    = tick(),
        -- New passives
        critBonus         = 0,
        damageReduction   = 0,
        berserkThreshold  = 0,
        dashCooldown      = GameConfig.DASH_COOLDOWN or 1.4,
        -- Difficulty
        difficulty      = "normal",
        enemyHpMult     = 1.0,
        enemyDmgMult    = 1.0,
    }
end

local function hudData(ps)
    return {
        hp              = ps.hp,
        maxHp           = ps.maxHp,
        shield          = ps.shield,
        level           = ps.level,
        score           = ps.score,
        weapon          = ps.weapon,
        passives        = ps.passives,
        gravityCooldown = ps.gravityCooldown,
        doubleJump      = ps.doubleJump,
        damageMult      = ps.damageMult,
        critBonus       = ps.critBonus,
        damageReduction = ps.damageReduction,
        berserkThreshold= ps.berserkThreshold,
        dashCooldown    = ps.dashCooldown,
    }
end

local function sendHUD(ps)
    UpdateHUD:FireClient(ps.player, hudData(ps))
end

-- ── Combo helpers ──────────────────────────────────────────────────────────
local function getComboMult(kills)
    local mult = 1.0
    for _, tier in ipairs(GameConfig.COMBO_TIERS) do
        if kills >= tier.kills then mult = tier.mult end
    end
    return mult
end

local function updateCombo(ps, scored)
    local now = tick()
    if now - ps.lastKillTime < GameConfig.COMBO_WINDOW then
        ps.comboKills = ps.comboKills + 1
    else
        ps.comboKills = 1
    end
    ps.lastKillTime = now
    ps.totalKills   = ps.totalKills + 1
    ps.comboMult    = getComboMult(ps.comboKills)
    ps.score        = ps.score + math.floor(scored * ps.comboMult)

    ComboUpdate:FireClient(ps.player, { combo = ps.comboKills, mult = ps.comboMult })

    local snapTime = now
    task.delay(GameConfig.COMBO_WINDOW + 0.15, function()
        if ps.lastKillTime == snapTime and ps.comboKills > 0 then
            ps.comboKills = 0
            ps.comboMult  = 1.0
            ComboUpdate:FireClient(ps.player, { combo = 0, mult = 1.0 })
        end
    end)
end

-- ── Upgrade helpers ──────────────────────────────────────────────────────
local function pickUpgrades(ps, count)
    local pool = {}
    for _, u in ipairs(UpgradeData) do
        if u.type == "consumable" then
            table.insert(pool, u)
        elseif u.type == "weapon" and u.id ~= ps.weapon then
            table.insert(pool, u)
        elseif u.type == "passive" then
            local has = false
            for _, pid in ipairs(ps.passives) do if pid == u.id then has = true; break end end
            if not has then table.insert(pool, u) end
        end
    end
    local chosen, remaining = {}, { table.unpack(pool) }
    for i = 1, math.min(count, #remaining) do
        local idx = math.random(1, #remaining)
        table.insert(chosen, remaining[idx])
        table.remove(remaining, idx)
    end
    return chosen
end

local function applyUpgrade(ps, upgradeId)
    local u = UpgradeData.byId[upgradeId]
    if not u then return end
    if u.type == "weapon" then
        ps.weapon = upgradeId
    elseif u.type == "passive" then
        local e = u.effect
        if e.maxHp           then ps.maxHp = ps.maxHp + e.maxHp; ps.hp = math.min(ps.hp + e.maxHp, ps.maxHp) end
        if e.moveSpeed       then ps.moveSpeed = ps.moveSpeed + e.moveSpeed end
        if e.gravityCooldown then ps.gravityCooldown = math.max(0.3, ps.gravityCooldown + e.gravityCooldown) end
        if e.doubleJump      then ps.doubleJump = true end
        if e.damageMult      then ps.damageMult = ps.damageMult * e.damageMult end
        if e.shieldAmount    then ps.shield = ps.shield + e.shieldAmount end
        if e.gravitySlamDamage then ps.gravitySlamDamage = e.gravitySlamDamage end
        if e.killHeal        then ps.killHeal = ps.killHeal + e.killHeal end
        if e.critBonus       then ps.critBonus = ps.critBonus + e.critBonus end
        if e.damageReduction then ps.damageReduction = math.min(0.75, ps.damageReduction + e.damageReduction) end
        if e.berserkThreshold then ps.berserkThreshold = e.berserkThreshold end
        if e.dashCooldown    then ps.dashCooldown = math.max(0.3, (ps.dashCooldown or 1.4) + e.dashCooldown) end
        table.insert(ps.passives, upgradeId)
    elseif u.type == "consumable" then
        local e = u.effect
        if e.healNow  then ps.hp = math.min(ps.hp + e.healNow, ps.maxHp) end
        if e.healFull then ps.hp = ps.maxHp end
    end
end

-- ── Teleport helpers ─────────────────────────────────────────────────────
local function teleportToHub(player)
    task.wait(0.1)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    root.Anchored = true
    root.CFrame = CFrame.new(HubBuilder.SPAWN_POS)
    root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    task.wait(0.15)
    root.Anchored = false
end

local function teleportToStart(player)
    -- Wait for level geometry to fully register in physics
    task.wait(0.6)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    -- Anchor to prevent falling during teleport
    root.Anchored = true
    -- Land on center of guaranteed spawn pad (Z=DEPTH*2, full-width solid floor)
    root.CFrame = CFrame.new(0, -GameConfig.TUNNEL_HALF + GameConfig.FLOOR_PLATFORM_SIZE.Y + 5, GameConfig.SECTION_DEPTH * 2)
    root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    -- Reset walk speed
    if hum then hum.WalkSpeed = GameConfig.BASE_MOVE_SPEED end
    -- Brief pause while anchored so physics settles
    task.wait(0.3)
    root.Anchored = false
end

-- ── Level flow ───────────────────────────────────────────────────────────
local function startLevel(ps)
    local player = ps.player
    local char = player.Character
    if not char then return end

    -- Anchor the character immediately so they don't fall while level builds
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = true end

    if ps.currentLevel and ps.currentLevel.Parent then
        ps.currentLevel:Destroy()
        ps.currentLevel = nil
    end
    EnemyManager.clearEnemies(ps)

    local isBoss = (ps.level % GameConfig.BOSS_EVERY_N == 0)
    local zone   = GameConfig.ZONES[((ps.level - 1) % #GameConfig.ZONES) + 1]

    local levelFolder, enemySpawns = LevelGenerator.generate(ps.level, workspace)
    ps.currentLevel = levelFolder

    local portal = levelFolder:FindFirstChild("EndPortal", true)
    if portal then
        portal.Touched:Connect(function(hit)
            local curChar = player.Character
            if curChar and hit:IsDescendantOf(curChar) and ps.state == STATE.PLAYING then
                onLevelComplete(ps)
            end
        end)
    end

    teleportToStart(player)  -- handles anchoring/unanchoring internally

    if isBoss then
        ps.state = STATE.BOSS
        local boss = BossManager.spawnBoss(ps.level, levelFolder)
        ps.boss = boss
        BossSpawned:FireClient(player, {
            name     = boss.displayName,
            subtitle = boss.subtitle,
            maxHp    = boss.maxHp,
        })
        BossHPUpdate:FireClient(player, { hp = boss.hp, maxHp = boss.maxHp, ratio = 1.0 })
    else
        ps.state = STATE.PLAYING
        EnemyManager.spawnEnemies(ps, enemySpawns, levelFolder, {
            level        = ps.level,
            enemyHpMult  = ps.enemyHpMult,
            enemyDmgMult = ps.enemyDmgMult,
        })
        LevelStart:FireClient(player, {
            level    = ps.level,
            zone     = zone.name,
            isBoss   = false,
            sections = GameConfig.LEVEL_SECTIONS,
        })
    end

    sendHUD(ps)
end

function onLevelComplete(ps)
    if ps.state ~= STATE.PLAYING and ps.state ~= STATE.BOSS then return end
    ps.score = ps.score + 100 * ps.level
    ps.level = ps.level + 1
    ps.state = STATE.UPGRADES

    LevelComplete:FireClient(ps.player, { score = ps.score, nextLevel = ps.level })
    task.wait(2.5)
    if ps.state ~= STATE.UPGRADES then return end
    ShowUpgrades:FireClient(ps.player, pickUpgrades(ps, GameConfig.UPGRADES_COUNT))
end

local function returnToHub(ps)
    if ps.currentLevel and ps.currentLevel.Parent then
        ps.currentLevel:Destroy()
        ps.currentLevel = nil
    end
    EnemyManager.clearEnemies(ps)
    ps.state = STATE.HUB
    teleportToHub(ps.player)
end

local function onPlayerDeath(ps)
    if ps.state == STATE.DEAD then return end
    ps.state = STATE.DEAD
    EnemyManager.clearEnemies(ps)
    GameOverEvent:FireClient(ps.player, {
        level       = ps.level,
        score       = ps.score,
        kills       = ps.totalKills,
        damageDealt = math.floor(ps.damageDealt or 0),
        timeAlive   = math.floor(tick() - ps.runStartTime),
        weapon      = ps.weapon,
        passives    = ps.passives,
    })
    -- Kill the Roblox Humanoid after a delay so DeathStats screen can show
    task.delay(3.0, function()
        local char = ps.player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end)
end

-- ── Remote event handlers ──────────────────────────────────────────────────
RequestGravitySwitch.OnServerEvent:Connect(function(player, gravDir)
    local ps = playerStates[player.UserId]
    if not ps or ps.state == STATE.DEAD or ps.state == STATE.HUB then return end
    if ps.gravitySlamDamage > 0 then
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                EnemyManager.damageNearby(ps, root.Position, 12, ps.gravitySlamDamage * ps.damageMult)
            end
        end
    end
    GravitySwitched:FireClient(player, gravDir)
end)

DamageEnemy.OnServerEvent:Connect(function(player, enemyId, damage, damageType)
    local ps = playerStates[player.UserId]
    if not ps or ps.state == STATE.DEAD then return end

    local actualDmg = damage * ps.damageMult
    ps.damageDealt  = (ps.damageDealt or 0) + actualDmg

    local died, score = EnemyManager.damageEnemy(ps, enemyId, actualDmg, damageType)

    if died then
        if ps.killHeal > 0 then
            ps.hp = math.min(ps.hp + ps.killHeal, ps.maxHp)
        end
        updateCombo(ps, score or 0)
        KillFeed:FireClient(player, {
            name    = EnemyManager.getEnemyName(enemyId),
            isElite = EnemyManager.wasElite(enemyId),
            score   = math.floor((score or 0) * ps.comboMult),
        })
        sendHUD(ps)

        if ps.state == STATE.PLAYING and EnemyManager.allEnemiesDefeated(ps) then
            LevelStart:FireClient(player, { portalOpen = true })
        end
    end
end)

DamageBoss.OnServerEvent:Connect(function(player, damage)
    local ps = playerStates[player.UserId]
    if not ps or ps.state ~= STATE.BOSS or not ps.boss then return end

    local actualDmg = damage * ps.damageMult
    ps.damageDealt  = (ps.damageDealt or 0) + actualDmg

    local died, phaseChanged, newPhase = BossManager.damageBoss(ps.boss, actualDmg)

    BossHPUpdate:FireClient(player, {
        hp    = ps.boss.hp,
        maxHp = ps.boss.maxHp,
        ratio = math.max(0, ps.boss.hp / ps.boss.maxHp),
    })

    if phaseChanged then
        BossPhaseWarning:FireClient(player, { phase = newPhase })
    end

    if died then
        ps.score = ps.score + (ps.boss.cfg.score or 0)
        if ps.killHeal > 0 then ps.hp = math.min(ps.hp + ps.killHeal * 5, ps.maxHp) end
        ps.boss  = nil
        BossDefeated:FireClient(player, { score = ps.score })
        sendHUD(ps)
        task.wait(3)
        onLevelComplete(ps)
    end
end)

SelectUpgrade.OnServerEvent:Connect(function(player, upgradeId)
    local ps = playerStates[player.UserId]
    if not ps or ps.state ~= STATE.UPGRADES then return end
    applyUpgrade(ps, upgradeId)
    sendHUD(ps)
    task.wait(0.5)
    startLevel(ps)
end)

-- ── Enemy / boss attack callbacks ──────────────────────────────────────────
local function handleDamage(ps, damage, dotInfo)
    if ps.state == STATE.DEAD or ps.state == STATE.HUB then return end
    if ps.shield > 0 then
        local absorbed = math.min(ps.shield, damage)
        ps.shield = ps.shield - absorbed
        damage    = damage - absorbed
    end
    if damage > 0 then
        ps.hp = math.max(0, ps.hp - damage)
        PlayerDamaged:FireClient(ps.player, { hp = ps.hp, maxHp = ps.maxHp, damage = damage })
        sendHUD(ps)
    end
    if dotInfo then
        task.spawn(function()
            for _ = 1, dotInfo.duration * 2 do
                task.wait(0.5)
                if ps.state == STATE.DEAD then return end
                ps.hp = math.max(0, ps.hp - dotInfo.damage * 0.5)
                PlayerDamaged:FireClient(ps.player, { hp = ps.hp, maxHp = ps.maxHp, damage = dotInfo.damage * 0.5, isDot = true })
                sendHUD(ps)
                if ps.hp <= 0 then onPlayerDeath(ps); return end
            end
        end)
    end
    if ps.hp <= 0 then onPlayerDeath(ps) end
end

EnemyManager.onEnemyAttackPlayer = handleDamage
BossManager.onBossAttackPlayer   = handleDamage

EnemyManager.onHazardDamage = function(player, damage)
    local ps = playerStates[player.UserId]
    if ps then handleDamage(ps, damage, nil) end
end

EnemyManager.onHPPickup = function(ps)
    local amt = GameConfig.HP_DROP_AMOUNT
    ps.hp = math.min(ps.hp + amt, ps.maxHp)
    HealPickup:FireClient(ps.player, { amount = amt, hp = ps.hp, maxHp = ps.maxHp })
    sendHUD(ps)
end

LevelGenerator.onHazardDamage = function(player, damage)
    local ps = playerStates[player.UserId]
    if ps then handleDamage(ps, damage, nil) end
end

-- ── Hub portal interaction ───────────────────────────────────────────────
local runPortal = hubFolder:FindFirstChild("RunPortal", true)
if runPortal then
    runPortal.Touched:Connect(function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character == char then
                local ps = playerStates[player.UserId]
                if ps and ps.state == STATE.HUB then
                    ps.state = STATE.SELECTING
                    ShowDifficultySelect:FireClient(player)
                end
                return
            end
        end
    end)
end

-- ── Vendor shop ──────────────────────────────────────────────────────────
local VENDOR_PRICES = { common = 100, uncommon = 220, rare = 380, epic = 600 }

local function makeVendorTouched(vendorType)
    return function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character == char then
                local ps = playerStates[player.UserId]
                if ps and ps.state == STATE.HUB then
                    -- Build item list for this vendor type
                    local items = {}
                    for _, u in ipairs(UpgradeData) do
                        if u.type == vendorType or (vendorType == "weapons" and u.type == "weapon") then
                            table.insert(items, {
                                id       = u.id,
                                name     = u.name,
                                desc     = u.description,
                                rarity   = u.rarity,
                                price    = VENDOR_PRICES[u.rarity] or 200,
                                type     = u.type,
                            })
                        end
                    end
                    OpenVendor:FireClient(player, { vendorType = vendorType, items = items, score = ps.score })
                end
                return
            end
        end
    end
end

-- Wire up vendor counter touches from hub
local weaponsCounter = hubFolder:FindFirstChild("WeaponsCounter", true)
local upgradesCounter = hubFolder:FindFirstChild("UpgradesCounter", true)
if weaponsCounter  then weaponsCounter.Touched:Connect(makeVendorTouched("weapon")) end
if upgradesCounter then upgradesCounter.Touched:Connect(makeVendorTouched("passive")) end

BuyVendorItem.OnServerEvent:Connect(function(player, itemId)
    local ps = playerStates[player.UserId]
    if not ps or ps.state ~= STATE.HUB then return end
    local u = UpgradeData.byId[itemId]
    if not u then return end
    local price = VENDOR_PRICES[u.rarity] or 200
    if ps.score < price then return end
    ps.score = ps.score - price
    applyUpgrade(ps, itemId)
    sendHUD(ps)
    -- Confirm purchase with updated score
    OpenVendor:FireClient(player, { purchased = itemId, score = ps.score })
end)

-- ── Difficulty selection ──────────────────────────────────────────────────
local DIFF = {
    easy   = { enemyHpMult = 0.70, enemyDmgMult = 0.70 },
    normal = { enemyHpMult = 1.00, enemyDmgMult = 1.00 },
    hard   = { enemyHpMult = 1.45, enemyDmgMult = 1.45 },
}
SetDifficulty.OnServerEvent:Connect(function(player, key)
    local ps = playerStates[player.UserId]
    if not ps or ps.state ~= STATE.SELECTING then return end
    local d = DIFF[key] or DIFF.normal
    ps.difficulty   = key
    ps.enemyHpMult  = d.enemyHpMult
    ps.enemyDmgMult = d.enemyDmgMult
    startLevel(ps)
end)

-- ── Player join / leave ──────────────────────────────────────────────────
local function setupPlayer(player)
    local ps = newPlayerState(player)
    playerStates[player.UserId] = ps

    local function onCharAdded()
        task.wait(0.5)
        if ps.state == STATE.HUB and not ps.currentLevel then
            -- First join or already in hub: go straight to hub
            teleportToHub(player)
            return
        end
        -- Any other state (DEAD, PLAYING, BOSS, SELECTING, UPGRADES):
        -- Clean up and return to hub. This handles death, falling out of
        -- bounds, and any other unexpected respawn.
        local diff      = ps.difficulty
        local hm        = ps.enemyHpMult
        local dm        = ps.enemyDmgMult
        local prevScore = ps.score
        if ps.currentLevel and ps.currentLevel.Parent then
            ps.currentLevel:Destroy()
        end
        EnemyManager.clearEnemies(ps)
        local fresh = newPlayerState(player, prevScore)  -- carry score over
        fresh.difficulty   = diff
        fresh.enemyHpMult  = hm
        fresh.enemyDmgMult = dm
        playerStates[player.UserId] = fresh
        ps = fresh
        teleportToHub(player)
    end

    if player.Character then onCharAdded() end
    player.CharacterAdded:Connect(onCharAdded)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
    local ps = playerStates[player.UserId]
    if ps then
        EnemyManager.clearEnemies(ps)
        if ps.currentLevel and ps.currentLevel.Parent then ps.currentLevel:Destroy() end
    end
    playerStates[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end

print("[GameManager] Hub built. Ready.")
