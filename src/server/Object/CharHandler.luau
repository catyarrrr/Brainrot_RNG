local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self = {}

function self.init()
    self.GiftEvent = shared.Event.new()
	self.Areas = workspace.SceneLogic.Areas
end

function self.start()
	shared.DataStore.PlayerDataLoadedEvent:Connect(InitChar)
end

function InitChar(_, player)
    local pathId = shared.DataStore.GetPlayerCurPath(player)
    local area = self.Areas:FindFirstChild(pathId)
    local spawnCF = area.SpawnPos.WorldCFrame

    local function Init(plr)
        local hrp = plr.Character:WaitForChild('HumanoidRootPart')
        hrp.CFrame = spawnCF

        local humanoid : Humanoid = plr.Character:WaitForChild('Humanoid')
        humanoid.WalkSpeed = 32

        local prompt = Instance.new('ProximityPrompt')
        prompt.ActionText = 'Gift'
        prompt.HoldDuration = .3
        prompt.Name = 'GiftPrompt'
        prompt.Enabled = false
        prompt.RequiresLineOfSight = false
        prompt.Parent = hrp

        prompt.Triggered:Connect(function(giver: Player)
            self.GiftEvent:Fire(giver, plr)
        end)
    end

    if player.Character then Init(player) end
    player.CharacterAdded:Connect(function(char) Init(player) end)
end

return self