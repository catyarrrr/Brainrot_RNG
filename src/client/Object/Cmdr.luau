local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetCmdrModule, Cmdr, Init = nil
local self = {}

function self.init()
	
end

function self.start()
	Init()
end 

function Init()
	task.spawn(function()
		GetCmdrModule()
		
		Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })

		Cmdr.Registry:RegisterHook("BeforeRun", function(context)
			-- print("Client BeforeRun")
		end)
	end)
end

function GetCmdrModule()
	if not Cmdr then
		Cmdr = require(ReplicatedStorage:WaitForChild('CmdrClient') :: ModuleScript)
	end

	return Cmdr
end

return self