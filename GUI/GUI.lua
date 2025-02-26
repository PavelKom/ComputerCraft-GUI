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
local MainPanel = nil
local backupPullEvent = os.pullEvent
local epfMonitor = nil
do
	local res, err = pcall(require, "epf.cc.monitor")
	if res then epfMonitor = err end
end
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
	cleanup(obj or MainPanel)
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
function NO_EXIT_CUSTOM(obj, ...)
	local loops = {}
	if type(obj) == 'string' then loops[#loops+1] = guiLoopN(obj) end -- No obj, only events
	for _, v in pairs{...} do loops[#loops+1] = guiLoopN(v) end
	parallel.waitForAny(no_exit, table.unpack(loops))
	cleanup(obj)
end
function NO_EXIT(obj)
	NO_EXIT_CUSTOM(obj, 'mouse_click', 'monitor_touch', 'key', 'char')
end
function EXIT(obj)
	os.queueEvent("GUI_USER_EXIT", obj)
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

local DEFAULTS = {
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
addLocals('DEFAULTS', DEFAULTS)

local function parseTarget(target)
	local t = kw.target or kw.monitor or kw.terminal or kw.term
	if t == nil then return nil end
	if type(t) == 'string' then
		if t == 'term' then return tern.native()
		elseif epfMonitor then
			return epfMonitor(t)
		else
			return peripheral.wrap(t)
		end
	else
		return t
	end
end
addLocals('parseTarget', parseTarget)

local function parseCallback(target)
	local c = kw.func or kw.call or kw.callback or kw.f
	if c == nil then return nil end
	if type(c) == 'function' then
		return c
	else
		return load(tostring(c),nil,nil,_ENV)
	end
end
addLocals('parseCallback', parseCallback)

Panel = {}
function Panel.new(self, kw)
	local widget = {_CHILDREN = {},
		x=kw.x,y=kw.y,
		visible = kw.visible
		enabled = kw.enabled
	}
	local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
	return setmetatable(widget, {__index=Panel, __name="Panel"})
end
function Panel.addCHILD(self, ...)
	local args = {...}
	for _, object in pairs(args) do
		table.insert(self._CHILDREN, object)
		object:addPARENT(self)
	end
end
function Panel.draw(self)
	if not self.visible then return end
	self:_dynRefresh()
	for _, child in pairs(self._CHILDREN) do
		child:draw()
	end
end
Panel = setmetatable(Panel, {__index=DEFAULTS, __call=Panel.new})
MainPanel = Panel()

Label = {}
function Label.new(self, kw)
	local widget = {
		target = parseTarget(kw),
		x=kw.x,y=kw.y,
		text = kw.text
		bg = kw.bg or kw.color_bg,
		fg = kw.fg or kw.color_text
	}
	local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
	return setmetatable(widget, {__index=Label, __name="Label"})
end
function Label.draw(self)
	if not self.visible then return end
	local cursorX, cursorY = self.target.getCursorPos()
	
	self:_dynRefresh()

	drawLine(self.target, self.dynX, self.dynY, self.dynX + string.len(self.text) - 1, self.dynY , self.bg)
	self.target.setTextColor(self.fg)
	self.target.setCursorPos(self.dynX, self.dynY)
	self.target.write(self.text)
	
	self.target.setCursorPos(cursorX, cursorY)
end
Label = setmetatable(Label, {__index=DEFAULTS, __call=Label.new})

Button = {}
function Button.new(self, kw)
	local widget = {
		target = parseTarget(kw),
		x=kw.x,y=kw.y,
		width=kw.width or kw.w,
		height=kw.height or kw.h,
		text = kw.text,
		func=parseCallback(kw),
		bg = kw.bg or kw.color_bg,
		fg = kw.fg or kw.color_text,
		ug = kw.ug or kw.color_used
	}
	local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
	return setmetatable(widget, {__index=Button, __name="Button"})
end
function Button.draw(self)
	if not self.visible then return end
	local cursorX, cursorY = self.target.getCursorPos()
	
	self:_dynRefresh()
	
	drawRect(self.target, self.dynX, self.dynY, self.width, self.height, self.bg)
	
	local cx, cy = getTextLayoutPos(self.text_pos, self.text, self.dynX, self.dynY, self.width, self.height)
	self.target.setTextColor(self.fg)
	self.target.setCursorPos(cx, cy)
	self.target.write(self.text)
		
	self.target.setCursorPos(cursorX, cursorY)
end
local function clickValid(self, e)
	if e[1] == 'mouse_click' then
		return self.target == term.native()
	elseif e[1] == 'monitor_touch' then
		return self.target and peripheral.getName(self.target)
	end
end
function Button.clickCheck(self, t)
	if not self.enabled then return end
	if not clickValid(self, t) then
		return
	end

	self:_dynRefresh()
	
	if inBounds(t[3], t[4], self.dynX, self.dynY, self.width - 1, self.height - 1) then
		self:used()
		return true
	end
	return false
end
Button = setmetatable(Button, {__index=DEFAULTS, __call=Button.new})

CheckBox = {}
function CheckBox.new(self, kw)
	local widget = {
		target = parseTarget(kw),
		x=kw.x,y=kw.y,
		width=kw.width or kw.w,
		height=kw.height or kw.h,
		text = kw.text,
		func=parseCallback(kw),
		bg = kw.bg or kw.color_bg,
		fg = kw.fg or kw.color_text,
		ug = kw.ug or kw.color_used,
		
		check=false
	}
	local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
	return setmetatable(widget, {__index=CheckBox, __name="CheckBox"})
end
function CheckBox.draw(self)
	if not self.visible then return end
	local cursorX, cursorY = self.target.getCursorPos()
			
	self:_dynRefresh()
	
	drawRect(self.target, self.dynX, self.dynY, self.width, self.height, self.bg)
			
	local cx, cy = getTextLayoutPos(self.text_pos, "[ ]-" .. self.text, self.dynX, self.dynY, self.width, self.height)
	self.target.setTextColor(s.fg)
	self.target.setCursorPos(cx, cy)
	self.target.write("["..( (self.check == true) and "X" or " ") .. "]-"..self.text)	
		
	self.target.setCursorPos(cursorX, cursorY)
end
function CheckBox.clickCheck(self, t)
	if not self.enabled then return end
	if not clickValid(self, t) then
		return
	end

	self:_dynRefresh()
	
	if inBounds(t[3], t[4], self.dynX, self.dynY, self.width - 1, self.height - 1) then
		self:used()
		return true
	end
	return false
end
function CheckBox.used(self, t)
	self.check = not self.check
	if self.func then self:func() end
	self:draw()
end
CheckBox = setmetatable(CheckBox, {__index=DEFAULTS, __call=CheckBox.new})

ProgressBar = {}
function ProgressBar.new(self, kw)
	local widget = {
		target = parseTarget(kw),
		x=kw.x,y=kw.y,
		width=kw.width or kw.w,
		height=kw.height or kw.h,
		text = kw.text,
		func=parseCallback(kw),
		bg = kw.bg or kw.color_bg,
		fg = kw.fg or kw.color_text,
		ug = kw.ug or kw.color_used,
		
		step=0.01,
		progress=0.0
	}
	local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
	return setmetatable(widget, {__index=ProgressBar, __name="ProgressBar"})
end
function ProgressBar.setProgress(self, val)
	self.progress = math.max(0,math.min(1,val))
	if s.func then s:func(s.progress) end
	self:draw()
end
function ProgressBar.clear(self, val)
	self.progress = 0
	if s.func then s:func(s.progress) end
	self:draw()
end
function ProgressBar.stepIt(self)
	self.progress = math.min(1,self.progress+self.step)
	if s.func then s:func(s.progress) end
	self:draw()
end
function ProgressBar.stepBack(self)
	self.progress = math.max(0,self.progress-self.step)
	if s.func then s:func(s.progress) end
	self:draw()
end
function ProgressBar.draw(self)
	if not self.visible then return end
	local cursorX, cursorY = self.target.getCursorPos()
	self:_dynRefresh()
	
	if self.func then
		self.progress, self.text = s:func()
	else
		self.text = tostring( math.floor(self.progress * 100) ).."%"
	end
	
	local pos = math.floor(0.5+ self.width * self.progress)
	local cx, cy = getTextLayoutPos(self.text_pos, self.text, self.dynX, self.dynY, self.width, self.height)
	local blit_bg = string.rep(colors.toBlit(self.bg), pos)..string.rep(colors.toBlit(self.ug), self.width-pos)
	local blit_fg = string.rep(colors.toBlit(self.fg), self.width)
	local blit_noText = string.rep(" ", self.width)
	local dXText = math.floor(0.5+ (self.width - #self.text) / 2)
	local blit_text = string.sub(string.rep(" ", dXText)..self.text..string.rep(" ", dXText+1), 1, #blit_noText)
	for i=self.dynY, self.dynY+self.height-1 do
		self.target.setCursorPos(self.dynX,i)
		if i ~= cy then
			self.target.blit(blit_noText, blit_fg, blit_bg)
		else
			self.target.blit(blit_text, blit_fg, blit_bg)
		end

	end
	self.target.setCursorPos(cursorX, cursorY)
end
ProgressBar = setmetatable(ProgressBar, {__index=DEFAULTS, __call=ProgressBar.new})

TextLine = {}
function TextLine.new(self, kw)
	local widget = {
		target = parseTarget(kw),
		x=kw.x,y=kw.y,
		width=kw.width or kw.w,
		text = kw.text,
		func=parseCallback(kw),
		bg = kw.bg or kw.color_bg,
		fg = kw.fg or kw.color_text,
		
		secure = false,
		_textpos = 1,
		_cursorpos = 1,
	}
	local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
	return setmetatable(widget, {__index=TextLine, __name="TextLine"})
end
function TextLine.draw(self)
	if not self.visible then return end
	local cursorX, cursorY = self.target.getCursorPos()
	
	self:_dynRefresh()
	
	drawRect(self.target, self.dynX, self.dynY, self.width, 1, self.bg)

	self.target.setTextColor(self.color_text)
	self.target.setCursorPos(self.dynX, self.dynY)
	local temp = string.sub(self.text, self._textpos, self._textpos + self.width)
	if self.secure then
		for i = 1, #temp do
			self.target.write("*")
		end
	else
		self.target.write(temp)
	end
		
	self.target.setCursorPos(cursorX, cursorY)
end
function TextLine.clickCheck(self, t)
	if not self.enabled then return end
	if not clickValid(self, t) then
		return
	end

	self:_dynRefresh()
	
	if inBounds(t[3], t[4], self.dynX, self.dynY, self.width - 1, self.height - 1) then
		SELECTED_OBJECT = self
		return true
	end
	return false
end
function TextLine.eventReact(self, e) -- TODO
	if not self.enabled then return end
	if e[1] == "key" then
		if e[2] == 28 then -- ???
			SELECTED_OBJECT = nil
			s:used()
		elseif e[2] == 14 then -- ???
			s.text = string.sub(s.text, 1, #s.text - 1)
			s._cursorpos = s._cursorpos - 1
			
			if s._cursorpos <= s._textpos then
				s._textpos = s._textpos - 4
			end
			if s._textpos < 1 then
				self._textpos = 1
			end
			if s._cursorpos < 1 then
				self._cursorpos = 1
			end
			
			s:draw()
		elseif e[2] == 203 then --left
		elseif e[2] == 205 then --right
		end
	elseif e[1] == "char" then
		self.text = self.text .. e[2]
		
		self._cursorpos = self._cursorpos + 1
		
		if self._cursorpos > self._textpos + self.width - 1 then
			self._textpos = self._textpos + 1
		end
		
		self:draw()
	end
end
TextLine = setmetatable(TextLine, {__index=DEFAULTS, __call=TextLine.new})

TextArea = {}
function TextArea.new(self, kw)
	local widget = {
		target = parseTarget(kw),
		x=kw.x,y=kw.y,
		width=kw.width or kw.w,
		height=kw.height or kw.h,
		text = kw.text,
		bg = kw.bg or kw.color_bg,
		fg = kw.fg or kw.color_text,
	}
	local master = kw[1] or kw.master or MainPanel
    if master then
        master:addCHILD(widget)
    end
	return setmetatable(widget, {__index=TextArea, __name="TextArea"})
end
function TextArea.draw(self)
	if not self.visible then return end
	local cursorX, cursorY = self.target.getCursorPos()
	
	self:_dynRefresh()
	
	drawRect(self.target, self.dynX, self.dynY, self.width, self.height, self.bg)
	
	local k = 0
	for i = 1, string.len(self.text), self.width do
		self.target.setCursorPos(self.dynX, self.dynY + k)
		k = k + 1
		self.target.setTextColor(self.color_text)
		self.target.write(string.sub(self.text, i, i + self.width - 1))
	end
		
	self.target.setCursorPos(cursorX, cursorY)
end
function TextLine.clickCheck(self, t)
	if not self.enabled then return end
	if not clickValid(self, t) then
		return
	end

	self:_dynRefresh()
	
	if inBounds(t[3], t[4], self.dynX, self.dynY, self.width - 1, self.height - 1) then
		SELECTED_OBJECT = self
		return true
	end
	return false
end
function TextLine.eventReact(self, e) -- TODO
	if not self.enabled then return end
	if e[1] == "key" then
		if e[2] == 28 then
			--testing
		elseif e[2] == 14 then
			self.text = string.sub(self.text, 1, #self.text - 1)
			self:draw()
		end
	elseif e[1] == "char" then
		self.text = self.text .. e[2] --testing
		self:draw()
	end
end

--click/touch handler
local function exec(event, object)
	if not object.enabled then return end
	for _, child in pairs(object._CHILDREN) do
		exec(event, child)
		if child:clickCheck(event) then
			return true
		end
	end
end

--Event handler. Call this if overwrite os.pullEvent()
-- TODO: Add fix for multishell duped events
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
		if coroutine.running() == mainThread[i] then
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
 
function kill(co)
  filter[co]=nil
end

function killAll()
  filter=setmetatable({},_filter_m)
  os.pullEventRaw=SingleThread
end

function busy()
	return #filter > 0
end









