local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local TextButton = require "widgets/textbutton"
local TextEdit = require "widgets/textedit"
local UIAnim = require "widgets/uianim"
-- [КАСТОМНЫЕ ИЗОБРАЖЕНИЯ АЛЬБОМА / ПАМЯТКА ХУДОЖНИКУ]
-- Сейчас альбом использует оригинальные анимационные изображения DST из scrapbookdata.
-- Чтобы заменить игровое изображение существа собственным рисунком, начните с функции AddCreatureArt()
-- ниже: добавьте условие для нужного prefab, которое создаёт Image с вашим атласом/текстурой
-- вместо UIAnim + entry.build/entry.bank. Зарегистрируйте новые файлы .xml/.tex в modmain.lua
-- (таблица Assets), а AddUnknownArt() оставьте запасным вариантом для существ без собственного изображения.
-- Эта вспомогательная функция также используется для значков связанных предметов, поэтому ограничьте ветку кастомных рисунков
-- prefab существами, если для связанных предметов должны продолжать использоваться изображения игрового Scrapbook.
local scrapbookdata = require("screens/redux/scrapbookdata")

local ROWS_PER_PAGE = 7
local ROW_HEIGHT = 54
local MAX_RELATED_ITEMS = 3

-- Исходные анимации имеют разные точки привязки и визуальные размеры. Эти небольшие
-- поправки для отдельных prefab выравнивают миниатюры относительно подписей строк.
local LIST_ART_Y_OFFSET = {
    bee = -68,
    killerbee = -52,
    beefalo = -25,
    butterfly = -18,
    crow = -25,
    noeyeddeer = -22,
    deer = -22,
    frog = -22,
}

-- В некоторых стандартных сборках Scrapbook много прозрачного пространства или
-- силуэт очень мал внутри своей рамки; поэтому масштаб таких изображений нужно немного увеличить.
local LIST_ART_SCALE = {
    bee = 1.45,
    killerbee = 1.35,
    beefalo = 1.30,
    butterfly = 1.16,
    crow = 1.22,
    noeyeddeer = 1.55,
    deer = 1.30,
    frog = 1.18,
}

-- У некоторых анимаций Scrapbook точки привязки или прозрачные поля располагают
-- видимый рисунок слишком близко к заголовку SKETCH. Опустите такие портреты
-- по отдельности, не меняя остальную часть страницы.
local DETAIL_ART_Y_OFFSET = {
    bee = -62,
    killerbee = -62,
    beefalo = -50,
    hound = -52,
    spider = -44,
    spider_dropper = -44,
    spider_hider = -44,
    spider_spitter = -44,
    spider_warrior = -44,
    spiderqueen = -36,
}

local function GetName(prefab)
    local names = STRINGS.NAMES or {}
    return names[string.upper(prefab)] or names[prefab] or prefab
end

local function DecodeNote(value)
    if value == nil or value == "" then return "" end
    return (value:gsub("%%(%x%x)", function(byte)
        return string.char(tonumber(byte, 16) or 32)
    end))
end

local function GetNotes(owner)
    local result = {}
    local netvar = owner ~= nil and owner._kara_album_notes_net or nil
    local raw = netvar ~= nil and netvar:value() or ""
    for part in string.gmatch(raw, "([^|]+)") do
        local prefab, encoded = string.match(part, "^([%w_]+)=(.*)$")
        if prefab ~= nil then result[prefab] = DecodeNote(encoded) end
    end
    return result
end

local function GetSketchDates(owner)
    local result = {}
    local netvar = owner ~= nil and owner._kara_album_dates_net or nil
    local raw = netvar ~= nil and netvar:value() or ""
    for part in string.gmatch(raw, "([^,]+)") do
        local prefab, day = string.match(part, "^([%w_]+)=(%d+)$")
        if prefab ~= nil then
            result[prefab] = tonumber(day)
        end
    end
    return result
end

-- [АЛЬБОМ: ЗАМЕНИТЬ ИГРОВОЙ РИСУНОК НА КАСТОМНЫЙ ЗДЕСЬ]

