local MakePlayerCharacter = require "prefabs/player_common"

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    -- Требуется AnimState персонажа, когда альбом копируется в символ swap_object.
    Asset("ANIM", "anim/book_kara.zip"),
}

TUNING.kara_HEALTH = 150
TUNING.kara_HUNGER = 150
TUNING.kara_SANITY = 200

TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.kara = {
    "flint",
    "flint",
    "twigs",
    "twigs",
}

local start_inv = {}

for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.kara
end

local prefabs = FlattenTree(start_inv, true)

local function onbecamehuman(inst)
    inst.components.locomotor:SetExternalSpeedMultiplier(
        inst,
        "kara_speed_mod",
        1
    )
end

local function onbecameghost(inst)
    inst.components.locomotor:RemoveExternalSpeedMultiplier(
        inst,
        "kara_speed_mod"
    )
end

local function sorted_album(inst)
    local result = {}
    for prefab, seen in pairs(inst.kara_scanned_creatures or {}) do
        if seen then
            result[#result + 1] = prefab
        end
    end
    table.sort(result)
    return result
end

local function publish_album(inst)
    if inst._kara_album_net ~= nil then
        inst._kara_album_net:set(table.concat(sorted_album(inst), ","))
    end
end

local function sorted_scan_dates(inst)
    local result = {}
    for prefab, day in pairs(inst.kara_scan_dates or {}) do
        if type(prefab) == "string" and type(day) == "number" then
            result[#result + 1] = prefab .. "=" .. tostring(math.floor(day))
        end
    end
    table.sort(result)
    return result
end

local function publish_scan_dates(inst)
    if inst._kara_album_dates_net ~= nil then
        inst._kara_album_dates_net:set(table.concat(sorted_scan_dates(inst), ","))
    end
end

local function encode_album_notes(notes)
    local entries = {}
    for prefab, note in pairs(notes or {}) do
        if type(prefab) == "string" and type(note) == "string" and note ~= "" then
            local encoded = note:gsub("[%c%%|=]", function(ch)
                return string.format("%%%02x", string.byte(ch))
            end)
            entries[#entries + 1] = prefab .. "=" .. encoded
        end
    end
    table.sort(entries)
    return table.concat(entries, "|")
end

local function publish_album_notes(inst)
    if inst._kara_album_notes_net ~= nil then
        inst._kara_album_notes_net:set(encode_album_notes(inst.kara_album_notes))
    end
end

local function onload(inst, data)
    if data ~= nil and data.kara_scanned_creatures ~= nil then
        inst.kara_scanned_creatures = {}
        for _, prefab in ipairs(data.kara_scanned_creatures) do
            if type(prefab) == "string" then
                inst.kara_scanned_creatures[prefab] = true
            end
        end
    end
    inst.kara_scanned_creatures = inst.kara_scanned_creatures or {}
    if data ~= nil then
        inst.kara_scan_dates = {}
        if type(data.kara_scan_dates) == "table" then
            for prefab, day in pairs(data.kara_scan_dates) do
                if type(prefab) == "string" and type(day) == "number" then
                    inst.kara_scan_dates[prefab] = math.max(1, math.floor(day))
                end
            end
        end
    else
        -- OnNewSpawn может вызываться без таблицы сохранения; не стирайте уже записанные даты.
        inst.kara_scan_dates = inst.kara_scan_dates or {}
    end
    if data ~= nil and type(data.kara_album_notes) == "table" then
        inst.kara_album_notes = {}
        for prefab, note in pairs(data.kara_album_notes) do
            if type(prefab) == "string" and type(note) == "string" then
                inst.kara_album_notes[prefab] = note:sub(1, 1200)
            end
        end
    else
        inst.kara_album_notes = inst.kara_album_notes or {}
    end
    publish_album(inst)
    publish_scan_dates(inst)
    publish_album_notes(inst)

    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)
    inst:ListenForEvent("ms_becameghost", onbecameghost)

    if inst:HasTag("playerghost") then
        onbecameghost(inst)
    else
        onbecamehuman(inst)
    end
end

local function RemoveKaraTailVisual(inst)
    local visual = inst._kara_tail_visual
    if visual ~= nil then
        inst._kara_tail_visual = nil
        if visual:IsValid() then
            visual:Remove()
        end
    end
end

local function TryAnimStateGetter(animstate, method)
    local ok, value = pcall(function()
        return animstate[method](animstate)
    end)
    return ok and value or nil
end

-- [ДОП. СЛОТ: ЗДЕСЬ ОТОБРАЖЕНИЕ ИНСТРУМЕНТОВ И МЕСТО ДЛЯ БУДУЩЕЙ АНИМАЦИИ]

-- Эта таблица задаёт отображение инструментов и оружия, для которых нужно использовать изображение предмета в руке/при экипировке
-- swap вместо обычной анимации prefab на земле или в состоянии idle.
-- Чтобы добавить другой инструмент, укажите ключ его prefab и правильные target/build/symbol из
-- обычного кода экипировки. Будущую анимацию/позу инструмента на хвосте можно добавить вокруг этапа
-- применения изображения ниже; переписывать логику слота/контейнера для этого не нужно.
-- Скин определяется по настоящему предмету, находящемуся в слоте.
local TAIL_HELD_ITEM_VISUALS = {
    axe =                 { target = "axe",              build = "swap_axe",            symbol = "swap_axe" },
    goldenaxe =           { target = "goldenaxe",        build = "swap_goldenaxe",      symbol = "swap_goldenaxe" },
    moonglassaxe =        { target = "glassaxe",         build = "swap_glassaxe",       symbol = "swap_glassaxe" },
    pickaxe =             { target = "pickaxe",          build = "swap_pickaxe",        symbol = "swap_pickaxe" },
    goldenpickaxe =       { target = "goldenpickaxe",    build = "swap_goldenpickaxe",  symbol = "swap_goldenpickaxe" },
    shovel =              { target = "shovel",           build = "swap_shovel",         symbol = "swap_shovel" },
    goldenshovel =        { target = "goldenshovel",     build = "swap_goldenshovel",   symbol = "swap_goldenshovel" },
    hammer =              { target = "swap_hammer",      build = "swap_hammer",         symbol = "swap_hammer" },
    spear =               { target = "swap_spear",       build = "swap_spear",          symbol = "swap_spear" },
    bugnet =              { target = "swap_bugnet",      build = "swap_bugnet",         symbol = "swap_bugnet" },
    fishingrod =          { target = "fishingrod",       build = "swap_fishingrod",     symbol = "swap_fishingrod" },
    torch =               { target = "swap_torch",        build = "swap_torch",          symbol = "swap_torch" },
    umbrella =            { target = "umbrella",         build = "swap_umbrella",       symbol = "swap_umbrella" },
    cane =                { target = "swap_cane",        build = "swap_cane",           symbol = "swap_cane" },
    nightsword =          { target = "nightmaresword",   build = "swap_nightmaresword", symbol = "swap_nightmaresword" },
    boomerang =           { target = "boomerang",        build = "swap_boomerang",      symbol = "swap_boomerang" },
    pitchfork =           { target = "pitchfork",        build = "swap_pitchfork",      symbol = "swap_pitchfork" },
    lucy =                { target = "lucy",             build = "swap_lucy_axe",       symbol = "swap_lucy_axe" },
    trident =             { target = "trident",          build = "swap_trident",        symbol = "swap_trident" },
    glasscutter =         { target = "swap_glasscutter", build = "swap_glasscutter",    symbol = "swap_glasscutter" },
}

-- ПРИМЕНЕНИЕ ИЗОБРАЖЕНИЙ ИНСТРУМЕНТОВ/ОРУЖИЯ: этот путь используют только prefab из TAIL_HELD_ITEM_VISUALS
-- для отображения через swap-символ предмета в руке. При добавлении инструмента сначала измените таблицу выше.
local function ApplyKaraTailHeldItemArt(visual, item)
    if visual == nil or visual.AnimState == nil or item == nil or not item:IsValid() then
        return false
    end

    local data = TAIL_HELD_ITEM_VISUALS[item.prefab]
    if data == nil then
        return false
    end

    local skin_build = nil
    if item.GetSkinBuild ~= nil then
        local ok, result = pcall(function() return item:GetSkinBuild() end)
        if ok then skin_build = result end
    end

    local ok = pcall(function()
        if skin_build ~= nil and skin_build ~= "" then
            -- Это соответствует стандартным обработчикам экипировки (например, axe.lua): использование
            -- GUID исходного предмета позволяет применить swap-изображение выбранного скина.
            visual.AnimState:OverrideItemSkinSymbol(data.target, skin_build, data.symbol, item.GUID, data.build)
        else
            visual.AnimState:OverrideSymbol(data.target, data.build, data.symbol)
        end
    end)
    return ok
end

local function UpdateKaraTailVisual(inst)
    RemoveKaraTailVisual(inst)

    local item = inst._kara_tail_item_net ~= nil and inst._kara_tail_item_net:value() or nil
    local prefab = inst._kara_tail_item_prefab_net ~= nil
        and inst._kara_tail_item_prefab_net:value() or ""
    if prefab == "" and item ~= nil and item:IsValid() then
        prefab = item.prefab or ""
    end
    if prefab == "" then
        return
    end

    -- [ДОП. СЛОТ: ЗДЕСЬ БАЗОВОЕ ОТОБРАЖЕНИЕ ОБЫЧНЫХ ПРЕДМЕТОВ]
    
    -- Создаём декоративную копию настоящего prefab с данными его скина. Для обычных предметов
    -- (еды, ресурсов и прочих вещей, отсутствующих в TAIL_HELD_ITEM_VISUALS) используется собственная
    -- анимация/idle этого prefab. Настраивайте анимацию обычных предметов в этой секции
    -- создания prefab и проигрывания idle; не направляйте все предметы через таблицу swap для инструментов.
    -- Настоящий предмет остаётся в скрытом однослотовом контейнере; эта копия нужна только для отображения.
    local skinname = item ~= nil and item:IsValid() and item.skinname or nil
    local skinid = item ~= nil and item:IsValid() and item.skin_id or nil
    local visual = nil
    local ok_spawn, result = pcall(SpawnPrefab, prefab, skinname, skinid, nil)
    if ok_spawn then
        visual = result
    end

    if visual == nil then
        visual = CreateEntity()
        visual.entity:AddTransform()
        visual.entity:AddAnimState()
        visual.persists = false
        local build = item ~= nil and item:IsValid() and item.AnimState ~= nil
            and TryAnimStateGetter(item.AnimState, "GetBuild") or nil
        if build ~= nil and build ~= "" then
            pcall(function() visual.AnimState:SetBank("item") end)
            pcall(function() visual.AnimState:SetBuild(build) end)
            pcall(function() visual.AnimState:PlayAnimation("idle", true) end)
        end
    end

    if visual == nil or not visual:IsValid() or visual.AnimState == nil then
        if visual ~= nil and visual:IsValid() then visual:Remove() end
        return
    end

    visual.persists = false
    if not visual:HasTag("FX") then visual:AddTag("FX") end
    if not visual:HasTag("NOCLICK") then visual:AddTag("NOCLICK") end
    if visual.Physics ~= nil then
        pcall(function() visual.Physics:ClearCollisionMask() end)
        pcall(function() visual.Physics:SetActive(false) end)
    end
    if visual.Follower == nil then
        pcall(function() visual.entity:AddFollower() end)
    end
    if visual.Follower == nil then
        visual:Remove()
        return
    end

    -- [ИНСТРУМЕНТЫ/ОРУЖИЕ] Здесь добавляется или переопределяется swap-изображение для отмеченных инструментов. Для обычных предметов, которых нет в списке,
    -- вспомогательная функция завершается, не заменяя их родную анимацию prefab.
    -- Важно: не вызывайте здесь SetBuild(skin_build), потому что это полностью заменит исходную анимационную сборку предмета
    -- и может удалить символ предмета в руке или его скин.
    ApplyKaraTailHeldItemArt(visual, item)

    -- [ДОП. СЛОТ: ЗДЕСЬ АНИМАЦИЯ ОБЫЧНЫХ ВЕЩЕЙ (стандартная idle-анимация prefab).]
    -- [АНИМАЦИЯ ОБЫЧНЫХ ПРЕДМЕТОВ] По умолчанию используется собственная зацикленная idle-анимация prefab.
    -- Если в будущем для нетехнических предметов понадобится отдельная анимация, изменять нужно место её запуска здесь.
    pcall(function() visual.AnimState:PlayAnimation("idle", true) end)
    pcall(function() visual.AnimState:SetScale(0.34, 0.34, 0.34) end)
    pcall(function() visual.AnimState:SetFinalOffset(1) end)
    -- [ДОП. СЛОТ: ЗДЕСЬ ТОЧКА ПРИВЯЗКИ ПРЕДМЕТА К АНИМИРОВАННОМУ ХВОСТУ]
    
    -- Здесь изображение следует за анимированным символом "tail" Кары. В будущем художники смогут анимировать хвост
    -- в анимационной сборке персонажа Кары; в этой точке привязки настраиваются смещение и поворот
    -- отображаемого предмета. Хранение предмета в слоте и сетевую синхронизацию следует оставлять отдельно.
    visual.Follower:FollowSymbol(inst.GUID, "tail", 0, 0, 0)
    inst._kara_tail_visual = visual
end

local common_postinit = function(inst)
    -- Синхронизируемый список идентификаторов prefab позволяет клиенту отображать интерфейс альбома.
    inst._kara_album_net = net_string(inst.GUID, "kara.albumdata", "kara_albumdirty")
    inst._kara_album_dates_net = net_string(inst.GUID, "kara.albumdates", "kara_albumdatesdirty")
    inst._kara_album_notes_net = net_string(inst.GUID, "kara.albumnotes", "kara_albumnotesdirty")
    -- Передаём данные предмета из специального хвостового слота Кары в интерфейс и визуальное отображение.
    inst._kara_tail_item_net = net_entity(inst.GUID, "kara.tailitem", "kara_tail_itemdirty")
    -- Передаём prefab и значок независимо от скрытого контейнера, чтобы интерфейс
    -- мог показывать значок, даже если сущность предмета не отображается как ячейка контейнера.
    inst._kara_tail_item_prefab_net = net_string(inst.GUID, "kara.tailitemprefab", "kara_tail_visualdirty")
    inst._kara_tail_item_image_net = net_string(inst.GUID, "kara.tailitemimage", "kara_tail_icon_dirty")
    inst._kara_tail_item_atlas_net = net_string(inst.GUID, "kara.tailitematlas", "kara_tail_icon_dirty")
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("kara_tail_itemdirty", UpdateKaraTailVisual)
        inst:ListenForEvent("kara_tail_visualdirty", UpdateKaraTailVisual)
        inst:DoTaskInTime(0, UpdateKaraTailVisual)
    end
    -- Сервер отправляет это сетевое событие после записи нового существа, чтобы клиент-владелец
    -- и остальные клиенты, наблюдающие за Карой, могли воспроизвести ту же анимацию сканирования.
    inst._kara_scan_anim = net_event(inst.GUID, "kara.scan_anim")
    if not TheWorld.ismastersim then
        inst:ListenForEvent("kara.scan_anim", function(player)
            if player.sg ~= nil
                and player.sg.currentstate ~= nil
                and player.sg.currentstate.name ~= "kara_scanbook"
                and not player.sg:HasAnyStateTag("busy", "doing", "sleeping", "dead")
                and (player.replica.rider == nil or not player.replica.rider:IsRiding()) then
                player.sg:GoToState("kara_scanbook")
            end
        end)
    end
    inst:AddTag("kara")
    inst.MiniMapEntity:SetIcon("kara.tex")
end

local master_postinit = function(inst)
    inst.kara_scanned_creatures = inst.kara_scanned_creatures or {}
    inst.kara_scan_dates = inst.kara_scan_dates or {}
    inst.kara_album_notes = inst.kara_album_notes or {}
    publish_album(inst)
    publish_scan_dates(inst)
    publish_album_notes(inst)

    inst:AddComponent("kara_tail_slot")
    inst.components.kara_tail_slot:Initialize()

    -- player_common.lua вызывает функцию сохранения персонажа в виде inst:_OnSave(data).
    -- Изменяйте переданную таблицу сохранения: новая таблица, возвращённая отсюда, будет проигнорирована.
    local old_onsave = inst.OnSave
    inst.OnSave = function(player, data)
        if old_onsave ~= nil then
            old_onsave(player, data)
        end
        if data ~= nil then
            data.kara_scanned_creatures = sorted_album(player)
            data.kara_scan_dates = {}
            for prefab, day in pairs(player.kara_scan_dates or {}) do
                if type(prefab) == "string" and type(day) == "number" then
                    data.kara_scan_dates[prefab] = math.floor(day)
                end
            end
            data.kara_album_notes = player.kara_album_notes or {}
        end
    end

    inst.starting_inventory =
        start_inv[TheNet:GetServerGameMode()]
        or start_inv.default

    inst.soundsname = "willow"

    inst.components.health:SetMaxHealth(TUNING.kara_HEALTH)
    inst.components.hunger:SetMax(TUNING.kara_HUNGER)
    inst.components.sanity:SetMax(TUNING.kara_SANITY)

    inst.components.combat.damagemultiplier = 1
    inst.components.hunger.hungerrate = TUNING.WILSON_HUNGER_RATE

    inst.OnLoad = onload
    inst.OnNewSpawn = onload
end

return MakePlayerCharacter(
    "kara",
    prefabs,
    assets,
    common_postinit,
    master_postinit,
    prefabs
)
