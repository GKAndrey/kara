
PrefabFiles = {
    "kara",
    "kara_none",
    "kara_scannerbook",
    "kara_tail_slot_container",
}

Assets = {
    Asset("IMAGE", "images/saveslot_portraits/kara.tex"),
    Asset("ATLAS", "images/saveslot_portraits/kara.xml"),

    Asset("IMAGE", "images/inventoryimages/book_kara.tex"),
    Asset("ATLAS", "images/inventoryimages/book_kara.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/kara.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/kara.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/kara_silho.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/kara_silho.xml"),

    Asset("IMAGE", "bigportraits/kara.tex"),
    Asset("ATLAS", "bigportraits/kara.xml"),

    Asset("IMAGE", "images/map_icons/kara.tex"),
    Asset("ATLAS", "images/map_icons/kara.xml"),

    Asset("IMAGE", "images/avatars/avatar_kara.tex"),
    Asset("ATLAS", "images/avatars/avatar_kara.xml"),

    Asset("IMAGE", "images/avatars/avatar_ghost_kara.tex"),
    Asset("ATLAS", "images/avatars/avatar_ghost_kara.xml"),

    Asset("IMAGE", "images/avatars/self_inspect_kara.tex"),
    Asset("ATLAS", "images/avatars/self_inspect_kara.xml"),

    Asset("IMAGE", "images/names_kara.tex"),
    Asset("ATLAS", "images/names_kara.xml"),

    Asset("IMAGE", "images/names_gold_kara.tex"),
    Asset("ATLAS", "images/names_gold_kara.xml"),
}

AddMinimapAtlas("images/map_icons/kara.xml")

local require = GLOBAL.require
local STRINGS = GLOBAL.STRINGS
local Vector3 = GLOBAL.Vector3

-- Таблицы и классы игрового движка берутся из GLOBAL, так как среда modmain изолирована.
-- Без этих псевдонимов ACTIONS может оказаться nil во время загрузки мода.
local ACTIONS = GLOBAL.ACTIONS
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local ActionHandler = GLOBAL.ActionHandler
local State = GLOBAL.State
local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH

-- =========================================================
-- СТРОКИ ПЕРСОНАЖА
-- =========================================================

STRINGS.CHARACTER_TITLES.kara = "The Sample Character"
STRINGS.CHARACTER_NAMES.kara = "Esc"
STRINGS.CHARACTER_DESCRIPTIONS.kara = "*Perk 1\n*Perk 2\n*Perk 3"
STRINGS.CHARACTER_QUOTES.kara = "\"Quote\""
STRINGS.CHARACTER_SURVIVABILITY.kara = "Slim"

STRINGS.CHARACTERS.kara = require "speech_kara"

STRINGS.NAMES.kara = "Kara"
STRINGS.SKIN_NAMES.kara_none = "Kara"

-- =========================================================
-- ЭКРАН ВЫБОРА ПЕРСОНАЖА
-- =========================================================

local skin_modes = {
    {
        type = "ghost_skin",
        anim_bank = "ghost",
        idle_anim = "idle",
        scale = 0.75,
        offset = { 0, -25 },
    },
}

AddModCharacter("kara", "FEMALE", skin_modes)



-- =========================================================
--   АЛЬБОМ КАРЫ
-- =========================================================

STRINGS.NAMES.KARA_SCANNERBOOK = "Album"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.KARA_SCANNERBOOK = "A field album for sketches of discovered creatures."
STRINGS.RECIPE_DESC.KARA_SCANNERBOOK = "Automatically sketches unknown creatures nearby."
STRINGS.ACTIONS.KARA_OPEN_ALBUM = "Open Album"

AddAction("KARA_OPEN_ALBUM", STRINGS.ACTIONS.KARA_OPEN_ALBUM, function(act)
    -- Клиент открывает окно в предположительно допустимом состоянии, а сервер проверяет действие.
    return act ~= nil and act.doer ~= nil and act.invobject ~= nil
        and act.invobject.prefab == "kara_scannerbook"
end)
ACTIONS.KARA_OPEN_ALBUM.rmb = true
ACTIONS.KARA_OPEN_ALBUM.priority = 1

AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions)
    if inst ~= nil and inst.prefab == "kara_scannerbook" then
        local equipped = doer ~= nil and doer.replica ~= nil
            and doer.replica.inventory ~= nil
            and doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst
        if not equipped then
            table.insert(actions, ACTIONS.KARA_OPEN_ALBUM)
        end
    end
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KARA_OPEN_ALBUM, "doshortaction"))

