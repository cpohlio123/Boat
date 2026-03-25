-- GameManager.server.lua
-- Orchestrates game flow: level generation, enemy spawning, boss fights,
-- upgrade selection, and player stats.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules       = script.Parent:WaitForChild("Modules")
local LevelGenerator = require(Modules.LevelGenerator)
local EnemyManager   = require(Modules.EnemyManager)
local BossManager    = require(Modules.BossManager)

local GameConfig    = require(ReplicatedStorage.Modules.GameConfig)
local UpgradeData   = require(ReplicatedStorage.Modules.UpgradeData)

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
local GameOverEvent        = makeEvent("GameOver")
local UpdateHUD            = makeEvent("UpdateHUD")
local PortalTouched        = makeEvent("PortalTouched")   -- internal trigger

-- ── Game States ────────────────────────────────────────────────────────────
local STATE = {
    IDLE     = "idle",
    PLAYING  = "playing",
    BOSS     = "boss",
    UPGRADES = "upgrades",
    DEAD     = "dead",
}

-- ── Per-player state ───────────────────────────────────────────────────────
local playerStates = {}

local function newPlayerState(player)
    return {
        player         = player,
        state          = STATE.IDLE,
        level          = 1,
        score          = 0,
        hp             = GameConfig.BASE_MAX_HP,
        maxHp          = GameConfig.BASE_MAX_HP,
        shield         = 0,
        moveSpeed      = GameConfig.BASE_MOVE_SPEED,
        damageMult     = 1,
        gravityCooldown = GameConfig.GRAVITY_SWITCH_COOLDOWN,
        doubleJump     = false,
        gravitySlamDamage = 0,
        killHeal       = 0,
        weapon         = "blaster",
        passives       = {},
        currentLevel   = nil,
        enemies        = {},
        boss           = nil,
    }
end

local function hudData(ps)
    return {
        hp             = ps.hp,
        maxHp          = ps.maxHp,
        shield         = ps.shield,
        level          = ps.level,
        score          = ps.score,
        weapon         = ps.weapon,
        passives       = ps.passives,
        gravityCooldown = ps.gravityCooldown,
        doubleJump     = ps.doubleJump,
    }
end

local function sendHUD(ps)
    UpdateHUD:FireClient(ps.player, hudData(ps))
end

-- ── Upgrade helpers ────────────────────────────────────────────────────────
local function pickUpgrades(ps, count)
    local pool = {}
    for _, u in ipairs(UpgradeData) do
        if u.type == "consumable" then
            table.insert(pool, u)
        elseif u.type == "weapon" and u.id ~= ps.weapon then
            table.insert(pool, u)
        elseif u.type == "passive" then
            local has = false
            for _, pid in ipairs(ps.passives) do
                if pid == u.id then has = true; break end
            end
            if not has then table.insert(pool, u) end
        end
    end
    local chosen = {}
    local remaining = { table.unpack(pool) }
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
        if e.maxHp         then ps.maxHp = ps.maxHp + e.maxHp; ps.hp = math.min(ps.hp + e.maxHp, ps.maxHp) end
        if e.moveSpeed     then ps.moveSpeed = ps.moveSpeed + e.moveSpeed end
        if e.gravityCooldown then ps.gravityCooldown = math.max(0.3, ps.gravityCooldown + e.gravityCooldown) end
        if e.doubleJump    then ps.doubleJump = true end
        if e.damageMult    then ps.damageMult = ps.damageMult * e.damageMult end
        if e.shieldAmount  then ps.shield = ps.shield + e.shieldAmount end
        if e.gravitySlamDamage then ps.gravitySlamDamage = e.gravitySlamDamage end
        if e.killHeal      then ps.killHeal = ps.killHeal + e.killHeal end
        table.insert(ps.passives, upgradeId)

    elseif u.type == "consumable" then
        local e = u.effect
        if e.healNow  then ps.hp = math.min(ps.hp + e.healNow, ps.maxHp) end
        if e.healFull then ps.hp = ps.maxHp end
    end
end

