--------------------------------------------------------------------------------
-- This class inherits the MOAILayer. <br>
-- Simplifies the generation of a set of size and layer. <br>
--------------------------------------------------------------------------------
--local lwd = true	-- define for touch debugging

-- import
local table                 = require "hp/lang/table"
local class                 = require "hp/lang/class"
local Event                 = require "hp/event/Event"
local InputManager          = require "hp/manager/InputManager"

-- class define
local M                     = class()

-- event cache
local EVENT_TOUCH_DOWN      = Event(Event.TOUCH_DOWN)
local EVENT_TOUCH_UP        = Event(Event.TOUCH_UP)
local EVENT_TOUCH_MOVE      = Event(Event.TOUCH_MOVE)
local EVENT_TOUCH_CANCEL    = Event(Event.TOUCH_CANCEL)

--
local function getPointByCache(self, e)
    for i, p in ipairs(self._touchPoints) do
        if p.idx == e.idx then
            return p
        end
    end
end

-- 
local function getPointByEvent(self, e)
    local layer = self._touchLayer

    local p = getPointByCache(self, e) or {}
    p.idx = e.idx
    p.tapCount = e.tapCount
    p.oldX, p.oldY = p.x, p.y
    p.x, p.y = layer:wndToWorld(e.x, e.y, 0)
    p.screenX, p.screenY = e.x, e.y
    
	if e.tapTime and e.isTap ~= nil then	-- Copy these for touchUp events
		p.isTap = e.isTap
		p.tapTime = e.tapTime
		p.moveX = e.moveX
		p.moveY = e.moveY
	elseif p.oldX and p.oldY then
        p.moveX = p.x - p.oldX
        p.moveY = p.y - p.oldY
    else
        p.oldX, p.oldY = p.x, p.y
        p.moveX, p.moveY = 0, 0
    end
if p.stoped then print('TouchProcessor:getPointByEvent:returning STOPED '..p.type) end
    return p
end

local function eventHandle(self, e, o)
    local layer = self._touchLayer
    while o do
        if o.isTouchEnabled and not o:isTouchEnabled() then
            break
        end
        if o.dispatchEvent then
			if e.stoped then
if lwd then print('TouchProcessor:eventHandler:'..e.type..':o NOT dispatching'..(e.stoped and " STOPED" or "")..' '..tostring(e.type)..' to '..tostring(o)) end
			else
				o:dispatchEvent(e)
			end
        end
        if o.getParent then
            o = o:getParent()
        else
            o = nil
        end
    end
end

--------------------------------------------------------------------------------
-- The constructor.
-- @param layer (option)Parameter is set to Object.<br>
--------------------------------------------------------------------------------
function M:init(layer)
    self._touchLayer        = assert(layer)
    self._touchPoints       = {}
    self._eventSource       = nil
    self._enabled           = true
end

--------------------------------------------------------------------------------
-- イベント発生元を設定します.
-- 典型的には、Sceneインスタンスが設定されます.
--------------------------------------------------------------------------------
function M:setEventSource(eventSource)
    if self._eventSource then
        self._eventSource:removeEventListener(Event.TOUCH_DOWN, self.touchDownHandler, self)
        self._eventSource:removeEventListener(Event.TOUCH_UP, self.touchUpHandler, self)
        self._eventSource:removeEventListener(Event.TOUCH_MOVE, self.touchMoveHandler, self)
        self._eventSource:removeEventListener(Event.TOUCH_CANCEL, self.touchCancelHandler, self)
    end
    
    self._eventSource = eventSource
    
    if self._eventSource then
        self._eventSource:addEventListener(Event.TOUCH_DOWN, self.touchDownHandler, self)
        self._eventSource:addEventListener(Event.TOUCH_UP, self.touchUpHandler, self)
        self._eventSource:addEventListener(Event.TOUCH_MOVE, self.touchMoveHandler, self)
        self._eventSource:addEventListener(Event.TOUCH_CANCEL, self.touchCancelHandler, self)
    end
end

--------------------------------------------------------------------------------
-- イベントソースに対する参照を削除します.
--------------------------------------------------------------------------------
function M:dispose()
    self:setEventSource(nil)
end

--------------------------------------------------------------------------------
-- プロセッサーが有効かどうか設定します.
--------------------------------------------------------------------------------
function M:setEnabled(value)
    self._enabled = value
end

--------------------------------------------------------------------------------
-- プロセッサーが有効かどうか返します.
--------------------------------------------------------------------------------
function M:isEnabled()
    return self._enabled
end

--------------------------------------------------------------------------------
-- タッチした時のイベント処理を行います.
--------------------------------------------------------------------------------
function M:touchDownHandler(e)
    if not self:isEnabled() then
        return
    end
    
    local layer = self._touchLayer

    local p = getPointByEvent(self, e)
    p.touchingProp = layer:getPartition():propForPoint(p.x, p.y, 0)
    table.insertElement(self._touchPoints, p)
    
    local te = table.copy(p, EVENT_TOUCH_DOWN)
    te.points = self._touchPoints
	te.stoped = false

    if p.touchingProp then