AddStategraphState("wilson_client", State{
    name = "kara_open_album",
    tags = { "doing", "busy" },
    server_states = { "doshortaction" },

    onenter = function(inst)
        local action = inst:GetBufferedAction()
        local invobject = action ~= nil and action.invobject or nil
        if invobject ~= nil and invobject.prefab == "kara_scannerbook" and GLOBAL.TheFrontEnd ~= nil then
            GLOBAL.TheFrontEnd:PushScreen(require("screens/kara_albumscreen")(inst))
        end
        inst:PerformPreviewBufferedAction()
        inst.sg:SetTimeout(0.5)
    end,

    onupdate = function(inst)
        if inst.sg:ServerStateMatches() then
            if inst.entity:FlattenMovementPrediction() then
                inst.sg:GoToState("idle", true)
            end
        elseif inst.bufferedaction == nil then
            inst.sg:GoToState("idle", true)
        end
    end,

    ontimeout = function(inst)
        inst:ClearBufferedAction()
        inst.sg:GoToState("idle", true)
    end,
})

AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KARA_OPEN_ALBUM, "kara_open_album"))

AddRecipe2("kara_scannerbook",
    { Ingredient("papyrus", 2), Ingredient("transistor", 1), Ingredient("goldnugget", 2) },
    TECH.SCIENCE_ONE,
    { atlas = "images/inventoryimages/book_kara.xml", image = "book_kara.tex" })

-- Личные заметки о существах отправляются с экрана альбома на сервер, а затем сохраняются
-- в обычных данных сохранения игрока Кары и передаются обратно клиенту-владельцу.
local function EncodeAlbumNotes(notes)
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

AddModRPCHandler("Kara", "SaveAlbumNote", function(player, prefab, note)
    if player == nil or not player:IsValid() or not player:HasTag("kara")
        or type(prefab) ~= "string" or type(note) ~= "string" then
        return
    end
    -- Игрок может оставить заметку только о существе, которое уже занесено в альбом.
    if player.kara_scanned_creatures == nil or not player.kara_scanned_creatures[prefab] then
        return
    end
    note = note:gsub("\r", ""):sub(1, 1200)
    player.kara_album_notes = player.kara_album_notes or {}
    if note == "" then
        player.kara_album_notes[prefab] = nil
    else
        player.kara_album_notes[prefab] = note
    end
    if player._kara_album_notes_net ~= nil then
        player._kara_album_notes_net:set(EncodeAlbumNotes(player.kara_album_notes))
    end
end)


-- Таблица кого рисуем и что получаем
-- имена рецептов (как в AddRecipe/AddRecipe2), которые откроются
local KARA_SKETCH_RECIPES = {
    spider    = { "trap" },        -- паук     -> ловушка
    bee       = { "beebox" },      -- пчела    -> улей
    pigman    = { "footballhat" }, -- свинья   -> футбольный шлем
    hound     = { "armorwood" },   -- гончая   -> деревянная броня
    butterfly = { "papyrus" },     -- бабочка  -> папирус
}
GLOBAL.KARA_SKETCH_RECIPES = KARA_SKETCH_RECIPES

-- Экшен "Зарисовать"
local SketchAction = AddAction("SKETCH", "Зарисовать", function(act)
    local doer, target = act.doer, act.target
    if doer ~= nil and target ~= nil and doer.components.karasketcher ~= nil then
        return doer.components.karasketcher:Start(target)
    end
    return false
end)
SketchAction.distance = 3


-- Обработчики действия зарисовки.
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.SKETCH, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.SKETCH, "doshortaction"))

-- Показываем «Зарисовать» только при наведении на подходящее живое существо,
-- когда книга Кары находится в руках.
AddComponentAction("EQUIPPED", "equippable", function(item, doer, target, actions, right)
    if right
        and item ~= nil and item.prefab == "kara_scannerbook"
        and target ~= nil and target ~= doer
        and target.prefab ~= nil
        and KARA_SKETCH_RECIPES[target.prefab] ~= nil
        and target.replica ~= nil and target.replica.health ~= nil
        and not target.replica.health:IsDead()
    then
        table.insert(actions, ACTIONS.SKETCH)
    end
end)

-- Сетевые переменные нужны и клиенту (для полоски), и серверу (для логики компонента).
local net_bool = GLOBAL.net_bool
local net_byte = GLOBAL.net_byte
local net_entity = GLOBAL.net_entity

local KaraSketchBar

