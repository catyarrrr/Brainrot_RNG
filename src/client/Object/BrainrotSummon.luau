local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local self : any, Init, TotemDrop = {}, nil
self.State, self.Index, self.Model, self.Aliens, self.Cot = nil
local EnumState = {

	PlayingIntro = {
		name = 'PlayingIntro',

		enter = function(self)
            shared.UIHandler.MainGui.Enabled = false
            shared.VFXHandler.ParticleModule.ToggleVisual(self.UFOEffect, false)
            shared.CameraHandler.SetCamera(self.IdleCF)
            shared.CameraHandler.GetCamera().FieldOfView = 70
			shared.CameraHandler.TweenCamera(self.ShowCF, 1)
            shared.SoundHandler:Play('UFO')
		end,

        duration = 1,

		next = 'UFOAnime',
	},

    UFOAnime = {
		name = 'UFOAnime',

		enter = function(self)
            self.UFOAnimationTrack:Play()
		end,

        duration = 2,

        exit = function(self)
        end,

		next = 'Falling',
	},

	Falling = {
		name = 'Falling',

		enter = function(self)
            shared.SoundHandler:Play('UFO_Reward')
            shared.CameraHandler.TweenFOV(70, 25, 1)
            shared.VFXHandler.ParticleModule.ToggleVisual(self.UFOEffect, true)
            task.delay(.8, function() shared.VFXHandler.ParticleModule.ToggleVisual(self.UFOEffect, false) end)
            
            shared.CameraHandler.LookAtPart(self.Alien)
            self.Alien:PivotTo(self.SpawnCF)
            self.Alien.PrimaryPart.Anchored = false
		end,

        duration = 3, 

		exit = function(self)
            
		end,

        next = 'Summary'
	},

    Summary = {
		name = 'Summary',

		enter = function(self)
			shared.CameraHandler.ResetCamera()
            if self.Alien then self.Alien:Destroy(); self.Alien = nil end
            
            shared.UIHandler.MainGui.Enabled = true
		end,

        duration = 0, 

		exit = function(self)

		end,
    }
}

--------  设置状态，执行进入、退出状态的函数
function self.SetState(newState)
	local state = EnumState[newState]
	if not state then warn('state not found for name:', newState);  return end
	
	if self.State and self.State.exit then self.State.exit(self) end
	
	self.State = state
	self.Timer = self.State.duration
	
	if state.enter then state.enter(self) end
end

function self.init()
    self.SummonEvent = shared.Event.new()
end

function self.start()
    ReplicatedStorage.Remote.Tower.Summon.OnClientEvent:Connect(self.Start)
    ReplicatedStorage.Remote.Tower.PrayTotem.OnClientEvent:Connect(TotemDrop)
    Init()
end

function Init()
    self.GachaRoom = workspace.SceneLogic:WaitForChild('AlienSummon')
    
    self.IdleCF = self.GachaRoom.IdlePos.WorldCFrame
    self.ShowCF = self.GachaRoom.ShowPos.WorldCFrame
    self.SpawnCF = self.GachaRoom.SpawnPos.WorldCFrame
    self.HiddenCF = self.GachaRoom.HiddenPos.WorldCFrame
    self.UFOModel = self.GachaRoom.UFO
    self.UFOEffect = self.GachaRoom.UFOEffect

    local animator = self.UFOModel.AnimationController.Animator
    self.UFOAnimationTrack = animator:LoadAnimation(self.UFOModel.AnimationController.Animation)
    self.UFOAnimationTrack:Play()
end

function self.Start(towerUID)
    -- print(towerUID)
    local towerType = TowerData.GetTowerTypeByTowerUID(towerUID)
    towerType = shared.Tool.FormatTowerType(towerType)

    self.Alien = ReplicatedStorage.Assets.Towers:FindFirstChild('BR' ..  tostring(towerType)):Clone()
    self.Alien.PrimaryPart.Anchored = true

    local model = Instance.new("Model")
    model.Name = self.Alien.Name
    model.PrimaryPart = self.Alien.PrimaryPart
    self.Alien.Parent = model
    self.Alien = model
    -- self.Alien.Circle:Destroy()
    -- self.Alien.Range:Destroy()
    -- self.Alien.SpawnArea:Destroy()
    shared.VFXHandler.GenerateMutParticle(nil, towerUID, self.Alien)
    
    local primaryPart = self.Alien.PrimaryPart
    for _, v in self.Alien:GetDescendants() do
        if v:IsA('BasePart') then
            if v ~= primaryPart then
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = primaryPart
                weld.Part1 = v
                weld.Parent = primaryPart
                v.Anchored = false
            end
        end
    end
    self.Alien:PivotTo(self.HiddenCF)
    self.Alien.Parent = self.GachaRoom

    self.SetState('PlayingIntro')

    while true do 
        task.wait(1)
        self.Timer -= 1
    
        if self.Timer <= 0 then 
            --- 	倒计时结束，准备切换到下一回合
            self.SetState(self.State.next) 
            if self.State.name == 'Summary' then
                break 
            end
        end

    end

end

function TotemDrop(totemUID)
	if totemUID == nil then return end
    -- print(totemUID)

	local character = Players.LocalPlayer.Character
	local humanoidRootPart = character and character:FindFirstChild('HumanoidRootPart')
	if not humanoidRootPart then return end

    local staticData = TotemData.GetData(totemUID)
    if staticData == nil then return end

	local totemModel = ReplicatedStorage.Assets.Parts.Totem:Clone()
    totemModel.Main.Icon.Image = staticData.MainIcon
    totemModel.Sub.Icon.Image = staticData.SubIcon
	local primaryPart = totemModel.PrimaryPart
	if primaryPart == nil then
		totemModel:Destroy()
		return
	end

	for _, v in totemModel:GetDescendants() do
		if v:IsA('BasePart') and v ~= primaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primaryPart
			weld.Part1 = v
			weld.Parent = primaryPart
			v.Anchored = false
		end
	end
	primaryPart.Anchored = false

	local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = 'Claim'
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = totemModel

	local offsetX = math.random(-6, 6)
	local offsetZ = math.random(-6, 6)

	totemModel:PivotTo(humanoidRootPart.CFrame * CFrame.new(offsetX, 15, offsetZ) * CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), math.rad(math.random(0, 360))))
	totemModel.Parent = workspace

    shared.SoundHandler:Play('PrayTotem')

	prompt.Triggered:Connect(function(plr)
		ReplicatedStorage.Remote.Tower.ClaimTotem:FireServer(totemUID)
		totemModel:Destroy()
	end)
end 

return self
