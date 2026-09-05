local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelData = require(ReplicatedStorage.Datas.LevelData :: ModuleScript)
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)

local GetReward, FormatNumber = nil
local self : any = {}

function self.start()
    
end

function self.Init(main)
	self.AFKHud = main.Hud.AFK
    self.AFKHud.Visible = false
	self.AFKFrame = main.Menu.AFK
    self.AFKFrame.Visible = false
    self.AFKDataPanel = self.AFKFrame.Frame.Frame
    
    self.AFKFrame.Frame.Title.Close.MouseButton1Click:Connect(function()
        self.AFKFrame.Visible = false
    end)
    self.AFKFrame.Frame.ClaimButton.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        ReplicatedStorage.Remote.PlayerClaimOfflineReward:FireServer()
    end)
    self.AFKFrame.Frame.Claim3xButton.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        shared.BuyHandler.BuyProduct(shared.ProductDatas['x3Offline'])
    end)
end

function self.Update(playerData)
    if playerData.States.IsNew == true then return end
    self.AFKFrame.Visible = true

    local offlineReward = playerData.States.OfflineReward
    self.AFKDataPanel.Desc.Desc.Text = string.format('Claim offline rewards (%dh %dm)', math.floor(offlineReward.TotalMin / 60), offlineReward.TotalMin % 60)
    self.AFKDataPanel.Cash.TextLabel.Text = FormatNumber(offlineReward.Cash)

    for _, slot in self.AFKDataPanel.Item:GetChildren() do
        if slot:IsA('ImageButton') then slot:Destroy() end
    end
    for itemId, amount in offlineReward.Items do
        local staticData = ItemData[tonumber(itemId)]
        local slot = ReplicatedStorage.Assets.UI.ItemSlot:FindFirstChild(staticData.Quality):Clone()
        slot.ItemNameText.Text = staticData.Name
        slot.ItemCountText.Text = tostring(amount) .. 'x'
        slot.Parent = self.AFKDataPanel.Item
    end
end

function self.ToggleAFKHUD(playerData, isShow)
    if isShow then
        self.AFKHud.Visible = true
    else
        self.AFKHud.Visible = false
    end

    local reward = GetReward(playerData)
    self.AFKHud:FindFirstChild('1Hour').Cash.TextLabel.Text = FormatNumber(reward)
    self.AFKHud:FindFirstChild('4Hour').Cash.TextLabel.Text = FormatNumber(reward * 4)
end

function GetReward(playerData)
    local round = playerData.Profile.MaxLevel
    local levelData = LevelData.GetData(round)
    if levelData == nil then return end

	local baseReward = 10 * round * 8 * 60

	return math.ceil(baseReward)
end

function FormatNumber(num)
	local str = tostring(num)
	local result = ""

	while #str > 3 do
		result = "," .. string.sub(str, -3) .. result
		str = string.sub(str, 1, -4)
	end

	return str .. result
end

return self