local function UpdateKaraSketchBar(inst)
    if inst.HUD == nil or inst._karasketch_active == nil then
        return
    end

    if inst._karasketch_active:value() then
        if inst._karabar == nil then
            if KaraSketchBar == nil then
                KaraSketchBar = require("widgets/karasketchbar")
            end
            inst._karabar = (inst.HUD.root or inst.HUD):AddChild(KaraSketchBar(inst))
        end
        inst._karabar:SetTarget(inst._karasketch_target:value())
        inst._karabar:SetPercent(inst._karasketch_pct:value() / 100)
    elseif inst._karabar ~= nil then
        inst._karabar:Kill()
        inst._karabar = nil
    end
end

AddPlayerPostInit(function(inst)
    if inst.prefab ~= "kara" then
        return
    end

    inst._karasketch_active = net_bool(inst.GUID, "karasketch.active", "karasketchdirty")
    inst._karasketch_pct = net_byte(inst.GUID, "karasketch.pct", "karasketchdirty")
    inst._karasketch_target = net_entity(inst.GUID, "karasketch.target", "karasketchdirty")
    inst:ListenForEvent("karasketchdirty", UpdateKaraSketchBar)

    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        inst:AddComponent("karasketcher")
    end
end)



-- =========================================================
-- ДОПОЛНИТЕЛЬНЫЙ СЛОТ ИНВЕНТАРЯ НА ХВОСТЕ 
-- =========================================================

AddModRPCHandler("Kara", "TailSlotClick", function(player)
    if player ~= nil and player:IsValid() and player:HasTag("kara")
        and player.components.kara_tail_slot ~= nil then
        player.components.kara_tail_slot:HandleClick()
    end
end)

AddModRPCHandler("Kara", "TailSlotDrop", function(player)
    if player ~= nil and player:IsValid() and player:HasTag("kara")
        and player.components.kara_tail_slot ~= nil then
        player.components.kara_tail_slot:DropItem()
    end
end)

AddModRPCHandler("Kara", "TailSlotUse", function(player)
    if player ~= nil and player:IsValid() and player:HasTag("kara")
        and player.components.kara_tail_slot ~= nil then
        player.components.kara_tail_slot:UseItem()
    end
end)

-- Добавляем отдельный слот интерфейса слева и немного выше обычного
-- ряда инвентаря Кары. Это отдельный слот, а не дополнительная ячейка панели быстрого доступа, поэтому
-- индексы стандартного инвентаря и расположение рюкзака не меняются.
AddClassPostConstruct("widgets/inventorybar", function(inventorybar)
    local old_rebuild = inventorybar.Rebuild
    inventorybar.Rebuild = function(self, ...)
        -- Виджет интерфейса может создаться раньше, чем реплика инвентаря игрока
        -- будет готова. Не вызывайте стандартный Rebuild в этот короткий промежуток: его
        -- обычная реализация сразу обращается к owner.replica.inventory по индексу.
        -- Оставляем rebuild_pending включённым, чтобы Inventorybar:OnUpdate повторил попытку обычным способом.
        if self.owner == nil or self.owner.replica == nil
            or self.owner.replica.inventory == nil then
            self.rebuild_pending = true
            return
        end

        local result = old_rebuild(self, ...)
        self.kara_tail_slot = nil -- старый верхний ряд (и его дочерние элементы) был пересоздан

        if self.owner ~= nil and self.owner.prefab == "kara"
            and self.toprow ~= nil and self.inv ~= nil and self.inv[1] ~= nil then
            local TailSlotWidget = require "widgets/kara_tail_slot"
            local slot = self.toprow:AddChild(TailSlotWidget(self.owner))
            local first_pos = self.inv[1]:GetPosition()
            slot:SetPosition(first_pos.x - 82, 44, 0)
            slot.top_align_tip = 68
            slot:MoveToFront()
            self.kara_tail_slot = slot

            -- Навигация с контроллера: нажатие влево из первой обычной ячейки
            -- переводит фокус в дополнительный слот Кары; нажатие вправо возвращает его в ячейку инвентаря № 1.
            if self.inv[1] ~= nil then
                self.inv[1]:SetFocusChangeDir(GLOBAL.MOVE_LEFT, slot)
                slot:SetFocusChangeDir(GLOBAL.MOVE_RIGHT, self.inv[1])
            end
        end
        return result
    end

    -- Сделать слот доступным и при управлении с контроллера. Обычно игра
    -- перемещает фокус только по массивам self.inv/self.equip, поэтому явно связываем ячейку 1 с
    -- дополнительным слотом, не меняя индексы инвентаря.
    local old_cursor_nav = inventorybar.CursorNav
    inventorybar.CursorNav = function(self, dir, same_container_only)
        local tail = self.kara_tail_slot
        if tail ~= nil and tail.inst:IsValid() then
            if self.active_slot == self.inv[1] and dir.x < 0 then
                self.current_list = self.inv
                self:SelectSlot(tail)
                return true
            elseif self.active_slot == tail and dir.x > 0 then
                self.current_list = self.inv
                if self.inv[1] ~= nil then
                    self:SelectSlot(self.inv[1])
                    return true
                end
            end
        end
        return old_cursor_nav(self, dir, same_container_only)
    end

    -- Не запускайте Rebuild принудительно из обработчика после создания виджета. На этом этапе
    -- replica.inventory игрока всё ещё может быть nil. Inv уже устанавливает
    -- rebuild_pending во время создания, а стандартный обработчик OnUpdate
    -- пересоберёт интерфейс, когда реплика появится; наша обёртка Rebuild добавит слот.
end)

