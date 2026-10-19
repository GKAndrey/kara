local assets =
{
    Asset("ANIM", "anim/book_kara.zip"),
    Asset("ATLAS", "images/inventoryimages/book_kara.xml"),
    Asset("IMAGE", "images/inventoryimages/book_kara.tex"),
    Asset("ANIM", "anim/wx_scanner_ring_fx.zip"),
}

local SCAN_PERIOD = 2
local SCAN_RADIUS = (TUNING.WX78_SCANNER_RANGE or 7)
local MUST_TAGS = { "animal", "character", "largecreature", "monster", "smallcreature" }
local CANT_TAGS = { "DECOR", "FX", "INLIMBO", "NOCLICK", "playerghost" }

local function GetCreatureName(prefab)
    local names = STRINGS.NAMES or {}
    return names[string.upper(prefab)] or names[prefab] or prefab
end

local function PublishAlbum(owner)
    if owner == nil or not owner:IsValid() then
        return
    end

    if owner._kara_album_net ~= nil then
        local prefabs = {}
        for prefab, seen in pairs(owner.kara_scanned_creatures or {}) do
            if seen then
                prefabs[#prefabs + 1] = prefab
            end
        end
        table.sort(prefabs)
        owner._kara_album_net:set(table.concat(prefabs, ","))
    end

    if owner._kara_album_dates_net ~= nil then
        local dates = {}
        for prefab, day in pairs(owner.kara_scan_dates or {}) do
            if type(prefab) == "string" and type(day) == "number" then
                dates[#dates + 1] = prefab .. "=" .. tostring(math.floor(day))
            end
        end
        table.sort(dates)
        owner._kara_album_dates_net:set(table.concat(dates, ","))
    end
end

local function RecordCreature(owner, target)
    if owner == nil or not owner:IsValid() or target == nil or not target:IsValid() then
        return false
    end
    if target == owner or target.prefab == nil or target:HasAnyTag("player", "playerghost", "INLIMBO", "NOCLICK", "FX", "DECOR") then
        return false
    end
    if target.components.health ~= nil and target.components.health:IsDead() then
        return false
    end

    owner.kara_scanned_creatures = owner.kara_scanned_creatures or {}
    if owner.kara_scanned_creatures[target.prefab] then
        return false
    end

    owner.kara_scanned_creatures[target.prefab] = true
    owner.kara_scan_dates = owner.kara_scan_dates or {}
    local cycles = TheWorld ~= nil and TheWorld.state ~= nil and TheWorld.state.cycles or 0
    -- Счёт циклов DST начинается с нуля в первый день; в альбоме отображаются привычные Day 1, Day 2 и т. д.
    owner.kara_scan_dates[target.prefab] = math.max(1, math.floor(tonumber(cycles) or 0) + 1)
    return true
end

-- Откладываем анимацию чтения книги, пока Кара не остановится.
-- События графа состояний нужно регистрировать через sg.events[eventname]; добавление
-- EventHandler по числовому индексу не регистрирует его в таблице поиска событий DST.
local function CancelScanAnimation(inst)
    if inst._kara_animation_task ~= nil then
        inst._kara_animation_task:Cancel()
        inst._kara_animation_task = nil
    end
end

local function QueueScanAnimation(inst, owner)
    if inst == nil or not inst:IsValid() or owner == nil or not owner:IsValid() then
        return
    end
    if inst._kara_animation_task ~= nil then
        return -- объединять несколько новых находок в одну анимацию зарисовки
    end
    inst._kara_animation_task = inst:DoTaskInTime(0.2, function()
        inst._kara_animation_task = nil
        if not inst:IsValid() or not owner:IsValid() or owner:HasTag("playerghost") then
            return
        end
        local inventory = owner.components.inventory
        if inventory == nil or inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= inst then
            return
        end
        local state = owner.sg ~= nil and owner.sg.currentstate or nil
        if state ~= nil and state.name == "idle"
            and not owner.sg:HasAnyStateTag("busy", "doing", "sleeping", "dead") then
            owner:PushEvent("kara_new_album_entry")
        else
            -- Хранить запрос на анимацию, пока эта книга находится в руках персонажа.
            -- Игрок может исследовать мир дольше нескольких секунд, прежде чем остановиться.
            QueueScanAnimation(inst, owner)
        end
    end)
end

local function ScanArea(inst, owner)
    if owner == nil or not owner:IsValid() or owner:HasTag("playerghost") then
        return false
    end
    if owner.components.health ~= nil and owner.components.health:IsDead() then
        return false
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(x, y, z, SCAN_RADIUS, nil, CANT_TAGS, MUST_TAGS)
    local found_names = {}

    for _, target in ipairs(entities) do
        if RecordCreature(owner, target) then
            found_names[#found_names + 1] = GetCreatureName(target.prefab)
        end
    end

    if #found_names > 0 then
        PublishAlbum(owner)

        -- Сохранять сообщение, чтобы Кара произнесла его только после анимации зарисовки.
        -- Если одновременно обнаружено несколько новых видов, сообщения объединяются.
        owner.kara_scan_pending_names = owner.kara_scan_pending_names or {}
        for _, name in ipairs(found_names) do
            owner.kara_scan_pending_names[#owner.kara_scan_pending_names + 1] = name
        end
        local names = owner.kara_scan_pending_names
        local shown = {}
        for i = 1, math.min(#names, 3) do
            shown[#shown + 1] = names[i]
        end
        local announcement = "Sketched: " .. table.concat(shown, ", ")
        if #names > 3 then
            announcement = announcement .. " and " .. tostring(#names - 3) .. " more new species"
        end
        owner.kara_scan_pending_announcement = announcement .. "!"

        -- Сканирование выполняется автоматически, но анимация зарисовки запускается только тогда, когда
        -- новый, ранее неизвестный вид действительно добавлен в альбом.
        QueueScanAnimation(inst, owner)
    end
    return #found_names > 0
end

local function StopScanning(inst)
    if inst._kara_scan_task ~= nil then
        inst._kara_scan_task:Cancel()
        inst._kara_scan_task = nil
    end
end

local CIRCLE_RADIUS_SCALE = 3201.5 / 150 / 2

local function RemoveScanRing(inst)
    if inst._kara_scan_ring ~= nil then
        if inst._kara_scan_ring:IsValid() then
            inst._kara_scan_ring:Remove()
        end
        inst._kara_scan_ring = nil
    end
end

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
        -- Книга отображается отдельным объектом-последователем уменьшенного масштаба, прикреплённым к точке привязки руки.
        -- Так не приходится угадывать имя исходного символа для OverrideSymbol.
        owner.AnimState:Show("ARM_carry")
        owner.AnimState:Hide("ARM_normal")
    end

    RemoveHeldBookVisual(inst)
    if owner ~= nil and owner:IsValid() then
        local held = SpawnPrefab("kara_scannerbook_held_child")
        if held ~= nil then
            held.entity:SetParent(owner.entity)
            inst._kara_handheld_proxy = held
        end
    end

    StopScanning(inst)
    RemoveScanRing(inst)
    if owner ~= nil and owner:IsValid() and owner:HasTag("kara") then
        inst._kara_scan_ring = SpawnPrefab("kara_scanner_ring_fx")
        if inst._kara_scan_ring ~= nil and inst._kara_scan_ring.TrackOwner ~= nil then
            inst._kara_scan_ring:TrackOwner(owner, inst)
        end
        -- Не запускайте сканирование сразу при экипировке. Первое настоящее сканирование происходит после
        -- полного интервала сканирования, поэтому одна лишь экипировка не запускает анимацию зарисовки.
        inst._kara_scan_task = inst:DoPeriodicTask(SCAN_PERIOD, ScanArea, SCAN_PERIOD, owner)
    end
end

local function OnUnequip(inst, owner)
    StopScanning(inst)
    CancelScanAnimation(inst)
    RemoveScanRing(inst)
    RemoveHeldBookVisual(inst)
    if owner ~= nil and owner.AnimState ~= nil then
        owner.AnimState:ClearOverrideSymbol("swap_object")
        owner.AnimState:Show("ARM_normal")
        owner.AnimState:Hide("ARM_carry")
    end
end

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
    inst:AddTag("kara_scannerbook")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable:SetDescription("Sketches nearby creatures while held and saves discoveries in the album.")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/book_kara.xml"
    -- Prefab называется kara_scannerbook, а значок предмета в инвентаре — book_kara.
    inst.components.inventoryitem:ChangeImageName("book_kara")

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL
    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)

    return inst
end

local function ringfn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.AnimState:SetBank("wx_scanner_ring_fx")
    inst.AnimState:SetBuild("wx_scanner_ring_fx")
    inst.AnimState:PlayAnimation("scan_loop", true)
    inst.AnimState:Hide("inner")
    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(1)
    inst.AnimState:SetScale(SCAN_RADIUS / CIRCLE_RADIUS_SCALE, SCAN_RADIUS / CIRCLE_RADIUS_SCALE)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    function inst:TrackOwner(owner, scanner)
        if owner ~= nil and owner:IsValid() then
            local x, y, z = owner.Transform:GetWorldPosition()
            self.Transform:SetPosition(x, y, z)
        end
        self:DoPeriodicTask(0.1, function(ring)
            if owner == nil or not owner:IsValid()
                or scanner == nil or not scanner:IsValid()
                or owner.components.inventory == nil
                or owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= scanner then
                ring:Remove()
                return
            end
            local x, y, z = owner.Transform:GetWorldPosition()
            ring.Transform:SetPosition(x, y, z)
        end)
    end

    return inst
end

-- Серверный вспомогательный объект. Лёгкий клиентский объект следует за символом персонажа
-- swap_object (рука), благодаря чему масштаб книги можно менять независимо от модели персонажа.
local function SpawnHeldBookClientObject(inst)
    if inst._client_obj ~= nil or not inst:IsValid() then
        return
    end
    local owner = inst.entity:GetParent()
    if owner == nil or not owner:IsValid() then
        return
    end

    local client_obj = SpawnPrefab("kara_scannerbook_held_client")
    if client_obj ~= nil then
        client_obj.entity:SetParent(owner.entity)
        client_obj.entity:AddFollower()
        -- Используем ту же точку привязки руки, что и обычные предметы в руках.
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
    -- Исходное изображение предмета широкое; показываем его в размере, подходящем для руки.
    inst.AnimState:SetScale(0.52, 0.52)
    inst.AnimState:SetFinalOffset(1)

    inst.entity:SetPristine()
    return inst
end

return Prefab("kara_scannerbook", fn, assets),
    Prefab("kara_scanner_ring_fx", ringfn, assets),
    Prefab("kara_scannerbook_held_child", heldchildfn),
    Prefab("kara_scannerbook_held_client", heldclientfn, { Asset("ANIM", "anim/book_kara.zip") })
