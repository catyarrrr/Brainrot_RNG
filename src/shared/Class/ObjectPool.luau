local HIDDEN_CF, POOLSIZE_DEFAULT = CFrame.new(0, -500, 0), 20
local HideObject, ShowObject = nil
local self, pools = {}, {}

-- 创建对象池
function self.Create(poolName, template, initCount, tag)
    if pools[poolName] then
        -- warn(poolName .. " pool already exists")
        return
    end

	-- self.DestroyByTag(tag)

    local folder = Instance.new("Folder")
    folder.Name = poolName .. "_Pool"
    folder.Parent = workspace

    local pool = {
        Template = template,
        Folder = folder,
        Available = {},
		All = {},
		Tag = tag
    }

    pools[poolName] = pool

    initCount = initCount or POOLSIZE_DEFAULT

    for _ = 1, initCount do
        local obj = template:Clone()
        obj.Parent = folder
        HideObject(obj)

        table.insert(pool.All, obj)
        table.insert(pool.Available, obj)
    end
end
-- 插入对象池
function self.Insert(name, obj)
    local pool = pools[name]
    if pool == nil then warn('pool insert error  for name:', name); return end

    obj.Parent = pool.Folder
    HideObject(obj)

    table.insert(pool.All, obj)
    table.insert(pool.Available, obj)
end
-- 获取对象
function self.Get(name)
    local pool = pools[name]
    if not pool then
        -- warn(name .. " pool not found")
        return nil
    end

	local obj = table.remove(pool.Available, 1)
	if obj then ShowObject(obj); return obj end

    -- 不够就扩容
    obj = pool.Template:Clone()
    obj.Parent = pool.Folder

    table.insert(pool.All, obj)

    return obj
end
-- 回收对象
function self.Return(name, obj)
    local pool = pools[name]
    if not pool then
        return
    end

	if table.find(pool.All, obj) == nil then warn('obj does not belong to pool:', name); return end
	if table.find(pool.Available, obj) then return end

	HideObject(obj)
	obj.Parent = pool.Folder
	table.insert(pool.Available, obj)
end
-- 销毁对象池
function self.Destroy(name)
    local pool = pools[name]
    if not pool then
        return
    end

    pool.Folder:Destroy()
    pools[name] = nil
end

function HideObject(obj)
    if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
        obj.Enabled = false
        obj.Adornee = nil  -- 如果用的是 Adornee
    elseif obj:IsA("BasePart") or obj:IsA("Model") then
        obj:PivotTo(HIDDEN_CF)
    else
        obj.Parent = nil  -- 兜底
    end
end
function ShowObject(obj)
    if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
        obj.Enabled = true
    end
    -- Part/Model 不需要在 Get 里做额外处理，由调用方设置位置
end
function self.DestroyByTag(tag)
	if tag == nil then return end

	local toDestroy = {}
	for k, v in pools do
		if v.Tag == tag then
			table.insert(toDestroy, k)
		end
	end

	for _, k in toDestroy do
		self.Destroy(k)
	end
end

return self