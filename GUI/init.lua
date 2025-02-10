--[[
    Autoloader for GUI API
]]
if GUI then
    return GUI
end

-- Load API
os.loadAPI("GUI/GUI.lua")

-- Load modules
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
local rel_path = script_path().."modules/"
if not fs.isDir(rel_path) then
    return GUI
end
for _,path in pairs(fs.list(rel_path)) do
    local p = rel_path..path
	if fs.exists(p) and not fs.isDir(p) and string.match(p, ".+%.lua") then
        --dofile(p) -- Execute modules
        loadfile(p,nil,_ENV)()
        --require(p:sub(1,-5))
    end
end

return GUI
