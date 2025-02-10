--[[
    Primitive geometry draw
]]

-- Radian To Degree Factor
local rtdf = math.pi / 180
local quarter_pi = math.pi * 0.25
local half_pi = math.pi * 0.5
local onehalf_pi = math.pi * 1.5
local double_pi = math.pi * 2
local SPACE = " "

--local blit_keys = {}
--for i=0, 15 do
--	blit_keys[2^i] = string.format("%x",i)
--end

local function noDraw(...) end

local function drawPixelInternal( target, xPos, yPos )
	target.setCursorPos(xPos, yPos)
	target.write(SPACE)
end

local function drawPixel(target, xPos, yPos, nColor )
	if nColor then
		target.setBackgroundColor( nColor )
	end
	drawPixelInternal( target, xPos, yPos )
end

local function drawLine(target, startX, startY, endX, endY, nColor )
	if nColor then
		target.setBackgroundColor( nColor )
	end
	
	startX = math.floor(startX)
	startY = math.floor(startY)
	endX = math.floor(endX)
	endY = math.floor(endY)
	
	if startX == endX and startY == endY then
		drawPixelInternal( target, startX, startY )
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
			drawPixelInternal( target, x, math.floor( y + 0.5 ) )
			y = y + dy
		end
	else
		local x = minX
		local dx = xDiff / yDiff
		if maxY >= minY then
			for y=minY,maxY do
				drawPixelInternal( target, math.floor( x + 0.5 ), y )
				x = x + dx
			end
		else
			for y=minY,maxY,-1 do
				drawPixelInternal( target, math.floor( x + 0.5 ), y )
				x = x - dx
			end
		end
	end
end

local function drawHorisontal(target, x1, y1, x2, nColor)
	if nColor then
		target.setBackgroundColor( nColor )
	end
	target.setCursorPos(x1,y1)
	target.write(SPACE:rep(x2-x1+1))
end

local function drawRect(target, x1, y1, w, h, nColor)
	for i = 0, h - 1 do
		drawHorisontal(target, x1, y1+i, x1+w-1, nColor)
	end
end
local function drawRect2(target, x1, y1, x2, y2, nColor)
	for i = y1, y2 do
		drawHorisontal(target, x1, i, x2, nColor)
	end
end

local function drawBox(target, x1, y1, w, h, nColor)
    drawHorisontal(target, x1, y1, x1 + w - 1, nColor)
    drawHorisontal(target, x1, y1 + h - 1, x1 + w - 1, nColor)
    drawLine(target, x1 + w - 1, y1, x1 + w - 1, y1 + h - 1, nColor)
    drawLine(target, x1, y1, x1, y1 + h - 1, nColor)
end
local function drawBox2(target, x1, y1, x2, y2, nColor)
    drawHorisontal(target, x1, y1, x2, nColor)
    drawHorisontal(target, x1, y2, x2, nColor)
    drawLine(target, x1, y1, x1, y2, nColor)
    drawLine(target, x2, y1, x2, y2, nColor)
end

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
    return x0, y0
end

local function drawCircle(target, x, y, r, nColor, fill)
    local _r = r + 0.25
    local step = 0.125/(_r^2)
    local x0, y0, x1, y1
    local draw = fill and drawLine or noDraw
    local angle = 0
    repeat
        x0, y0 = angToPos(x, y, r, angle)
		if x0 ~= x1 or y0 ~= y1 then
			drawPixel( target, x0, y0,nColor )
			draw(target, x, y0, x0, y0, nColor)
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= double_pi
end

local function drawLineDegree(target, x, y, r, angle, nColor)
    local x0, y0 = angToPos(x, y, r,angle*rtdf)
    drawLine(target, x, y, x0, y0, nColor)
end

local function drawLineRadian(target, x, y, r, angle, nColor)
    local x0, y0 = angToPos(x, y, r, angle)
    drawLine(target, x, y, x0, y0, nColor)
end


local function drawArc(target, x,y,r,a1,a2,nColor,noSort)
	if not noSort then
		a1, a2 = a1 % 360, a2 % 360
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
	local _r = r + 0.25
    local step = quarter_pi/(_r^2)
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle*rtdf)
		if x0 ~= x1 or y0 ~= y1 then
			drawPixel( target, x0, y0, nColor )
			x1, y1 = x0, y0
		end
		angle = angle + step
    until angle >= a2
end

local function drawArcRadian(target, x,y,r,a1,a2,nColor,noSort)
	if not noSort then
		a1, a2 = a1 % double_pi, a2 % double_pi
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
	local _r = r + 0.25
    local step = 0.125/(_r^2) --* 0.25
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle)
		if x0 ~= x1 or y0 ~= y1 then
        	drawPixel( target, x0, y0,nColor )
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= a2
end

local function drawSector(target, x,y,r,a1,a2,nColor,noSort)
	if not noSort then
		a1, a2 = a1 % 360, a2 % 360
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
	local _r = r + 0.25
    local step = quarter_pi/(_r^2)
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle*rtdf)
		if x0 ~= x1 or y0 ~= y1 then
			drawLine(target, x, y, x0, y0, nColor)
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= a2
end
local function drawSectorRadian(target, x,y,r,a1,a2,nColor,noSort)
	if not noSort then
		a1, a2 = a1 % double_pi, a2 % double_pi
		a1, a2 = math.min(a1,a2), math.max(a1,a2)
	end
	local _r = r + 0.25
    local step =0.125/(_r^2) --* 0.25
    local x0, y0, x1, y1
	local angle = a1
	repeat
        x0, y0 = angToPos(x, y, r,angle)
		if x0 ~= x1 or y0 ~= y1 then
			drawLine(target, x, y, x0, y0, nColor)
			x1, y1 = x0, y0
		end
        angle = angle + step
    until angle >= a2
end


local lib = {
    drawPixelInternal=drawPixelInternal,
    drawPixel=drawPixel,
    drawLine=drawLine,
    drawHorisontal=drawHorisontal,
    drawRect=drawRect,
    drawRectAbs=drawRect2,
    drawBox=drawBox,
    drawBox2=drawBox2,
    drawCircle=drawCircle,
    drawLineDegree=drawLineDegree,
    drawLineRadian=drawLineRadian,
	drawArc=drawArc,
	drawArcRadian=drawArcRadian,
	drawSector=drawSector,
	drawSectorRadian=drawSectorRadian,
	drawSectorExRadian=drawSectorExRadian
}

return lib