-- ── Level flow ─────────────────────────────────────────────────────────────
local function teleportToStart(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(0, -GameConfig.TUNNEL_HALF + GameConfig.FLOOR_PLATFORM_SIZE.Y + 3, 0)
    end
end

local function startLevel(ps)
    local player = ps.player
    if not player.Character then return end

    -- Cleanup previous level
    if ps.currentLevel and ps.currentLevel.Parent then
        ps.currentLevel:Destroy()
        ps.currentLevel = nil
    end
    EnemyManager.clearEnemies(ps)

    local isBoss = (ps.level % GameConfig.BOSS_EVERY_N == 0)
    local zone   = GameConfig.ZONES[((ps.level - 1) % #GameConfig.ZONES) + 1]

    local levelFolder, enemySpawns = LevelGenerator.generate(ps.level, workspace)
    ps.currentLevel = levelFolder

    -- Wire up end-portal touch detection
    local portal = levelFolder:FindFirstChild("EndPortal", true)
    if portal then
        portal.Touched:Connect(function(hit)
            local char = player.Character
            if char and hit:IsDescendantOf(char) and ps.state == STATE.PLAYING then
                onLevelComplete(ps)
            end
        end)
    end

    teleportToStart(player)

    if isBoss then
        ps.state = STATE.BOSS
        local boss = BossManager.spawnBoss(ps.level, levelFolder)
        ps.boss = boss
        BossSpawned:FireClient(player, {
            name     = boss.displayName,
            subtitle = boss.subtitle,
        })
    else
        ps.state = STATE.PLAYING
        EnemyManager.spawnEnemies(ps, enemySpawns, levelFolder)
        LevelStart:FireClient(player, {
            level  = ps.level,
            zone   = zone.name,
            isBoss = false,
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
    local upgrades = pickUpgrades(ps, GameConfig.UPGRADES_COUNT)
    ShowUpgrades:FireClient(ps.player, upgrades)
end

local function onPlayerDeath(ps)
    ps.state = STATE.DEAD
    GameOverEvent:FireClient(ps.player, {
        level = ps.level,
        score = ps.score,
    })
end

-- ── Remote event handlers ──────────────────────────────────────────────────

-- Gravity switch request from client
RequestGravitySwitch.OnServerEvent:Connect(function(player, gravDir)
    local ps = playerStates[player.UserId]
    if not ps or ps.state == STATE.DEAD then return end

    -- Gravity slam damage if unlocked
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

-- Enemy damage from client
DamageEnemy.OnServerEvent:Connect(function(player, enemyId, damage, damageType)
    local ps = playerStates[player.UserId]
    if not ps or ps.state == STATE.DEAD then return end

    local actualDmg = damage * ps.damageMult
    local died, score = EnemyManager.damageEnemy(ps, enemyId, actualDmg, damageType)

    if died then
        ps.score = ps.score + (score or 0)
        if ps.killHeal > 0 then
            ps.hp = math.min(ps.hp + ps.killHeal, ps.maxHp)
        end
        sendHUD(ps)

        if ps.state == STATE.PLAYING and EnemyManager.allEnemiesDefeated(ps) then
            -- All enemies dead but portal still needs to be reached;
            -- open the portal (already exists) and notify client
            LevelStart:FireClient(player, { portalOpen = true })
        end
    end
end)

-- Boss damage from client
DamageBoss.OnServerEvent:Connect(function(player, damage)
    local ps = playerStates[player.UserId]
    if not ps or ps.state ~= STATE.BOSS or not ps.boss then return end

    local actualDmg = damage * ps.damageMult
    local died = BossManager.damageBoss(ps.boss, actualDmg)

    if died then
        ps.score = ps.score + (ps.boss.cfg.score or 0)
        if ps.killHeal > 0 then
            ps.hp = math.min(ps.hp + ps.killHeal * 5, ps.maxHp)
        end
        ps.boss = nil
        BossDefeated:FireClient(player, { score = ps.score })
        sendHUD(ps)
        task.wait(3)
        onLevelComplete(ps)
    end
end)

-- Upgrade selection from client
SelectUpgrade.OnServerEvent:Connect(function(player, upgradeId)
    local ps = playerStates[player.UserId]
    if not ps or ps.state ~= STATE.UPGRADES then return end

    applyUpgrade(ps, upgradeId)
    sendHUD(ps)
    task.wait(0.5)
    startLevel(ps)
end)

-- ── Enemy attacks player (callback from EnemyManager) ─────────────────────
EnemyManager.onEnemyAttackPlayer = function(ps, damage, dotInfo)
    if ps.state == STATE.DEAD then return end

    -- Shield absorbs first
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

    -- DoT (acid, etc.)
    if dotInfo then
        task.spawn(function()
            local ticks = dotInfo.duration * 2
            for _ = 1, ticks do
                task.wait(0.5)
                if ps.state == STATE.DEAD then return end
                ps.hp = math.max(0, ps.hp - dotInfo.damage * 0.5)
                PlayerDamaged:FireClient(ps.player, { hp = ps.hp, maxHp = ps.maxHp, damage = dotInfo.damage * 0.5, isDot = true })
                sendHUD(ps)
                if ps.hp <= 0 then
                    onPlayerDeath(ps)
                    return
                end
            end
        end)
    end

    if ps.hp <= 0 then
        onPlayerDeath(ps)
    end
end

BossManager.onBossAttackPlayer = EnemyManager.onEnemyAttackPlayer

-- ── Player join / leave ────────────────────────────────────────────────────
local function setupPlayer(player)
    local ps = newPlayerState(player)
    playerStates[player.UserId] = ps

    local function onCharAdded(char)
        -- Brief wait for character to fully load
        task.wait(1.5)
        -- Reset if dead or idle
        if ps.state == STATE.DEAD or ps.state == STATE.IDLE then
            local fresh = newPlayerState(player)
            fresh.state = STATE.IDLE
            playerStates[player.UserId] = fresh
            ps = fresh
        end
        startLevel(ps)
    end

    if player.Character then
        onCharAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharAdded)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
    local ps = playerStates[player.UserId]
    if ps then
        EnemyManager.clearEnemies(ps)
        if ps.currentLevel and ps.currentLevel.Parent then
            ps.currentLevel:Destroy()
        end
    end
    playerStates[player.UserId] = nil
end)

-- Handle any players who joined before the script loaded
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

print("[GameManager] Ready.")
