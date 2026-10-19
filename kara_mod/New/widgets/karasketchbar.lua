local Widget = require "widgets/widget"
local Image  = require "widgets/image"

local W, H = 90, 14
local PAD  = 2
local VIRTUAL_H = 720

local KaraSketchBar = Class(Widget, function(self, owner)
    Widget._ctor(self, "KaraSketchBar")
    self.owner  = owner
    self.target = nil
    self.fillw  = W - PAD * 2

    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(W, H)
    self.bg:SetTint(0, 0, 0, 0.7)

    self.fill = self:AddChild(Image("images/global.xml", "square.tex"))
    self.fill:SetSize(self.fillw, H - PAD * 2)
    self.fill:SetTint(0.45, 0.8, 1.0, 1.0)

    self:SetPercent(0)
    self:StartUpdating()
end)

function KaraSketchBar:SetTarget(target)
    self.target = target
end

function KaraSketchBar:SetPercent(p)
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    self.fill:SetSize(math.max(1, self.fillw * p), H - PAD * 2)
    self.fill:SetPosition(-(self.fillw * (1 - p)) / 2, 0)  -- заполнение слева направо
end

function KaraSketchBar:OnUpdate(dt)
    local target = self.target
    if target == nil or not target:IsValid() then
        self:Hide()
        return
    end
    self:Show()

    local x, y, z = target.Transform:GetWorldPosition()
    local sx, sy  = TheSim:GetScreenPos(x, y, z)
    local w,  h   = TheSim:GetScreenSize()
    local scale   = h / VIRTUAL_H

    -- позиция относительно центра экрана, в виртуальных единицах HUD
    self:SetPosition((sx - w / 2) / scale, (sy - h / 2) / scale + 70)
end

return KaraSketchBar