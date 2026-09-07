local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rng = Random.new()
local player = Players.LocalPlayer
local InitSellNPC, InitEvoNPC, DialogModule, GetDialogModule = nil
local self = {SellDialog = nil, EvoDialog = nil}

function self.init()
end

function self.start()
    ReplicatedStorage.Remote.Tower.Sell.OnClientEvent:Connect(function(isSell, text)
        if not self.SellDialog then return end

        if isSell then
            self.SellDialog:hideGui("Poor little guy... anyway, here's your Cash")
        else
            self.SellDialog:hideGui(text)
        end
    end)
    ReplicatedStorage.Remote.Tower.SellAll.OnClientEvent:Connect(function(isSell, text)
        if not self.SellDialog then return end

        if isSell then
            self.SellDialog:hideGui("Don't worry, I'll send them straight to Mars.")
        else
            self.SellDialog:hideGui(text)
        end
    end)
    ReplicatedStorage.Remote.Tower.Estimate.OnClientEvent:Connect(function(isEstimate, gems, cashMin, cashMax)
        if not self.SellDialog then return end

        if isEstimate then
            self.SellDialog:hideGui("This Brainrot is worth " .. tostring(gems) .. ' Gems', true)
            task.wait(1)
            local text = string.format('Its Cash value ranges from $%s to $%s.', shared.Tool.FormatNumber(cashMin), shared.Tool.FormatNumber(cashMax))
            self.SellDialog:hideGui(text)
        else
            self.SellDialog:hideGui('No Brainrot, no appraisal.')
        end
    end)
    ReplicatedStorage.Remote.Tower.Combine.OnClientEvent:Connect(function(isCombine, text)
        if not self.EvoDialog then return end

        if isCombine then
            self.EvoDialog:hideGui("Perfect! Let's mutate 'em!")
        else
            self.EvoDialog:hideGui(text)
        end
    end)

	InitSellNPC();InitEvoNPC();InitFuseNPC()
end 

function InitSellNPC()
    task.spawn(function()
        local DialogModule = GetDialogModule()

        local npc = workspace.NPCs:WaitForChild("Merchant")
        local prompt = npc:WaitForChild("ProximityPrompt")
    
        self.SellDialog = DialogModule.new("Sell NPC", npc, prompt)
        self.SellDialog:addDialog("You want Cash? I want Brainrots. Sounds like a deal.", {"I want to sell my inventory", "I want to sell this", "How do you price them?", "How much is this Brainrot worth?", "Never mind"})
        self.SellDialog:addDialog("Are u sure?", {"Yep", "Nope"})
    
        --
    
        -- what happens when triggered
        prompt.Triggered:Connect(function(player)
            self.SellDialog:triggerDialog(player, 1)
        end)
    
        -- logic to go through dialogs
        self.SellDialog.responded:Connect(function(responseNum, dialogNum)
            if dialogNum == 1 then
                if responseNum == 1 then
                    self.SellDialog:triggerDialog(player, 2)
                elseif responseNum == 2 then
                    ReplicatedStorage.Remote.Tower.Sell:FireServer()
                elseif responseNum == 3 then
                    self.SellDialog:hideGui('The price? Hmmm...', true)
                    task.wait(1)
                    self.SellDialog:hideGui('Gem value is based on its DPS', true)
                    task.wait(1)
                    self.SellDialog:hideGui('While Cash value depends on what you paid for them')
                elseif responseNum == 4 then
                    ReplicatedStorage.Remote.Tower.Estimate:FireServer()
                elseif responseNum == 5 then
                    local farewells = { 'Come back soon !', 'Until next time !', 'See ya !' }
                    self.SellDialog:hideGui(farewells[rng:NextInteger(1, #farewells)])
                end
            elseif dialogNum == 2 then
                if responseNum == 1 then
                    ReplicatedStorage.Remote.Tower.SellAll:FireServer()
                elseif responseNum == 2 then
                    self.SellDialog:hideGui("You can't just tease me with a deal like that!")
                end
                -- task.delay(5, function()  self.SellDialog:hideGui("") end)
            end
        end)
    end)
end
function InitEvoNPC()
    task.spawn(function()
        local DialogModule = GetDialogModule()

        local npc = workspace.NPCs:WaitForChild("BR002")
        local prompt = npc:WaitForChild("ProximityPrompt")
    
        self.EvoDialog = DialogModule.new("Evolve NPC", npc, prompt)
        self.EvoDialog:addDialog("Hey ! What do you wanna do ?", {"I want to power up my Brainrots", "I want to mutate my Brainrots", "How can i get Gems","Never mind"})
        self.EvoDialog:addDialog("Put 5 Brainrots with same mutation in your inventory first!", {"I'm ready !", "Not yet"})
    
        prompt.Triggered:Connect(function(player)
            self.EvoDialog:triggerDialog(player, 1)
        end)
    
        self.EvoDialog.responded:Connect(function(responseNum, dialogNum)
            if dialogNum == 1 then
                if responseNum == 1 then
                    shared.UIHandler.TriggerEvoEvent:Fire(true)
                    self.EvoDialog:hideGui('Check this out')
                elseif responseNum == 2 then
                    self.EvoDialog:triggerDialog(player, 2)
                elseif responseNum == 3 then
                    self.EvoDialog:hideGui('You can get more by selling Brainrots')
                elseif responseNum == 4 then
                    local farewells = { 'Sure !', 'See ya !', 'Later !' }
                    self.EvoDialog:hideGui(farewells[rng:NextInteger(1, #farewells)])
                end
            elseif dialogNum == 2 then
                ReplicatedStorage.Remote.Tower.Combine:FireServer()
            end
        end)
    end)
end
function InitFuseNPC()
    task.spawn(function()
        local DialogModule = GetDialogModule()

        local npc = workspace.NPCs:WaitForChild("BR003")
        local prompt = npc:WaitForChild("ProximityPrompt")
    
        self.FuseDialog = DialogModule.new("Fuse NPC", npc, prompt)
        self.FuseDialog:addDialog("Hey! What's up?", {"I want to fuse my fragments","Never mind"})
    
        prompt.Triggered:Connect(function(player)
            self.FuseDialog:triggerDialog(player, 1)
        end)
    
        self.FuseDialog.responded:Connect(function(responseNum, dialogNum)
            if dialogNum == 1 then
                if responseNum == 1 then
                    shared.UIHandler.TriggerFuseEvent:Fire(true)
                    self.FuseDialog:hideGui('Check this out')
                elseif responseNum == 2 then
                    local farewells = { 'See you around! Take care!', 'Don\'t get into too much trouble!', 'Later !' }
                    self.FuseDialog:hideGui(farewells[rng:NextInteger(1, #farewells)])
                end
            elseif dialogNum == 2 then
                ReplicatedStorage.Remote.Tower.Combine:FireServer()
            end
        end)
    end)
end

function GetDialogModule()
	if not DialogModule then
		DialogModule = require(ReplicatedStorage.DialogModule :: ModuleScript)
	end
	return DialogModule
end

return self
