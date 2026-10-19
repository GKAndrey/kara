local assets = {
    Asset("IMAGE", "exported/kara/tail/tail-0.tex"),
    Asset("ATLAS", "images/inventoryimages/kara_backpack.xml"),
}

-- Настройки рюкзака Кары
local backpack_config = {

    -- Основные параметры
    name = "kara_backpack",
    armor_slot = true,          -- Занимает слот брони
    can_unequip = false,        -- Можно ли снять
    can_replace = false,        -- Можно ли заменить другой бронёй

    -- Размер контейнера
    slots = 4,

    -- Настройки отдельных слотов
    slot_rules = {
        [1] = {
            name = "amulet_slot",
            allowed_prefabs = {
                "amulet",
                "blueamulet",
                "purpleamulet",
            },
        },

        [2] = {
            name = "cane_slot",
            allowed_prefabs = {
                "cane",
            },
        },

        [3] = {
            name = "slot_3",
            allowed_prefabs = {
                -- "prefab предмета",
            },
        },

        [4] = {
            name = "slot_4",
            allowed_prefabs = {
                -- "prefab предмета",
            },
        },
    },

    -- Эффекты предметов внутри рюкзака
    item_effects = {
        ["amulet"] = {
            enabled = true,
            -- параметры эффекта
        },

        ["cane"] = {
            enabled = true,
            -- параметры эффекта
        },
    },
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    -- inst.AnimState:SetBank("backpack")
    -- inst.AnimState:SetBuild("backpack")
    -- inst.AnimState:PlayAnimation("anim")

    inst:AddTag("backpack")
    inst:AddTag("armor")

    -- маркер-компонент должен существовать и на клиенте, чтобы экшен отображался
    inst:AddComponent("karasketchtool")

    MakeInventoryFloatable(inst, "med", 0.05, { 1.1, 0.5, 1.1 })

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    -- Настройка изображения в инвентаре
    inst.components.inventoryitem.atlasname = "images/inventoryimages/kara_backpack.xml"
    inst.components.inventoryitem.imagename = "kara_backpack"
end

return Prefab("kara_backpack", fn, assets)