if lwd then print('TouchProcessor:touchDownHandler:p handling'..(te.stoped and " STOPED" or "")..' event!') end
        eventHandle(self, te, p.touchingProp)
    end
    if not te.stoped then
if lwd then print('TouchProcessor:touchDownHandler:o handling'..(te.stoped and " STOPED" or "")..' event!') end
		layer:dispatchEvent(te)
    end
    if te.stoped then
        e:stop()
    end
end

----------------------------------------------------------------
-- タッチした時のイベント処理を行います.
----------------------------------------------------------------
function M:touchUpHandler(e)
    if not self:isEnabled() then
        return
    end

    local layer = self._touchLayer

    local p = getPointByEvent(self, e)
    local te = table.copy(p, EVENT_TOUCH_UP)
	te.stoped = false
if p.stoped ~= te.stoped and te.stoped then
	print(printableTable('TouchProcessor:touchUpHandler:p',p))
	print(printableTable('TouchProcessor:touchUpHandler:te',te))
end

    if p.touchingProp then
if lwd then print('TouchProcessor:touchUpHandler:p handling p:'..(p.stoped and "STOPED" or "")..' te:'..(te.stoped and "STOPED" or "")..' event!') end
        eventHandle(self, te, p.touchingProp)
    end
    
--[[
    local o = layer:getPartition():propForPoint(p.x, p.y, 0)
    if o and o ~= p.touchingProp then
if lwd then print('TouchProcessor:touchUpHandler:o handling'..(te.stoped and " STOPED" or "")..' event!') end
        eventHandle(self, te, o)
    end
]]
    local ol = {layer:getPartition():propListForPoint(p.x, p.y, 0, SORT_PRIORITY_ASCENDING)}
--    local ol = {layer:getPartition():propListForPoint(p.x, p.y, 0, SORT_PRIORITY_DESCENDING)}
    if ol then
		for _, o in ipairs(ol) do
			if o ~= p.touchingProp then
if lwd then print('TouchProcessor:touchUpHandler:o handling'..(te.stoped and " STOPED" or "")..' event!') end
				eventHandle(self, te, o)
				if te.stoped then
					if lwd then print('prop handled touchUp!') end
					break
				end
			end
		end
    end

    if not te.stoped then
if lwd then print('TouchProcessor:touchUpHandler:layer dispatching'..(te.stoped and " STOPED" or "")..' event!') end
        layer:dispatchEvent(te)
    end
    if te.stoped then
        e:stop()
    end
    
    table.removeElement(self._touchPoints, p)
end

----------------------------------------------------------------
-- タッチした時のイベント処理を行います.
----------------------------------------------------------------
function M:touchMoveHandler(e)
    if not self:isEnabled() then
        return
    end

    local layer = self._touchLayer

    local p = getPointByEvent(self, e)
    local te = table.copy(p, EVENT_TOUCH_MOVE)
	te.stoped = false
    
    if p.touchingProp then
if lwd then print('TouchProcessor:touchMoveHandler:p handling'..(te.stoped and " STOPED" or "")..' event!') end
        eventHandle(self, te, p.touchingProp)
    end
    
    local o = layer:getPartition():propForPoint(p.x, p.y, 0)
    if o and o ~= p.touchingProp then
if lwd then print('TouchProcessor:touchMoveHandler:o handling'..(te.stoped and " STOPED" or "")..' event!') end
        eventHandle(self, te, o)
    end
    
    if not te.stoped then
if lwd then print('TouchProcessor:touchMoveHandler:layer dispatching'..(te.stoped and " STOPED" or "")..' event!') end
        layer:dispatchEvent(te)
    end
    if te.stoped then
        e:stop()
    end
end

----------------------------------------------------------------
-- タッチした時のイベント処理を行います.
----------------------------------------------------------------
function M:touchCancelHandler(e)
    if not self:isEnabled() then
        return
    end

    local layer = self._touchLayer

    local p = getPointByEvent(self, e)
    local te = table.copy(p, EVENT_TOUCH_CANCEL)
	te.stoped = false
    
    if p.touchingProp then
if lwd then print('TouchProcessor:touchCancelHandler:p handling'..(te.stoped and " STOPED" or "")..' event!') end
        eventHandle(self, te, p.touchingProp)
    end
    
    local o = layer:propForPoint(p.x, p.y, 0)
    if o and o ~= p.touchingProp then
if lwd then print('TouchProcessor:touchCancelHandler:o handling'..(te.stoped and " STOPED" or "")..' event!') end
        eventHandle(self, te, o)
    end
    if not te.stoped then
if lwd then print('TouchProcessor:touchCancelHandler:layer dispatching'..(te.stoped and " STOPED" or "")..' event!') end
        layer:dispatchEvent(te)
    end
    if te.stoped then
        e:stop()
    end
    
    table.removeElement(self._touchPoints, p)
end

return M