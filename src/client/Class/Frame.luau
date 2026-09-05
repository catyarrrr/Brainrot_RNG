local TweenService = game:GetService('TweenService')

local Class = {}
Class.__index = Class

function Class.new(newFrame)
	local self = setmetatable({}, Class)

	self.Frame = newFrame
	self.IsOpen = false

	return self
end

function Class:Toggle()
	self.Frame.Visible = not self.Frame.Visible
end

function Class:Visible(isShow)
	self.Frame.Visible = isShow
end

function Class:Tween(isShow: boolean, time, style, direction, property)
	local easingStyle = Enum.EasingStyle[style]
	local easingDir = Enum.EasingDirection[direction]
	local tweenInfo = TweenInfo.new(time, easingStyle, easingDir)
	local tween = TweenService:Create(self.Frame, tweenInfo, property)
	tween:Play()

	if isShow then self:Visible(true)
	else
		tween.Completed:Wait()
		self:Visible(false)
	end
end

function Class:TweenOpen()
	if self.IsOpen then return end
	shared.SoundHandler:Play('UI_Success')
	self.IsOpen = true

    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local frame = self.Frame

    frame.Visible = true
    if frame:FindFirstChild('UIScale') == nil then
        local uiScale = Instance.new('UIScale')
        uiScale.Parent = frame
    end
    frame.UIScale.Scale = .2
    local tween = game:GetService('TweenService'):Create(frame.UIScale, tweenInfo, {Scale = 1})
    tween:Play()
end

function Class:TweenClose()
	if not self.IsOpen then return end
	shared.SoundHandler:Play('UI_Fail')
	self.IsOpen = false

    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local frame = self.Frame

	if frame:FindFirstChild('UIScale') == nil then
        local uiScale = Instance.new('UIScale')
        uiScale.Parent = frame
    end
    frame.UIScale.Scale = 1
    local tween = game:GetService('TweenService'):Create(frame.UIScale, tweenInfo, {Scale = 0.2})
    tween:Play()

    tween.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed then return end

		if self.IsOpen then
			return
		end
		
		frame.Visible = false
	end)
end


return Class