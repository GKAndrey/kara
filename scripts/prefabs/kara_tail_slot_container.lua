local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Посредник inventoryitem позволяет предметам внутри контейнера определять Кару как владельца
    -- (по тому же принципу, что и предметы в рюкзаке). Сам контейнер
    -- скрыт, и его нельзя поднять.
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.canbepickedup = false
    inst.components.inventoryitem.cangoincontainer = false

    inst:AddComponent("container")
    inst.components.container:SetNumSlots(1)
    inst.components.container.acceptsstacks = false
    inst.components.container.ignoresound = true
    inst.components.container.skipopensnd = true
    inst.components.container.skipclosesnd = true

    -- Разрешаем любые предметы инвентаря; вместимость стопки при этом ограничена одной единицей.
    -- Это намеренно обходит обычные ограничения контейнеров, например
    -- cangoincontainer=false, поскольку это личный хвостовой слот Кары.
    inst.components.container.CanTakeItemInSlot = function(container, item, slot)
        if item == nil or not item:IsValid() or item.components.inventoryitem == nil
            or container.readonlycontainer then
            return false
        end
        if slot ~= nil and slot ~= 1 then
            return false
        end
        return container.slots[1] == nil or container.slots[1] == item
    end

    return inst
end

return Prefab("kara_tail_slot_container", fn)
