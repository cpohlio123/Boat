-- UpgradeData.lua
-- All roguelike upgrade definitions

local UpgradeData = {
    -- ── WEAPONS ──────────────────────────────────────────────────────────
    {
        id          = "blaster",
        name        = "Plasma Blaster",
        description = "Rapid hitscan bolts. Fast and reliable.",
        type        = "weapon",
        rarity      = "common",
        weaponStats = { damage = 25, cooldown = 0.25, range = 200 },
    },
    {
        id          = "shotgun",
        name        = "Scatter Cannon",
        description = "Fires 5 pellets in a wide spread. Devastating up close.",
        type        = "weapon",
        rarity      = "uncommon",
        weaponStats = { damage = 14, pellets = 5, spread = 0.18, cooldown = 0.7, range = 80 },
    },
    {
        id          = "sniper",
        name        = "Rail Rifle",
        description = "One high-damage piercing shot. Slow fire rate.",
        type        = "weapon",
        rarity      = "rare",
        weaponStats = { damage = 90, cooldown = 1.6, range = 300, piercing = true },
    },
    {
        id          = "sword",
        name        = "Plasma Blade",
        description = "Melee weapon. Wide slash AoE, no ammo required.",
        type        = "weapon",
        rarity      = "uncommon",
        weaponStats = { damage = 55, cooldown = 0.4, range = 9, meleeOnly = true },
    },
    {
        id          = "flamethrower",
        name        = "Inferno Torch",
        description = "Continuous stream of fire. Burns enemies over time.",
        type        = "weapon",
        rarity      = "rare",
        weaponStats = { damage = 10, dotDamage = 8, dotDuration = 3, cooldown = 0.07, range = 18 },
    },
    {
        id          = "grenade_launcher",
        name        = "Grenade Launcher",
        description = "Lobs explosive grenades that deal AoE damage.",
        type        = "weapon",
        rarity      = "rare",
        weaponStats = { damage = 70, aoeRadius = 8, cooldown = 1.2, range = 60 },
    },

    -- ── PASSIVES ─────────────────────────────────────────────────────────
    {
        id          = "hp_boost",
        name        = "Reinforced Plating",
        description = "Max HP +30.",
        type        = "passive",
        rarity      = "common",
        effect      = { maxHp = 30 },
    },
    {
        id          = "speed_boost",
        name        = "Overclock Boots",
        description = "Movement speed +4.",
        type        = "passive",
        rarity      = "common",
        effect      = { moveSpeed = 4 },
    },
    {
        id          = "gravity_charge",
        name        = "Gravity Cell",
        description = "Gravity switch cooldown −0.4 s.",
        type        = "passive",
        rarity      = "uncommon",
        effect      = { gravityCooldown = -0.4 },
    },
    {
        id          = "double_jump",
        name        = "Thruster Pack",
        description = "Allows one extra jump while airborne.",
        type        = "passive",
        rarity      = "uncommon",
        effect      = { doubleJump = true },
    },
    {
        id          = "damage_amp",
        name        = "Charged Cells",
        description = "All damage dealt ×1.25.",
        type        = "passive",
        rarity      = "rare",
        effect      = { damageMult = 1.25 },
    },
    {
        id          = "shield",
        name        = "Energy Shield",
        description = "Absorbs the next 40 damage.",
        type        = "passive",
        rarity      = "rare",
        effect      = { shieldAmount = 40 },
    },
    {
        id          = "gravity_slam",
        name        = "Gravity Slam",
        description = "Switching gravity blasts nearby enemies for 45 damage.",
        type        = "passive",
        rarity      = "rare",
        effect      = { gravitySlamDamage = 45 },
    },
    {
        id          = "leech",
        name        = "Lifesteal Round",
        description = "Each kill restores 10 HP.",
        type        = "passive",
        rarity      = "uncommon",
        effect      = { killHeal = 10 },
    },

    -- ── CONSUMABLES ──────────────────────────────────────────────────────
    {
        id          = "medkit",
        name        = "Auto-Medkit",
        description = "Immediately restore 50 HP.",
        type        = "consumable",
        rarity      = "common",
        effect      = { healNow = 50 },
    },
    {
        id          = "full_heal",
        name        = "Nanite Infusion",
        description = "Fully restore HP.",
        type        = "consumable",
        rarity      = "rare",
        effect      = { healFull = true },
    },
}

-- Quick lookup by id
local byId = {}
for _, u in ipairs(UpgradeData) do
    byId[u.id] = u
end
UpgradeData.byId = byId

return UpgradeData
