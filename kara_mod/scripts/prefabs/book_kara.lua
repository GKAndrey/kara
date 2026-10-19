local assets = {
    Asset("ANIM", "anim/books.zip"),
    Asset("ANIM", "anim/swap_books.zip"),
    Asset("IMAGE", "images/inventoryimages/book_kara.tex"),
    Asset("ATLAS", "images/inventoryimages/book_kara.xml"),
}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_books", "book_gardening")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("books")
    inst.AnimState:SetBuild("books")
    inst.AnimState:PlayAnimation("book_gardening")

    inst:AddTag("book")

    -- маркер-компонент должен существовать и на клиенте, чтобы экшен отображался
    inst:AddComponent("karasketchtool")

    MakeInventoryFloatable(inst, "med", 0.05, { 1.1, 0.5, 1.1 })

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/book_kara.xml"
    inst.components.inventoryitem.imagename = "book_kara"

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(17)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("book_kara", fn, assets)