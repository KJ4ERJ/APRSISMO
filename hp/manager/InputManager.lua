--------------------------------------------------------------------------------
-- To catch the operation of the screen, and sends the event. <br>
--------------------------------------------------------------------------------

local table = require("hp/lang/table")
local Event = require("hp/event/Event")
local EventDispatcher = require("hp/event/EventDispatcher")

local M = EventDispatcher()
local pointer = {x = 0, y = 0, down = false}
local keyboard = {key = 0, down = false}
local touchEventStack = {}

local TOUCH_EVENTS = {}
TOUCH_EVENTS[MOAITouchSensor.TOUCH_DOWN] = Event.TOUCH_DOWN
TOUCH_EVENTS[MOAITouchSensor.TOUCH_UP] = Event.TOUCH_UP
TOUCH_EVENTS[MOAITouchSensor.TOUCH_MOVE] = Event.TOUCH_MOVE
TOUCH_EVENTS[MOAITouchSensor.TOUCH_CANCEL] = Event.TOUCH_CANCEL

local dTapTime, dTapMargin = 0.6, 50.0	-- From MOAITouchSensor.cpp
local tapTime, tapMargin = dTapTime, dTapMargin	-- initial values

function M:setTapMargin(margin)
	margin = margin or dTapMargin
	tapMargin = margin
	MOAITouchSensor:setTapMargin(margin)
end

function M:setTapTime(time)
	time = time or dTapTime
	tapTime = time
	MOAITouchSensor:setTapTime(time)
end

local function onTouch(eventType, idx, x, y, tapCount)
    -- event
--print(string.format("inputmanager:onTouch:%i[%i] %.4f %.4f %i", eventType, idx, x, y, tapCount))
    local event = touchEventStack[idx] or Event(TOUCH_EVENTS[eventType], M)
    local oldX, oldY = event.x, event.y
    event.type = TOUCH_EVENTS[eventType]
    event.idx = idx
    event.x = x
    event.y = y
    event.tapCount = tapCount
    
    if eventType == MOAITouchSensor.TOUCH_DOWN then
		event.orgTime = MOAISim.getDeviceTime()
		event.orgX, event.orgY = x, y
        touchEventStack[idx] = event
    elseif eventType == MOAITouchSensor.TOUCH_UP then
		if event.orgX and event.orgY and event.orgTime then
			event.tapTime = MOAISim.getDeviceTime() - event.orgTime
			event.moveX = event.x - event.orgX
			event.moveY = event.y - event.orgY
			local d = math.sqrt(event.moveX*event.moveX + event.moveY*event.moveY)
			event.isTap = (event.tapTime <= tapTime and d <= tapMargin)	-- In range for a "tap"
		else print('InputManager:onTouch:touchUp:orgX('..type(event.orgX)..') orgY('..type(event.orgY)..') orgTime('..type(event.orgTime)..'), cannot calculate TAP!')
		end
        touchEventStack[idx] = nil
    elseif eventType == MOAITouchSensor.TOUCH_MOVE then
        if oldX == nil or oldY == nil then
            return
        end
        event.moveX = event.x - oldX
        event.moveY = event.y - oldY
        touchEventStack[idx] = event
    elseif eventType == MOAITouchSensor.TOUCH_CANCEL then
        touchEventStack[idx] = nil
	else
		print(printableTable('InputManager:onTouch:event', event))
    end

    M:dispatchEvent(event)
--[[
	if eventType == MOAITouchSensor.TOUCH_UP then
		if event.orgX and event.orgY and event.orgTime then
			event.tapTime = MOAISim.getDeviceTime() - event.orgTime
			event.moveX = event.x - event.orgX
			event.moveY = event.y - event.orgY
			local d = math.sqrt(event.moveX*event.moveX + event.moveY*event.moveY)
			if event.tapTime <= tapTime and d <= tapMargin then	-- In range for a "tap"
				event.type = Event.TOUCH_TAP
				print(printableTable('InputManager:tap', event))
				M:dispatchEvent(event)
			--else print('InputManager:onTouch:touchUp:d='..d..' t='..event.tapTime..' NOT a tap')
			end
		else print('InputManager:onTouch:touchUp:orgX('..type(event.orgX)..') orgY('..type(event.orgY)..') orgTime('..type(event.orgTime)..'), cannot calculate TAP!')
		end
	end
]]
end

local function onPointer(x, y)
    pointer.x = x
    pointer.y = y

	if not MOAIInputMgr.device.touch or not MOAIInputMgr.device.touch.countTouches or MOAIInputMgr.device.touch:countTouches() <= 0 then
		if pointer.down then
--			print("onPointer:TOUCH.MOVE:"..tostring(x).." "..tostring(y))
			onTouch(MOAITouchSensor.TOUCH_MOVE, 111, x, y, 1)
--		else print("onPointer:pointer.down:"..tostring(pointer.down))
		end
--	else print("onPointer:TouchCount:"..tostring(MOAIInputMgr.device.touch:countTouches()))
	end
end

local function onClick(down)
    pointer.down = down

	if not MOAIInputMgr.device.touch or not MOAIInputMgr.device.touch.countTouches or MOAIInputMgr.device.touch:countTouches() <= 0 then
		local eventType = nil
		if down then
			eventType = MOAITouchSensor.TOUCH_DOWN
		else
			eventType = MOAITouchSensor.TOUCH_UP
		end
		
		onTouch(eventType, 111, pointer.x, pointer.y, 1)
	end
end

local function onKeyboard(key, down)
    keyboard.key = key
    keyboard.down = down
    
    local etype = down and Event.KEY_DOWN or Event.KEY_UP
    local event = Event:new(etype, M)
    event.key = key

    M:dispatchEvent(event)
end

--------------------------------------------------------------------------------
-- Initialize InputManager. <br>
-- Register a callback function for input operations.
--------------------------------------------------------------------------------
function M:initialize()

    -- コールバック関数の登録
    if MOAIInputMgr.device.pointer then
print("inputmanager.lua:Using pointer(mouse) input")
        -- mouse input
        MOAIInputMgr.device.pointer:setCallback(onPointer)
        MOAIInputMgr.device.mouseLeft:setCallback(onClick)
		if MOAIInputMgr.device.touch then
print("inputmanager.lua:Adding touch input")
			MOAIInputMgr.device.touch:setCallback(onTouch)
--	        MOAIInputMgr.device.touch:setCallback(function(eventType, idx, x, y, tapCount)
--print(string.format("inputmanager:touch:%i[%i] %.4f %.4f %i", eventType, idx, x, y, tapCount))
--													end)
		end
    else
print("inputmanager.lua:Using touch input")
        -- touch input
        MOAIInputMgr.device.touch:setCallback(onTouch)
    end

    -- keyboard input
    if MOAIInputMgr.device.keyboard then
        MOAIInputMgr.device.keyboard:setCallback(onKeyboard)
    end
end

function M:isKeyDown(key)
    if MOAIInputMgr.device.keyboard then
        return MOAIInputMgr.device.keyboard:keyIsDown(key)
    end
end

return M
