local MakePlayerCharacter = require("prefabs/player_common")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}

TUNING.KARA_HEALTH = 150
TUNING.KARA_HUNGER = 100
TUNING.KARA_SANITY = 200

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.KARA
end
local prefabs = FlattenTree(start_inv, true)

local function onbecamehuman(inst)
	inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kara_speed_mod", 1)
end

local function onbecameghost(inst)
   inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kara_speed_mod")
end

local function onload(inst)
    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)
    inst:ListenForEvent("ms_becameghost", onbecameghost)
    
    if inst:HasTag("playerghost") then
        onbecameghost(inst)
    else
        onbecamehuman(inst)
    end
end

local common_postinit = function(inst)
end

    -- Константы для расчета рассудка
local rad = 15
local sz = 0.01 * rad
	-- Получение рассудка от entity и штрафы за одиночество
local function sanityfn(inst)
    local nearby_count = {0, 0} -- [1] = игроки, [2] = животные
	local x, y, z = inst.Transform:GetWorldPosition()
	local AllAnimals = TheSim:FindEntities(x, y, z, rad, { "animal" }, { "player", "hostile", "INLIMBO" })
    for _, player in pairs(AllPlayers) do
        if player ~= inst then
            local distsq = inst:GetDistanceSqToInst(player)
            if distsq < rad * rad then
                nearby_count[1] = (nearby_count[1] or 0) + 1
            end
        end
    end
    
    for _, entity in pairs(AllAnimals) do
        local distsq = inst:GetDistanceSqToInst(entity)

        if distsq < rad * rad then
            nearby_count[2] = nearby_count[2] + 1
        end
    end
    if nearby_count[1] == 0 and nearby_count[2] == 0 then
        inst.alone_time = math.min((inst.alone_time or 0) + 0.001, 3)
    elseif nearby_count[1] > 0 or nearby_count[2] > 0 then
        inst.alone_time = math.max(0, (inst.alone_time or 0) - 0.003)
    end
    local bonus = 0
    if nearby_count[1] > 0 or nearby_count[2] > 0 then
        bonus = math.min((nearby_count[1] * 0.3 + nearby_count[2] * 0.2), 3)
    end
    local outvalue = TUNING.SANITYAURA_TINY * (inst.alone_time * -1 + bonus)
    -- Отладочный вывод в консоль
    print("[SANITY] nearby_count:", nearby_count[1], nearby_count[2], "| outvalue:", outvalue, "| alone_time:", inst.alone_time or 0)
    return outvalue
end

local master_postinit = function(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default
	
	inst.soundsname = "willow"
	inst.components.health:SetMaxHealth(TUNING.KARA_HEALTH)
	inst.components.hunger:SetMax(TUNING.KARA_HUNGER)
	inst.components.sanity:SetMax(TUNING.KARA_SANITY)
	
    inst.components.combat.damagemultiplier = 1
	
	inst.components.hunger.hungerrate = 1 * TUNING.WILSON_HUNGER_RATE
	
	inst.OnLoad = onload
    inst.OnNewSpawn = onload
	
	inst.components.sanity.custom_rate_fn = sanityfn
end

return MakePlayerCharacter("kara", prefabs, assets, common_postinit, master_postinit, prefabs)
