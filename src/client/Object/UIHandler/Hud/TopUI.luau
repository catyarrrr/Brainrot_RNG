local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)

local BOSSWAVE_COOLDOWN, RANK_MAXROUND = 25, 150
local BOSS_BAR_INNERS, BOSS_BAR_HEALTH = 10, 1000000
local BOSS_BAR_TWEEN = TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BOSS_BAR_SHAKE_DISTANCE, BOSS_BAR_SHAKE_TWEEN = 4, TweenInfo.new(.04, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local self : any = {}

function self.start()
    shared.Game.GameStartedEvent:Connect(function()
        self.RoundCountFrame.RoundCountText.Text = ''
        self.RoundCountFrame.InnerFrame.Size = UDim2.new(0, 0, 1, 0)
        self.RoundCountFrame.RoundTipsText.Visible = false
        self.Frame.GameFrame.Start.Visible = false
        self.Frame.GameFrame.Stop.Visible = true
        self.RoundCountFrame.Visible = true
    end)
    shared.Game.GameOverEvent:Connect(function()
        self.Frame.GameFrame.Start.Visible = true
        self.Frame.GameFrame.Stop.Visible = false
        self.RoundCountFrame.Visible = false
    end)
    shared.Game.GameWinEvent:Connect(function()
        self.Frame.GameFrame.Start.Visible = true
        self.Frame.GameFrame.Stop.Visible = false
        self.RoundCountFrame.Visible = false
    end)
    shared.Game.GameEndedEvent:Connect(function()
        if shared.Game.Rush then RestoreNormalUI() end
    end)
    shared.Game.RoundStartedEvent:Connect(EnemiesCounterReset, self)
    shared.Enemy.MyEnemiesDestroyedEvent:Connect(EnemiesCounterDec)
    ReplicatedStorage.Remote.Game.GameAuto.OnClientEvent:Connect(function(isOn)
        self.AutoBtn.TextLabel.Text = isOn and 'On' or 'Off'
    end)
end

function self.Init(main)
	self.Main = shared.Frame.new(main.Hud.Top)
    self.Main:Visible(true)

    self.Frame = self.Main.Frame
    self.RoundCountFrame = self.Frame.RoundCountFrame
    self.RoundCountFrame.Visible = false
    self.BestWaveFrame = self.Frame.BestWaveFrame
    self.BestWaveFrame.Visible = true
    self.BossBar = self.Frame.BossHP
    self.BossBar.Visible = false
    self.BossBarActive = false
    self.BossBarPos = self.BossBar.Position
    self.GameFrame = self.Frame.GameFrame
    self.GameFrame.Visible = true
    self.AutoBtnFrame = self.Frame.AutoBtnFrame
    self.AutoBtnFrame.Visible = true

    self.PopUpBtn = main.PopUp.CombatEndTips
    self.PopUpBtn.Visible = false
    self.PopUpFrame = self.PopUpBtn.Frame.Frame
    self.PopUpFrame.Visible = true
    self.BossBtn = self.Frame.Boss
    self.BossBtn.Visible = true

    self.PopUpBtn.MouseButton1Click:Connect(function()
        self.PopUpBtn.Visible = false
    end)

    self.BossBtn.Button.MouseButton1Click:Connect(function()
        local playerData = shared.PlayerDataHandler.GetData()
        if playerData.Profile.MaxLevel < 150 then shared.UIHandler.ServerWarn('Reach wave 150 to unlock Boss Challenge'); return end

        shared.UIHandler.TriggerRushEvent:Fire()
    end)
    self.StartBtn = self.Frame.GameFrame.Start
    self.StartBtn.Visible = true
    self.StartBtn.MouseButton1Click:Connect(function()
		ReplicatedStorage.Remote.Game.GameStart:FireServer()
    end)
    self.Frame.GameFrame.Stop.Visible = false
    self.Frame.GameFrame.Stop.MouseButton1Click:Connect(function()
		ReplicatedStorage.Remote.Game.GameStop:FireServer()
    end)

    self.AutoBtn = self.AutoBtnFrame.AutoBtn
    self.AutoBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Game.GameAuto:FireServer()
    end)
end

function self.Update(playerData)
    local level = TempData.GetLevelByGrid(playerData.Grid)
    if level >= 3 and not self.BossBarActive then
        self.AutoBtnFrame.Visible = true
    else
        self.AutoBtnFrame.Visible = false
    end
end

