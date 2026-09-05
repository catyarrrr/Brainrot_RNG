local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local player = Players.LocalPlayer
local self = {}


function self.init()
	
end

function self.start()
	ReplicatedStorage.Remote.Game.RushStart.OnClientEvent:Connect(function(needed)
        self.BuyProduct(shared.ProductDatas['x' .. tostring(needed) .. 'BossChallenge'])
    end)
    ReplicatedStorage.Remote.Tower.KeepThis.OnClientEvent:Connect(function(towerUID)
        local staticData = TowerData.GetData(towerUID)
        local product = shared.ProductDatas['KeepAlien' .. staticData.Quality]
        if product then
            self.BuyProduct(product)
        end

    end)
end 

function self.BuyPass(passId)
    MarketplaceService:PromptGamePassPurchase(player, passId)
end

function self.BuyProduct(productId)
    MarketplaceService:PromptProductPurchase(player, productId)
end



return self
