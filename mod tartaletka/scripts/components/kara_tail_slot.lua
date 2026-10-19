require "class" -- Загружает глобальный конструктор Class; require возвращает true, а не сам Class.

local TailSlot = Class(function(self, inst)
    self.inst = inst
    self.slot_container = nil
    self._ondrop = function() self:DropToWorld() end
end)

function TailSlot:Initialize()
    if self.slot_container ~= nil and self.slot_container:IsValid() then
        self:Sync()
        return
    end

    local container = SpawnPrefab("kara_tail_slot_container")
    if container == nil then
        return
    end

    container.entity:SetParent(self.inst.entity)
    container.Transform:SetPosition(0, 0, 0)
    if container.components.inventoryitem ~= nil then
        container.components.inventoryitem:SetOwner(self.inst)
    end
    self.slot_container = container

    -- Этот скрытый однослотовый контейнер обеспечивает штатное владение предметом и его сохранение.
    -- Он не открывается как сундук; пользовательский слот игрока использует небольшой RPC-вызов.
    container:ListenForEvent("itemget", function() self:Sync() end)
    container:ListenForEvent("itemlose", function() self:Sync() end)
    self.inst:ListenForEvent("death", self._ondrop)

    self:Sync()
end

function TailSlot:GetContainer()
    local container = self.slot_container
    return container ~= nil and container:IsValid() and container.components.container or nil
end

function TailSlot:GetItem()
    local container = self:GetContainer()
    return container ~= nil and container:GetItemInSlot(1) or nil
end

local function GetInventoryIconData(item)
    if item == nil or not item:IsValid() then
        return "", ""
    end

    local image, atlas
    -- Реплика предоставляет точный значок, включая переопределения и атласы модов.
    local replica = item.replica ~= nil and item.replica.inventoryitem or nil
    if replica ~= nil then
        pcall(function() image = replica:GetImage() end)
        pcall(function() atlas = replica:GetAtlas() end)
    end

    if type(image) ~= "string" or image == "" then
        image = item.inv_image or (item.prefab ~= nil and (item.prefab .. ".tex")) or ""
        if image ~= "" and not image:match("%.tex$") then
            image = image .. ".tex"
        end
    end
    if type(atlas) ~= "string" or atlas == "" then
        atlas = item.inv_atlas
        if atlas == nil or atlas == "" then
            if image ~= "" and GetInventoryItemAtlas ~= nil then
                local ok, result = pcall(GetInventoryItemAtlas, image)
                atlas = ok and result or "images/inventoryimages.xml"
            else
                atlas = "images/inventoryimages.xml"
            end
        end
    end
    return image or "", atlas or ""
end

function TailSlot:Sync()
    local item = self:GetItem()
    if self.inst._kara_tail_item_net ~= nil then
        self.inst._kara_tail_item_net:set(item)
    end
    local image, atlas = GetInventoryIconData(item)
    if self.inst._kara_tail_item_prefab_net ~= nil then
        self.inst._kara_tail_item_prefab_net:set(item ~= nil and item.prefab or "")
    end
    if self.inst._kara_tail_item_image_net ~= nil then
        self.inst._kara_tail_item_image_net:set(image)
    end
    if self.inst._kara_tail_item_atlas_net ~= nil then
        self.inst._kara_tail_item_atlas_net:set(atlas)
    end
end

local function PutTailSlotItemOnCursor(owner, inventory, item)
    if item == nil or not item:IsValid() or item.components.inventoryitem == nil then
        return false
    end
    local inventoryitem = item.components.inventoryitem
    local old_cangoincontainer = inventoryitem.cangoincontainer
    inventoryitem.cangoincontainer = true
    inventoryitem:OnPutInInventory(owner)
    inventory:SetActiveItem(item)
    inventoryitem.cangoincontainer = old_cangoincontainer

    if inventory:GetActiveItem() == item then
        owner:PushEvent("itemget", { item = item, slot = nil })
        return true
    end
    return false
end