-- Это единственное место, где изображения Scrapbook выводятся в списке, на странице существа
-- и в полосе связанных предметов. Сейчас по умолчанию используются анимационные build и bank игрового Scrapbook.
-- В будущем для prefab с собственными рисунками создавайте Image из зарегистрированного пользовательского
-- атласа здесь; существующий путь через Scrapbook ниже оставьте запасным для всех остальных prefab.
local function AddCreatureArt(parent, prefab, x, y, scale, fit_width, fit_height, fit_scale_multiplier)
    local entry = scrapbookdata[prefab]
    if entry ~= nil and entry.build ~= nil and entry.bank ~= nil then
        local art = parent:AddChild(UIAnim())
        local state = art:GetAnimState()
        state:SetBuild(entry.build)
        state:SetBank(entry.bank)
        if entry.overridebuild then
            if type(entry.overridebuild) == "table" then
                for _, build in ipairs(entry.overridebuild) do state:AddOverrideBuild(build) end
            else
                state:AddOverrideBuild(entry.overridebuild)
            end
        end
        state:SetPercent(entry.anim or "idle", entry.animpercent or 0.25)
        state:Hide("mouseover")
        state:Hide("snow")
        if entry.hide ~= nil then
            for _, symbol in ipairs(entry.hide) do state:Hide(symbol) end
        end
        if entry.hidesymbol ~= nil then
            for _, symbol in ipairs(entry.hidesymbol) do state:HideSymbol(symbol) end
        end
        if entry.symbolcolours ~= nil then
            for _, values in ipairs(entry.symbolcolours) do
                state:SetSymbolMultColour(values[1], tonumber(values[2]) or 1,
                    tonumber(values[3]) or 1, tonumber(values[4]) or 1,
                    tonumber(values[5]) or 1)
            end
        end

        if fit_width ~= nil and fit_height ~= nil then
            -- Анимационные сборки существ и предметов имеют очень разные исходные размеры (пчела
            -- маленькая, а бифало огромное). Подгоняйте фактические границы рисунка под
            -- общую область интерфейса, чтобы все записи списка имели читаемый и одинаковый размер.
            local x1, y1, x2, y2 = state:GetVisualBB()
            local width = math.abs(x2 - x1)
            local height = math.abs(y2 - y1)
            if width < 1 or height < 1 then
                -- В некоторых записях Scrapbook нет пригодного кадра idle.
                -- Возвращаем отсутствие изображения, чтобы вызывающий код мог показать заметную заглушку.
                art:Kill()
                return nil
            end
            local fitted_scale = math.min(fit_width / width, fit_height / height, 0.70)
            fitted_scale = fitted_scale * (fit_scale_multiplier or 1)
            art:SetScale(fitted_scale)
            art:SetPosition(x - ((x1 + x2) * 0.5) * fitted_scale,
                y - ((y1 + y2) * 0.5) * fitted_scale)
        else
            art:SetScale(scale or 0.12)
            art:SetPosition(x, y)
        end
        return art
    end
    return nil
end

local function AddUnknownArt(parent, x, y, size)
    -- Всегда показывайте небольшую заглушку вместо пустого места, если
    -- в Scrapbook нет анимационной записи для существа из мода.
    local badge = parent:AddChild(Image("images/global.xml", "square.tex"))
    badge:ScaleToSize(size or 28, size or 28)
    badge:SetPosition(x, y)
    badge:SetTint(0.43, 0.44, 0.43, 1)
    local mark = parent:AddChild(Text(HEADERFONT, 20, "?"))
    mark:SetPosition(x, y - 1)
    mark:SetColour(0.90, 0.90, 0.88, 1)
    return badge
end

local function MakeLine(parent, width, x, y, alpha)
    local line = parent:AddChild(Image("images/global.xml", "square.tex"))
    line:ScaleToSize(width, 1)
    line:SetPosition(x, y)
    line:SetTint(0.35, 0.36, 0.36, alpha or 0.50)
    return line
end

