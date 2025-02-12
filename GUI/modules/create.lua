--[[
    GUI API Widgets for Create mod
]]

if not GUI then
    error("GUI API not loaded")
elseif not GUI.Gauge and not fs.exists("GUI/modules/bars.lua") then
    error("Can't read GUI/modules/bars.lua")
end
local RSC =  require "epf.create.rsc"
local Stress =  require "epf.create.stress"
local locals = GUI.getLocals()
local drawRect = locals.primitives.drawRect
local getTextLayoutPos = locals.getTextLayoutPos
local SPEED_FORMAT = "%s%.3i"
local DELTA_FORMAT = "%.4i"
local NUM_FORMAT = "%i"
local ABS_SPEED = "%.3i"
GUI.StressometerMain = nil
do
    local res, err = pcall(Stress)
    if res then GUI.StressometerMain = err end
end
function GUI.setStressometer(p)
    if type(p) ~= 'table' then
        local res, err = pcall(Stress, p)
        if res then GUI.StressometerMain = err end
        return
    end
    GUI.StressometerMain = p
end


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
    rsc.label = kw.label or rsc.__pName
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
        if t[1] == "monitor_touch" and t[2] ~= peripheral.getName(s.target)
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
        text = master.label
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

local calibrate_in_process = false
local function calibrate(s)
    while calibrate_in_process do sleep(0.1) end
    calibrate_in_process = true
    if not s or not s.p or not peripheral.isPresent(s.__pName) 
        or not GUI.StressometerMain or s.p.abs < 2 then
        calibrate_in_process = false
        return
    end
    local stress = GUI.StressometerMain.stress
    s.p.abs = s.p.abs - 1
    sleep(0.1)
    s.delta = math.abs(stress - GUI.StressometerMain.stress)
    calibrate_in_process = false
end
local function rsc_auto_think(s, delay)
    delay = delay or 0.05
    while true do
        while calibrate_in_process do sleep(0.1) end
        if not s or not getmetatable(s) or
            not s.p or not peripheral.isPresent(s.__pName) then
            return
        end
        local S = GUI.StressometerMain
        if s.p.abs > s.maxSpeed then
            s.p.abs = s.p.abs - 1
        elseif s.p.abs < s.minSpeed then
            s.p.abs = s.p.abs + 1
        elseif S then
            if S.free > 2*s.delta and s.p.abs < s.maxSpeed then
                s.p.abs = s.p.abs + 1
                if S.overload and s.p.abs > 1 then
                    sleep(0.1)
                    calibrate(s)
                    sleep(0.1)
                end
            elseif S.overload and s.p.abs > s.minSpeed then
                sleep(0.1)
                calibrate(s)
                sleep(0.1)
                s.p.abs = s.p.abs - 1
            end
        elseif s.p.abs < s.maxSpeed then
            s.p.abs = s.p.abs + 1
        end
        s:draw()
        sleep(delay)
    end
end
GUI.addLocals('rsc_auto_think', rsc_auto_think)

local function rsc_auto_callback(s, _val, value)
    if custype(s) ~= "RotationSpeedControllerAutoWidget" then
        return rsc_auto_callback(s._PARENT, _val, value)
    end
    if value then
        if _val == 0 then
            s.minSpeed = math.clamp(s.minSpeed+value, 0, s.maxSpeed)
        elseif _val == 1 then
            s.maxSpeed = math.clamp(s.maxSpeed+value, s.minSpeed, 256)
        elseif _val == 2 then
            s.p.inv()
            s.__buttons.bReverse:setText(s.p.dir > 0 and "+" or "-")
        end
        s:draw()
        return
    end
    return s.p.abs, s.minSpeed, s.maxSpeed
end
RotationSpeedControllerAuto = {}
RotationSpeedControllerAuto.help = [[RotationSpeedControllerAuto{
    master, target=target, x=x, y=y,rsc=rsc,}]]
    RotationSpeedControllerAuto._meta = {
    __index=locals.defaults,
    __name="RotationSpeedControllerAutoWidget"}
