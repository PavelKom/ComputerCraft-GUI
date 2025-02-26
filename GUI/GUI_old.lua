--[[
	Graphic API based on widgets. Original API written by 1Ridav, but has not been updated for over 10 years. Old API is kept for backward support.
	Note: for correct work it is required that API is loaded via os.loadAPI(),
		but you can load API using require(),
		it will load all modules and remain in the global table
	Original API: https://github.com/1Ridav/ComputerCraft-GUI
	Authors: 1Ridav (original API), PavelKom (new API)
	List of updates/improvements:
		The default value table is not duplicated when creating new widgets, which reduces memory consumption.
		It is possible to create widgets with postional and named arguments (like *args and **kwargs in Python).
		You don't have to pass all the arguments, because there is a default value for each one.
			Old API:
				local button = GUI.NewButton(monitor, x, y, width, height, text, func, color_bg, color_text, color_used)
			New API:
				-- monitor positional argument, others by key. Note: Syntactic sugar is used to pass named arguments, since the function takes only 1 argument (table).
				local button = GUI.Button{monitor, x=x, y=y, width=width, height=height, text=text, func=func, color_bg=color_bg, color_text=color_text, color_used=color_used}
				-- or
				local button = GUI.Button( {monitor, x=x, y=y, width=width, height=height, text=text, func=func, color_bg=color_bg, color_text=color_text, color_used=color_used} )
		Progress bar can accept a function to display a custom message
		When the program is terminated via GUI.EXIT(), the widgets are completely deleted (but still remain on the screen, since the terminal/monitor is not updated).
		To work, widgets use the events 'mouse_click', 'monitor_touch', 'key', 'char'.
			If your program does not call all these events, then just use GUI.NO_OUTPUT()
			And if they are used, then GUI.NO_OUTPUT_CUSTOM(...) specifying the events that you do NOT track.
		Ability to write modules and import local methods and properties from GUI using GUI.getLocals(), 
			so that you don't have to reassign them in the module. You can also add local methods and properties to modules using GUI.addLocals()
		The construction of pixels, lines and rectangles has been moved to a separate file.
			There are also methods for constructing circles, arcs, sectors and lines by radius and rotation angle.
			When constructing arcs/circles/sectors, the radius is specified equal to the height,
			since due to the pixel proportions (2/3), the width is multiplied by 3/2 to avoid ellipticity.
		Widgets are automatically made a child of MainPanel unless otherwise specified.
]]

-- Pool with local or imported functions. Used for API modules but not required for programs.
local _l = {}
function addLocals(name, obj)
    --if _l[name] ~= nil then return end
    _l[name] = obj
end
function getLocals() return _l end

addLocals('primitives', dofile("GUI/primitives.lua"))
local drawLine = _l.primitives.drawLine
local drawRect = _l.primitives.drawRect
-------------------------------------------------
local SELECTED_OBJECT = nil
local backupPullEvent = os.pullEvent
-------------------------------------------------
function SET_SELECTED_OBJECT(OBJ)
	SELECTED_OBJECT = OBJ
end
function CLEAR_SCREEN(color, target)
	if not target then target = term.native() end
	if color then target.setBackgroundColor(color) end
	target.clear()
end
local function cleanup(object)
	for k, child in pairs(object._CHILDREN or {}) do
		cleanup(child)
		setmetatable(object, nil) -- Remove metatable
		object._CHILDREN[k] = nil -- MOST IMPORTANT PART!!! UNBIND BY KEY
	end
end
addLocals('cleanup', cleanup)
function CLEAN()
	cleanup(MainPanel)
end

local function guiLoopN(name)
	return function()
		while true do
			os.pullEvent(name)
		end
	end
end
addLocals('guiLoopN', guiLoopN)
local function no_exit()
	os.pullEvent("GUI_USER_EXIT")