-- Приглушённые пепельно-серые элементы сочетаются с бумагой альбома вместо
-- стандартной золотисто-белой палитры TextButton. Неактивные элементы остаются приглушёнными.
local function StyleBookButton(button, disabled)
    if button == nil then return end
    if disabled then
        button:SetTextColour(0.36, 0.37, 0.36, 1)
        button:SetTextFocusColour(0.40, 0.41, 0.40, 1)
    else
        button:SetTextColour(0.45, 0.46, 0.45, 1)
        button:SetTextFocusColour(0.54, 0.55, 0.54, 1)
    end
end

local KaraAlbumScreen = Class(Screen, function(self, owner)
    Screen._ctor(self, "KaraAlbumScreen")
    self.owner = owner
    self.page = 1
    self.selected_prefab = nil
    self.editing_note = false

    self.root = self:AddChild(Widget("kara-album-root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    local overlay = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    overlay.image:SetVRegPoint(ANCHOR_MIDDLE)
    overlay.image:SetHRegPoint(ANCHOR_MIDDLE)
    overlay:SetVAnchor(ANCHOR_MIDDLE)
    overlay:SetHAnchor(ANCHOR_MIDDLE)
    overlay:SetScaleMode(SCALEMODE_FILLSCREEN)
    overlay.image:SetTint(0, 0, 0, 0.72)
    overlay:SetOnClick(function() self:ExitScreen() end)
    overlay:SetClickable(true)

    self.panel = self.root:AddChild(Widget("kara-album-panel"))
    self.panel:SetVAnchor(ANCHOR_MIDDLE)
    self.panel:SetHAnchor(ANCHOR_MIDDLE)
    self.panel:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.panel:SetPosition(0, 0, 0)
    local panelbg = self.panel:AddChild(Image("images/global.xml", "square.tex"))
    panelbg:ScaleToSize(780, 590)
    panelbg:SetTint(0.25, 0.26, 0.27, 0.99)
    local inner = self.panel:AddChild(Image("images/global.xml", "square.tex"))
    inner:ScaleToSize(730, 500)
    inner:SetPosition(0, -12)
    inner:SetTint(0.74, 0.75, 0.74, 1)

    -- Вид списка
    self.list_title = self.panel:AddChild(Text(HEADERFONT, 34, "ALBUM"))
    self.list_title:SetPosition(0, 255)
    self.list_title:SetColour(0.91, 0.92, 0.90, 1)
    self.counter = self.panel:AddChild(Text(BODYTEXTFONT, 20, ""))
    self.counter:SetPosition(0, 213)
    self.counter:SetColour(0.32, 0.33, 0.32, 1)
    self.rows_root = self.panel:AddChild(Widget("album-rows"))
    self.rows_root:SetPosition(0, 165)

    self.prev_button = self.panel:AddChild(TextButton())
    self.prev_button:SetText("‹ Previous")
    self.prev_button:SetTextSize(24)
    StyleBookButton(self.prev_button, true)
    self.prev_button:SetPosition(-245, -235)
    self.prev_button:SetOnClick(function()
        if self.page > 1 then self.page = self.page - 1; self:Refresh() end
    end)
    self.next_button = self.panel:AddChild(TextButton())
    self.next_button:SetText("Next ›")
    self.next_button:SetTextSize(24)
    StyleBookButton(self.next_button, false)
    self.next_button:SetPosition(245, -235)
    self.next_button:SetOnClick(function()
        local pages = math.max(1, math.ceil(#self.prefabs / ROWS_PER_PAGE))
        if self.page < pages then self.page = self.page + 1; self:Refresh() end
    end)
    self.close_button = self.panel:AddChild(TextButton())
    self.close_button:SetText("Close")
    self.close_button:SetTextSize(24)
    StyleBookButton(self.close_button, false)
    self.close_button:SetPosition(0, -235)
    self.close_button:SetOnClick(function() self:ExitScreen() end)

    -- Разворот с подробной информацией создаётся один раз и переиспользуется для каждого существа.
    self.detail_root = self.panel:AddChild(Widget("album-detail-root"))
    self.detail_root:Hide()
    self.left_page = self.detail_root:AddChild(Image("images/global.xml", "square.tex"))
    self.left_page:ScaleToSize(340, 460)
    self.left_page:SetPosition(-174, -2)
    self.left_page:SetTint(0.76, 0.77, 0.76, 1)
    self.right_page = self.detail_root:AddChild(Image("images/global.xml", "square.tex"))
    self.right_page:ScaleToSize(340, 460)
    self.right_page:SetPosition(174, -2)
    self.right_page:SetTint(0.76, 0.77, 0.76, 1)
    MakeLine(self.detail_root, 2, 0, -2, 0.65)

    self.detail_title_left = self.detail_root:AddChild(Text(HEADERFONT, 21, "SKETCH"))
    self.detail_title_left:SetPosition(-174, 205)
    self.detail_title_left:SetColour(0.34, 0.35, 0.34, 1)
    self.detail_name_left = self.detail_root:AddChild(Text(HEADERFONT, 24, ""))
    self.detail_name_left:SetPosition(-174, -194)
    self.detail_name_left:SetRegionSize(300, 48)
    self.detail_name_left:SetColour(0.31, 0.32, 0.31, 1)

    self.detail_name_right = self.detail_root:AddChild(Text(HEADERFONT, 24, ""))
    self.detail_name_right:SetPosition(174, 205)
    self.detail_name_right:SetRegionSize(300, 40)
    self.detail_name_right:SetColour(0.31, 0.32, 0.31, 1)
    MakeLine(self.detail_root, 285, 174, 176, 0.45)

    self.related_title = self.detail_root:AddChild(Text(BODYTEXTFONT, 20, "RELATED ITEMS"))
    self.related_title:SetPosition(174, 151)
    self.related_title:SetColour(0.34, 0.35, 0.34, 1)
    self.related_root = self.detail_root:AddChild(Widget("album-related-items"))
    self.related_root:SetPosition(174, 104)
    MakeLine(self.detail_root, 285, 174, 64, 0.45)

    self.kara_comment = self.detail_root:AddChild(Text(BODYTEXTFONT, 17, ""))
    self.kara_comment:SetPosition(174, 36)
    self.kara_comment:SetRegionSize(285, 43)
    self.kara_comment:EnableWordWrap(true)
    self.kara_comment:SetColour(0.34, 0.35, 0.34, 1)

    self.notes_title = self.detail_root:AddChild(Text(BODYTEXTFONT, 19, "PLAYER NOTES"))
    self.notes_title:SetPosition(174, -5)
    self.notes_title:SetColour(0.34, 0.35, 0.34, 1)
    self.notes_text = self.detail_root:AddChild(Text(BODYTEXTFONT, 18, ""))
    self.notes_text:SetPosition(174, -75)
    self.notes_text:SetRegionSize(285, 100)
    self.notes_text:EnableWordWrap(true)
    self.notes_text:SetVAlign(ANCHOR_TOP)
    self.notes_text:SetColour(0.34, 0.35, 0.34, 1)

    self.note_button = self.detail_root:AddChild(TextButton())
    self.note_button:SetText("Write a note")
    self.note_button:SetTextSize(19)
    StyleBookButton(self.note_button, false)
    self.note_button:SetPosition(174, -153)
    self.note_button:SetOnClick(function() self:BeginEditNote() end)

    self.detail_back_button = self.detail_root:AddChild(TextButton())
    self.detail_back_button:SetText("‹ Back to list")
    self.detail_back_button:SetTextSize(22)
    StyleBookButton(self.detail_back_button, false)
    self.detail_back_button:SetPosition(-228, -235)
    self.detail_back_button:SetOnClick(function() self:CloseDetail() end)
    self.detail_close_button = self.detail_root:AddChild(TextButton())
    self.detail_close_button:SetText("Close")
    self.detail_close_button:SetTextSize(22)
    StyleBookButton(self.detail_close_button, false)
    self.detail_close_button:SetPosition(228, -235)
    self.detail_close_button:SetOnClick(function() self:ExitScreen() end)

    self:Refresh()
    self.default_focus = self.close_button
end)

function KaraAlbumScreen:GetPrefabs()
    local result = {}
    local netvar = self.owner ~= nil and self.owner._kara_album_net or nil
    local raw = netvar ~= nil and netvar:value() or ""
    for prefab in string.gmatch(raw, "([^,]+)") do result[#result + 1] = prefab end
    table.sort(result)
    return result
end

function KaraAlbumScreen:Refresh()
    self.prefabs = self:GetPrefabs()
    self.rows_root:KillAllChildren()
    local total = #self.prefabs
    local pages = math.max(1, math.ceil(total / ROWS_PER_PAGE))
    self.page = math.min(self.page, pages)
    self.counter:SetString(string.format("Sketches: %d   •   Page %d of %d", total, self.page, pages))
    StyleBookButton(self.prev_button, self.page <= 1)
    StyleBookButton(self.next_button, self.page >= pages)

    if total == 0 then
        local empty = self.rows_root:AddChild(Text(BODYTEXTFONT, 25, "No sketches yet. Hold the album and explore the world."))
        empty:SetPosition(0, -35)
        empty:SetColour(0.34, 0.35, 0.34, 1)
        return
    end

    local first = (self.page - 1) * ROWS_PER_PAGE + 1
    local last = math.min(total, first + ROWS_PER_PAGE - 1)
    local sketch_dates = GetSketchDates(self.owner)
    for index = first, last do
        local prefab = self.prefabs[index]
        local rownum = index - first
        local row = self.rows_root:AddChild(Widget("album-row-" .. prefab))
        row:SetPosition(0, -rownum * ROW_HEIGHT, 0)
        local separator = row:AddChild(Image("images/global.xml", "square.tex"))
        separator:ScaleToSize(680, 1)
        separator:SetPosition(0, -23)
        separator:SetTint(0.35, 0.36, 0.36, 0.48)
        local art_y = LIST_ART_Y_OFFSET[prefab] or -22
        local art = AddCreatureArt(row, prefab, -250, art_y, nil, 44, 36, LIST_ART_SCALE[prefab] or 1)
        if art == nil then
            -- Оставляйте заглушки неизвестных изображений по центру строки: у них нет точки привязки анимации для коррекции.
            AddUnknownArt(row, -250, 0, 27)
        end

        -- Используем TextButton из DST: он подгоняет прозрачную область нажатия под
        -- фактическую измеренную ширину текста. Старая ImageButton фиксированной ширины выходила
        -- на пустое пространство, из-за чего часть щелчков не попадала по видимой подписи, а часть
        -- пустых областей реагировала на нажатие. Сдвигайте вправо только текст, а изображение оставляйте на месте.
        local name = GetName(prefab)
        local name_button = row:AddChild(TextButton())
        name_button:SetFont(BODYTEXTFONT)
        name_button:SetTextSize(24)
        name_button:SetTextColour(0.31, 0.32, 0.31, 1)
        name_button:SetTextFocusColour(0.24, 0.25, 0.24, 1)
        name_button:SetText(name)
        local text_width = name_button:GetSize()
        if type(text_width) ~= "number" or text_width <= 0 then
            text_width = math.max(44, #name * 11)
        end
        local label_left = -80
        name_button:SetPosition(label_left + text_width * 0.5, -7)
        name_button:SetOnClick(function() self:OpenDetail(prefab) end)
        name_button:SetHelpTextMessage("Open " .. name)

        -- Короткая игровая дата размещается в свободной правой части строки.
        -- Для существ, найденных в сохранениях до появления учёта дат, показываем явное
        -- значение «неизвестно», а не делаем вид, будто они были зарисованы сегодня.
        local day = sketch_dates[prefab]
        local date_label = row:AddChild(Text(BODYTEXTFONT, 16,
            day ~= nil and ("Day " .. tostring(day)) or "Day unknown"))
        date_label:SetPosition(248, -7)
        date_label:SetRegionSize(112, 24)
        date_label:SetColour(0.43, 0.44, 0.43, 1)
    end
end

function KaraAlbumScreen:GetKaraComment(prefab)
    local comments = {
        butterfly = "Pretty. Best not to sketch one at full speed.",
        rabbit = "Small, fluffy, and suspiciously fast.",
        beefalo = "Best approach with respect. And from a distance.",
        spider = "The sketch came out nicely. Must remove the web from the page later.",
        hound = "Lots of teeth. Not much love for artists.",
        deerclops = "I drew quickly. Very quickly.",
        tentacle = "I'm not sure which part was supposed to be the head.",
        pigman = "Looks friendly. Until you touch its food.",
        butterflywings = "Technically, these are wings, not a creature. Still pretty, though."
    }
    return comments[prefab] or "Kara's observation: worth a closer look. Preferably from a safe distance."
end

function KaraAlbumScreen:OpenDetail(prefab)
    self.selected_prefab = prefab
    self.list_title:Hide()
    self.counter:Hide()
    self.rows_root:Hide()
    self.prev_button:Hide()
    self.next_button:Hide()
    self.close_button:Hide()
    self.detail_root:Show()
    self:BuildDetail(prefab)
end

function KaraAlbumScreen:BuildDetail(prefab)
    local name = GetName(prefab)
    self.detail_name_left:SetString(name)
    self.detail_name_right:SetString(name)
    self.kara_comment:SetString(self:GetKaraComment(prefab))

    if self.detail_art ~= nil then
        self.detail_art:Kill()
        self.detail_art = nil
    end
    -- На левой странице отображается увеличенный портрет в стиле Scrapbook. У некоторых записей
    -- очень крупные bank, поэтому изображение нужно держать умеренного размера, чтобы оно помещалось на странице.
    local scrapbook_entry = scrapbookdata[prefab]
    local detail_art_scale = scrapbook_entry ~= nil and scrapbook_entry.subcat == "bird" and 0.90 or 1
    local detail_art_y = 12 + (DETAIL_ART_Y_OFFSET[prefab]
        or (scrapbook_entry ~= nil and scrapbook_entry.subcat == "spider" and -44 or 0))
    self.detail_art = AddCreatureArt(self.detail_root, prefab, -174, detail_art_y, nil, 205, 250, detail_art_scale)
    if self.detail_art == nil then
        self.detail_art = self.detail_root:AddChild(Widget("album-detail-art-fallback-" .. prefab))
        AddUnknownArt(self.detail_art, 0, 0, 58)
    end

    self.related_root:KillAllChildren()
    local entry = scrapbookdata[prefab]
    local related = {}
    if entry ~= nil and entry.deps ~= nil then
        for _, dep in ipairs(entry.deps) do
            local depentry = scrapbookdata[dep]
            if depentry ~= nil and depentry.build ~= nil and depentry.bank ~= nil
                and (depentry.type == "item" or depentry.type == "food") then
                related[#related + 1] = dep
                if #related >= MAX_RELATED_ITEMS then break end
            end
        end
    end
    if #related == 0 then
        local noitems = self.related_root:AddChild(Text(BODYTEXTFONT, 16, "No related items recorded"))
        noitems:SetPosition(0, -2)
        noitems:SetColour(0.36, 0.37, 0.36, 1)
    else
        for i, itemprefab in ipairs(related) do
            local x = (i - (#related + 1) / 2) * 90
            local art = AddCreatureArt(self.related_root, itemprefab, x, 4, nil, 34, 27)
            if art == nil then
                AddUnknownArt(self.related_root, x, 4, 22)
            end
            local itemname = GetName(itemprefab)
            local label = self.related_root:AddChild(Text(BODYTEXTFONT, 13, itemname))
            label:SetPosition(x, -27)
            label:SetRegionSize(82, 28)
            label:EnableWordWrap(true)
            label:SetColour(0.34, 0.35, 0.34, 1)
        end
    end

    local notes = GetNotes(self.owner)
    local note = notes[prefab] or ""
    self.notes_text:SetString(note ~= "" and note or "No notes yet. Click \"Write a note\" to add your own.")
    self.note_button:SetText(note ~= "" and "Edit note" or "Write a note")
    self.notes_text:Show()
    self.note_button:Show()
    self:CancelEditNote()
    self.default_focus = self.detail_back_button
end

function KaraAlbumScreen:ExitScreen()
    if self.note_editor ~= nil then
        self:CancelEditNote()
    end
    TheFrontEnd:PopScreen()
end

function KaraAlbumScreen:CloseDetail()
    if self.note_editor ~= nil then
        self:CancelEditNote()
    end
    self.detail_root:Hide()
    self.selected_prefab = nil
    self.list_title:Show()
    self.counter:Show()
    self.rows_root:Show()
    self.prev_button:Show()
    self.next_button:Show()
    self.close_button:Show()
    self.default_focus = self.close_button
end

function KaraAlbumScreen:BeginEditNote()
    -- Редактирование текста создаётся заново для каждой записи, чтобы несохранённый ввод не переносился на другое существо.
    if self.note_editor ~= nil then self.note_editor:Kill() end
    self.note_button:Hide()
    self.notes_text:Hide()
    local existing = GetNotes(self.owner)[self.selected_prefab] or ""
    self.note_editor = self.detail_root:AddChild(TextEdit(BODYTEXTFONT, 17, existing))
    self.note_editor:SetPosition(174, -75)
    self.note_editor:SetRegionSize(285, 108)
    self.note_editor:SetVAlign(ANCHOR_TOP)
    self.note_editor:EnableWordWrap(true)
    self.note_editor:SetAllowNewline(true)
    self.note_editor:SetTextLengthLimit(350)
    self.note_editor:SetTextPrompt("Write an observation about this creature...", { 0.45, 0.36, 0.25, 1 })
    self.note_editor:SetForceEdit(true)
    self.note_editor:SetHelpTextEdit("")
    self.note_editor:SetHelpTextApply("Save")
    self.note_editor:SetEditing(true)

    self.save_note_button = self.detail_root:AddChild(TextButton())
    self.save_note_button:SetText("Save")
    self.save_note_button:SetTextSize(18)
    StyleBookButton(self.save_note_button, false)
    self.save_note_button:SetPosition(110, -153)
    self.save_note_button:SetOnClick(function() self:SaveNote() end)
    self.cancel_note_button = self.detail_root:AddChild(TextButton())
    self.cancel_note_button:SetText("Cancel")
    self.cancel_note_button:SetTextSize(18)
    StyleBookButton(self.cancel_note_button, false)
    self.cancel_note_button:SetPosition(235, -153)
    self.cancel_note_button:SetOnClick(function() self:CancelEditNote() end)
end

function KaraAlbumScreen:CancelEditNote()
    if self.note_editor ~= nil then
        self.note_editor:SetEditing(false)
        self.note_editor:Kill()
        self.note_editor = nil
    end
    if self.save_note_button ~= nil then self.save_note_button:Kill(); self.save_note_button = nil end
    if self.cancel_note_button ~= nil then self.cancel_note_button:Kill(); self.cancel_note_button = nil end
    self.notes_text:Show()
    self.note_button:Show()
    self.editing_note = false
end

function KaraAlbumScreen:SaveNote()
    if self.note_editor == nil or self.selected_prefab == nil then return end
    local text = self.note_editor:GetString() or ""
    text = string.gsub(text, "\r", "")
    if #text > 1200 then text = string.sub(text, 1, 1200) end
    self.note_editor:SetEditing(false)
    local rpc = GetModRPC("Kara", "SaveAlbumNote")
    if rpc ~= nil then
        SendModRPCToServer(rpc, self.selected_prefab, text)
    end
    -- Показываем текст сразу; окончательная версия сохраняется на сервере.
    self.notes_text:SetString(text ~= "" and text or "No notes yet. Click \"Write a note\" to add your own.")
    self.note_button:SetText(text ~= "" and "Edit note" or "Write a note")
    self:CancelEditNote()
    self.default_focus = self.detail_back_button
end

function KaraAlbumScreen:OnControl(control, down)
    if KaraAlbumScreen._base.OnControl(self, control, down) then return true end
    if not down and (control == CONTROL_CANCEL or control == CONTROL_MENU_BACK) then
        if self.note_editor ~= nil then
            self:CancelEditNote()
        elseif self.selected_prefab ~= nil then
            self:CloseDetail()
            self.selected_prefab = nil
        else
            self:ExitScreen()
        end
        return true
    end
    return false
end

function KaraAlbumScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " Back"
end

return KaraAlbumScreen
