local TweenService = game:GetService("TweenService")
local Battle = require(script.Battle)

local self : any = {}


function self.Init(frame)
    self.FightFrame = frame.PopUp.FightFrame
    self.FightFrame.Visible = false
    self.ResultFrame = self.FightFrame.Result
    self.ResultFrame.Visible = false
    self.ResultFrame.Win.Visible = false
    self.ResultFrame.Lose.Visible = false

    self.ResultFrame.Quit.MouseButton1Click:Connect(function()
        self:CloseResult()
    end)
end

--	播放服务端回传的战斗结算；onQuit 在结算面板点 Quit 时回调
function self:PlayResult(result, onQuit)
    if result == nil or result.Ally == nil or result.Enemy == nil then return end

    self.OnQuit = onQuit
    self.ResultFrame.Visible = false
    self.FightFrame.Visible = true
    Battle:Start(self.FightFrame, result, function(winner)
        --	winner == 'L' 代表我方胜利，'R' 代表敌方胜利
        self:ShowResult(winner, result)
    end)
end

--	战斗结束：显示结算面板（胜/负 + 获得的 Crystals）
function self:ShowResult(winner, result)
    local isWin = winner == 'L'
    self.ResultFrame.Win.Visible = isWin
    self.ResultFrame.Lose.Visible = not isWin

    local crystal = (isWin and result and result.Crystal) or 0
    local crystalFrame = self.ResultFrame:FindFirstChild('Crystal ')
    local cash = (isWin and result and result.Cash) or 0
    local cashFrame = self.ResultFrame:FindFirstChild('Cash')
    if cashFrame then
        local cashLabel = cashFrame:FindFirstChild('Cash')
        if cashLabel then cashLabel.Text = shared.Tool.FormatNumber(cash) end
    end

    self.ResultFrame.Visible = true

    if crystalFrame then
        task.spawn(function() self:PlayCrystalGain(crystalFrame, crystal) end)
    end
end

--	Crystals 获取表现：数字从 0 累加到目标值，每 +1 图标放大一次
function self:PlayCrystalGain(crystalFrame, target)
    target = math.max(0, math.floor(target or 0))

    local count = crystalFrame:FindFirstChild('PMB99M')
    local icon = crystalFrame:FindFirstChildOfClass('ImageLabel')
    if count then count.Text = '0' end

    local scale
    if icon then
        scale = icon:FindFirstChildOfClass('UIScale')
        if scale == nil then
            scale = Instance.new('UIScale')
            scale.Parent = icon
        end
        scale.Scale = 1
    end

    local upInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local downInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    for i = 1, target do
        if count then count.Text = tostring(i) end
        if scale then
            scale.Scale = 1
            local up = TweenService:Create(scale, upInfo, {Scale = 1.4})
            up:Play()
            up.Completed:Wait()
            TweenService:Create(scale, downInfo, {Scale = 1}):Play()
        end
        if i < target then task.wait(0.12) end
    end
end

--	结算面板的 Quit：收起战斗界面并回调外部
function self:CloseResult()
    self:Hide()
    if self.OnQuit then self.OnQuit() end
end

--	收起战斗界面并停止战斗（关闭 PVP 菜单时也会调用）
function self:Hide()
    if self.ResultFrame then self.ResultFrame.Visible = false end
    if self.FightFrame then self.FightFrame.Visible = false end
    Battle:Stop()
end

return self