function self.ShowRushBossBar(show, maxHealth)
    self.BossBarActive = show
    self.BossBar.Visible = show
    self.BestWaveFrame.Visible = not show
    self.GameFrame.Visible = not show
    self.AutoBtnFrame.Visible = not show
    if show then
        self.UpdateBossBar(maxHealth, maxHealth, true)
    end
end

function self.UpdateBossBar(health, maxHealth, noShake)
    if not self.BossBarActive or not self.BossBar.Visible then return end
    local totalBars = math.max(1, math.ceil(maxHealth / BOSS_BAR_HEALTH))
    local slots = math.min(BOSS_BAR_INNERS, totalBars)
    local segment = maxHealth / slots
    local activeSlot = math.clamp(math.floor((maxHealth - health) / segment) + 1, 1, slots)

    for i = 1, BOSS_BAR_INNERS do
        local inner = self.BossBar:FindFirstChild('Inner' .. i)
        if inner then
            if i > slots then
                inner.ZIndex = 0
                TweenService:Create(inner, BOSS_BAR_TWEEN, { Size = UDim2.new(0, 0, 1, 0) }):Play()
            else
                local lo = maxHealth - i * segment
                inner.ZIndex = if i == activeSlot then BOSS_BAR_INNERS + 1 else i
                TweenService:Create(inner, BOSS_BAR_TWEEN, { Size = UDim2.new(math.clamp((health - lo) / segment, 0, 1), 0, 1, 0) }):Play()
            end
        end
    end

    if not noShake then self.ShakeBossBar() end

    local barCountText = self.BossBar:FindFirstChild('BarCountText')
    if barCountText then
        barCountText.Text = string.format('%d/%d', math.ceil(math.max(0, health) / BOSS_BAR_HEALTH), totalBars)
    end
end

function self.ShakeBossBar()
    if self.BossBarShakeTask then task.cancel(self.BossBarShakeTask) end
    if self.BossBarShakeTween then self.BossBarShakeTween:Cancel() end
    local basePos = self.BossBarPos
    self.BossBar.Position = basePos
    self.BossBarShakeTask = task.spawn(function()
        for i = 1, 4 do
            local offset = (i % 2 == 0 and -1 or 1) * BOSS_BAR_SHAKE_DISTANCE
            self.BossBarShakeTween = TweenService:Create(self.BossBar, BOSS_BAR_SHAKE_TWEEN, { Position = basePos + UDim2.fromOffset(offset, 0) })
            self.BossBarShakeTween:Play()
            self.BossBarShakeTween.Completed:Wait()
            if self.BossBarShakeTween == nil then return end
        end
        self.BossBarShakeTween = TweenService:Create(self.BossBar, BOSS_BAR_SHAKE_TWEEN, { Position = basePos })
        self.BossBarShakeTween:Play()
        self.BossBarShakeTween.Completed:Wait()
        self.BossBar.Position = basePos
    end)
end

function RestoreNormalUI()
    if not self.BossBarActive then return end
    self.BossBarActive = false
    self.BossBar.Visible = false
    self.BestWaveFrame.Visible = true
    self.GameFrame.Visible = true
    self.Update(shared.PlayerDataHandler.GetData())
end

function self.TogglePupOut(round)
    self.PopUpBtn.Visible = true
    self.PopUpFrame.Tips.Wave.Text = round

    if round >= self.BestWave then
        self.BestWaveFrame.TextLabel.Text = round
        self.BestWave = round

        for k, v in self.PopUpFrame.ParticleEmitter:GetChildren() do
            if v:IsA('Configuration') then
                v.Emit:Fire(30)
            end
        end
    end

    round = math.min(RANK_MAXROUND, round)
    local rank = 148.7776*(1 - math.pow(math.e, -round / 134.5081)) - .01
    self.PopUpFrame.LeaderStats.Text = string.format('Surpassed  %.2f%%  Players', rank)
end

function EnemiesCounterReset(_, round, amount)
    self.RoundCountFrame.Visible = true
    self.RoundCountFrame.RoundTipsText.Visible = false
    self.RoundCountFrame.RoundCountText.Text = string.format('Wave %d', round)
    -- self.RoundCountFrame.RoundTipsText.Text = string.format('Boss in Wave %d', GetBossWave(round))
    self.MaxSize = amount
    self.CurSize = 0
	TweenService:Create(self.RoundCountFrame.InnerFrame, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 0, 1, 0)
	}):Play()
end
function EnemiesCounterDec()
    self.CurSize += 1
    local conn = TweenService:Create(self.RoundCountFrame.InnerFrame, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Size = UDim2.new(math.min(self.MaxSize, self.CurSize) / self.MaxSize, 0, 1, 0)
	})
	conn:Play()
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end

return self
