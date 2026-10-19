require "class"
local InvSlot = require "widgets/invslot"
local Image = require "widgets/image"

local KaraTailSlot = Class(InvSlot, function(self, owner)
    InvSlot._ctor(self, 1, "images/hud.xml", "inv_slot.tex", owner, owner.replica.inventory)
    self.owner = owner
    self:SetClickable(true)
    self.top_align_tip = 68
    -- Сохраняем обычный вид ячейки и обработку нажатий, но направляем щелчки в
    -- серверное хранилище одного предмета, а не в ячейку инвентаря № 1.
    self.container = owner.replica.inventory
    self.num = 1

    -- Тонкая пепельно-серебристая рамка сочетается с альбомом Кары, а не оставляет
    -- дополнительную ячейку в стандартном оформлении.
    self:CreateAshFrame()

    self.item_icon = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.item_icon:SetScale(0.62)
    self.item_icon:SetClickable(false)
    self.item_icon:Hide()

    self.inst:ListenForEvent("kara_tail_icon_dirty", function()
        self:RefreshTailItem()
    end, owner)
    self.inst:ListenForEvent("kara_tail_itemdirty", function()
        self:RefreshTailItem()
    end, owner)
    self.inst:ListenForEvent("refreshinventory", function()
        self:RefreshTailItem()
    end, owner)

    self:RefreshTailItem()
end)

function KaraTailSlot:CreateAshFrame()
    local w, h = self.bgimage:GetSize()
    if w == nil or w < 8 then w = 64 end
    if h == nil or h < 8 then h = 64 end

    self.ash_frame = {}
    local function line(width, height, x, y, r, g, b, a)
        local img = self:AddChild(Image("images/ui.xml", "white.tex"))
        img:SetSize(width, height)
        img:SetTint(r, g, b, a or 1)
        img:SetClickable(false)
        img:SetPosition(x, y, 0)
        self.ash_frame[#self.ash_frame + 1] = img
        return img
    end

    -- Внешняя графитовая кромка и тонкая светлая внутренняя линия создают рамку в стиле книги.
    local halfw, halfh = w * 0.5, h * 0.5
    local edge = 2
    line(w + 6, edge, 0, halfh + 2, 0.30, 0.32, 0.34, 0.95)
    line(w + 6, edge, 0, -halfh - 2, 0.30, 0.32, 0.34, 0.95)
    line(edge, h + 6, -halfw - 2, 0, 0.30, 0.32, 0.34, 0.95)
    line(edge, h + 6, halfw + 2, 0, 0.30, 0.32, 0.34, 0.95)
    line(w - 2, 1, 0, halfh - 3, 0.76, 0.78, 0.79, 0.9)
    line(w - 2, 1, 0, -halfh + 3, 0.54, 0.57, 0.59, 0.9)
    line(1, h - 2, -halfw + 3, 0, 0.76, 0.78, 0.79, 0.9)
    line(1, h - 2, halfw - 3, 0, 0.54, 0.57, 0.59, 0.9)
end

function KaraTailSlot:RefreshTailItem()
    local image = self.owner ~= nil and self.owner._kara_tail_item_image_net ~= nil
        and self.owner._kara_tail_item_image_net:value() or ""
    local atlas = self.owner ~= nil and self.owner._kara_tail_item_atlas_net ~= nil
        and self.owner._kara_tail_item_atlas_net:value() or ""

    if image ~= nil and image ~= "" and atlas ~= nil and atlas ~= "" then
        local ok = pcall(function()
            self.item_icon:SetTexture(atlas, image)
        end)
        if ok then
            self.item_icon:Show()
            self.item_icon:MoveToFront()
        else
            self.item_icon:Hide()
        end
    else
        self.item_icon:Hide()
    end
end

-- Ввод обрабатывается через InvSlot:OnControl, как и для обычных ячеек
-- инвентаря. Не переопределяйте OnMouseButton: маршрутизация фокуса виджета обеспечивает
-- одинаково корректную работу мыши, клавиатуры и контроллера.

function KaraTailSlot:Click(stack_mod)
    if self.owner ~= nil and self.owner.prefab == "kara"
        and MOD_RPC ~= nil and MOD_RPC.Kara ~= nil and MOD_RPC.Kara.TailSlotClick ~= nil then
        SendModRPCToServer(MOD_RPC.Kara.TailSlotClick)
    end
end

-- Щелчок правой кнопкой использует тот же выбор действий, что и обычная ячейка инвентаря.
function KaraTailSlot:UseItem()
    if self.owner ~= nil and self.owner.prefab == "kara"
        and MOD_RPC ~= nil and MOD_RPC.Kara ~= nil and MOD_RPC.Kara.TailSlotUse ~= nil then
        SendModRPCToServer(MOD_RPC.Kara.TailSlotUse)
    end
end

function KaraTailSlot:DropItem(single)
    if self.owner ~= nil and self.owner.prefab == "kara"
        and MOD_RPC ~= nil and MOD_RPC.Kara ~= nil and MOD_RPC.Kara.TailSlotDrop ~= nil then
        SendModRPCToServer(MOD_RPC.Kara.TailSlotDrop)
    end
end

return KaraTailSlot
