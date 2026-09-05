local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GetCmdrModule, Cmdr, Init = nil
local self = {}
local admin = {
    [10597568952] = true,
    [10653321361] = true,
    [10065389473] = true,
    [10142054306] = true,
}

function self.init()
	
end

function self.start()
	Init()
end 

function Init()
    task.spawn(function()
        GetCmdrModule()
        Cmdr.Registry:RegisterDefaultCommands()

        Cmdr.Registry:RegisterHook('BeforeRun', function(context)
            if not admin[context.Executor.UserId] then
                return 'u are not creator'
            else
                return nil
            end
        end)
    end)
end

function GetCmdrModule()
	if not Cmdr then
		Cmdr = require(ServerScriptService.Cmdr :: ModuleScript)
	end

	return Cmdr
end

return self