function RotationSpeedControllerAuto:new(kw)
    kw = kw or {}
    local _rsc = kw.rsc
    if type(_rsc) ~= 'table' then _rsc = RSC(_rsc) end
    local rsc = GUI.Panel{kw[1] or kw.master, x=kw.x, y=kw.y}
    rsc.p = _rsc
    rsc.__pName = peripheral.getName(_rsc)
    local _m = getmetatable(rsc)
    _m.__name="RotationSpeedControllerAutoWidget"
    rsc = setmetatable(rsc, _m)
    rsc.label = kw.label or rsc.__pName
    rsc.minSpeed = 0
    rsc.maxSpeed = 256
    rsc.delta = 0
    rsc.canvas = GUI.Canvas{
        rsc, target=kw.target,
        width=10,
        height=6
    }
    rsc.canvas.draw = function(s)
        if not s.visible then return end
        local master = s._PARENT
        local cursorX, cursorY = s.target.getCursorPos()
        s:_dynRefresh()
        s.frame:draw(s.dynX, s.dynY)
        local text, text2, text3 = rsc_auto_callback(s)
        text = string.format(ABS_SPEED, text)
        master.__labels.labelSpeed.text = text
        text = string.format(SPEED_FORMAT, text2<0 and "" or "0", text2)
        master.__labels.labelMin.text = text
        text = string.format(SPEED_FORMAT, text3<0 and "" or "0", text3)
        master.__labels.labelMax.text = text
        
        text = master.label
        if #text > 8 then text = "..."..string.sub(text, -5) end
        master.__labels.labelName.text = text
        text = string.format(DELTA_FORMAT, master.delta)
        master.__buttons.bDelta.text = text

        s.target.setCursorPos(cursorX, cursorY)
    end
    rsc.canvas.frame:box(1,1,10,6,colors.orange) -- frame
    rsc.__buttons = {
        bMove = GUI.Button{rsc, target=kw.target,
            x=1,y=1, bg=colors.blue, text=">"},
        bErase = GUI.Button{rsc, target=kw.target,
            x=10,y=1,bg=colors.red,text="X",
            func=function(s) s._PARENT:erase() end},

        minRem10 = GUI.Button{rsc, target=kw.target,
            x=2,y=5,bg=colors.green, text="-",
            func=function(s) rsc_auto_callback(s, 0, -10) end},
        minRem1 = GUI.Button{rsc, target=kw.target,
            x=3,y=5,bg=colors.lime, text="-",
            func=function(s) rsc_auto_callback(s, 0, -1) end},
        minAdd1 = GUI.Button{rsc, target=kw.target,
            x=8,y=5,bg=colors.pink, text="+",
            func=function(s) rsc_auto_callback(s, 0, 1) end},
        minAdd10 = GUI.Button{rsc, target=kw.target,
            x=9,y=5,bg=colors.red, text="+",
            func=function(s) rsc_auto_callback(s, 0, 10) end},

        maxRem10 = GUI.Button{rsc, target=kw.target,
            x=2,y=4,bg=colors.green, text="-",
            func=function(s) rsc_auto_callback(s, 1, -10) end},
        maxRem1 = GUI.Button{rsc, target=kw.target,
            x=3,y=4,bg=colors.lime, text="-",
            func=function(s) rsc_auto_callback(s, 1, -1) end},
        maxAdd1 = GUI.Button{rsc, target=kw.target,
            x=8,y=4,bg=colors.pink, text="+",
            func=function(s) rsc_auto_callback(s, 1, 1) end},
        maxAdd10 = GUI.Button{rsc, target=kw.target,
            x=9,y=4,bg=colors.red, text="+",
            func=function(s) rsc_auto_callback(s, 1, 10) end},
            
            
        bDelta = GUI.Button{rsc, target=kw.target,
            x=6,y=3,bg=colors.cyan, text="0000", w=4,
            func=function(s) calibrate(s._PARENT) end},
        bReverse = GUI.Button{rsc, target=kw.target,
            x=2,y=3,bg=colors.magenta, text=(rsc.p.dir > 0 and "+" or "-"),
            func=function(s) rsc_auto_callback(s, 2, 0) end},

    }
    rsc.canvas.frame:pixel(10,1,colors.red) -- close
    rsc.canvas.frame:pixel(1,1,colors.blue) -- move
    rsc.canvas.frame:pixel(2,3,colors.magenta) -- reverse
    rsc.canvas.frame:line2(6,3,4,1,colors.blue) -- delta
    rsc.canvas.frame:line2(2,4,1,2,colors.blue) -- -10
    rsc.canvas.frame:line2(3,4,1,2,colors.blue) -- -1
    rsc.canvas.frame:line2(8,4,1,2,colors.blue) -- +1
    rsc.canvas.frame:line2(9,4,1,2,colors.blue) -- +1

    rsc.__buttons.bMove._clickCheck = rsc.__buttons.bMove.clickCheck
    rsc.__buttons.bMove.clickCheck = function(s, t)
        if not s._active then
            local result = s:_clickCheck(t)
            if result then s._active = true end
            return result
        end
        if not s.enabled then return end
        if t[1] == "monitor_touch" and t[2] ~= peripheral.getName(s.target)
            or s.target ~= term.native() and t[1] == "mouse_click" then
            return
        end
        s._PARENT:move(t[3],t[4])
        s._active = false
        s._PARENT._PARENT:draw()
        return true
    end

    rsc.__labels = {
        labelName = GUI.Label{rsc,target=kw.target,
        x=2,y=2,text="12345678",bg=colors.gray},
        labelSpeed = GUI.Label{rsc,target=kw.target,
            x=3,y=3,text="000",bg=colors.brown},
        labelMax = GUI.Label{rsc,target=kw.target,
            x=4,y=4,text="000",bg=colors.brown},
        labelMin = GUI.Label{rsc,target=kw.target,
            x=4,y=5,text="000",bg=colors.brown},
    }
    rsc.canvas.frame:line2(2,2,8,1,colors.gray) -- label
    rsc.canvas.frame:line2(3,3,4,1,colors.brown) -- speed
    rsc.canvas.frame:box2(2,2,4,2,colors.brown) -- min/max

    calibrate(rsc)
    GUI.think(rsc_auto_think, rsc)
    
    return rsc
