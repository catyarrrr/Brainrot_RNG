local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SPIN_DURATION = 4
local self : any = {WheelRoattion = 0}
local rng = Random.new()

function self.start()
    
end

function self.Init(main)
	self.Main = shared.Frame.new(main.PopUp.Wheel)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.Wheel = self.Frame.Frame
    self.Wheel.Rotation = 0
    self.RotateBtn = self.Frame.RotateButton
    self.CountdownLabel = self.Frame.CountText
    self.Spining = false

    self.Frame.Buy1Button.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.x1Spin)
    end)
    self.Frame.Buy5Button.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.x5Spin)
    end)
    self.RotateBtn.MouseButton1Click:Connect(function()
        if self.Spining == true then return end
        ReplicatedStorage.Remote.PlayerSpin:FireServer()
    end)
    self.Frame.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self:Close()
    end)
end

function self.Update(playerData)
    self.RotateBtn.TextLabel.Text = string.format('Rotate(%d)', playerData.Gacha.Spins)
end

function self.Countdown(playerData)

    if self.CountdonwTask then return end
    self.CountdonwTask = task.spawn(function()
        local endTime = playerData.Gacha.LastSpin
        while true do
            local remain = math.floor(600 - ((workspace:GetServerTimeNow() - endTime)%600))
            if remain <= 0 then 
                local cot = string.match(self.RotateBtn.TextLabel.Text, '(%d+)')
                cot = tonumber(cot)
                self.RotateBtn.TextLabel.Text = string.format('Rotate(%d)', cot + 1)
            end

            self.CountdownLabel.Text = string.format('Free spins within %s seconds', shared.Tool.FormatTime(remain))

            task.wait(1)
        end 
    end)
end
function EndCountdown()
    if self.CountdonwTask then
        task.cancel(self.CountdonwTask)
        self.CountdonwTask = nil
    end
end

function self.Spin(rotation)
    self.Spining = true

	self.WheelRoattion += 5 * 360
    self.WheelRoattion -= self.WheelRoattion%360
    self.WheelRoattion += rotation + rng:NextNumber(-18, 18)


	local tweenInfo = TweenInfo.new(
		SPIN_DURATION,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)
    
	local tween = TweenService:Create(
		self.Wheel,
		tweenInfo,
		{
			Rotation = self.WheelRoattion
		}
	)

	tween:Play()
    tween.Completed:Connect(function() self.Spining = false end)
end

function self:Open()
    self.Wheel.Rotation = 0
    self.WheelRoattion = 0
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
    EndCountdown()
end


return self
