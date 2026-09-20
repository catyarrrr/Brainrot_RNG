local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local CardSlot = ReplicatedStorage.Assets.UI.CardSlot

--==============================================================================
-- 常量与共享状态
--==============================================================================

-- 逻辑常量
local TURN_INTERVAL = .8         -- 主循环间隔（秒），即每次相撞的节奏
local COUNTDOWN_TIME = 3         -- 开场倒计时秒数
local CLASH_OFFSET = .14         -- 相撞时双方朝中间移动的距离（Scale）

-- 模块自身：既是状态机的 owner，也是对外暴露的接口表
local self = {RefreshAll = nil, ApplyTurn = nil, SetFighter = nil}

-- 单局战斗的运行时状态
local state = {
    Running = false,            -- 主循环是否运行中
    Counting = false,           -- 是否处于开场倒计时
    Token = 0,                  -- 局次令牌，用于取消旧的循环/倒计时
    Machine = nil,              -- 状态机实例
    Container = nil,            -- fightFrame.Battle
    LeftHolder = nil,           -- 我方卡牌容器（Battle.L1）
    RightHolder = nil,          -- 敌方卡牌容器（Battle.R1）
    LeftCard = nil,             -- 我方卡牌（L1.Frame）
    RightCard = nil,            -- 敌方卡牌（R1.Frame）
    LeftRest = nil,             -- 我方容器静止位置
    RightRest = nil,            -- 敌方容器静止位置
    AllyList = nil,             -- 我方出战列表（按顺序）
    EnemyList = nil,            -- 敌方出战列表（按顺序）
    AllyIndex = 1,              -- 我方当前出战下标
    EnemyIndex = 1,             -- 敌方当前出战下标
    AllyHP = 0,                 -- 我方当前单位血量
    EnemyHP = 0,                -- 敌方当前单位血量
    Turns = {},                 -- 服务端结算好的逐回合日志
    TurnCount = 0,              -- 回合总数
    TurnIndex = 1,              -- 下一回合日志下标
    TimerToken = 0,             -- 计时线程令牌
    ResultWinner = nil,         -- 服务端结算的胜方
    Winner = nil,               -- 结算后的胜方
    OnFinished = nil,           -- 结束回调 function(winner)
}

-- 前向声明：以下函数在文件底部的 UI 段实现，会被状态机/核心逻辑提前引用
local GetIcon, GetCardLabel, SetLabelText, SpawnDamageText, Countdown, StartTimer = nil

--==============================================================================
-- 状态机定义
--   Idle -> Prepare -> Attacking -> Finished
--==============================================================================

