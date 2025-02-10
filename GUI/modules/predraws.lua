--[[
    More calculation, less drawing
]]

if not GUI then
    os.loadAPI("GUI/GUI.lua")
end

-- Radian To Degree Factor
local rtdf = math.pi / 180
local quarter_pi = math.pi * 0.25
local half_pi = math.pi * 0.5
local onehalf_pi = math.pi * 1.5
local double_pi = math.pi * 2
local SPACE, FG = " ", "0"

local blit_keys = {}
for i=0, 15 do
	blit_keys[2^i] = string.format("%x",i)
end

local function noDraw(...) end
local function pixel(tbl, x,y,nColor) tbl[y][x]=blit_keys[nColor] end

local function angToPos(x, y, r,ang)
    local _r = r + 0.25
    local x0, y0
    --ang = ang % double_pi
    if ang <= half_pi then
        x0 = x + math.floor(0.5+math.cos(ang)*_r*1.5)
        y0 = y - math.floor(0.5+math.sin(ang)*_r)+0.5
    elseif ang <= math.pi then
        x0 = x + math.floor(0.5+math.cos(ang)*_r*1.5)-- + (r % 2) --
        y0 = y - math.floor(0.5+math.sin(ang)*_r)+0.5
    elseif ang <= onehalf_pi then
        x0 = x + math.floor(0.5+math.cos(ang)*_r*1.5)--+ (r % 2) --
        y0 = y - math.floor(0.5+math.sin(ang)*_r)+0.5 --
    else
        x0 = x + math.floor(0.5+math.cos(ang)*_r*1.5)
        y0 = y - math.floor(0.5+math.sin(ang)*_r)+0.5 --
    end
    return math.floor(x0), math.floor(y0)
end

local function line(tbl, startX, startY, endX, endY, nColor)
    nColor = nColor or tbl.nColor
	startX = math.floor(startX)
	startY = math.floor(startY)
	endX = math.floor(endX)
	endY = math.floor(endY)
	
	if startX == endX and startY == endY then
		tbl[startY][startX] = blit_keys[nColor]
		return
	end
	local minX = math.min( startX, endX )
	if minX == startX then
		minY = startY
		maxX = endX
		maxY = endY
	else
		minY = endY
		maxX = startX
		maxY = startY
	end
		
	local xDiff = maxX - minX
	local yDiff = maxY - minY
			
	if xDiff > math.abs(yDiff) then
		local y = minY
		local dy = yDiff / xDiff
		for x=minX,maxX do
			tbl[math.floor( y + 0.5 )][x] = blit_keys[nColor]
			y = y + dy
		end
	else
		local x = minX
		local dx = xDiff / yDiff
		if maxY >= minY then
			for y=minY,maxY do
				tbl[y][math.floor( x + 0.5 )] = blit_keys[nColor]
				x = x + dx
			end
		else
			for y=minY,maxY,-1 do
				tbl[y][math.floor( x + 0.5 )] = blit_keys[nColor]
				x = x - dx
			end
		end
	end
	return tbl
end
local function lineOffset(tbl, startX, startY, w, h, nColor)
    return line(tbl, startX, startY, startX+w-1, startY+h-1, nColor)
end

local function horizontal(tbl, x1, y, x2, nColor)
    nColor = nColor or tbl.nColor
	for i=x1, x2 do
		tbl[y][i] = blit_keys[nColor]
	end
	return tbl
end
local function horizontalOffset(tbl, x1, y, w, nColor)
	return horizontal(tbl, x1, y, x1+w-1, nColor)
end

local function vertical(tbl, x, y1, y2, nColor)
    nColor = nColor or tbl.nColor
	for i=y1, y2 do
		tbl[i][x] = blit_keys[nColor]
	end
	return tbl
end
local function verticalOffset(tbl, x, y1, h, nColor)
	return vertical(tbl, x, y1, y1+h-1, nColor)
end

local function rect(tbl, x1, y1, x2, y2, nColor)
	for i = y1, y2 do
		horizontal(tbl, x1, i, x2, nColor)
	end
	return tbl
end
local function rectOffset(tbl, x1, y1, w, h, nColor)
	return rect(tbl, x1, y1, x1+w-1, y1+h-1, nColor)
end

local function box(tbl, x1, y1, x2, y2, nColor)
    horizontal(tbl, x1, y1, x2, nColor)
    horizontal(tbl, x1, y2, x2, nColor)
    vertical(tbl, x1, y1, y2, nColor)
    vertical(tbl, x2, y1, y2, nColor)
	return tbl
end
local function boxOffset(tbl, x1, y1, w, h, nColor)
	return box(tbl, x1, y1, x1+w-1, y1+h-1, nColor)
end

local function circle(tbl, x, y, r, nColor, fill)
    nColor = nColor or tbl.nColor
    local _r = r + 0.25
    local step = 0.125/(_r^2)
    local x0, y0, x1, y1
    local _draw = fill and line or noDraw
    local angle = 0
    repeat
        x0, y0 = angToPos(x, y, r, angle)
		if x0 ~= x1 or y0 ~= y1 then
			_draw(tbl, x, y0, x0, y0, nColor)
            --print(y0, x0, blit_keys[nColor])
			tbl[y0][x0] = blit_keys[nColor]
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= double_pi
	return tbl
