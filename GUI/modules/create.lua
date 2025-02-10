--[[
    GUI API Widgets for Create mod
]]

if not GUI then
    error("GUI API not loaded")
elseif not GUI.Gauge and not fs.exists("GUI/modules/bars.lua") then
    error("Can't read GUI/modules/bars.lua")
end
local RSC =  require "epf.create.rsc"
local locals = GUI.getLocals()
local defaults = locals.defaults
local getTextLayoutPos = locals.getTextLayoutPos


--[[
Callback example:
local function callback(s, value)
    if value then
        setValue(value)
        s:draw()
        return
    end
    return getValue()/getMaxValue(), string.format("%i/%i", getValue(), getMaxValue())
end
]]
local GaugeText = {}
GaugeText.help = [[GaugeText{
    master, target=target, x=x, y=y, mode=mode, height=height,
    func=func,
    color_bg=color_bg, color_text=color_text, color_used=color_used,
    color_frame=color_frame, color_bg2=color_bg2}]]
GaugeText._meta = {__index=locals.defaults, __name="GaugeText"}
function GaugeText:new(kw)
    if not kw.func and not kw.callback and not kw.call then
        error("GUI.GaugeText required callback function for getting/setting stress value")
    end
    local gauge = GUI.Gauge(kw)
    local _m = getmetatable(gauge)
    _m.__name="GaugeText"
    gauge = setmetatable(gauge, _m)
    gauge.func = kw.func or kw.callback or kw.call
    gauge._draw = gauge.draw
    gauge.draw = function(s)
        s.progress, s.text = s:func()
        local cursorX, cursorY = s:_draw(true)
        
        s.__frame:rect2(s.dynX, s.dynY+s.height, s.width, 2, s.color_bg2)
        s.__frame:box2(s.dynX, s.dynY+s.height-1, s.width, 3, s.color_frame)
        s.__frame:draw()
        local cx, cy = getTextLayoutPos(s.text_pos, s.text, s.dynX+1, s.dynY+s.height, s.width-2, 1)
        s.target.setCursorPos(cx, cy)
        s.target.blit(
            s.text,
            colors.toBlit(s.color_text):rep(#s.text),
            colors.toBlit(s.color_bg2):rep(#s.text)
        )

        s.target.setCursorPos(cursorX, cursorY)
    end
	return gauge
end
GUI.GaugeText = setmetatable(GaugeText,{__call=GaugeText.new})

local SPEED_FORMAT = "%s%.3i"
local function rsc_callback(s, value)
    if custype(s) ~= "RotationSpeedControllerWidget" then
        return rsc_callback(s._PARENT, value)
    end
    if value then
        s.p.speed = s.p.speed + value
        s:draw()
        return
    end
    return s.p.speed
end
local RotationSpeedController = {}
RotationSpeedController.help = [[RotationSpeedController{
    master, target=target, x=x, y=y,rsc=rsc,}]]
RotationSpeedController._meta = {
    __index=locals.defaults,
    __name="RotationSpeedController"}
function RotationSpeedController:new(kw)
    kw = kw or {}
    local _rsc = kw.rsc
    if type(_rsc) ~= 'table' then _rsc = RSC(_rsc) end
    local rsc = GUI.Panel{kw[1] or kw.master, x=kw.x, y=kw.y}
    rsc.p = _rsc
    rsc.__pName = peripheral.getName(_rsc)
    local _m = getmetatable(rsc)
    _m.__name="RotationSpeedControllerWidget"
    rsc = setmetatable(rsc, _m)
--[[
X - frame; B - button, N - Name label, S - speed label
XXXXXXXXXX
XNNNNNNNNX
XBBSSSSBBX
XXXXXXXXXX
]]
    rsc.bMove = GUI.Button{rsc, target=kw.target,
        x=1,y=1, bg=colors.blue, text=">"
    }
    rsc.bMove._clickCheck = rsc.bMove.clickCheck
    rsc.bMove.clickCheck = function(s, t)
        if not s._active then
            local result = s:_clickCheck(t) 
            if result then s._active = true end
            return result
        end
        if not s.enabled then return end
        if t[1] == "monitor_touch" and t[2] ~= peripheral.getName()
            or s.target ~= term.native() and t[1] == "mouse_click" then
            return
        end
        s._PARENT:move(t[3],t[4])
        s._active = false
        s._PARENT._PARENT:draw()
        return true
    end
    rsc.bErase = GUI.Button{rsc, target=kw.target,
        x=10,y=1,bg=colors.red,text="X",
        func=function(s) s._PARENT:erase() end
    }

    rsc.bRem10 = GUI.Button{rsc, target=kw.target,
        x=2,y=3, bg=colors.green, text="-",
        func=function(s) return rsc_callback(s, -10) end
    }
    rsc.bRem1 = GUI.Button{rsc, target=kw.target,
        x=3,y=3, bg=colors.lime, text="-",
        func=function(s) return rsc_callback(s, -1) end
    }
    rsc.bAdd1 = GUI.Button{rsc, target=kw.target,
        x=8,y=3, bg=colors.pink, text="+",
        func=function(s) return rsc_callback(s, 1) end
    }
    rsc.bAdd10 = GUI.Button{rsc, target=kw.target,
        x=9,y=3, bg=colors.red, text="+",
        func=function(s) return rsc_callback(s, 10) end
    }
    rsc.labelSpeed = GUI.Label{rsc,target=kw.target,
    x=4,y=3,text="0000",bg=colors.brown}
    rsc.labelName = GUI.Label{rsc,target=kw.target,
    x=2,y=2,text="12345678",bg=colors.gray}

    rsc.canvas = GUI.Canvas{
        rsc, target=kw.target,
        width=10,
        height=4
    }
    rsc.canvas.draw = function(s)
        if not s.visible then return end
        local master = s._PARENT
        local cursorX, cursorY = s.target.getCursorPos()
        s:_dynRefresh()
        s.frame:draw(s.dynX, s.dynY)
        local text = rsc_callback(s)
        text = string.format(SPEED_FORMAT, text<0 and "" or "0",text)
        master.labelSpeed:setText(text)
        text = master.__pName
        if #text > 8 then text = "..."..string.sub(text, -5) end
        master.labelName:setText(text)
        master.bRem10:draw()
        master.bRem1:draw()
        master.bAdd1:draw()
        master.bAdd10:draw()
        master.bMove:draw()
        master.bErase:draw()
        s.target.setCursorPos(cursorX, cursorY)
    end
    rsc.canvas.frame:rect(1,1,10,4,colors.black)
    rsc.canvas.frame:box(1,1,10,4,colors.orange)

    return rsc
end
GUI.RotationSpeedController = setmetatable(
    RotationSpeedController,
    {__call=RotationSpeedController.new})








