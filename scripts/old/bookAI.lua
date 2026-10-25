-- scripts/prefabs/book_kara.lua
-- Единая книга Кары.
--   * Арт и отображение в руке: из tartaletka (anim/book_kara.zip, прокси-объект на символе swap_object).
--   * karasketchtool (маркер для экшена SKETCH) и урон: из kara_mod.
--   * Режима сканера нет: фоновое запоминание существ живёт в персонаже/компоненте,
--     а запись "зарисовано" делает компонент karasketcher.
--   * Альбом открывается экшеном KARA_OPEN_ALBUM (см. modmain), книга сама никаких данных не хранит.

local assets =
{
    Asset("ANIM", "anim/book_kara.zip"),
    Asset("ATLAS", "images/inventoryimages/book_kara.xml"),
    Asset("IMAGE", "images/inventoryimages/book_kara.tex"),
}

local held_assets =
{
    Asset("ANIM", "anim/book_kara.zip"),
}

-- Урон книги в ближнем бою (значение из kara_mod). Поставь 0, если книга не должна быть оружием.
local BOOK_DAMAGE = 17

-- Масштаб книги в руке (из tartaletka: исходный рисунок широкий).
local HELD_SCALE = 0.52

---------------------------------------------------------------------------
-- Отображение в руке
---------------------------------------------------------------------------

local function RemoveHeldBookVisual(inst)
    local held = inst._kara_handheld_proxy
    if held ~= nil then
        if held:IsValid() then
            held:Remove()
        end
        inst._kara_handheld_proxy = nil
    end
end

local function OnEquip(inst, owner)
    if owner ~= nil and owner.AnimState ~= nil then
        -- Книга рисуется отдельным объектом, прикреплённым к руке,
        -- поэтому символ swap_object не подменяется.
        owner.AnimState:Show("ARM_carry")
        owner.AnimState:Hide("ARM_normal")
    end

    RemoveHeldBookVisual(inst)
    if owner ~= nil and owner:IsValid() then
        local held = SpawnPrefab("book_kara_held_child")
        if held ~= nil then
            held.entity:SetParent(owner.entity)
            inst._kara_handheld_proxy = held
        end
    end
end

local function OnUnequip(inst, owner)
    RemoveHeldBookVisual(inst)
    if owner ~= nil and owner.AnimState ~= nil then
        owner.AnimState:ClearOverrideSymbol("swap_object")
        owner.AnimState:Show("ARM_normal")
        owner.AnimState:Hide("ARM_carry")
    end
end

---------------------------------------------------------------------------
-- Основной prefab
---------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("book_kara")
    inst.AnimState:SetBuild("book_kara")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("book")
    inst:AddTag("bookcabinet_item")

    -- Маркер-компонент должен существовать и на клиенте, чтобы экшен SKETCH отображался.
    inst:AddComponent("karasketchtool")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Описание берётся из STRINGS.CHARACTERS.*.DESCRIBE.BOOK_KARA (modmain / speech).
    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/book_kara.xml"
    inst.components.inventoryitem:ChangeImageName("book_kara")

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    if BOOK_DAMAGE > 0 then
        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(BOOK_DAMAGE)
    end

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL
    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)

    return inst
end

---------------------------------------------------------------------------
-- Книга в руке: серверный прокси + клиентский визуальный объект
---------------------------------------------------------------------------

-- Клиентский объект следует за символом swap_object (рука),
-- благодаря чему масштаб книги меняется независимо от модели персонажа.
local function SpawnHeldBookClientObject(inst)
    if inst._client_obj ~= nil or not inst:IsValid() then
        return
    end
    local owner = inst.entity:GetParent()
    if owner == nil or not owner:IsValid() then
        return
    end

    local client_obj = SpawnPrefab("book_kara_held_client")
    if client_obj ~= nil then
        client_obj.entity:SetParent(owner.entity)
        client_obj.entity:AddFollower()
        client_obj.Follower:FollowSymbol(owner.GUID, "swap_object", 0, 0, 0)
        inst._client_obj = client_obj
        inst:ListenForEvent("onremove", function()
            if inst._client_obj ~= nil then
                if inst._client_obj:IsValid() then
                    inst._client_obj:Remove()
                end
                inst._client_obj = nil
            end
        end)
    end
end

local function heldchildfn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.entity:SetPristine()

    if not TheNet:IsDedicated() then
        inst:DoTaskInTime(0, SpawnHeldBookClientObject)
    end

    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

local function heldclientfn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.Transform:SetFourFaced()
    inst.AnimState:SetBank("book_kara")
    inst.AnimState:SetBuild("book_kara")
    inst.AnimState:PlayAnimation("anim", true)
    inst.AnimState:SetScale(HELD_SCALE, HELD_SCALE)
    inst.AnimState:SetFinalOffset(1)

    inst.entity:SetPristine()
    return inst
end

return Prefab("book_kara", fn, assets),
    Prefab("book_kara_held_child", heldchildfn),
    Prefab("book_kara_held_client", heldclientfn, held_assets)