end
GUI.RotationSpeedControllerAuto = setmetatable(
    RotationSpeedControllerAuto,
    {__call=RotationSpeedControllerAuto.new})


local function stress_auto_think(s, delay)
    delay = delay or 0.05
    while true do
        if not s or 
            not s.p or not peripheral.isPresent(s.__pName) then
            return
        end
        s:draw()
        sleep(delay)
    end
end
GUI.addLocals('stress_auto_think', stress_auto_think)
local function stress_callback(s, m)
    if custype(s) ~= "StressometerBar" then
        return stress_callback(s._PARENT, m)
    end
    if m == 0 then
        return math.clamp(s.p.use,0,1), string.format(NUM_FORMAT, s.p.stress)
    else
        return math.clamp(s.p.use,0,1), string.format(NUM_FORMAT, s.p.cap)
    end
end
local function stress_color_parse(s)
    if s.p.use <= 0.5 then
        for _,v in pairs(s.__bars) do v.color_bg = colors.green end
    elseif s.p.use <= 0.8 then
        for _,v in pairs(s.__bars) do v.color_bg = colors.yellow end
    else
        for _,v in pairs(s.__bars) do v.color_bg = colors.red end
    end
end
local StressometerBar = {}
StressometerBar.help = [[StressometerBar{
    master, target=target, x=x, y=y,stress=stress,label=label}]]
    StressometerBar._meta = {
    __index=locals.defaults,
    __name="StressometerBar"}
function StressometerBar:new(kw)
    kw = kw or {}
    local _stress = kw.stress
    if type(_rsc) ~= 'table' then _stress = Stress(_stress) end
    local stress = GUI.Panel{kw[1] or kw.master, x=kw.x, y=kw.y}
    stress.p = _stress
    stress.__pName = peripheral.getName(_stress)
    local _m = getmetatable(stress)
    _m.__name="StressometerBar"
    stress = setmetatable(stress, _m)
    stress.label = kw.label or stress.__pName
    stress.canvas = GUI.Canvas{
        stress, target=kw.target,
        width=10,
        height=5
    }
    stress.canvas.draw = function(s)
        if not s.visible then return end
        local master = s._PARENT
        local cursorX, cursorY = s.target.getCursorPos()
        s:_dynRefresh()
        s.frame:draw(s.dynX, s.dynY)
        
        local text = master.label
        if #text > 8 then text = "..."..string.sub(text, -5) end
        master.labelName.text = text
        
        stress_color_parse(master)
        s.target.setCursorPos(cursorX, cursorY)
    end
    stress.canvas.frame:rect(2,2,9,4,colors.black)
    stress.canvas.frame:box(1,1,10,5,colors.orange)
    stress.__buttons = {
    bMove = GUI.Button{stress, target=kw.target,
        x=1,y=1, bg=colors.blue, text=">"},
    bErase = GUI.Button{stress, target=kw.target,
        x=10,y=1,bg=colors.red,text="X",
        func=function(s) s._PARENT:erase() end},
    }
    stress.__buttons.bMove._clickCheck = stress.__buttons.bMove.clickCheck
    stress.__buttons.bMove.clickCheck = function(s, t)
        if not s._active then
            local result = s:_clickCheck(t)
            if result then s._active = true end
            return result
        end
        if not s.enabled then return end
        if t[1] == "monitor_touch" and t[2] ~= peripheral.getName(s.target)
            or s.target ~= term.native() and t[1] == "mouse_click" then
            return
        end
        s._PARENT:move(t[3],t[4])
        s._active = false
        s._PARENT._PARENT:draw()
        return true
    end
    stress.labelName = GUI.Label{stress,target=kw.target,
        x=2,y=2,text="12345678",bg=colors.gray}
    stress.__bars = {
        barStress = GUI.ProgressBar{stress,target=kw.target,
            x=2,y=3,w=8,color_used=colors.purple,
            func=function(s) return stress_callback(s, 0) end},
        barCap = GUI.ProgressBar{stress,target=kw.target,
            x=2,y=4,w=8,color_used=colors.purple,
            func=function(s) return stress_callback(s, 1) end},
    }

    GUI.think(stress_auto_think, stress)

    return stress
end
GUI.StressometerBar = setmetatable(
    StressometerBar,
    {__call=StressometerBar.new})