-- =========================================================
-- АНИМАЦИЯ ЧТЕНИЯ  
-- После записи НОВОГО вида проигрывается короткая стандартная анимация чтения книги,
-- но только когда персонаж неподвижен. Она не прерывает движение или бой.
-- =========================================================

local EventHandler = GLOBAL.EventHandler

local function MakeKaraScanbookState(is_client)
    local state = {
        name = "kara_scanbook",
        tags = { "doing", "busy" },
        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:Stop()
            end
            -- Повторяем стандартную последовательность использования книги: сначала открыть, затем читать.
            inst.AnimState:OverrideSymbol("book_open", "player_actions_uniqueitem", "book_open")
            inst.AnimState:OverrideSymbol("book_closed", "player_actions_uniqueitem", "book_closed")
            inst.AnimState:PlayAnimation("action_uniqueitem_pre")
            inst.AnimState:PushAnimation("book", false)

            -- Стандартные эффекты страниц и книги дают визуальную обратную связь во время зарисовки.
            if not is_client then
                local book_fx = GLOBAL.SpawnPrefab("book_fx")
                if book_fx ~= nil then
                    book_fx.entity:SetParent(inst.entity)
                    inst.sg.statemem.kara_book_fx = book_fx
                end
            end
            if inst.SoundEmitter ~= nil then
                inst.SoundEmitter:PlaySound("dontstarve/common/use_book_light")
            end
        end,
        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.SoundEmitter ~= nil then
                        inst.SoundEmitter:PlaySound("dontstarve/common/use_book_close")
                    end
                    -- Сообщать результат только после полного завершения анимации зарисовки.
                    if not is_client and inst.components.talker ~= nil then
                        local announcement = inst.kara_scan_pending_announcement
                        if announcement ~= nil then
                            inst.components.talker:Say(announcement)
                            inst.kara_scan_pending_announcement = nil
                            inst.kara_scan_pending_names = nil
                        end
                    end
                    inst.sg:GoToState("idle")
                end
            end),
        },
        onexit = function(inst)
            -- Восстанавливаем стандартные символы книги, используемые оригинальной игрой.
            inst.AnimState:OverrideSymbol("book_open", "player_actions_uniqueitem", "book_open")
            inst.AnimState:OverrideSymbol("book_closed", "player_actions_uniqueitem", "book_closed")
            local book_fx = inst.sg.statemem.kara_book_fx
            if book_fx ~= nil and book_fx:IsValid() then
                book_fx:Remove()
            end
        end,
    }
    if is_client then
        state.server_states = { "kara_scanbook" }
    end
    return State(state)
end

AddStategraphState("wilson", MakeKaraScanbookState(false))
AddStategraphState("wilson_client", MakeKaraScanbookState(true))

local function CanStartKaraScanbook(inst)
    return inst.sg ~= nil
        and inst.sg.currentstate ~= nil
        and inst.sg.currentstate.name == "idle"
        and not inst.sg:HasAnyStateTag("busy", "doing", "sleeping", "dead")
        and (inst.components.rider == nil or not inst.components.rider:IsRiding())
end

AddStategraphPostInit("wilson", function(sg)
    -- Это событие создаётся сервером после записи нового вида.
    sg.events["kara_new_album_entry"] = EventHandler("kara_new_album_entry", function(inst)
        if CanStartKaraScanbook(inst) then
            inst.sg:GoToState("kara_scanbook")
            if inst._kara_scan_anim ~= nil then
                inst._kara_scan_anim:push()
            end
        end
    end)
end)
