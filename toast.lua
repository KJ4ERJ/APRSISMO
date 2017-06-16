module(..., package.seeall)

local trueDestroy;

local width, height
local layer
local font
local toastCount = 0
local toastsActive = 0
local touchHandler

local activeToasts = {}

function trueDestroy(toast)
	if activeToasts[toast] then
		--print('Destroying Toast:'..tostring(toast.text.name))
		if type(toast.pDestroy) == 'function' then
			pcall(toast.pDestroy, toast)
		end
--		toast.layer:getPartition():removeProp(toast.group)
		toast.layer:getPartition():removeProp(toast.text);
		toast.layer:getPartition():removeProp(toast.prop3);
		toast.layer:getPartition():removeProp(toast.prop2);
		activeToasts[toast] = nil
		toastsActive = toastsActive - 1
		if toastsActive <= 0 then
			toastCount = 0	-- Reset our layering counter
		end
	end
end

--[[
local function drawRoundedRect(x, y, width, height, radius, circlestep)
  circlestep = circlestep or 32
  local hw, hh = width/2, height/2
 
  MOAIDraw.fillRect( x-hw+radius, y-hh,        x+hw-radius, y+hh )
  MOAIDraw.fillRect( x-hw,        y-hh+radius, x+hw,        y+hh-radius )
  MOAIDraw.fillCircle( x-hw+radius, y-hh+radius, radius, circlestep )
  MOAIDraw.fillCircle( x-hw+radius, y+hh-radius, radius, circlestep )
  MOAIDraw.fillCircle( x+hw-radius, y-hh+radius, radius, circlestep )
  MOAIDraw.fillCircle( x+hw-radius, y+hh-radius, radius, circlestep )
end
]]
-------------------------------
-- public functions
-------------------------------
local function onTouch(e, layer)
	--print('toast:onTouch:'..tostring(e.type))
	--print(printableTable('toast:onTouch', e))
	if e.type == "touchUp" then
		if e.isTap then
--print(printableTable('toast:onTouchUp', e))
		local partition = layer:getPartition()
		local sortMode = layer:getSortMode()
		local wx, wy = layer:wndToWorld(e.x, e.y, 0)
		local props = {partition:propListForPoint(wx, wy, 0, sortMode)}
		for i = #props, 1, -1 do
			local prop = props[i]
			if prop:getAttr(MOAIProp.ATTR_VISIBLE) > 0 then
				--print('Found prop!  '..tostring(prop.name)..' with '..tostring(type(prop.onTap)))
				if type(prop.onTap) == 'function' then
					prop.onTap()
					e.stoped = true
					return true
				end
			end
		end
		end
	end
end

function new(pText, pTime, pTap, pDestroy)
	--if not pTime or pTime <= 0 then pTime = 5000 end

    local text = tostring(pText)-- or "nil";

	if not pTime or pTime == 0 then
		text = os.date("%d %H:%M ")..text
	elseif not simRunning and not simStarting then
		print('toast.new['..tostring(pTime)..']:IGNORING:'..tostring(text))
		return nil	-- timed toasts require simRunning or at least simStarting
	end

	print('toast.new['..tostring(pTime)..']:'..tostring(text))

if not layer then
	local Event = require "hp/event/Event"
	layer = Layer { touchEnabled = true, Priority=2000000000 }
	width, height = Application.viewWidth, Application.viewHeight
	layer:setPriority(2000000000)
	SceneManager:addBehindFrontLayer(layer)
	SceneManager:addEventListener(Event.SCENE_CLOSING,
							function(event)
								print("toast:Scene("..tostring(event.data and event.data:getName())..") Closing!")
								layer:setScene(nil)
							end)
	SceneManager:addEventListener(Event.SCENE_RESUMING,
							function(event)
								print("toast:Scene("..tostring(event.data and event.data:getName())..") Resuming!")
								layer:setScene(event.data)
							end)
	layer:setSortMode(MOAILayer.SORT_PRIORITY_ASCENDING)
    layer:addEventListener("touchUp", function(e) onTouch(e,layer) end, self, 1000)	-- make SURE we have it hooked!
elseif Application.viewWidth ~= myWidth or Application.viewHeight ~= myHeight then
	width, height = Application.viewWidth, Application.viewHeight
	layer:setSize(width, height)
end

if not font then
	--print('toast:Creating font')
	font = MOAIFont.new ()
	font:load ( "arial-rounded.ttf" )
	font:setDefaultSize(18)
end