end
addLocals('no_exit', no_exit)
function NO_EXIT_CUSTOM(...)
	local loops = {}
	for _, v in pairs{...} do loops[#loops+1] = guiLoopN(v) end
	parallel.waitForAny(no_exit, table.unpack(loops))
	cleanup(MainPanel)
	--collectgarbage()
end
function NO_EXIT()
	NO_EXIT_CUSTOM('mouse_click', 'monitor_touch', 'key', 'char')
end
function EXIT()
	os.queueEvent("GUI_USER_EXIT")
end
local function getTextLayoutPos(layout, text, x, y, width, height, px, py)
	if layout == "topleft" then
		return x, y
	elseif layout == "top" then
		local cx = x + math.floor( ( width - string.len(text) ) / 2)
		return cx, y
	elseif layout == "topright" then
		local cx = x + ( width - string.len(text) ) + 1
		return cx, y
	elseif layout == "center" then
		local cy = y + math.floor(height / 2)
		local cx = x + math.floor( ( width - string.len(text) ) / 2)
		return cx, cy	
	elseif layout == "left" then
		local cy = y + math.floor(height / 2)
		return x, cy	
	elseif layout == "right" then
		local cx = x +( width - string.len(text) ) + 1
		local cy = y + math.floor(height / 2) 
		return cx, cy
	elseif layout == "bottomleft" then
		local cy = y + math.floor(height / 2) + 1
		return x, cy
	elseif layout == "bottom" then
		local cx = x + math.floor( ( width - string.len(text) ) / 2)
		local cy = y + math.floor(height / 2) + 1
		return cx, cy
	elseif layout == "bottomright" then
		local cx = x +( width - string.len(text) ) + 1
		local cy = y + math.floor(height / 2) + 1
		return cx, cy
	end
end
addLocals('getTextLayoutPos', getTextLayoutPos)
-- Vertical version
local function getTextLayoutPosV(layout, text, x, y, width, height, px, py)
	if layout == "topleft" then
		return x, y
	elseif layout == "top" then
		local cx = x + math.floor( width / 2)
		return cx, y
	elseif layout == "topright" then
		local cx = x + width + 1
		return cx, y
	elseif layout == "center" then
		local cy = y + math.floor( ( height - string.len(text) ) / 2)
		local cx = x + math.floor( width / 2)
		return cx, cy	
	elseif layout == "left" then
		local cy = y + math.floor( ( height - string.len(text) ) / 2)
		return x, cy	
	elseif layout == "right" then
		local cx = x + x + width + 1
		local cy = y + math.floor( ( height - string.len(text) ) / 2)
		return cx, cy
	elseif layout == "bottomleft" then
		local cy = y + math.floor( ( height - string.len(text) ) / 2) + 1
		return x, cy
	elseif layout == "bottom" then
		local cx = x + math.floor( width / 2)
		local cy = y + math.floor( ( height - string.len(text) ) / 2) + 1
		return cx, cy
	elseif layout == "bottomright" then
		local cx = x + x + width + 1
		local cy = y + math.floor( ( height - string.len(text) ) / 2) + 1
		return cx, cy
	end
end
addLocals('getTextLayoutPosV', getTextLayoutPosV)
local function inBounds(x, y, x1, y1, w, h)
	if ( ( x >= x1 and x <= ( x1 + w) ) and (y >= y1 and y <= ( y1 + h ) ) ) then
		return true
	end
	return false
end
addLocals('inBounds', inBounds)
--Defaults for all objects
local function getDefaults()
	local _mt = {
		target = term.native(),
		x = 1, y = 1,
		dynX = 1, dynY = 1,
		width = 1, height = 1,
		enabled = true, visible = true,
		text = "", func = nil,
		text_pos = "center",
		color_text = colors.white, color_bg = colors.blue, color_used = colors.red,
		_PARENT = nil, _CHILDREN = {},
		addPARENT = function(s, object) s._PARENT = object end,
		addCHILD = function(s, ...) end,
		enable = function(s) s.enabled = true end,
		disable = function(s) s.enabled = false end,
		show = function(s) s.visible = true end,
		showNDraw = function(s) s:show(); s:draw() end,
		showNDrawNEnable = function(s) s:showNDraw(); s:enable() end,
		hide = function(s) s.visible = false end,
		hideNDisable = function(s) s:hide(); s:disable() end,
		showNEnable = function(s) s:showNDraw(); s:enable() end,
		setText = function(s, t) s.text = t; s:draw() end,
		move = function(s, x, y) s.x = x; s.y = y; s:_dynRefresh() end,
		resize = function(s, w, h) s.width = w; s.height = h end,
		_dynRefresh = function(s)
			px, py = 1, 1
			if s._PARENT then
				px, py = s._PARENT.dynX, s._PARENT.dynY
			end
			s.dynX = s.x + px - 1
			s.dynY = s.y + py - 1
		end,
		clickCheck = function(s) return false end,
		draw = function(s) end,
		eventReact = function(s, e) end,
		used = function(s) if s.func then s:func(); s:draw() end end,
		erase = function(s)
			if s._PARENT then
				for k,v in pairs(s._PARENT._CHILDREN or {}) do
					if s == v then s._PARENT._CHILDREN[k] = nil; break end
				end
			end
			cleanup(s)
		end,
		draw2 = function(s) s:draw(); s:draw() end,
	}
	
	return _mt -- For __index
end
addLocals('getDefaults', getDefaults)
-- Non-recreating method
local defaults = {
    target = term.native(),
    x = 1, y = 1,
    dynX = 1, dynY = 1,
    width = 1, height = 1,
    enabled = true, visible = true,
    text = "", func = nil,
    text_pos = "center",
    color_text = colors.white, color_bg = colors.blue, color_used = colors.red,
    _PARENT = nil, _CHILDREN = {},
    
    addPARENT = function(s, object)
        s._PARENT = object
    end,
    
    addCHILD = function(s, ...) end,
    
    enable = function(s)
        s.enabled = true
    end,
    
    disable = function(s)
        s.enabled = false
    end,
    
    show = function(s)
        s.visible = true
    end,
    
    showNDraw = function(s)
        s:show()
        s:draw()
    end,
    
    showNDrawNEnable = function(s)
        s:showNDraw()
        s:enable()
    end,
    
    hide = function(s)
        s.visible = false
    end,
    
    hideNDisable = function(s)
        s:hide()
        s:disable()
    end,
    
    showNEnable = function(s)
        s:showNDraw()
        s:enable()
    end,
    
    setText = function(s, t)
        s.text = t
        s:draw()
    end,
    
    move = function(s, x, y)
        s.x = x
        s.y = y
        s:_dynRefresh()
    end,
    
    resize = function(s, w, h)
        s.width = w
        s.height = h
    end,
    
    _dynRefresh = function(s)
        px, py = 1, 1
        if s._PARENT then
            px, py = s._PARENT.dynX, s._PARENT.dynY
        end
        s.dynX = s.x + px - 1
        s.dynY = s.y + py - 1
    end,
    
    clickCheck = function(s) return false end,
    draw = function(s) end,
    eventReact = function(s, e) end,
    
    used = function(s)
        if s.func then s:func(); sleep(0); s:draw() end
    end,

	erase = function(s)
		local p = s._PARENT
		if p then
			for k,v in pairs(s._PARENT._CHILDREN or {}) do
				if s == v then s._PARENT._CHILDREN[k] = nil; break end
			end
		end
		cleanup(s)
		
		if p then sleep(0); p:draw() end
	end,
	draw2 = function(s) s:draw(); s:draw() end,
}
addLocals('defaults', defaults)

Panel = {}
Panel.help = "Panel{master, target=target, x=x, y=y, visible=visible, enabled=enabled}"
function Panel:new(kw) -- Panel{master, x=x,y=y,...}
	kw = kw or {}
    local widget = NewPanel(kw.x, kw.y, kw.visible, kw.enabled)
    local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
    return widget
end
setmetatable(Panel,{__call=Panel.new})
--Panel constructor
function NewPanel(x, y, visible, enabled)
	local panel = {
		_CHILDREN = {},
		addCHILD = function(s, ...)
			local args = {...}
			for _, object in pairs(args) do
				table.insert(s._CHILDREN, object)
				object:addPARENT(s)
			end
		end,
		
		draw = function(s)
			if not s.visible then return end
			s:_dynRefresh()
			for _, child in pairs(s._CHILDREN) do
				child:draw()
			end
		end
	}
	--panel = setmetatable(panel, getDefaults())
	panel = setmetatable(panel, {__index=defaults, __name="Panel"}) -- need test
	panel.x = x
	panel.y = y
	panel.visible = visible
	panel.enabled = enabled
	
	return panel
end
MainPanel = setmetatable(NewPanel(), {__index=defaults, __name="MainPanel"})


Button = {}
Button.help = "Button{master, target=target, x=x, y=y, width=width, height=height, text=text, func=func, color_bg=color_bg, color_text=color_text, color_used=color_used}"
function Button:new(kw) -- Button{master, x=x,y=y,...}
    local widget = NewButton(
        kw.target or kw.monitor or kw.terminal or kw.term,
        kw.x, kw.y, kw.width or kw.w, kw.height or kw.h,
        kw.text, kw.func or kw.callback,
        kw.color_bg or kw.bg, kw.color_text or kw.fg, kw.color_used or kw.cu
    )
    local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
    return widget
end
setmetatable(Button,{__call=Button.new})

--Button constructor
function NewButton(target, x, y, width, height, text, func, color_bg, color_text, color_used)
	local button = {
		draw = function(s, color)
			if not s.visible then return end
			if not color then color = s.color_bg end
			local cursorX, cursorY = s.target.getCursorPos()
			
			s:_dynRefresh()
			
			drawRect(s.target, s.dynX, s.dynY, s.width, s.height, color)
			
			local cx, cy = getTextLayoutPos(s.text_pos, s.text, s.dynX, s.dynY, s.width, s.height)
			s.target.setTextColor(s.color_text)
			s.target.setCursorPos(cx, cy)
			s.target.write(s.text)
				
			s.target.setCursorPos(cursorX, cursorY)
		end,
		
		clickCheck = function(s, t)
			if not s.enabled then return end
			
			if t[1] == "monitor_touch" and t[2] ~= peripheral.getName(s.target) --getPeripheralName(s.target) 
				or s.target ~= term.native() and t[1] == "mouse_click" then
				return
			end

			s:_dynRefresh()
			
			if inBounds(t[3], t[4], s.dynX, s.dynY, s.width - 1, s.height - 1) then
				s:used()
				return true
			end
			return false
		end,
	}
	button = setmetatable(button, {__index=defaults, __name="Button"})
	button.target = target
	button.x = x
	button.y = y
	button.width = width
	button.height = height
	button.text = text
	button.func = func
	button.color_text = color_text
	button.color_bg = color_bg
	button.color_used = color_used
	
	return button
end

CheckBox = {}
CheckBox.help = "CheckBox{master, target=target, x=x, y=y, width=width, height=height, text=text, func=func, color_bg=color_bg, color_text=color_text, color_used=color_used}"
function CheckBox:new(kw) -- CheckBox{master, x=x,y=y,...}
    local widget = NewCheckBox(
        kw.target or kw.monitor or kw.terminal or kw.term,
        kw.x, kw.y, kw.width or kw.w, kw.height or kw.h,
        kw.text, kw.func or kw.callback or kw.call,
        kw.color_bg or kw.bg, kw.color_text or kw.fg, kw.color_used or kw.cu
    )
    local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
    return widget
end
setmetatable(CheckBox,{__call=CheckBox.new})

--CheckBox constructor
function NewCheckBox(target, x, y, width, height, text, func, color_bg, color_text, color_used)
	local chbox = {
		check = false,
		
		draw = function(s, color)
			if not s.visible then return end
			if not color then color = s.color_bg end
			local cursorX, cursorY = s.target.getCursorPos()
			
			s:_dynRefresh()
			
			drawRect(s.target, s.dynX, s.dynY, s.width, s.height, color)
			
			local cx, cy = getTextLayoutPos(s.text_pos, "[ ]-" .. s.text, s.dynX, s.dynY, s.width, s.height)
			s.target.setTextColor(s.color_text)
			s.target.setCursorPos(cx, cy)
			s.target.write("["..( (s.check == true) and "X" or " ") .. "]-"..s.text)	
				
			s.target.setCursorPos(cursorX, cursorY)
		end,
		
		clickCheck = function(s, t)
			if not s.enabled then return end
			
			if t[1] == "monitor_touch" and t[2] ~= peripheral.getName(s.target)
				or s.target ~= term.native() and t[1] == "mouse_click" then
				return 
			end

			s:_dynRefresh()
			
			if inBounds(t[3], t[4], s.dynX, s.dynY, s.width - 1, s.height - 1) then
				s:used()
				return true
			end
			return false
		end,
		
		used = function(s)
			s.check = not s.check
			if s.func then s:func() end
			s:draw()
		end,
	}
	--chbox = setmetatable(chbox, getDefaults())
	chbox = setmetatable(chbox, {__index=defaults, __name="CheckBox"})
	
	chbox.target = target
	chbox.x = x
	chbox.y = y
	chbox.width = width
	chbox.height = height
	chbox.text = text
	chbox.func = func
	chbox.color_text = color_text
	chbox.color_bg = color_bg
	chbox.color_used = color_used
	
	return chbox
end

ProgressBar = {}
ProgressBar.help = "ProgressBar{master, target=target, x=x, y=y, width=width, height=height, color_bg=color_bg, color_text=color_text, color_used=color_used}"
function ProgressBar:new(kw) -- ProgressBar{master, x=x,y=y,...}
    local widget = NewProgressBar(
        kw.target or kw.monitor or kw.terminal or kw.term,
        kw.x, kw.y, kw.width or kw.w, kw.height or kw.h,
		kw.func or kw.callback or kw.call,
        kw.color_bg or kw.bg, kw.color_text or kw.fg, kw.color_used or kw.cu
    )
    local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
    return widget
end
setmetatable(ProgressBar,{__call=ProgressBar.new})
--[[
Example for func:
local function barCallback(s, value)
    if value then
        setValue(value)
        return
    end
    -- Return 2 values: 1) Scale filling; 2) Formatted string
    return getValue()/getMaxValue(), string.format("%i/i%", getValue(), getMaxValue())
end
]]
--Progress Bar constructor
function NewProgressBar(target, x, y, width, height, func, color_bg, color_text, color_used)
	local pbar = {
		step = 0.01,
		progress = 0.0,
		
		setProgress = function(s, np)
			s.progress = (np > 1) and 1 or np
			if s.func then s:func(np) end
			s:draw()
		end,
		
		clear = function(s)
			s.progress = 0
			if s.func then s:func(s.progress) end
			s:draw()
		end,
		
		stepIt = function(s)
			s.progress = s.progress + s.step
			if s.progress > 1 then s.progress = 1 end
			if s.func then s:func(s.progress) end
			s:draw()
		end,
		
		stepBack = function(s)
			s.progress = s.progress - s.step
			if s.progress < 0 then s.progress = 0 end
			if s.func then s:func(s.progress) end
			s:draw()
		end,
		
		draw = function(s)
			if not s.visible then return end
			local cursorX, cursorY = s.target.getCursorPos()
			s:_dynRefresh()
			
			if s.func then
				s.progress, s.text = s:func()
			else
				s.text = tostring( math.floor(s.progress * 100) ).."%"
			end

			local pos = math.floor(0.5+ s.width * s.progress)
			local cx, cy = getTextLayoutPos(s.text_pos, s.text, s.dynX, s.dynY, s.width, s.height)
			local blit_bg = string.rep(colors.toBlit(s.color_bg),pos)..string.rep(colors.toBlit(s.color_used),s.width-pos)
			local blit_fg = string.rep(colors.toBlit(s.color_text),s.width)
			local blit_noText = string.rep(" ", s.width)
			local dXText = math.floor(0.5+ (s.width - #s.text) / 2)
			local blit_text = string.sub(string.rep(" ", dXText)..s.text..string.rep(" ", dXText+1), 1, #blit_noText)
			for i=s.dynY, s.dynY+s.height-1 do
				s.target.setCursorPos(s.dynX,i)
				if i ~= cy then
					s.target.blit(blit_noText, blit_fg, blit_bg)
				else
					s.target.blit(blit_text, blit_fg, blit_bg)
				end

			end
			s.target.setCursorPos(cursorX, cursorY)
		end,
	}
	--pbar = setmetatable(pbar, getDefaults())
	pbar = setmetatable(pbar, {__index=defaults, __name="ProgressBar"}) -- need test
	pbar.target = target
	pbar.x = x
	pbar.y = y
	pbar.width = width
	pbar.height = height
	pbar.func = func
	pbar.color_bg = color_bg
	pbar.color_text = color_text
	pbar.color_used = color_used
	
	return pbar
end

TextLine = {}
TextLine.help = "TextLine{master, target=target, x=x, y=y, width=width, color_bg=color_bg, color_text=color_text}"
function TextLine:new(kw) -- TextLine{master, x=x,y=y,...}
    local widget = NewTextLine(
        kw.target or kw.monitor or kw.terminal or kw.term,
        kw.x, kw.y, kw.width or kw.w,
        kw.text, kw.func or kw.callback or kw.call,
        kw.color_bg or kw.bg, kw.color_text or kw.fg
    )
    local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
    return widget
end
setmetatable(TextLine,{__call=TextLine.new})

function NewTextLine(target, x, y, width, text, func, color_bg, color_text)
	local textline = {
		secure = false,
		_textpos = 1,
		_cursorpos = 1,
		
		draw = function(s)
			if not s.visible then return end
			local cursorX, cursorY = s.target.getCursorPos()
			
			s:_dynRefresh()
			
			drawRect(s.target, s.dynX, s.dynY, s.width, 1, s.color_bg)

			s.target.setTextColor(s.color_text)
			s.target.setCursorPos(s.dynX, s.dynY)
			local temp = string.sub(s.text, s._textpos, s._textpos + s.width)
			if s.secure then
				for i = 1, #temp do
					s.target.write("*")
				end
			else
				s.target.write(temp)
			end
				
			s.target.setCursorPos(cursorX, cursorY)
		end,
		
		clickCheck = function(s, t)
			if not s.enabled then return end
			
			if t[1] == "monitor_touch" and t[2] ~= peripheral.getName(s.target)
				or s.target ~= term.native() and t[1] == "mouse_click" then
				return 
			end

			s:_dynRefresh()
			
			if inBounds(t[3], t[4], s.dynX, s.dynY, s.width - 1, s.height - 1) then
				SELECTED_OBJECT = s
				return true
			end
			return false
		end,
		
		eventReact = function(s, e)
			if not s.enabled then return end
			if e[1] == "key" then
				if e[2] == 28 then
					SELECTED_OBJECT = nil
					s:used()
				elseif e[2] == 14 then
					s.text = string.sub(s.text, 1, #s.text - 1)
					s._cursorpos = s._cursorpos - 1
					
					if s._cursorpos <= s._textpos then
						s._textpos = s._textpos - 4
					end
					if s._textpos < 1 then
						s._textpos = 1
					end
					if s._cursorpos < 1 then
						s._cursorpos = 1
					end
					
					s:draw()
				elseif e[2] == 203 then
				--left
				elseif e[2] == 205 then
				--right
				end
			elseif e[1] == "char" then
				s.text = s.text .. e[2] --testing
				
				s._cursorpos = s._cursorpos + 1
				
				if s._cursorpos > s._textpos + s.width - 1 then
					s._textpos = s._textpos + 1
				end
				
				s:draw()
			end
		end,
	}
	--textline = setmetatable(textline, getDefaults())
	textline = setmetatable(textline, {__index=defaults, __name="TextLine"}) -- need test
	textline.target = target
	textline.x = x
	textline.y = y
	textline.width = width
	textline.text = text
	textline.func = func
	textline.color_bg = color_bg
	textline.color_text = color_text
	return textline
end

TextArea = {}
TextArea.help = "TextArea{master, target=target, x=x, y=y, width=width, height=height, text=text, color_bg=color_bg, color_text=color_text}"
function TextArea:new(kw) -- TextArea{master, x=x,y=y,...}
    local widget = NewTextArea(
        kw.target or kw.monitor or kw.terminal or kw.term,
        kw.x, kw.y, kw.width or kw.w, kw.height or kw.h,
        kw.text,
        kw.color_bg or kw.bg, kw.color_text or kw.fg
    )
    local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
    return widget
end
setmetatable(TextArea,{__call=TextArea.new})

--TextArea constructor
function NewTextArea(target, x, y, width, height, text, color_bg, color_text)
	local textarea = {
		draw = function(s)
			if not s.visible then return end
			local cursorX, cursorY = s.target.t()
			
			s:_dynRefresh()
			
			drawRect(s.target, s.dynX, s.dynY, s.width, s.height, s.color_bg)
			
			local k = 0
			for i = 1, string.len(s.text), s.width do
				s.target.setCursorPos(s.dynX, s.dynY + k)
				k = k + 1
				s.target.setTextColor(s.color_text)
				s.target.write(string.sub(s.text, i, i + s.width - 1))
			end
				
			s.target.setCursorPos(cursorX, cursorY)
		end,
		
		clickCheck = function(s, t)
			if not s.enabled then return end
			
			if t[1] == "monitor_touch" and t[2] ~= getPeripheralName(s.target) 
				or s.target ~= term.native() and t[1] == "mouse_click" then
				return 
			end

			s:_dynRefresh()
			
			if inBounds(t[3], t[4], s.dynX, s.dynY, s.width - 1, s.height - 1) then
				SELECTED_OBJECT = s
				return true
			end
			return false
		end,
		
		eventReact = function(s, e)
			if not s.enabled then return end
			if e[1] == "key" then
				if e[2] == 28 then
					--testing
				elseif e[2] == 14 then
					s.text = string.sub(s.text, 1, #s.text - 1)
					s:draw()
				end
			elseif e[1] == "char" then
				s.text = s.text .. e[2] --testing
				s:draw()
			end
		end,
	}
	--textarea = setmetatable(textarea, getDefaults())
	textarea = setmetatable(textarea, {__index=defaults, __name="TextArea"}) -- need test
	textarea.target = target
	textarea.x = x
	textarea.y = y
	textarea.width = width
	textarea.height = height
	textarea.text = text
	textarea.color_bg = color_bg
	textarea.color_text = color_text
	return textarea
end

Label = {}
Label.help = "Label{master, target=target, x=x, y=y, text=text, color_bg=color_bg, color_text=color_text}"
function Label:new(kw) -- Label{master, x=x,y=y,...}
    local widget = NewLabel(
        kw.target or kw.monitor or kw.terminal or kw.term,
        kw.x, kw.y,
        kw.text,
        kw.color_bg or kw.bg, kw.color_text or kw.fg
    )
    local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
    return widget
end
setmetatable(Label,{__call=Label.new})

--Label constructor
function NewLabel(target, x, y, text, color_bg, color_text)
	local label = {
		draw = function(s)
			if not s.visible then return end
			local cursorX, cursorY = s.target.getCursorPos()
			
			s:_dynRefresh()
	
			drawLine(s.target, s.dynX, s.dynY, s.dynX + string.len(s.text) - 1, s.dynY , s.color_bg)
			s.target.setTextColor(s.color_text)
			s.target.setCursorPos(s.dynX, s.dynY)
			s.target.write(s.text)
			
			s.target.setCursorPos(cursorX, cursorY)
		end,
	}
	--label = setmetatable(label, getDefaults())
	label = setmetatable(label, {__index=defaults, __name="Label"}) -- need test
	label.target = target
	label.x = x
	label.y = y
	label.text = text
	label.color_bg = color_bg
	label.color_text = color_text
	return label
end

--click/touch handler
local function exec(event, object)
	if not object.enabled then return end
	for _, child in pairs(object._CHILDREN) do
		exec(event, child)
		if child.clickCheck and child:clickCheck(event) then
			return true
		end
	end
end

--Event handler. Call this if overwrite os.pullEvent()
function eventHandler(e)
	if e[1] == "mouse_click" or e[1] == "monitor_touch" then
		--Check if selected object or its children clicked
		if SELECTED_OBJECT then
			exec(e, SELECTED_OBJECT)
		end
		SELECTED_OBJECT = nil
		exec(e, MainPanel)
	elseif e[1] == "key" or e[1] == "char"then
		if SELECTED_OBJECT then
			SELECTED_OBJECT:eventReact(e)
		end
	end
end

function os.pullEvent(...)
	local e = { backupPullEvent(...) }
	eventHandler(e)
	return table.unpack(e)
end

function DRAW()
	MainPanel:draw()
end

-- From 
-- https://computercraft.ru/topic/393-mnogopotochnost-v-computercraft/
-- https://pastebin.com/32S4HssH

-- Think method for autoupdate by time

pullEventRawBackup = os.pullEventRaw


local _filter_m = {
	__len=function(self)
		local i = 0
		for _,_ in pairs(self) do i = i + 1 end
		return i
	end
}
-- Patch for multishell loads
local mainThread={coroutine.running()}
local filter=setmetatable({},_filter_m)

function updateThread()
	local running = coroutine.running()
	local toAdd = true
	for i=1, #mainThread do
		if running == mainThread[i] then
			toAdd = false
			break
		end
	end
	if toAdd then
		mainThread[#mainThread+1]=coroutine.running()
	end
end

local function SingleThread( _sFilter )
    return coroutine.yield( _sFilter )
end
local thread = false
local function MultiThread( _sFilter )
	for i=#mainThread, 1, -1 do
		if coroutine.running()==mainThread[i] then
			thread = true
			local event,co
			repeat
				event={coroutine.yield()}
				co=next(filter)
				if not co then os.pullEventRaw=SingleThread end
				while co do
					if coroutine.status( co ) == "dead" then
						filter[co],co=nil,next(filter,co)
					else
						if filter[co] == '' or filter[co] == event[1] or event[1] == "terminate" then
						local ok, param = coroutine.resume( co, unpack(event) )
						if not ok then filter={} error( param )
						else filter[co] = param or '' end
						end
						co=next(filter,co)
					end
				end
			until _sFilter == nil or _sFilter == event[1] or event[1] == "terminate"
			return unpack(event)
		end
		if type(mainThread[i]) ~= 'thread' or coroutine.status( mainThread[i] ) == "dead" then
			table.remove(mainThread, i)
		end
	end
  	return coroutine.yield( _sFilter )
end
 

function create(f,...)
  os.pullEventRaw=MultiThread
  local co=coroutine.create(f)
  filter[co]=''
  local ok, param = coroutine.resume( co, ... )
  if not ok then filter={} error( param )
  else filter[co] = param or '' end
  updateThread()
  return co
end
think = create
 

function kill()
  filter[co]=nil
end
 

function killAll()
  filter=setmetatable({},_filter_m)
  os.pullEventRaw=SingleThread
end

function busy()
	return #filter > 0
end





