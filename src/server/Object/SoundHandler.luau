local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService('SoundService')
local soundFolder = Instance.new('Folder')
soundFolder.Parent = workspace
soundFolder.Name = 'Sounds'

local self = {}
self.Sounds = {}
self.Channels = {
	BGM = {},
	SFX = {},
	UI = {},
}

function self.init()
	-- self:Register(name, assetId, channel, volume, looped, minDistance, maxDistance)
	self:RegisterSound('AlienPlace_Success', 'SFX')
	self:RegisterSound('AlienPlace_Fail', 'SFX')
	self:RegisterSound('AlienUpgrade', 'SFX')
	self:RegisterSound('AlienBuy_Success', 'SFX')
	self:RegisterSound('AlienBuy_Fail', 'SFX')

	self:RegisterSound('Operate_Fail', 'SFX')
	self:RegisterSound('Operate_Success', 'SFX')
	self:RegisterSound('Collect_Coin', 'SFX')
	self:RegisterSound('Collect_Loot', 'SFX')

	self:RegisterSound('Clone', 'UI')
	self:RegisterSound('AlienClone', 'UI')
	self:RegisterSound('AlienEvolve', 'UI')

	self:RegisterSound('Roll', 'SFX')
	self:RegisterSound('RollFast', 'SFX')
end

function self:Register(name, assetId, channel, volume, looped, minDistance, maxDistance)
	local sound = Instance.new('Sound')
	sound.Name = name
	sound.SoundId = assetId
	sound.Parent = SoundService
	sound.Volume = volume or .5
	sound.Looped = looped or false
	if maxDistance then sound.RollOffMaxDistance = maxDistance end
	if minDistance then sound.RollOffMinDistance = minDistance end
	
	self.Sounds[name] = sound
	self.Channels[channel][name] = sound
end

function self:RegisterSound(soundName, channel)
	if not self.Channels[channel] then warn('invalid channel:', channel); return end
	if self.Sounds[soundName] then warn('sound already registered:', soundName); return end

	local template = ReplicatedStorage.Assets.Sounds:FindFirstChild(soundName)
	if template == nil then warn('sound not found for name:', soundName); return end

	local clone = template:Clone()
	clone.Parent = SoundService

	self.Sounds[soundName] = clone
	self.Channels[channel][soundName] = clone
end

function self:RegisterGroup(name, assetId, channel, volume, looped, minDistance, maxDistance)
	local sound = Instance.new('Sound')
	sound.Name = name
	sound.SoundId = assetId
	sound.Parent = SoundService
	sound.Volume = volume or .5
	sound.Looped = looped or false
	if maxDistance then sound.RollOffMaxDistance = maxDistance end
	if minDistance then sound.RollOffMinDistance = minDistance end

	self.Sounds[name] = self.Sounds[name] or {}
	table.insert(self.Sounds[name], sound)
	
	self.Channels[channel][name] = sound
end

function self:Play(name)
	local sound = self.Sounds[name]
	if not sound then return end

	sound:Play()
end
function self:PlayAsync(name)
	local sound = self.Sounds[name]:Clone()
	sound.Parent = SoundService
	if not sound then return end

	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end

function self:PlayRanAt(name, pos)
	local list = self.Sounds[name]
	if not list then return end
	
	local sound = list[math.random(#list)]:Clone()
	local part = Instance.new('Part')
	part.Position = pos
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.Parent = soundFolder

	sound.Parent = part

	sound:Play()

	sound.Ended:Connect(function() part:Destroy() end)
end

function self:PlayRan(name)
	local list = self.Sounds[name]
	if not list then return end
	
	local sound = list[math.random(#list)]

	sound:Play()
end

function self:PlayAt(name, pos, speed)
	local sound = self.Sounds[name]:Clone()
	local part = Instance.new('Part')
	part.Position = pos
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.AudioCanCollide = false
	part.CanQuery = false
	part.Anchored = true
	part.Parent = soundFolder
	
	sound.Parent = part
	
	sound.PlaybackSpeed = speed or 1
	sound:Play()
	
	sound.Ended:Connect(function() part:Destroy() end)
end

function self:PlayAtPlayer(name, player)
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild('HumanoidRootPart')
    if not root then return end

    self:PlayAt(name, root.Position)
end

function self:CheckIsPlaying(name)
	local sound = self.Sounds[name]
	if sound == nil or sound.IsPlaying == false then return false end

	return true
end

function self:Stop(name)
	local sound = self.Sounds[name]
	if not sound or not sound.Playing then return end

	sound:Stop()
end

function self:StopGroup(name)
	local list = self.Sounds[name]
	if list == nil then warn('stop groupmusic error for name:', name) end
	for _, music in list do
		music:Stop()
	end
end	

return self