local width, height = MOAIGfxDevice:getViewSize()
local toast = {}
activeToasts[toast] = toast
toast.pDestroy = pDestroy
toast.layer = layer
toast.text = MOAITextBox.new ()
toast.text.name = "toast:"..text
toast.text:setFont ( font )
toast.text:setTextSize ( 22*config.Screen.scale )
--toast.text:setRect ( -160, -80, 160, 80 )
toast.text:setRect ( -width/2, -height*0.15, width/2, height*0.15 )	-- whole width, 30% of height
--toast.text:setYFlip ( true )
toast.text:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
toast.text:setString ( text )
toastCount = toastCount + 1
toastsActive = toastsActive + 1

--[[
if toastsActive == 1 then
  local lastScene = nil
  local timer = MOAITimer.new()
  timer:setSpan(1/10)
  timer:setMode(MOAITimer.LOOP)
  timer:setListener(MOAITimer.CONTINUE,
					function()
						if toastsActive > 0 then
							thisScene = SceneManager:getCurrentScene()
							if thisScene ~= lastScene then
								print('toast:setting new scene!')
								layer:setScene(thisScene)
								lastScene = thisScene
							end
						else
							print('toast:cancelling timer.')
							toastCount = 0	-- Reset the layer priority driver
							timer:stop()	-- No longer need to run
							timer = nil
						end
					end)
  timer:start()
end
]]

