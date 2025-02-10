--[[
    Gauge widget for GUI API
]]

if not GUI then
    os.loadAPI("GUI/GUI.lua")
end

-- Yes, Lua didn't known math.sign
if not math.sign then
    function math.sign(value)
        return value >= 0 and 1 or -1
    end
end
local locals = GUI.getLocals()
local defaults = locals.defaults

-- Radian To Degree Factor
--local rtdf = math.pi / 180
local half_pi = math.pi * 0.5
local onehalf_pi = math.pi * 1.5
local double_pi = math.pi * 2
local twohalf_pi = math.pi * 2.5

local ModeToOffset = {--          W                         H         X                             Y       A(0)            A(1)            dA          R
    [1] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        1,                            h-2,    0,              half_pi,        half_pi,    h-3    end,
    [2] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        (h*1.5)-(h*1.5)%2-2,          h-2,    half_pi,        math.pi,        half_pi,    h-3    end,
    [3] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        (h*1.5)-(h*1.5)%2-2,          1,      math.pi,        onehalf_pi,     half_pi,    h-3    end,
    [4] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        1,                            1,      onehalf_pi,     double_pi,      half_pi,    h-3    end,
    [5] = function(h) return   ((h*1.5)-(h*1.5)%2)*2-3,     h,        (((h*1.5)-(h*1.5)%2)*2-3)/2,  h-2,    0,              math.pi,        math.pi,    h-3    end,
    [6] = function(h) return   (h*1.5)-(h*1.5)%2,           h*2-3,    (h*1.5)-(h*1.5)%2-2,          h-2,    half_pi,        onehalf_pi,     math.pi,    h-3    end,
    [7] = function(h) return   ((h*1.5)-(h*1.5)%2)*2-3,     h,        (((h*1.5)-(h*1.5)%2)*2-3)/2,  1,      math.pi,        double_pi,      math.pi,    h-3    end,
    [8] = function(h) return   (h*1.5)-(h*1.5)%2,           h*2-3,    1,                            h-2,    onehalf_pi,     twohalf_pi,     math.pi,    h-3    end,
    
    [-4] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        1,                            h-2,    0,             -half_pi,       -half_pi,    h-3    end,
    [-3] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        (h*1.5)-(h*1.5)%2-2,          h-2,    -half_pi,      -math.pi,       -half_pi,    h-3    end,
    [-2] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        (h*1.5)-(h*1.5)%2-2,          1,      -math.pi,      -onehalf_pi,    -half_pi,    h-3    end,
    [-1] = function(h) return   (h*1.5)-(h*1.5)%2,           h,        1,                            1,      -onehalf_pi,   -double_pi,     -half_pi,    h-3    end,
    [-7] = function(h) return   ((h*1.5)-(h*1.5)%2)*2-3,     h,        (((h*1.5)-(h*1.5)%2)*2-3)/2,  h-2,    0,             -math.pi,       -math.pi,    h-3    end,
    [-8] = function(h) return   (h*1.5)-(h*1.5)%2,           h*2-3,    (h*1.5)-(h*1.5)%2-2,          h-2,    -half_pi,      -onehalf_pi,    -math.pi,    h-3    end,
    [-5] = function(h) return   ((h*1.5)-(h*1.5)%2)*2-3,     h,        (((h*1.5)-(h*1.5)%2)*2-3)/2,  1,      -math.pi,      -double_pi,     -math.pi,    h-3    end,
    [-6] = function(h) return   (h*1.5)-(h*1.5)%2,           h*2-3,    1,                            h-2,    -onehalf_pi,   -twohalf_pi,    -math.pi,    h-3    end,
}
--[[
local ModeToOffset = {--                            X        Y       A(0)            A(1)            dA
    [1] = function(w,h) return                      1,       h-2,    0,              half_pi,        half_pi     end,
    [2] = function(w,h) return                      w-2,     h-2,    half_pi,        math.pi,        half_pi     end,
    [3] = function(w,h) return                      w-2,     1,      math.pi,        onehalf_pi,     half_pi     end,
    [4] = function(w,h) return                      1,       1,      onehalf_pi,     double_pi,      half_pi     end,
    [5] = function(w,h) return                      w/2,     h-2,      0,              math.pi,        math.pi     end,
    [6] = function(w,h) return                      w-1,     h/2,    half_pi,        onehalf_pi,     math.pi     end,
    [7] = function(w,h) return                      w/2,     1,      math.pi,        double_pi,      math.pi     end,
    [8] = function(w,h) return                      1,       h/2,    onehalf_pi,     twohalf_pi,     math.pi     end,

    [-1] = function(w,h) return                     1,      1,      0,              -half_pi,       -half_pi    end,
    [-2] = function(w,h) return                     w-2,    1,      -half_pi,       -math.pi,       -half_pi    end,
    [-3] = function(w,h) return                     w-2,    h-2,    -math.pi,       -onehalf_pi,    -half_pi    end,
    [-4] = function(w,h) return                     1,      h-2,    -onehalf_pi,    -double_pi,     -half_pi    end,
    [-5] = function(w,h) return                     1,      h/2,    0,              -math.pi,       -math.pi    end,
    [-6] = function(w,h) return                     w/2,    1,      -half_pi,       -onehalf_pi,    -math.pi    end,
    [-7] = function(w,h) return                     w/2,    h-2,      -math.pi,       -double_pi,     -math.pi    end,
    [-8] = function(w,h) return                     w/2,    h/2,    -onehalf_pi,    -twohalf_pi,    -math.pi    end,
}
]]
--[[
   -3|-4            -7              |
    2|1             5              6|-6
-----+-----     -----+-----         +
   -2|-1            7             -8|8
    3|4             -5              |

    Mode|Start| End  | Xoffset | Yoffset
    1   |   0 |   90 |    1    |   h-1
    2   |  90 |  180 |   w-1   |   h-1
    3   | 180 |  270 |   w-1   |    1
    4   | 270 |  360 |    1    |    1
    5   |   0 |  180 |   w/2   |   h-1
    6   |  90 |  270 |   w-1   |   h/2
    7   | 180 |  360 |   w/2   |    1
    8   | 270 |  450 |    1    |   h/2
    -1  |   0 |  -90 |    1    |    1
    -2  | -90 | -180 |   w-1   |    1
    -3  |-180 | -270 |   w-1   |   h-1
    -4  |-270 | -360 |    1    |   h-1
    -5  |   0 | -180 |   w/2   |    1
    -6  | -90 | -270 |    1    |   h/2
    -7  |-180 | -360 |   w/2   |   h-1
    -8  |-270 | -450 |    1    |   h/2
]]
local Gauge = {}
Gauge.help = "Gauge{master, target=target, x=x, y=y, mode=mode, height=height, color_bg=color_bg, color_text=color_text, color_used=color_used, color_frame=color_frame, color_bg2=color_bg2}"
Gauge._meta = {__index=locals.defaults, __name="Gauge"}
function Gauge:new(kw)
    local gauge = {
		progress = 0.0,
		setProgress = function(s, np)
			s.progress = math.max(0, math.min(1, np))
			s:draw()
		end,
		clear = function(s)
			s.progress = 0
			s:draw()
		end,

        draw = function(s, noDraw)
			if not s.visible then return end
			local cursorX, cursorY = s.target.getCursorPos()
			
			s:_dynRefresh()

            local angle = s.empty + s.progress * s.mult

            if s.frame.target ~= s.target then
                s.frame.target = s.target
            end
            s.frame:clear()
            s.frame:rect2(1,1, s.width, s.height, s.color_bg2)
            s.frame:box2(1,1, s.width, s.height, s.color_frame)
            s.frame:sectorR(1 + s.offsetX, 1 + s.offsetY, s.radius, angle, s.full, s.color_bg, true)
            s.frame:sectorR(1 + s.offsetX, 1 + s.offsetY, s.radius, s.empty, angle, s.color_used, true)
            s.frame:lineR(1 + s.offsetX, 1 + s.offsetY, s.radius, angle, s.color_text)
			
            if not noDraw then
                s.frame:draw(s.dynX, s.dynY)
                s.target.setCursorPos(cursorX, cursorY)
            else
                return cursorX, cursorY
            end
		end,
    }
    kw = kw or {}
	gauge = setmetatable(gauge, {__index=defaults, __name="Gauge"})
	gauge.target = kw.target
	gauge.x = kw.x
	gauge.y = kw.y
	--gauge.height = kw.height or kw.h or kw.size or kw.s or 10
	gauge.color_text = kw.color_text or kw.fg    -- Clock hand color
	gauge.color_bg = kw.color_bg or kw.bg        -- Unused
	gauge.color_used = kw.color_used or kw.cu    -- Used
	gauge.color_frame = kw.color_frame or colors.orange
	gauge.color_bg2 = kw.color_bg2 or colors.black -- Free space
    gauge.mode = ModeToOffset[math.abs(kw.mode or 1)] and kw.mode or 1

    gauge.frame = GUI.Predraw(gauge.target, colors.black)
    
    gauge.width, gauge.height,
        gauge.offsetX, gauge.offsetY,
            gauge.empty, gauge.full,
                gauge.mult, gauge.radius = ModeToOffset[math.abs(gauge.mode)](kw.height or kw.h or kw.size or kw.s or 10)
    
	local master = kw[1] or kw.master or GUI.MainPanel
    if master then
        master:addCHILD(gauge)
    end
	
	return gauge
end
GUI.Gauge = setmetatable(Gauge,{__call=Gauge.new})

local Canvas = {}
Canvas.help = "Canvas{master, target=target, x=x, y=y, width=width, height=height, color_bg=color_bg}"
Canvas._meta = {__index=locals.defaults, __name="Canvas"}
function Canvas:new(kw)
    local canvas = {
        draw = function(s)
			if not s.visible then return end
			local cursorX, cursorY = s.target.getCursorPos()
			s:_dynRefresh()
            s.frame:draw(s.dynX, s.dynY)
            s.target.setCursorPos(cursorX, cursorY)
        end
    }
    kw = kw or {}
	canvas = setmetatable(canvas, {__index=defaults, __name="Canvas"})
	canvas.target = kw.target
	canvas.x = kw.x
	canvas.y = kw.y
    canvas.width = kw.width or kw.w
    canvas.height = kw.height or kw.h
    canvas.frame = GUI.Predraw(canvas.target, kw.color_bg or kw.bg or colors.white)

    local master = kw[1] or kw.master or GUI.MainPanel
    if master then
        master:addCHILD(canvas)
    end
	
	return canvas
end
GUI.Canvas = setmetatable(Canvas,{__call=Canvas.new})
