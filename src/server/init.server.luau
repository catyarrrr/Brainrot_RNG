for _, descendant in ipairs(script:GetDescendants()) do
	if descendant.ClassName == 'ModuleScript' then
		shared[descendant.Name] = require(descendant)
	end
end

for _, descendant in ipairs(game.ReplicatedStorage.Shared:GetDescendants()) do
    if descendant.ClassName == 'ModuleScript' then
        shared[descendant.Name] = require(descendant)
    end
end

for _, module in pairs(shared) do
	if type(module.init) == 'function' then
		module.init()
	end
end

for _, module in pairs(shared) do
	if type(module.start) == 'function' then
		task.defer(module.start)
	end
end