function TailSlot:HandleClick()
    local owner = self.inst
    local inventory = owner.components.inventory
    local container = self:GetContainer()
    if inventory == nil or container == nil then
        return false
    end

    local active_item = inventory:GetActiveItem()
    local stored_item = container:GetItemInSlot(1)

    if active_item ~= nil then
        if stored_item ~= nil then
            -- Обмениваем предмет в руках курсора с предметом в хвостовом слоте. Если курсор
            -- держит стопку, одна единица помещается в хвостовой слот, а остаток
            -- возвращается в обычный инвентарь; прежний предмет из хвостового слота оказывается на курсоре.
            local stackable = active_item.components.stackable
            local stack_count = stackable ~= nil and stackable:StackSize() or 1
            local is_multistack = stackable ~= nil and stack_count > 1
            if is_multistack and inventory:CanAcceptCount(active_item, stack_count - 1) < stack_count - 1 then
                return false
            end

            local moving_item
            local remainder_item = nil
            if is_multistack then
                moving_item = stackable:Get(1)
                remainder_item = inventory:RemoveItem(active_item, true) or active_item
                if inventory:GetActiveItem() == active_item then
                    -- Что-то помешало отделить остаток стопки, находившейся на курсоре.
                    if moving_item ~= nil and moving_item:IsValid() then
                        stackable:Put(moving_item)
                    end
                    return false
                end
            else
                moving_item = inventory:RemoveItem(active_item, true) or active_item
            end

            local old_item = container:RemoveItemBySlot(1)
            if old_item == nil then
                if is_multistack and remainder_item ~= nil and remainder_item:IsValid() then
                    inventory:GiveActiveItem(remainder_item)
                    if moving_item ~= nil and moving_item:IsValid() then inventory:GiveItem(moving_item) end
                elseif moving_item ~= nil and moving_item:IsValid() then
                    PutTailSlotItemOnCursor(owner, inventory, moving_item)
                end
                self:Sync()
                return false
            end

            local accepted = container:GiveItem(moving_item, 1, nil, false)
            if not accepted and container:GetItemInSlot(1) ~= moving_item then
                container:GiveItem(old_item, 1, nil, false)
                if is_multistack then
                    if remainder_item ~= nil and remainder_item:IsValid() then inventory:GiveActiveItem(remainder_item) end
                    if moving_item ~= nil and moving_item:IsValid() then inventory:GiveItem(moving_item) end
                elseif moving_item ~= nil and moving_item:IsValid() then
                    PutTailSlotItemOnCursor(owner, inventory, moving_item)
                end
                self:Sync()
                return false
            end

            if is_multistack and remainder_item ~= nil and remainder_item:IsValid() then
                inventory:GiveItem(remainder_item)
            end

            if not PutTailSlotItemOnCursor(owner, inventory, old_item) then
                inventory:GiveItem(old_item)
            end
            self:Sync()
            return true
        end

        local moving_item = active_item
        local stackable = active_item.components.stackable
        if stackable ~= nil and stackable:IsStack() then
            -- Отделяем ровно одну единицу; остальная часть стопки остаётся на курсоре.
            moving_item = stackable:Get(1)
        else
            moving_item = inventory:RemoveItem(active_item, true) or active_item
        end

        if moving_item == nil or not moving_item:IsValid() then
            return false
        end

        local accepted = container:GiveItem(moving_item, 1, nil, false)
        if not accepted and container:GetItemInSlot(1) ~= moving_item then
            if moving_item:IsValid() then
                if moving_item.components.inventoryitem ~= nil
                    and moving_item.components.inventoryitem.owner ~= nil then
                    moving_item.components.inventoryitem:OnRemoved()
                end
                if inventory:GetActiveItem() == nil then
                    inventory:SetActiveItem(moving_item)
                else
                    inventory:GiveItem(moving_item)
                end
            end
            self:Sync()
            return false
        end

        self:Sync()
        return true
    end

    -- Пустой курсор + занятый слот: переносим предмет на курсор, как из
    -- обычной ячейки инвентаря, а не отправляем его в другую пронумерованную ячейку.
    if stored_item ~= nil then
        local item = container:RemoveItemBySlot(1)
        self:Sync()
        if item ~= nil and item:IsValid() then
            if PutTailSlotItemOnCursor(owner, inventory, item) then
                return true
            end
            inventory:GiveItem(item)
            return false
        end
        return false
    end

    return false
end

function TailSlot:DropToWorld()
    local container = self:GetContainer()
    if container == nil then
        return
    end
    local item = container:RemoveItemBySlot(1)
    self:Sync()
    if item ~= nil and item:IsValid() then
        local x, y, z = self.inst.Transform:GetWorldPosition()
        item.Transform:SetPosition(x + 0.35, y, z + 0.35)
        if item.components.inventoryitem ~= nil then
            item.components.inventoryitem:OnDropped(true)
        end
    end
end

function TailSlot:UseItem()
    local owner = self.inst
    local container = self:GetContainer()
    local item = container ~= nil and container:GetItemInSlot(1) or nil
    local inventory = owner.components.inventory
    local picker = owner.components.playeractionpicker
    local locomotor = owner.components.locomotor
    if item == nil or inventory == nil or picker == nil or locomotor == nil
        or (owner.sg ~= nil and owner.sg:HasStateTag("busy")) then
        return false
    end

    -- Повторяем выбор действия обычной ячейки инвентаря, но пропускаем стандартную
    -- проверку CanAccessItem, поскольку этот предмет специально находится в закрытом скрытом
    -- контейнере, а не в одной из пронумерованных ячеек инвентаря.
    local active_item = inventory:GetActiveItem()
    local actions = active_item ~= nil
        and picker:GetUseItemActions(item, active_item, true)
        or picker:GetInventoryActions(item, true)
    local action = actions ~= nil and actions[1] or nil
    if action ~= nil then
        locomotor:PushAction(action, true)
        return true
    end
    return false
end

function TailSlot:DropItem()
    if self:GetItem() == nil then
        return false
    end
    self:DropToWorld()
    return true
end

function TailSlot:OnSave()
    local container = self:GetContainer()
    if container ~= nil and not container:IsEmpty() then
        local data, references = container:OnSave()
        if data ~= nil then
            return { contents = data }, references
        end
    end
end

function TailSlot:OnLoad(data, newents)
    local container = self:GetContainer()
    if data ~= nil and data.contents ~= nil and container ~= nil then
        container:OnLoad(data.contents, newents)
    end
    self:Sync()
end

function TailSlot:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("death", self._ondrop)
    local slotcontainer = self.slot_container
    self.slot_container = nil
    if slotcontainer ~= nil and slotcontainer:IsValid() then
        local comp = slotcontainer.components.container
        local item = comp ~= nil and comp:RemoveItemBySlot(1) or nil
        if slotcontainer.components.inventoryitem ~= nil then
            slotcontainer.components.inventoryitem:ClearOwner()
        end
        if item ~= nil and item:IsValid() then
            local x, y, z = self.inst.Transform:GetWorldPosition()
            item.Transform:SetPosition(x, y, z)
            if item.components.inventoryitem ~= nil then
                item.components.inventoryitem:OnDropped(true)
            end
        end
        slotcontainer:Remove()
    end
end

return TailSlot
