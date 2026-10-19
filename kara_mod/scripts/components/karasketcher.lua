local DURATION  = 5      -- секунд на полную зарисовку
local SLOWDOWN  = 0.4    -- множитель скорости во время зарисовки (в этом и риск)
local MAX_RANGE = 6      -- отойдёшь дальше — отмена
local TICK      = 3 * FRAMES

local function GetRecipes(target)
    return target ~= nil and KARA_SKETCH_RECIPES[target.prefab] or nil
end

local KaraSketcher = Class(function(self, inst)
    self.inst = inst
    self.target = nil
    self.progress = 0
    self.task = nil
    self._onattack = function() self:Stop("attack") end
end)

function KaraSketcher:IsActive()
    return self.target ~= nil
end

function KaraSketcher:HasTool()
    local inv = self.inst.components.inventory
    local hands = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    return hands ~= nil and hands.components.karasketchtool ~= nil
end

function KaraSketcher:KnowsAll(target)
    local recipes = GetRecipes(target)
    local builder = self.inst.components.builder
    if recipes == nil or builder == nil then return true end
    for _, r in ipairs(recipes) do
        if not builder:KnowsRecipe(r) then return false end
    end
    return true
end

function KaraSketcher:CanSketch(target)
    return target ~= nil
        and target:IsValid()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and GetRecipes(target) ~= nil
        and self.inst.components.builder ~= nil
        and self:HasTool()
        and not self:KnowsAll(target)
end

function KaraSketcher:Start(target)
    if self:IsActive() then
        if self.target == target then return true end
        self:Stop("retarget")
    end

    if not self:CanSketch(target) then
        if target ~= nil and self:KnowsAll(target) and self.inst.components.talker ~= nil then
            self.inst.components.talker:Say("Это я уже зарисовал(а).")
        end
        return false
    end

    self.target = target
    self.progress = 0

    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "karasketch", SLOWDOWN)
    end

    self.inst:ListenForEvent("onattackother", self._onattack)

    self.inst._karasketch_active:set(true)
    self.inst._karasketch_target:set(target)
    self.inst._karasketch_pct:set(0)

    self.task = self.inst:DoPeriodicTask(TICK, function() self:OnTick(TICK) end)
    return true
end

function KaraSketcher:OnTick(dt)
    local target = self.target
    if not self:CanSketch(target) then
        self:Stop("invalid")
        return
    end
    if self.inst:GetDistanceSqToInst(target) > MAX_RANGE * MAX_RANGE then
        self:Stop("toofar")
        return
    end

    self.progress = self.progress + dt
    local pct = self.progress / DURATION
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    self.inst._karasketch_pct:set(math.floor(pct * 100 + 0.5))

    if self.progress >= DURATION then
        self:Finish()
    end
end

function KaraSketcher:Finish()
    local target = self.target
    local recipes = GetRecipes(target)
    local builder = self.inst.components.builder
    if recipes ~= nil and builder ~= nil then
        for _, r in ipairs(recipes) do
            if not builder:KnowsRecipe(r) then
                builder:UnlockRecipe(r)
            end
        end
    end
    if self.inst.components.talker ~= nil then
        self.inst.components.talker:Say("Зарисовано! Новый рецепт получен.")
    end
    self.inst:PushEvent("karasketch_complete", { target = target })
    self:Stop("complete")
end

function KaraSketcher:Stop(reason)
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "karasketch")
    end
    self.inst:RemoveEventCallback("onattackother", self._onattack)

    self.target = nil
    self.progress = 0

    if self.inst._karasketch_active ~= nil then
        self.inst._karasketch_active:set(false)
        self.inst._karasketch_target:set(nil)
        self.inst._karasketch_pct:set(0)
    end
end

function KaraSketcher:OnRemoveFromEntity()
    self:Stop("removed")
end

return KaraSketcher