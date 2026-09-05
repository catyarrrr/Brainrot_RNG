local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)
local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.Fusion)
    self.Main:Visible(false)

    self.Frame = self.Main.Frame
    self.FuseButton = self.Frame.Frame.FuseBtn
    self.CostLabel = self.FuseButton.CashCount.CashCountText
    self.ResultDict = self.Frame.PossibleResults.ScrollingFrame
    self.RequiredDict = self.Frame.YourFraments.ScrollingFrame
    self.ConsumeSlot = self.Frame.Frame.CostIcon

    self.LegendaryFragmentsRBX = self.Frame.Tab:FindFirstChild('49')
    self.MythicFragmentsRBX = self.Frame.Tab:FindFirstChild('129')
    self.SecretFragmentsRBX = self.Frame.Tab:FindFirstChild('249')
    self.GodFragmentsRBX = self.Frame.Tab:FindFirstChild('499')
    self.LimitedGodFragmentsRBX = self.Frame.Tab:FindFirstChild('299')

    self.Frame.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)

    self.FuseButton.MouseButton1Click:Connect(function()
        if self.Selected == nil then return end
        ReplicatedStorage.Remote.Fuse:FireServer(self.Selected)
    end)

    local fragmentProducts = {
        [self.LegendaryFragmentsRBX] = shared.ProductDatas.LegendaryFragments,
        [self.MythicFragmentsRBX] = shared.ProductDatas.MythicFragments,
        [self.SecretFragmentsRBX] = shared.ProductDatas.SecretFragments,
        [self.GodFragmentsRBX] = shared.ProductDatas.GodFragments,
        [self.LimitedGodFragmentsRBX] = shared.ProductDatas.LimitedGodFragments,
    }
    for btn, productId in fragmentProducts do
        if btn then
            btn.MouseButton1Click:Connect(function()
                shared.BuyHandler.BuyProduct(productId)
            end)
        end
    end

    for _, slot in self.RequiredDict:GetChildren() do
        if slot:IsA('ImageButton') then
            slot.MouseButton1Click:Connect(function()
                self.SelectFragment(tonumber(slot.Name))
            end)
        end
    end
end

function self.SelectFragment(itemId)
    if itemId == nil then return end
    local config = shared.CalculateData.GetFragmentConfig(itemId)
    if config == nil then return end
    self.Selected = itemId

    local itemData = ItemData[itemId]

    for _, result in self.ResultDict:GetChildren() do
        if result:IsA('ImageLabel') then
            if tonumber(result.Name) == config.ResultID then
                result.Visible = true
                local probability = result:FindFirstChild('Probability', true)
                if probability and probability:IsA('TextLabel') then
                    probability.Text = string.format('%d%%', math.floor(config.SuccessRate * 100 + 0.5))
                end
            else
                result.Visible = false
            end
        end
    end
    if config.SuccessRate ~= 1 then
        local failResult = self.ResultDict:FindFirstChild(itemId)
        if failResult then
            failResult.Visible = true
            failResult.Probability.Text = string.format('%d%%', math.floor((1 - config.SuccessRate) * 100 + 0.5))
        end
    end

    self.CostLabel.Text = string.format('$%s', shared.Tool.FormatNumber(config.NeedCash))

    self.ConsumeSlot.Icon.Image = itemData.Icon
    self.ConsumeSlot.Cost.Text = string.format('x%d', config.NeedCount)
    self.ConsumeSlot.CostTips.Text = string.format('Fuse %dx %s', config.NeedCount, itemData.Name)
end

function self.RefreshRequired()
    -- print('update')
    local playerData = shared.PlayerDataHandler.GetData()
    if playerData == nil then return end

    for _, slot in self.RequiredDict:GetChildren() do
        if slot:IsA('ImageButton') then
            local itemId = tonumber(slot.Name)
            if itemId == nil then continue end

            local config = shared.CalculateData.GetFragmentConfig(itemId)
            if config == nil then continue end

            local owned = playerData.Item.Inv[tostring(itemId)] or 0
            local countLabel = slot:FindFirstChild('Count', true)
            if countLabel and countLabel:IsA('TextLabel') then
                countLabel.Text = string.format('%d/%d', owned, config.NeedCount)
                if owned >= config.NeedCount then
                    countLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                else
                    countLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                end
            end
        end
    end
end

function self:Open()
    self.RefreshRequired()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end

return self