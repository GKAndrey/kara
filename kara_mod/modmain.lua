PrefabFiles =
{
	"kara",
	"kara_none",
	"book_kara",
    "kara_backpack",
}

Assets =
{
    Asset("IMAGE", "bigportraits/kara.tex"),
    Asset("ATLAS", "bigportraits/kara.xml"),

    Asset("IMAGE", "images/avatars/avatar_ghost_kara.tex"),
    Asset("ATLAS", "images/avatars/avatar_ghost_kara.xml"),
    Asset("IMAGE", "images/avatars/avatar_kara.tex"),
    Asset("ATLAS", "images/avatars/avatar_kara.xml"),
    Asset("IMAGE", "images/avatars/self_inspect_kara.tex"),
    Asset("ATLAS", "images/avatars/self_inspect_kara.xml"),

    Asset("IMAGE", "images/crafting_menu_avatars/avatar_kara.tex"),
    Asset("ATLAS", "images/crafting_menu_avatars/avatar_kara.xml"),

    Asset("IMAGE", "images/map_icons/kara.tex"),
    Asset("ATLAS", "images/map_icons/kara.xml"),

    Asset("IMAGE", "images/saveslot_portraits/kara.tex"),
    Asset("ATLAS", "images/saveslot_portraits/kara.xml"),
    
    Asset("IMAGE", "images/names_gold_kara.tex"),
    Asset("ATLAS", "images/names_gold_kara.xml"),
    Asset("IMAGE", "images/names_kara.tex"),
    Asset("ATLAS", "images/names_kara.xml"),
}

AddMinimapAtlas("images/map_icons/kara.xml")

local GLOBAL     = GLOBAL
local require    = GLOBAL.require
local ACTIONS    = GLOBAL.ACTIONS
local Ingredient = GLOBAL.Ingredient
local TECH       = GLOBAL.TECH
local ActionHandler = GLOBAL.ActionHandler
local net_bool   = GLOBAL.net_bool
local net_byte   = GLOBAL.net_byte
local net_entity = GLOBAL.net_entity

GLOBAL.STRINGS.NAMES.BOOK_KARA = "Книга Кары"
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.BOOK_KARA = "Зарисую любого, кто постоит смирно."
GLOBAL.STRINGS.CHARACTER_TITLES.kara = "The Character"
GLOBAL.STRINGS.CHARACTER_NAMES.kara = "Kara"
GLOBAL.STRINGS.CHARACTER_DESCRIPTIONS.kara = "*Perk 1\n*Perk 2\n*Perk 3"
GLOBAL.STRINGS.CHARACTER_QUOTES.kara = "\"...\""
GLOBAL.STRINGS.CHARACTER_SURVIVABILITY.kara = "Slim"
GLOBAL.STRINGS.CHARACTERS.KARA = require "speech_kara"
GLOBAL.STRINGS.NAMES.KARA = "Kara"
GLOBAL.STRINGS.SKIN_NAMES.kara_none = "Kara"

local skin_modes =
{
    { 
        type = "ghost_skin",
        anim_bank = "ghost",
        idle_anim = "idle", 
        scale = 0.75, 
        offset = { 0, -25 } 
    },
}

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

AddStategraphActionHandler("wilson",        ActionHandler(ACTIONS.SKETCH, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.SKETCH, "doshortaction"))

-- Показывать экшен по ПКМ, когда книга экипирована
AddComponentAction("EQUIPPED", "karasketchtool", function(inst, doer, target, actions, right)
    if right
        and target ~= nil and target ~= doer
        and KARA_SKETCH_RECIPES[target.prefab] ~= nil
        and target.replica.health ~= nil and not target.replica.health:IsDead()
    then
        table.insert(actions, ACTIONS.SKETCH)
    end
end)

-- Полоска прогресса (клиент) + логика (сервер)
local KaraSketchBar  -- подгрузим лениво, при первом показе полоски

local function UpdateKaraBar(inst)
    if inst.HUD == nil then return end  -- только у локального игрока есть HUD
    if inst._karasketch_active:value() then
        if inst._karabar == nil then
            if KaraSketchBar == nil then
                KaraSketchBar = require("widgets/karasketchbar")
            end
            local parent = inst.HUD.root or inst.HUD
            inst._karabar = parent:AddChild(KaraSketchBar(inst))
            print("[KARA] полоска создана")
        end
        inst._karabar:SetTarget(inst._karasketch_target:value())
        inst._karabar:SetPercent(inst._karasketch_pct:value() / 100)
    elseif inst._karabar ~= nil then
        inst._karabar:Kill()
        inst._karabar = nil
    end
end

AddPlayerPostInit(function(inst)
    inst._karasketch_active = net_bool(inst.GUID, "karasketch.active", "karasketchdirty")
    inst._karasketch_pct = net_byte(inst.GUID, "karasketch.pct", "karasketchdirty")
    inst._karasketch_target = net_entity(inst.GUID, "karasketch.target", "karasketchdirty")

    inst:ListenForEvent("karasketchdirty", UpdateKaraBar)

    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        inst:AddComponent("karasketcher")

        inst:DoTaskInTime(1, function()
            if inst.components.inventory == nil then
                return
            end

            -- Выдать книгу
            local book = GLOBAL.SpawnPrefab("book_kara")
            if book then
                inst.components.inventory:GiveItem(book)
            end

            -- Выдать рюкзак
            local backpack = GLOBAL.SpawnPrefab("kara_backpack")
            if backpack then
                inst.components.inventory:Equip(backpack)
            end
        end)
    end
end)

-- Рецепт книги для скетчей
if AddRecipe2 ~= nil then
    AddRecipe2("book_kara",
        { Ingredient("papyrus", 2), Ingredient("featherpencil", 1) },
        TECH.NONE,
        { atlas = "images/inventoryimages/book_kara.xml", image = "book_kara.tex" },
        { "TOOLS" })
end

AddModCharacter("kara", "FEMALE", skin_modes)