local States = {
    Idle = {
        name = 'Idle',
    },
    -- 准备：清场并铺好双方首发卡牌，随后进入开场倒计时
    Prepare = {
        name = 'Prepare',
        enter = function(owner)
            self:Clear()
            state.AllyIndex = 1
            state.EnemyIndex = 1
            self:SetFighter('L')
            self:SetFighter('R')
            state.Counting = true
            task.defer(Countdown, owner)
        end,
        update = function(owner)
            if state.Counting then return end  -- 倒计时结束前不开打
            owner:SetState('Attacking')
        end,
    },
    -- 战斗：按服务端下发的回合日志逐条播放相撞，直到日志播完或一方全灭
    Attacking = {
        name = 'Attacking',
        enter = function(owner)
            shared.SoundHandler:Play('BattleStart')
            task.spawn(StartTimer)
        end,
        update = function(owner)
            if state.AllyIndex > #state.AllyList or state.EnemyIndex > #state.EnemyList then
                owner:SetState('Finished')
                return
            end

            if state.TurnIndex > state.TurnCount then
                owner:SetState('Finished')
                return
            end

            local turn = state.Turns[state.TurnIndex]
            if turn == nil then
                owner:SetState('Finished')
                return
            end

            state.TurnIndex += 1
            self:ApplyTurn(turn)
        end,
    },
    -- 结束：判定胜方并回调
    Finished = {
        name = 'Finished',
        enter = function(owner)
            state.Running = false
            state.TimerToken += 1
            state.Winner = state.ResultWinner or (state.AllyIndex <= #state.AllyList and 'L' or 'R')
            if state.Winner == 'L' then
                shared.SoundHandler:Play('BattleWin')
            else
                shared.SoundHandler:Play('BattleLose')
            end
            if state.OnFinished then state.OnFinished(state.Winner) end
        end,
    },
}

--==============================================================================
-- 核心流程：启动 / 停止 / 清场 / 主循环 / 状态转发
--==============================================================================

-- 开始一局战斗。result 为服务端回传的结算结果：
--   { Ally = { { TowerUID, DPS, ... }, ... }, Enemy = { ... }, Seed = number, Winner = 'L'|'R' }
--   客户端用同一 seed 复现服务端的战斗过程。
function self:Start(fightFrame, result, onFinished)
    state.Container = fightFrame and fightFrame:FindFirstChild('Battle')
    state.AllyList = result.Ally or {}
    state.EnemyList = result.Enemy or {}
    if state.Container == nil then warn('[PVP Battle] Battle container not found'); return end

    state.LeftHolder = state.Container:FindFirstChild('L1')
    state.RightHolder = state.Container:FindFirstChild('R1')
    state.LeftCard = nil
    state.RightCard = nil

    --	容器里原有的占位 Frame 不再使用，卡面改为按品质克隆 Assets.UI.CardSlot
    for _, holder in ipairs({state.LeftHolder, state.RightHolder}) do
        if holder ~= nil then
            local placeholder = holder:FindFirstChild('Frame')
            if placeholder ~= nil then placeholder:Destroy() end
        end
    end

    state.LeftRest = state.LeftHolder and state.LeftHolder.Position
    state.RightRest = state.RightHolder and state.RightHolder.Position

    local sim = shared.PVPBattle.Simulate(result.Ally, result.Enemy, result.Seed)
    state.Turns = sim.Turns or {}
    state.TurnCount = #state.Turns
    state.TurnIndex = 1
    state.ResultWinner = result.Winner or sim.Winner
    state.OnFinished = onFinished

    state.Machine = shared.StateMachine.new(States, self)
    self:SetState('Prepare')
    self:Run()
end

-- 停止战斗并回到 Idle
function self:Stop()
    state.Running = false
    state.Counting = false
    self:SetState('Idle')
end

-- 清空本局运行时状态，并重置双方卡牌
function self:Clear()
    state.Running = false
    state.Counting = false
    state.Token += 1
    state.TimerToken += 1
    state.Winner = nil

    if state.Container == nil then return end
    local countdown = state.Container:FindFirstChild('CountdownFight')
    if countdown then countdown.Text = '' end
    local timer = state.Container:FindFirstChild('Timer')
    if timer then timer.Text = '00:00' end

    for _, child in state.Container:GetChildren() do
        if child:IsA('GuiObject') and child:GetAttribute('Attacking') then child:Destroy() end
    end

    self:ClearCard('L')
    self:ClearCard('R')
    self:ResetHolder(self.LeftHolder, self.LeftRest)
    self:ResetHolder(self.RightHolder, self.RightRest)
end

-- 把某方容器恢复为静止位置
function self:ResetHolder(holder, rest)
    if holder == nil then return end
    if rest ~= nil then holder.Position = rest end
end

-- 移除某方当前卡牌
function self:ClearCard(side)
    local card = side == 'L' and state.LeftCard or state.RightCard
    if card ~= nil and card.Parent ~= nil then card:Destroy() end
    if side == 'L' then state.LeftCard = nil else state.RightCard = nil end
end

-- 按品质克隆 Assets.UI.CardSlot 作为卡面
function self:CreateCard(side, quality)
    self:ClearCard(side)
    local holder = side == 'L' and state.LeftHolder or state.RightHolder
    if holder == nil then return nil end

    local template = CardSlot:FindFirstChild('Card' .. tostring(quality)) or CardSlot:FindFirstChild('CardCommon')
    if template == nil then return nil end

    local card = template:Clone()
    card.Name = 'Card'
    card.AnchorPoint = Vector2.new(.5, .5)
    card.Position = UDim2.fromScale(.5, .5)
    card.Size = UDim2.fromScale(1, 1)

    --	战斗卡面只保留名字/图标：隐藏棋盘用的星级与收益文字
    local label = card:FindFirstChild('Frame') and card.Frame:FindFirstChild('Label')
    if label ~= nil then
        local line = label:FindFirstChild('Line')
        if line ~= nil then line.Visible = false end
        local mutations = label:FindFirstChild('Mutations')
        if mutations ~= nil then
            for _, mutation in ipairs(mutations:GetChildren()) do mutation.Visible = false end
        end
    end

    card.Parent = holder

    if side == 'L' then state.LeftCard = card else state.RightCard = card end
    return card
end

-- 启动主循环：按 TURN_INTERVAL 的节奏驱动状态机 Update
function self:Run()
    state.Running = true
    state.Token += 1
    local token = state.Token

    task.spawn(function()
        while state.Running and state.Token == token do
            self:Update(TURN_INTERVAL)
            task.wait(TURN_INTERVAL)
        end
    end)
end

-- 状态机转发
function self:SetState(name)
    if state.Machine == nil then return end
    state.Machine:SetState(name)
end

function self:GetState()
    if state.Machine == nil then return nil end
    return state.Machine:GetState()
end

function self:Update(dt)
    if state.Machine == nil then return end
    state.Machine:Update(dt)
end

--==============================================================================
-- 战斗结算
--==============================================================================

-- 按服务端回合日志播放一次相撞：双方互相扣血并播放表现
function self:ApplyTurn(turn)
    if turn == nil then return end

    self:PlayClash(turn)

    if turn.Ally ~= nil then
        state.AllyHP = turn.Ally.HP or state.AllyHP
        SetLabelText(state.LeftCard, 'HP', 'HP: ' .. shared.Tool.FormatNumber(math.max(0, math.floor(state.AllyHP))))
    end
    if turn.Enemy ~= nil then
        state.EnemyHP = turn.Enemy.HP or state.EnemyHP
        SetLabelText(state.RightCard, 'HP', 'HP: ' .. shared.Tool.FormatNumber(math.max(0, math.floor(state.EnemyHP))))
    end

    local allyDead = turn.Ally ~= nil and turn.Ally.Dead == true
    local enemyDead = turn.Enemy ~= nil and turn.Enemy.Dead == true

    if allyDead then self:PlayDeath(state.LeftCard) end
    if enemyDead then self:PlayDeath(state.RightCard) end

    if allyDead then state.AllyIndex += 1 end
    if enemyDead then state.EnemyIndex += 1 end

    -- 阵亡后由下一名替补出场
    if allyDead and state.AllyIndex <= #state.AllyList then
        self:SetFighter('L')
    end
    if enemyDead and state.EnemyIndex <= #state.EnemyList then
        self:SetFighter('R')
    end
end

-- 渲染某一方当前出战单位到卡牌上
function self:SetFighter(side)
    local list = side == 'L' and state.AllyList or state.EnemyList
    local index = side == 'L' and state.AllyIndex or state.EnemyIndex
    local info = list and list[index]
    if info == nil then
        self:ClearCard(side)
        return
    end

    self:ResetHolder(side == 'L' and state.LeftHolder or state.RightHolder, side == 'L' and state.LeftRest or state.RightRest)

    local staticData = TowerData.GetData(info.TowerUID)
    local quality = (staticData and staticData.Quality) or 'Common'
    local card = self:CreateCard(side, quality)
    if card == nil then return end

    local hp = info.DPS or 0
    if side == 'L' then
        state.AllyHP = hp
    else
        state.EnemyHP = hp
    end

    local label = GetCardLabel(card)
    if label ~= nil then
        local nameText = label:FindFirstChild('NameText')
        if nameText and staticData then nameText.Text = staticData.DisplayName end
        local icon = label:FindFirstChild('Icon')
        if icon then
            local image = GetIcon(info.TowerUID)
            if image then icon.Image = image end
        end
    end
end

--==============================================================================
-- UI 表现
--==============================================================================

-- 出手/受击动画参数
local CLASH_TIME = .18           -- 相撞前冲/回位时长（秒）
local ATTACK_Z_INDEX = 100

-- 飘字样式（外观取自 ReplicatedStorage.Assets.UI.DamageGui.TextLabel）
local DAMAGE_TEXT_TEMPLATE = ReplicatedStorage.Assets.UI.DamageGui.TextLabel
local DAMAGE_TEXT_COUNTER_COLOR = Color3.fromRGB(255, 196, 40)   -- 克制命中颜色
local DAMAGE_TEXT_COUNTER_STROKE = Color3.fromRGB(120, 55, 0)    -- 克制命中描边
local DAMAGE_TEXT_COUNTER_TILT = 25                              -- 克制命中旋转角度
local DAMAGE_TEXT_MISS_COLOR = Color3.fromRGB(170, 170, 170)     -- Miss 颜色
local DAMAGE_TEXT_RISE = UDim2.fromScale(.5, -.1)  -- 飘字上浮终点
local DAMAGE_TEXT_LIFE = 1.2                       -- 飘字时长（秒）

-- 受击表现
local HIT_SHAKE_X = {4, -4, 3, -3, 2, -2}
local HIT_SHAKE_STEP = .03
local HIT_FLASH_COLOR = Color3.fromRGB(255, 255, 255)
local HIT_FLASH_TRANSPARENCY = .35
local HIT_FLASH_TIME = .2

-- 相撞表现：双方朝中间冲刺撞击，弹出伤害数字并晃动，随后各自归位
function self:PlayClash(turn)
    local leftHolder = state.LeftHolder
    local rightHolder = state.RightHolder
    local info = TweenInfo.new(CLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    if leftHolder ~= nil and state.LeftRest ~= nil then
        local target = UDim2.new(state.LeftRest.X.Scale + CLASH_OFFSET, state.LeftRest.X.Offset, state.LeftRest.Y.Scale, state.LeftRest.Y.Offset)
        TweenService:Create(leftHolder, info, {Position = target}):Play()
    end
    if rightHolder ~= nil and state.RightRest ~= nil then
        local target = UDim2.new(state.RightRest.X.Scale - CLASH_OFFSET, state.RightRest.X.Offset, state.RightRest.Y.Scale, state.RightRest.Y.Offset)
        TweenService:Create(rightHolder, info, {Position = target}):Play()
    end

    task.wait(CLASH_TIME)

    -- 命中飘字：我方伤害落在敌方卡牌上，敌方伤害落在我方卡牌上
    if turn.Enemy ~= nil then
        SpawnDamageText(state.LeftCard, turn.Enemy.Damage, turn.Enemy.Miss, turn.Enemy.Counter)
        self:PlayHit(state.LeftCard)
    end
    if turn.Ally ~= nil then
        SpawnDamageText(state.RightCard, turn.Ally.Damage, turn.Ally.Miss, turn.Ally.Counter)
        self:PlayHit(state.RightCard)
    end

    task.wait(.08)

    if leftHolder ~= nil and state.LeftRest ~= nil then
        TweenService:Create(leftHolder, info, {Position = state.LeftRest}):Play()
    end
    if rightHolder ~= nil and state.RightRest ~= nil then
        TweenService:Create(rightHolder, info, {Position = state.RightRest}):Play()
    end

    task.wait(CLASH_TIME)
end

-- 阵亡表现：卡牌缩放归零后隐藏
function self:PlayDeath(card)
    if card == nil or card.Parent == nil then return end

    local scale = card:FindFirstChildOfClass('UIScale')
    if scale == nil then
        scale = Instance.new('UIScale')
        scale.Parent = card
    end

    local tween = TweenService:Create(scale, TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
    tween:Play()
    tween.Completed:Wait()
    card.Visible = false
end

-- 根据 TowerUID 取卡面图标
function GetIcon(towerUID)
    local assetId = TowerData.GetAssetIdByTowerUID(towerUID)
    if assetId == nil then return nil end
    local asset = AssetsData[assetId]
    return asset and asset.Icon
end

-- 取卡牌的 Label（兼容 Label 直接挂在卡牌下 / 嵌套在 Frame 下两种结构）
function GetCardLabel(card)
    if card == nil then return nil end
    local label = card:FindFirstChild('Label')
    if label ~= nil then return label end
    local inner = card:FindFirstChild('Frame')
    if inner ~= nil then return inner:FindFirstChild('Label') end
    return nil
end

-- 设置卡牌 Label 下某个字段的文字
function SetLabelText(card, field, text)
    local label = GetCardLabel(card)
    if label == nil then return end
    local target = label:FindFirstChild(field)
    if target then target.Text = text end
end

-- 在卡牌上方生成一个上浮淡出的飘字（Miss 显示 MISS；克制命中强化）
function SpawnDamageText(card, damage, isMiss, isCounter)
    --	音效：闪避 / 克制超额伤害 / 普通伤害
    if isMiss then
        shared.SoundHandler:Play('Dodge')
    elseif isCounter then
        shared.SoundHandler:Play('Hhit')
    else
        shared.SoundHandler:Play('Hit')
    end

    if card == nil or card.Parent == nil or DAMAGE_TEXT_TEMPLATE == nil then return end

    local text = DAMAGE_TEXT_TEMPLATE:Clone()
    text.Name = 'DamageText'
    text.AnchorPoint = Vector2.new(.5, .5)
    text.Position = UDim2.fromScale(.5, .35)
    text.Text = isMiss and 'MISS' or ('-' .. shared.Tool.FormatNumber(math.floor(damage)))
    text.TextTransparency = 0
    text.ZIndex = 10
    text.TextScaled = true

    if isCounter and not isMiss then
        text.Size = UDim2.fromScale(2.1, .85)
        text.TextColor3 = DAMAGE_TEXT_COUNTER_COLOR
        text.TextStrokeColor3 = DAMAGE_TEXT_COUNTER_STROKE
        text.TextStrokeTransparency = 0
    else
        text.Size = UDim2.fromScale(1.5, .6)
        if isMiss then
            text.TextColor3 = DAMAGE_TEXT_MISS_COLOR
        end
    end
    text.Parent = card.Parent

    -- 克制命中：旋转 + 放大再缩小（不向上飘）
    if isCounter and not isMiss then
        local scale = Instance.new('UIScale')
        scale.Scale = 0.5
        scale.Parent = text

        text.Rotation = -DAMAGE_TEXT_COUNTER_TILT
        TweenService:Create(text, TweenInfo.new(DAMAGE_TEXT_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = DAMAGE_TEXT_COUNTER_TILT}):Play()

        local growTime = DAMAGE_TEXT_LIFE * 0.5
        local shrinkTime = DAMAGE_TEXT_LIFE * 0.5
        local grow = TweenService:Create(scale, TweenInfo.new(growTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.6})
        grow:Play()
        grow.Completed:Connect(function()
            TweenService:Create(scale, TweenInfo.new(shrinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0}):Play()
        end)

        task.delay(growTime, function()
            if text.Parent then
                TweenService:Create(text, TweenInfo.new(shrinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
            end
        end)
        task.delay(DAMAGE_TEXT_LIFE + 0.1, function()
            if text.Parent then text:Destroy() end
        end)
        return
    end

    local tween = TweenService:Create(text, TweenInfo.new(DAMAGE_TEXT_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = DAMAGE_TEXT_RISE,
        TextTransparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function() text:Destroy() end)
end

-- 受击表现：卡牌轻微晃动 + 一层高亮闪烁
function self:PlayHit(card)
    if card == nil or card.Parent == nil then return end

    local flash = Instance.new('Frame')
    flash.Name = 'HitFlash'
    flash.AnchorPoint = Vector2.new(.5, .5)
    flash.Position = UDim2.fromScale(.5, .5)
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = HIT_FLASH_COLOR
    flash.BackgroundTransparency = HIT_FLASH_TRANSPARENCY
    flash.BorderSizePixel = 0
    flash.ZIndex = ATTACK_Z_INDEX + 1
    flash.Parent = card
    TweenService:Create(flash, TweenInfo.new(HIT_FLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    }):Play()
    task.delay(HIT_FLASH_TIME, function()
        if flash.Parent then flash:Destroy() end
    end)

    task.spawn(function()
        local tweenInfo = TweenInfo.new(HIT_SHAKE_STEP, Enum.EasingStyle.Linear)
        for _, dx in ipairs(HIT_SHAKE_X) do
            if card.Parent == nil then return end
            TweenService:Create(card, tweenInfo, {Position = UDim2.new(.5, dx, .5, 0)}):Play()
            task.wait(HIT_SHAKE_STEP)
        end
        if card.Parent then
            TweenService:Create(card, tweenInfo, {Position = UDim2.fromScale(.5, .5)}):Play()
        end
    end)
end

-- 开场倒计时：在 Container.CountdownFight 上显示 COUNTDOWN_TIME..1
function Countdown(owner)
    local token = state.Token
    local label = state.Container and state.Container:FindFirstChild('CountdownFight')
    if label == nil then warn('[PVP Battle] CountdownFight label not found') end

    for i = COUNTDOWN_TIME, 1, -1 do
        if state.Token ~= token or not state.Running then return end
        shared.SoundHandler:Play('TimeStart')
        if label then label.Text = tostring(i) end
        task.wait(1)
    end

    if state.Token ~= token or not state.Running then return end
    if label then label.Text = '' end
    state.Counting = false
end

-- 战斗计时：进入战斗后在 Container.Timer 上累计显示 mm:ss
function StartTimer()
    state.TimerToken += 1
    local token = state.TimerToken
    local label = state.Container and state.Container:FindFirstChild('Timer')
    if label == nil then return end

    local startClock = os.clock()
    while state.TimerToken == token and state.Running do
        local elapsed = math.floor(os.clock() - startClock)
        label.Text = string.format('%02d:%02d', math.floor(elapsed / 60), elapsed % 60)
        task.wait(0.25)
    end
end

return self