end

local function lineRadian(tbl, x, y, r, angle, nColor)
    local x0, y0 = angToPos(x, y, r, angle)
    return line(tbl, x, y, x0, y0, nColor)
end
local function lineDegree(tbl, x, y, r, angle, nColor)
    return lineRadian(tbl, x, y, r, angle*rtdf, nColor)
end

local function arcRadian(tbl, x,y,r,a1,a2, nColor, noSort)
	if not noSort then
		a1, a2 = a1 % double_pi, a2 % double_pi
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
    nColor = nColor or tbl.nColor
	local _r = r + 0.25
    local step = 0.125/(_r^2) --* 0.25
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle)
		if x0 ~= x1 or y0 ~= y1 then
        	tbl[y0][x0] = blit_keys[nColor]
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= a2
	return tbl
end
local function arcDegree(tbl, x,y,r,a1,a2, nColor, noSort)
	if not noSort then
		a1, a2 = a1 % 360, a2 % 360
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
    nColor = nColor or tbl.nColor
	local _r = r + 0.25
    local step = quarter_pi/(_r^2)
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle*rtdf)
		if x0 ~= x1 or y0 ~= y1 then
			tbl[y0][x0] = blit_keys[nColor]
			x1, y1 = x0, y0
		end
		angle = angle + step
    until angle >= a2
	return tbl
end

local function sectorDegree(tbl, x,y,r,a1,a2, nColor, noSort)
	if not noSort then
		a1, a2 = a1 % 360, a2 % 360
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
    nColor = nColor or tbl.nColor
	local _r = r + 0.25
    local step = quarter_pi/(_r^2)
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle*rtdf)
		if x0 ~= x1 or y0 ~= y1 then
			line(tbl, x, y, x0, y0, nColor)
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= a2
end
local function sectorRadian(tbl, x,y,r,a1,a2, nColor, noSort)
	if not noSort then
		a1, a2 = a1 % double_pi, a2 % double_pi
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
    nColor = nColor or tbl.nColor
	local _r = r + 0.25
    local step =0.125/(_r^2) --* 0.25
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle)
		if x0 ~= x1 or y0 ~= y1 then
			line(tbl, x, y, x0, y0, nColor)
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= a2
end
local function draw(tbl, relX, relY) -- Drawing from relX or 1, relY or 1
    local dX, dY = (relX or 1)-1, (relY or 1)-1
    local tX, tY = tbl.target.getSize()
    local cX, buffer, bg, fg
    for y=1, tY-dY do
        tbl[y] = tbl[y] -- Autogenerate empty rows
        if #tbl[y] == 0 then goto continue end
        buffer, bg, fg = "", "", ""
        cX = 0
        for x=1, tX-dX do
            if tbl[y][x] then
                if cX <= 0 then cX = x end
                buffer = buffer..SPACE
                bg = bg..tbl[y][x]
                fg = fg..FG
            elseif cX > 0 then
                tbl.target.setCursorPos(cX+dX,y+dY)
                tbl.target.blit(buffer, fg, bg)
                buffer, bg, fg = "", "", ""
                cX = 0
            end
        end
        ::continue::
    end
end
local function clear(tbl)
    local _, tY = tbl.target.getSize()
    for k, _ in pairs(tbl) do
       if tonumber(k) then tbl[k] = nil end
    end
end

local _mm = { -- Metatable for predraw row
    __len=function(self)
        local l = 0
        for _,_ in pairs(self) do l = l + 1 end
        return l
    end
}
local _m = { -- Metatable for predraw object
    __index=function(self, index)
        if tonumber(index) then
            self[index] = setmetatable({},_mm); return self[index]
        end
    end,
}

local function getPredrawTbl(target, nColor)
    local tbl = {target=target or term.native(), }
    tbl.nColor=nColor or tbl.target.getBackgroundCOlor()
    --With absolute coordinates
    tbl.line = line
    tbl.h = horizontal
    tbl.v = vertical
    tbl.rect = rect
    tbl.box = box
    tbl.circle = circle
    -- With left upper corner and size
    tbl.line2 = lineOffset
    tbl.h2 = horizontalOffset
    tbl.v2 = verticalOffset
    tbl.rect2 = rectOffset
    tbl.box2 = boxOffset
    
    -- Rotations by dergees
    tbl.lineD = lineDegree
    tbl.arcD = arcDegree
    tbl.sectorD = sectorDegree
    
    -- Rotation by radians
    tbl.lineR = lineRadian
    tbl.arcR = arcRadian
    tbl.sectorR = sectorRadian

    tbl.draw = draw
    tbl.clear = clear
    return setmetatable(tbl, _m)
end

local function getPredrawTblEx(target, nColor)
    local tbl = {target=target or term.native(), }
    tbl.nColor=nColor or tbl.target.getBackgroundCOlor()

end

GUI.Predraw = getPredrawTbl
