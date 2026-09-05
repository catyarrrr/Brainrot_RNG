local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Class = {}
Class.__index = Class

function Class.start()
	HealthBarInit()
end

function Class.new(parent, value, max, color)
	local self = setmetatable({}, Class)

	self.Max = max
	self.Value = value
	self.DelayTween = nil

	local ratio = math.clamp(value / max, 0, 1)

	self.Billboard = shared.ObjectPool.Get('Bar')
	self.Billboard.Size = UDim2.new(3, 0, .3, 0)
	self.Billboard.ExtentsOffsetWorldSpace = Vector3.new()
	self.Billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	self.Billboard.Adornee = parent

	self.OuterFrame = self.Billboard.OuterFrame
	self.OuterFrame.Size = UDim2.new(1, 0, 1, 0)
	self.OuterFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	self.OuterFrame.BorderColor3 = Color3.new(0, 0, 0)
	self.OuterFrame.BorderSizePixel = 2

	-- 白条
	self.DelayFrame = self.OuterFrame.DelayFrame
	self.DelayFrame.Size = UDim2.new(1, 0, 1, 0)
	self.DelayFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	self.DelayFrame.BorderSizePixel = 0

	-- 血条
	self.InnerFrame = self.OuterFrame.InnerFrame
	self.InnerFrame.Size = UDim2.new(ratio, 0, 1, 0)
	self.InnerFrame.BackgroundColor3 = color
	self.InnerFrame.BorderSizePixel = 0

	-- 一开始的扣血tween
	if ratio < 1 then
		task.defer(function()
			if not self.DelayFrame.Parent then
				return
			end

			self.DelayTween = TweenService:Create(
				self.DelayFrame,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = UDim2.new(ratio, 0, 1, 0)
				}
			)

			self.DelayTween:Play()
		end)
	end

	return self
end

function Class:Set(value, max)
	if value then self.Value = value end
	if max then self.Max = max end

	local ratio = math.clamp(self.Value / self.Max, 0, 1)

	-- 当前血条立即变化
	self.InnerFrame.Size = UDim2.new(ratio, 0, 1, 0)

	-- 停止之前Tween
	if self.DelayTween then
		self.DelayTween:Cancel()
	end

	-- 白条先保持，再慢慢缩
	task.delay(0.15, function()
		if not self.DelayFrame.Parent then
			return
		end

		self.DelayTween = TweenService:Create(
			self.DelayFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = UDim2.new(ratio, 0, 1, 0)
			}
		)

		self.DelayTween:Play()
	end)
end

function Class:Increment(amount)
	self:Set(self.Value + amount)
end

function Class:Destroy()
	if self.DelayTween then
		self.DelayTween:Cancel()
	end

	shared.ObjectPool.Return('Bar', self.Billboard)
end

function Class.PlayEmptyEffect(parent, color)
	local part = shared.ObjectPool.Get('BarBase')
	part.Position = parent.Position
	local bar = Class.new(part, 1, 1, color or Color3.new(.92, .22, .2))
	bar:Set(0)
	task.delay(0.6, function()
		bar:Destroy()
		shared.ObjectPool.Return('BarBase', part)
	end)
end

function HealthBarInit()
	task.spawn(function()
		local template = ReplicatedStorage.Assets.UI.Bar

		shared.ObjectPool.Create('Bar', template, 20)

		local part = Instance.new('Part')
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.CanTouch = false

		shared.ObjectPool.Create('BarBase', part, 20)

		part:Destroy()
	end)
end

return Class