--toast.text:spool ()
local x1,y1,x2,y2 = toast.text:getStringBounds(1,#text)
--print('toast('..tostring(text)..' at '..tostring(x1)..','..tostring(y1)..' -> '..tostring(x2)..','..tostring(y2))
--print(string.format('toast(%s) is %i,%i->%i,%i or %ix%i index(%s) Screen:%ix%i', text, x1, y1, x2, y2, x2-x1, y2-y1, tostring(toastCount), width, height))
if x1 and y2 then
	toast.text:setRect(x1-2,y1,x2+2,y2)	-- Reset to actual text coverage
else
	print('toast:getStringBounds('..tostring(text)..') returned NILs!')
	x1 = width/8
	x2 = width*7/8
	y1 = height/2
	y2 = height
end
local xOffset = width/2
local yOffset = height*(1.0-0.15)	-- 15% up from bottom gives 30% available height
toast.text:setLoc ( width/2, yOffset )
--local x1,y1,x2,y2 = toast.text:getStringBounds(1,#text)
--print('toast('..tostring(text)..' at '..tostring(x1)..','..tostring(y1)..' -> '..tostring(x2)..','..tostring(y2))

local pad = 4
local lx = (x1+x2)/2+xOffset
local ly = (y1+y2)/2+yOffset
local xw = x2-x1+pad*2
local yh = y2-y1+pad*2
local hx = lx + xw
local hy = ly + yh
--[[
toast.scriptDeck = MOAIScriptDeck.new ()
toast.scriptDeck:setRect ( lx, ly, hx, hy )
--print("creating toast background @"..x1..','..y1..' -> '..x2+pad..','..y2+pad)
toast.scriptDeck:setDrawCallback ( function ( index, xOff, yOff, xFlip, yFlip )
			local width, height = x2-x1+pad*2, y2-y1+pad*2
			local cornerRound = 16*config.Screen.scale
			local alpha = toast.text:getAttr ( MOAIColor.ATTR_A_COL)
			alpha = 1
			MOAIGfxDevice.setPenColor(96/255,88/255,96/255,alpha)
			MOAIGfxDevice.setPenWidth(6)
			drawRoundedRect((x1+x2)/2+xOffset,(y1+y2)/2+yOffset,width+6,height+6,cornerRound)
			MOAIGfxDevice.setPenColor(72/255,64/255,72/255,alpha)
			MOAIGfxDevice.setPenWidth(1)
			drawRoundedRect((x1+x2)/2+xOffset,(y1+y2)/2+yOffset,width,height,cornerRound)
		end
 )
--toast(APRS-IS ldeffenb.dnsalias.net:10152 (192.168.10.8) Verified) is -154,-73->157,35 or 311x108
toast.prop2 = MOAIProp2D.new ()
toast.prop2.name = "toastBackground"
toast.prop2:setDeck ( toast.scriptDeck )
--toast.text:setLoc ( 0, -100 )
]]

local cr = 16*config.Screen.scale	-- Corner round
local st = 32	-- steps

toast.prop2 = Graphics{ width=xw+6, height=yh+6, left=lx-3, top=ly-3}
toast.prop2:setColor(96/255,88/255,96/255,1)
toast.prop2:fillRoundRect(0,0,xw+6,yh+6,cr,cr,st)
toast.prop2:setPos(lx-xw/2-3,ly-yh/2-3)

toast.prop3 = Graphics{ width=xw, height=yh, left=lx, top=ly}
toast.prop3:setColor(72/255,64/255,72/255,1)
toast.prop3:fillRoundRect(0,0,xw,yh,cr,cr,st)
toast.prop3:setPos(lx-xw/2,ly-yh/2)

toast.prop2:setPriority(2000000000-toastCount*2-2)
toast.prop3:setPriority(2000000000-toastCount*2-1)
toast.text:setPriority(2000000000-toastCount*2)

--toast.group = Group{ layer = layer }
--toast.group:addChild(toast.prop2)
--toast.group:addChild(toast.prop3)
--toast.group:addChild(toast.text)

--layer:getPartition():insertProp(toast.group)

layer:getPartition():insertProp ( toast.prop2 )
layer:getPartition():insertProp ( toast.prop3 )
layer:getPartition():insertProp ( toast.text )

--toast.prop2:setAttrLink ( MOAIColor.ATTR_A_COL, toast.text, MOAIColor.ATTR_A_COL )toast.text:setColor(1,1,1,0)
local fadeIn = toast.text:moveColor(0, 0, 0, 1, .250, MOAIEaseType.LINEAR)
fadeIn:setListener ( MOAIAction.EVENT_STOP,
	function()
		if pTime ~= nil then
	        performWithDelay(pTime, function() destroy(toast) end);
			--[[local fadeOut = toast.text:moveColor(0, 0, 0, -1, pTime/1000, MOAIEaseType.LINEAR)
			fadeOut:setListener ( MOAIAction.EVENT_STOP, 
				function ()
					--print('Removing '..tostring(toast.text.name))
					trueDestroy(toast)
				end
			)]]
		end
		
		if type(pTap) == 'function' then
			toast.text.onTap = function ()
				pTap()
				trueDestroy(toast)
				return true
			end
		else
			toast.text.onTap = function ()
				trueDestroy(toast)
				return true
			end
		end
		toast.prop2.onTap = toast.text.onTap
		toast.prop3.onTap = toast.text.onTap
	end)

--[[
    local pTime = pTime;
    local toast = display.newGroup();

    toast.text                      = display.newText(toast, pText, 14, 12, native.systemFont, 20);
    toast.background                = display.newRoundedRect( toast, 0, 0, math.min(display.contentWidth, toast.text.width + 24), math.min(display.contentHeight, toast.text.height + 24), 16 );
    toast.background.strokeWidth    = 4
    toast.background:setFillColor(72, 64, 72)
    toast.background:setStrokeColor(96, 88, 96)
	if fillTextSquare then fillTextSquare(toast.background, toast.text) end
	toast.text.x = toast.background.contentWidth / 2
	toast.text.y = toast.background.contentHeight / 2

    toast.text:toFront();

    toast:setReferencePoint(display.CenterReferencePoint)
    --toast:setReferencePoint(toast.width*.5, toast.height*.5)
    --utils.maintainRatio(toast);

    toast.alpha = 0;
    toast.transition = transition.to(toast, {time=250, alpha = 1});

    if pTime ~= nil then
        timer.performWithDelay(pTime, function() destroy(toast) end);
    end

    toast.x = display.contentWidth * .5
    toast.y = display.contentHeight * .9

	if type(pTap) == 'function' then
		toast:addEventListener( "tap", function (event)
											--print(tostring(event.numTaps)..' tap on toast '..toast.text.text)
											pTap(event)
											trueDestroy(toast)
											return true
										end )
	else
		toast:addEventListener( "tap", function (event)
											trueDestroy(toast)
											return true
										end )
	end
]]	
    return toast;
end

function destroy(toast, immediate)
	if activeToasts[toast] then
		if immediate then
			trueDestroy(toast)
		else
			--toast.prop2:moveColor(0,0,0,-1,.050, MOAIEaseType.LINEAR)
			local fadeOut = toast.text:moveColor(0, 0, 0, -1, .250, MOAIEaseType.LINEAR)
			fadeOut:setListener ( MOAIAction.EVENT_STOP, 
				function ()
					--print('Removing '..tostring(toast.text.name))
					trueDestroy(toast)
				end
			)
		end
	end
--    toast.transition = transition.to(toast, {time=250, alpha = 0, onComplete = function() trueDestroy(toast) end});
end
