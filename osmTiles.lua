local debugging = false
local MaxSymbols = 1000
local concurrentLoadingThreads = 4
local delayBetweenTiles = 0 --2000

-- Project: APRSISMO
--
-- Date: Jun 19, 2013
--
-- Version: 0.1
--
-- File name: osmTiles.lua
--
-- Author: Lynn Deffenbaugh, KJ4ERJ
--
-- Abstract: Tile fetching support
--
-- Demonstrates: sockets, network
--
-- File dependencies: 
--
-- Target devices: Simulator and Device
--
-- Limitations: Requires internet access; no error checking if connection fails
--
-- Update History:
--	v0.1		Initial implementation
--
-- Comments: 
-- Uses LuaSocket libraries that ship with Corona. 
--
-- Copyright (C) 2013 Homeside Software, Inc. All Rights Reserved.
---------------------------------------------------------------------------------------
local osmTiles = { VERSION = "0.0.1" }

local tileScale = 1
local tileSize = 256*tileScale

function osmTiles:getTileScale()
	return tileScale, tileSize
end

-- Load the relevant LuaSocket modules (no additional files required for these)
local lfs = require("lfs")
local socket = require("socket")
local http = require("socket.http")
--local ltn12 = require("ltn12")
--local widget = require("widget")
local toast = require("toast");
local colors = require("colors");
local LatLon = require("latlon")

-- local busyImage
local osmLoading = {}

local zoom, zoomDiv, zoomDelta = 0, 1/(2^(20-0))*tileScale, 2^0*tileScale
local zoomMax = 20

local tileAlpha = 0.10

function osmTiles:getTileAlpha()
	return tileAlpha
end

local tileGroup = Group()	-- global for access by main (stupid, I know)
local tilesLoaded = 0		-- Count of loaded tiles

function osmTiles:getTilesLoaded()
	return tilesLoaded
end

function osmTiles:getTileGroup()
	return tileGroup
end

function osmTiles:getZoom()
	return zoom, zoomMax
end

local activeCallbacks = {}

function osmTiles:addCallback(callFunc)
	for k,v in pairs(activeCallbacks) do
		if v == callFunc then return false end
	end
	table.insert(activeCallbacks, callFunc)
	return true
end

function osmTiles:removeCallback(callFunc)
	for k,v in pairs(activeCallbacks) do
		if v == callFunc then
			activeCallbacks[k] = nil
			return true
		end
	end
	return false
end

local function invokeCallbacks(what, ...)
	for k,v in pairs(activeCallbacks) do
		v(what,...)
	end
end

local currentVersionID = 0
local function newVersionID()
	currentVersionID = currentVersionID + 1
	return currentVersionID
end

function fillTextSquare(square, text, minSize, maxSize, padWidth, padHeight)
--[[
	minSize = minSize or 1
	maxSize = maxSize or 128
	local w, h = square.contentWidth, square.contentHeight
	for f = minSize, maxSize do
		text.size = f
		-- print(string.format('size:%i %s:%ix%i square:%ix%i', f, text.text, text.contentWidth, text.contentHeight, w, h))
		if text.contentHeight > h or text.contentWidth > w then break end
	end
	text.size = text.size - 1
	return text.size
]]
	minSize = minSize or 1
	maxSize = maxSize or 128
	padWidth = padWidth or 0
	padHeight = padHeight or 0
	local w, h = square.contentWidth, square.contentHeight
	local s = 1.0
	while text.contentHeight+padHeight > h or text.contentWidth+padWidth > w do
		s = s * 0.9
		text:scale(0.9, 0.9)
		--print(string.format('scale:%i %s:%ix%i square:%ix%i', s, text.text, text.contentWidth, text.contentHeight, w, h))
	end
	--print(string.format('scale:%i %s:%ix%i square:%ix%i', s, text.text, text.contentWidth, text.contentHeight, w, h))
	--print(string.format("fill(%s) size:%f is scale %f", text.text, text.size, text.xScale))
	return text.xScale
end

--[[local function isPointInsideRectangle(rectangle, x, y)
        local c = math.cos(-rectangle.rotation*math.pi/180)
        local s = math.sin(-rectangle.rotation*math.pi/180)
        
        -- UNrotate the point depending on the rotation of the rectangle
        local rotatedX = rectangle.x + c * (x - rectangle.x) - s * (y - rectangle.y)
        local rotatedY = rectangle.y + s * (x - rectangle.x) + c * (y - rectangle.y)
        
        -- perform a normal check if the new point is inside the 
        -- bounds of the UNrotated rectangle
        local leftX = rectangle.x - rectangle.width / 2
        local rightX = rectangle.x + rectangle.width / 2
        local topY = rectangle.y - rectangle.height / 2
        local bottomY = rectangle.y + rectangle.height / 2
        
        return leftX <= rotatedX and rotatedX <= rightX and
                topY <= rotatedY and rotatedY <= bottomY
end]]

local tapTimer, tapTransition

local tapStartTime, tapTotalTime, tapStartAlpha, tapDelta, tapEndAlpha, tapEndTime

local function fixTileGroupSegments()
	local myGroup = tileGroup.zoomGroup
	if myGroup.segments then
		for _,v in pairs(myGroup.segments) do
			v.x = v.x + myGroup.x + tileGroup.x
			v.y = v.y + myGroup.y + tileGroup.y
		end
	end
end

local function setTapGroupAlpha(alpha)
	if tileGroup then
		local myGroup = tileGroup.zoomGroup
		if myGroup then
			myGroup.alpha = alpha
			if myGroup.segments then
				for _,v in pairs(myGroup.segments) do v.alpha = alpha end
			end
		end
	end
end

local function tapFader(event)
	local now = event.time
	if now < tapEndTime then
		local newAlpha = easing.linear(now-tapStartTime, tapTotalTime, tapStartAlpha, tapDelta)
		setTapGroupAlpha(newAlpha)
	else
		Runtime:removeEventListener( "enterFrame", tapFader )
		--timer.cancel(tapTransition)
		setTapGroupAlpha(tapEndAlpha)
	end
end

function osmTiles:removeTapGroup(event)
	--print('removeTapGroup('..type(event)..'('..tostring(event)..'))')
	if not event then
		timer.performWithDelay(100, function () osmTiles:removeTapGroup(true) end)
	else
		if tapTimer then timer.cancel(tapTimer) tapTimer=nil end
		if tapTransition then Runtime:removeEventListener( "enterFrame", tapFader ) tapTransition=nil end
		setTapGroupAlpha(0)
	end
end

local function fadeZoomGroup(endAlpha, totalTime)
	if tapTransition then Runtime:removeEventListener( "enterFrame", tapFader ) end
	tapStartTime = MOAISim.getDeviceTime()*1000
	tapTotalTime = totalTime
	tapEndTime = tapStartTime+tapTotalTime
	tapStartAlpha = tileGroup.zoomGroup.alpha
	tapEndAlpha = endAlpha
	tapDelta = tapEndAlpha-tapStartAlpha
	Runtime:addEventListener( "enterFrame", tapFader )
	--tapTransition = timer.performWithDelay( 1000/30, tapFader, 0)
	tapTransition = true
	return tapTransition
end

--[[local function tapTransitionComplete()
	tapTransition = nil
end]]

local function tapTimerExpired()
	--tileGroup.zoomGroup.alpha = 0	-- Make it invisible until tapped again
	--tapTransition = transition.to( tileGroup.zoomGroup, { alpha = 0, time=2000, onComplete = tapTransitionComplete } )
	tapTransition = fadeZoomGroup(0, 2000)
	tapTimer = nil
end

local function resetTapTimer()
	if tapTimer then
		timer.cancel(tapTimer)
	else
		--if tapTransition then transition.cancel(tapTransition); tapTransition = nil end
		--transition.to( tileGroup.zoomGroup, { alpha = 0.75, time=500 } )
--		if tapTransition then timer.cancel(tapTransition); tapTransition = nil end
		fadeZoomGroup(0.75, 250)
		tileGroup:addChild(tileGroup.zoomGroup)
		--tileGroup.zoomGroup.alpha = 0.75	-- Make zoom control visible
	end
	tapTimer = timer.performWithDelay( 5*1000, tapTimerExpired)
end

function osmTiles:validLatLon(lat_deg, lon_deg)	-- returns true or false
	if lat_deg < -85.0511 or lat_deg > 85.0511 or lon_deg < -180 or lon_deg > 180 then
		print(string.format("osmTiles:validLatLon:Invalid lat(%f) or lon(%f)", lat_deg, lon_deg))
		return false
	end
	return true
end

local function osmTileNum(lat_deg, lon_deg, zoom)	-- lat/lon in degrees gives xTile, yTile
	--if not lat_deg or not lon_deg then return nil end
	if not osmTiles:validLatLon(lat_deg, lon_deg) then
		print(string.format("osmTileNum:Invalid lat(%f) or lon(%f)", lat_deg, lon_deg))
		return nil
	end
	local n = 2 ^ zoom
	local xtile = n * ((lon_deg + 180) / 360)

--	1 = n * ((0.017971305190311+180)/360)
--	1 = n * 0.5000499202921953
--	n = 1.999800338765513 (0.000199661234487)
--	1 = n * 0.4999500797078047
--	n = 2.000199701107056 (0.0001997011070564653)
--	1/0.017971305190311 = 20031.93402970472 or approx 20032 or 78.25 256pixel tiles
	
	local lat_rad = math.rad(lat_deg)
	local ytile = n * (1 - (math.log(math.tan(lat_rad) + (1/math.cos(lat_rad))) / math.pi)) / 2
	if xtile < 0 or xtile >= 2^zoom or ytile < 0 or ytile >= 2^zoom then
		--print(string.format("osmTileNum:%f %f gave %f %f zoom %i", lat_deg, lon_deg, xtile, ytile, zoom))
		local foo = nil
		foo.x = 5
	end
	return xtile, ytile
end
-- This returns the NW-corner of the square. Use the function with xtile+1 and/or ytile+1
-- to get the other corners. With xtile+0.5 & ytile+0.5 it will return the center of the tile. 
local function osmTileLatLon(xTile, yTile, zTile)	-- xTile, yTile, zoom -> lat, lon
	local n = 2^zTile
	local lon_deg = xTile / n * 360.0 - 180.0
	local lat_deg = 180.0 / math.pi * math.atan(math.sinh(math.pi * (1 - 2 * yTile / n)))
	return lat_deg, lon_deg
end

function osmTiles:getCenter()
	return tileGroup.lat, tileGroup.lon, zoom
end

function osmTiles:moveTo(lat, lon, newZoom)
	local force = false
	if not lat or not lon then
		force = true
		lat = tileGroup.lat
		lon = tileGroup.lon
		newZoom = zoom
	end
	if serviceActive then
		if simRunning then
			local start = MOAISim.getDeviceTime()
			performWithDelay2("serviceMoveTo",1,function()
								local elapsed = (MOAISim.getDeviceTime()-start)*1000
								--print(string.format("moveTo:finishing service deferral after %.2fms", elapsed))
								self:moveTo(lat,lon,newZoom)
								end)
		end
	else
	newZoom = newZoom or zoom
--print('moveTo:'..lat..' '..lon..' '..tostring(newZoom).." service:"..tostring(serviceActive))
	if force or tileGroup.lat ~= lat or tileGroup.lon ~= lon or zoom ~= newZoom then
local start = MOAISim.getDeviceTime()
		local xTile, yTile = osmTileNum(lat, lon, zoom)
		if xTile and yTile then
			tileGroup.lat, tileGroup.lon = lat, lon
			-- print(string.format('moveTo:%f %f is Tile %i/%i/%i', lat, lon, zoom, xTile, yTile))
			if zoom == newZoom then
				config.lastMapLat, config.lastMapLon, config.lastMapZoom = lat, lon, newZoom
				osmTiles:osmLoadTiles(xTile, yTile, zoom, force)
				invokeCallbacks('move')
			else
				osmTiles:zoomTo(newZoom)
			end
		end
local elapsed = (MOAISim.getDeviceTime()-start)*1000
if elapsed > 10 then print("osmTiles:moveTo:Took "..elapsed.."ms") end
	-- else print(string.format('moveTo %.5f %.5f %i redundant', lat, lon, newZoom))
	end
	end
end

function osmTiles:pixelLatLon()
	local xTile, yTile = osmTileNum(tileGroup.lat, tileGroup.lon, zoom)
	--xTile, yTile = math.floor(xTile), math.floor(yTile)	-- Ensures room to add 0.5!
	local latNW, lonNW = osmTileLatLon(xTile-0.25, yTile-0.25, zoom)
	local latCenter, lonCenter = osmTileLatLon(xTile+0.25, yTile+0.25, zoom)
	local latPerY = (latCenter-latNW)/(tileSize/2)
	local lonPerX = (lonCenter-lonNW)/(tileSize/2)
	return latPerY, lonPerX
end

function osmTiles:rangeLatLon(radius)
	if not radius then radius = math.min(tileGroup.width, tileGroup.height)/2 end	-- radius is 1/2 min dimension
	radius = radius / 2	-- +/- means use 1/2 radius in each direction
	local latPerY, lonPerX = osmTiles:pixelLatLon()
	local fromPoint = LatLon.new(tileGroup.lat-radius*latPerY, tileGroup.lon)
	local toPoint = LatLon.new(tileGroup.lat+radius*latPerY, tileGroup.lon)
	local vertDistance = kmToMiles(fromPoint.distanceTo(toPoint))
	--local vertBearing = fromPoint.bearingTo(toPoint)
	fromPoint = LatLon.new(tileGroup.lat, tileGroup.lon-radius*lonPerX)
	toPoint = LatLon.new(tileGroup.lat, tileGroup.lon+radius*lonPerX)
	local horzDistance = kmToMiles(fromPoint.distanceTo(toPoint))
	--local horzBearing = fromPoint.bearingTo(toPoint)
	return horzDistance, vertDistance
end

function osmTiles:deltaMove(dx, dy)	-- in pixels
	local start = MOAISim.getDeviceTime()
--	local xTile, yTile = osmTileNum(tileGroup.lat, tileGroup.lon, zoom)
--	xTile, yTile = math.floor(xTile), math.floor(yTile)	-- Ensures room to add 0.5!
--	local latNW, lonNW = osmTileLatLon(xTile, yTile, zoom)
--	local latCenter, lonCenter = osmTileLatLon(xTile+0.5, yTile+0.5, zoom)
--	local latPerY = (latCenter-latNW)/128
--	local lonPerX = (lonCenter-lonNW)/128

	local latPerY, lonPerX = osmTiles:pixelLatLon()
	local newLat = tileGroup.lat-dy*latPerY
	local newLon = tileGroup.lon-dx*lonPerX
	if newLat < -85.0511 then newLat = -85.0511+latPerY*(tileSize/2) end
	if newLat > 85.0511 then newLat = 85.0511-latPerY*(tileSize/2) end
	if newLon < -180 then newLon = newLon + 360 end
	if newLon > 180 then newLon = newLon - 360 end
	osmTiles:moveTo(newLat, newLon)
local elapsed = (MOAISim.getDeviceTime()-start)*1000
if elapsed > 10 then print("osmTiles:deltaMove:Took "..elapsed.."ms") end
	
	osmTiles:showCrosshair()
end

function osmTiles:crosshairActive()
	return tileGroup.crossHair ~= nil
end

function osmTiles:removeCrosshair()
	if tileGroup.crossTimer then tileGroup.crossTimer:stop() end
	if tileGroup.crossHair then
		tileGroup:removeChild(tileGroup.crossHair)
		tileGroup.crossHair = nil
	end
end

function osmTiles:showCrosshair()
	if not tileGroup.crossHair then
		local w, h = tileGroup.width, tileGroup.height
		local cx, cy = w/2, h/2
		local len = math.min(cx,cy)/4
		local len2 = len*2
		local vertPoints = { len,len-len2, len,len+len2 }
		local horzPoints = { len-len2,len, len+len2,len }
		tileGroup.crossHair = Graphics { left=cx-len, top=cy-len, width=len*2, height=len*2 }
		tileGroup.crossHair:setPenColor(0,0,0,0.75):setPenWidth(math.max(config.Screen.scale*2,1)):drawLine(vertPoints):drawLine(horzPoints)
		tileGroup.crossHair:setPriority(3000000)
		tileGroup:addChild(tileGroup.crossHair)
	end
	if tileGroup.crossTimer then tileGroup.crossTimer:stop() end
	tileGroup.crossTimer = performWithDelay(5000,
						function()
							tileGroup.crossTimer = nil	-- It expired
							osmTiles:removeCrosshair()
						end)
end

local function showSliderText(slider, value)
if slider then
	if not slider.text then
		local text = display.newEmbossedText(value, 0,0, native.systemFont, math.min(slider.contentWidth,slider.contentHeight)) --display.newText(value, 0,0, native.systemFont, 128)
		tileGroup:addChild(text)
--myText:setText( "Hello World!" )
		text:setTextColor( 64, 64, 64 )
		text:setEmbossColor({highlight={r=128,g=128,b=128,a=255}, shadow={r=0,g=0,b=0,a=255}})
		--text:setEmbossColor({highlight={r=64,g=64,b=64,a=255}, shadow={r=64,g=64,b=64,a=255}})
		if not slider.textScale then
			slider.textScale = fillTextSquare(slider, text)
		--else text.size = slider.textSize
		end
		slider.text = text
	end
	if value then slider.text:setText(value) end
	slider.text.x = slider.x
	slider.text.y = slider.y
--[[	local function textTimeout()
		slider.text:removeSelf()
		slider.transition = nil
		slider.text = nil
		text = nil
	end
	if slider.transition then
		transition.cancel(slider.transition)
		slider.transition = nil
	end]]
--[[	if slider.text then
		slider.text:removeSelf()
		slider.text = nil
	end]]
	--slider.transition = transition.to( zoomText, { alpha = 0, time=1000, transition = easing.inQuad, onComplete = textTimeout } )
end
end

local function showZoom(newZoom)
	newZoom = newZoom or zoom
	showSliderText(tileGroup.zoomGroup.zoomSlider, string.format("%2i", newZoom))
end

function osmTiles:deltaZoom(delta)
	local newZoom = zoom + delta
	return osmTiles:zoomTo(newZoom)
end

local zoomToast

function osmTiles:zoomTo(newZoom)
	if newZoom < 0 then newZoom = 0 elseif newZoom > zoomMax then newZoom = zoomMax end
	newZoom = math.floor(newZoom)
	if newZoom ~= zoom then
local start = MOAISim.getDeviceTime()
		--print (string.format('Zooming to %f', newZoom))
		--tileGroup.zoomGroup.alpha = 0	-- Make it invisible to prevent additional taps
		local lat, lon = tileGroup.lat, tileGroup.lon
		local xTile, yTile = osmTileNum(lat, lon, newZoom)
		if xTile and yTile then
			if zoomToast then toast.destroy(zoomToast, true) end
			zoomToast = toast.new("Zoom:"..newZoom, 500, nil, function() zoomToast = nil end)
			zoom = newZoom
			zoomDiv = 1/(2^(20-zoom))*tileSize	-- for symbol and track fixing
			zoomDelta = 2^zoom*tileSize	-- pixels across world wrapping
--print('zoomTo:'..lat..' '..lon..' '..newZoom)
			config.lastMapZoom = newZoom
			showZoom(zoom)
			if tileGroup.zoomGroup.zoomSlider then
				tileGroup.zoomGroup.zoomSlider:setValue(math.floor(zoom/zoomMax*100+0.5))
			end
			--print(string.format('zoomTo:%f %f is Tile %i/%i/%i', lat, lon, zoom, xTile, yTile))
			osmTiles:osmLoadTiles(xTile, yTile, zoom);
			invokeCallbacks('zoom')
		end
		osmTiles:showCrosshair()
print("osmTiles:zoomTo:Took "..((MOAISim.getDeviceTime()-start)*1000).."ms")
	end
	return newZoom
end
local function zoomSliderListener( event )
	local slider = event.target
	local value = event.value
	-- print( "ZoomSlider at " .. value .. "%" )
	osmTiles:zoomTo(math.floor(value/100*zoomMax+0.5))
	resetTapTimer()
end

local function showAlpha(newAlpha)
	newAlpha = newAlpha or tileAlpha
	showSliderText(tileGroup.zoomGroup.alphaSlider, string.format("%i%%", newAlpha*100))
end

function osmTiles:deltaTileAlpha(delta)
	osmTiles:setTileAlpha(tileAlpha+delta)
end

function osmTiles:setTileAlpha(newAlpha)
--print("setTileAlpha to ", newAlpha)
	if newAlpha < 0 then newAlpha = 0
	elseif newAlpha > 1 then newAlpha = 1
	end
	if newAlpha ~= tileAlpha then
		tileAlpha = newAlpha
	toast.new(tostring(math.floor(tileAlpha*100)).."% Opaque", 1000)
		tileGroup.tilesGroup.alpha = tileAlpha		-- change the actual map alpha
		tileGroup.tilesGroup:setColor(tileAlpha,tileAlpha,tileAlpha,tileAlpha)
		config.lastMapAlpha = tileAlpha
	end
end

local function alphaSliderListener( event )
	local slider = event.target
	local value = event.value
	--print( "AlphaSlider at " .. value .. "%" )
	osmTiles:setTileAlpha(value/100)
	resetTapTimer()
end

local scaleToast

function osmTiles:setTileScale(newScale)
	if newScale < 1 then newScale = 1 elseif newScale > 9 then newScale = 9 end
	newScale = math.floor(newScale)
	if newScale ~= tileScale then
local start = MOAISim.getDeviceTime()
			if scaleToast then toast.destroy(scaleToast, true) end
			scaleToast = toast.new("Scale:"..newScale, 500, nil, function() scaleToast = nil end)
			tileScale = newScale
			tileSize = 256*tileScale
			config.lastMapScale = tileScale
			zoomDiv = 1/(2^(20-zoom))*tileSize	-- for symbol and track fixing
			zoomDelta = 2^zoom*tileSize	-- pixels across world wrapping
			osmTiles:resetSize('scale')
		osmTiles:showCrosshair()
print("osmTiles:zoomTo:Took "..((MOAISim.getDeviceTime()-start)*1000).."ms")
	end
	return newZoom
end


local function tileTap( event )
	resetTapTimer()
	--print ('tileTap:'..event.name..':'..event.numTaps..' @ '..event.x..','..event.y)
	
	if tapTimer or tapTransition then	-- if the slider is visible
		--resetTapTimer()
		if event.numTaps > 1 then
local function getSliderPercent(slider)
	local localx, localy = event.target:contentToLocal(event.x, event.y)
	local width = slider.contentWidth
	local height = slider.contentHeight
	--print('AlphaBar:tap '..localx..','..localy..' slider@'..slider.x..','..slider.y..' size '..width..'x'..height)
	localx = localx - (slider.x-width/2)
	localy = localy - (slider.y-height/2)
	if localx >= 0 and localx <= width and localy >= 0 and localy <= height then	-- inside slider?
		local xPercent = localx/width
		local yPercent = 1.0-(localy/height)
		--print (string.format('slider:x:%i%% y:%i%% width:%i height%i', xPercent*100, yPercent*100, width, height))
		if width > height then
			return xPercent
		else
			return yPercent
		end
	else
		--print(string.format("slider@%f,%f out of range in size %fx%f", localx, localy, width, height))
	end
	return nil
end

local function checkSliderTap(slider, listener)
	local Percent = getSliderPercent(slider)
	if Percent then
		local percent = math.floor(100*Percent+0.5)
		slider:setValue(percent)
		listener({ target=slider, value=percent})
		return true
	end
	return false
end
			if checkSliderTap(tileGroup.zoomGroup.alphaSlider, alphaSliderListener) then return true end
			if checkSliderTap(tileGroup.zoomGroup.zoomSlider, zoomSliderListener) then return true end
		end
	end
    return false
end 














local function calculateDelta( previousTouches, event )
	local id,touch = next( previousTouches )
	if event.id == id then
		id,touch = next( previousTouches, id )
		assert( id ~= event.id )
	end

	local dx = touch.x - event.x
	local dy = touch.y - event.y
	return dx, dy
end

--local debugText = nil
local stretchImage = nil
local ln2 = math.log(2)

local function log2(n)
	return math.log(n) / ln2
end

-- create a table listener object for the bkgd image
local function tileTouch( event )

	local self = tileGroup	-- Temporary!  (yeah, right!)
	
	local result = true

	local phase = event.phase
	--print('tileTouch: phase:'..phase..' @ '..event.x..','..event.y)

	local previousTouches = self.previousTouches

	local numTotalTouches = 1
	if ( previousTouches ) then
		-- add in total from previousTouches, subtract one if event is already in the array
		numTotalTouches = numTotalTouches + self.numPreviousTouches
		if previousTouches[event.id] then
			numTotalTouches = numTotalTouches - 1
		end
	end

	if "began" == phase then
		-- Very first "began" event
		if ( not self.isFocus ) then
			-- Subsequent touch events will target button even if they are outside the contentBounds of button
			display.getCurrentStage():setFocus( self )
			self.isFocus = true

			previousTouches = {}
			self.previousTouches = previousTouches
			self.numPreviousTouches = 0

-- This returns the NW-corner of the square. Use the function with xtile+1 and/or ytile+1
-- to get the other corners. With xtile+0.5 & ytile+0.5 it will return the center of the tile. 
--local function osmTileNum(lat_deg, lon_deg, zoom)	-- lat/lon in degrees gives xTile, yTile
--local function osmTileLatLon(xTile, yTile, zTile)	-- xTile, yTile, zoom -> lat, lon
--????? tileGroup.lat, tileGroup.lon = lat, lon
local xTile, yTile = osmTileNum(tileGroup.lat, tileGroup.lon, zoom)
xTile, yTile = math.floor(xTile), math.floor(yTile)
local latNW, lonNW = osmTileLatLon(xTile, yTile, zoom)
local latCenter, lonCenter = osmTileLatLon(xTile+0.5, yTile+0.5, zoom)
--print(string.format('%.4f lat/pixel(y) %.4f lon/pixel(x)', (latCenter-latNW)/128, (lonCenter-lonNW)/128))
self.touchX = event.x
self.touchY = event.y
self.latPerY = (latCenter-latNW)/(tileSize/2)
self.lonPerX = (lonCenter-lonNW)/(tileSize/2)

		elseif ( not self.distance ) then
			local dx,dy

			if previousTouches and ( numTotalTouches ) >= 2 then
				dx,dy = calculateDelta( previousTouches, event )
			end

			-- initialize to distance between two touches
			if ( dx and dy ) then
				local d = math.sqrt( dx*dx + dy*dy )
				if ( d > 0 ) then
--[[if not debugText then
debugText = display.newText("", 0,0, native.systemFont, 28)
debugText:setReferencePoint(display.CenterLeftReferencePoint)
debugText.x = display.screenOriginX
debugText.y = display.contentHeight /4
debugText:setTextColor(0,0,0)
end]]
if not stretchImage then
stretchImage = display.capture(tileGroup)
--stretchImage:setReferencePoint(display.TopLeftReferencePoint)
stretchImage.x = stretchImage.x + display.screenOriginX
stretchImage.y = stretchImage.y + display.screenOriginY
end
					self.distance = d
					self.xScaleOriginal = self.xScale
					self.yScaleOriginal = self.yScale
					self.xScaleOriginal = stretchImage.xScale
					self.yScaleOriginal = stretchImage.yScale
					self.originalZoom = zoom
--debugText.text = string.format("d=%.2f", self.distance)
					--print( "distance = " .. self.distance )
				end
			end
		end

		if not previousTouches[event.id] then
			self.numPreviousTouches = self.numPreviousTouches + 1
		end
		previousTouches[event.id] = event

	elseif self.isFocus then
		if "moved" == phase then
			if ( self.distance ) then
				local dx,dy
				if previousTouches and ( numTotalTouches ) >= 2 then
					dx,dy = calculateDelta( previousTouches, event )
				end

				if ( dx and dy ) then
					local newDistance = math.sqrt( dx*dx + dy*dy )
					local scale = newDistance / self.distance
					--resetTapTimer()	-- Make the zoom control visible
					local scale2 = 2^math.modf(log2(scale))
					--print( "newDistance(" ..newDistance .. ") / distance(" .. self.distance .. ") = scale("..  scale ..")" )
--debugText.text = string.format("%.2f -> %.2f -> %i", log2(scale), scale2, self.originalZoom+log2(scale)*2+0.5)
					if ( scale > 0 ) then
						self.newZoom = self.originalZoom + log2(scale2)
						stretchImage.xScale = self.xScaleOriginal * scale2
						stretchImage.yScale = self.yScaleOriginal * scale2
--						self.xScale = self.xScaleOriginal * scale
--						self.yScale = self.yScaleOriginal * scale
					end
				end
			else
				if self.touchX and self.touchY and zoom ~= 0 then
					local dx, dy = event.x - self.touchX, event.y - self.touchY
					--print(string.format('Moved %i x %i', dx, dy))
					--if math.abs(dx) > 10 or math.abs(dy) > 10 then
-- This returns the NW-corner of the square. Use the function with xtile+1 and/or ytile+1
-- to get the other corners. With xtile+0.5 & ytile+0.5 it will return the center of the tile. 
--local function osmTileLatLon(xTile, yTile, zTile)	-- xTile, yTile, zoom -> lat, lon
--????? tileGroup.lat, tileGroup.lon = lat, lon
--stretchImage.latPerY = (latCenter-latNW)/128
--stretchImage.lonPerX = (lonCenter-lonNW)/128
						local newLat = tileGroup.lat-dy*self.latPerY
						local newLon = tileGroup.lon-dx*self.lonPerX
						if newLat < -85.0511 then newLat = -85.0511+self.latPerY*(tileSize/2) end
						if newLat > 85.0511 then newLat = 85.0511-self.latPerY*(tileSize/2) end
						if newLon < -180 then newLon = newLon + 360 end
						if newLon > 180 then newLon = newLon - 360 end
						osmTiles:moveTo(newLat, newLon)
						--stretchImage.x = stretchImage.x + dx
						--stretchImage.y = stretchImage.y + dy
						self.touchX = event.x
						self.touchY = event.y
					--end
				end
			end

			if not previousTouches[event.id] then
				self.numPreviousTouches = self.numPreviousTouches + 1
			end
			previousTouches[event.id] = event

		elseif "ended" == phase or "cancelled" == phase then
			if previousTouches[event.id] then
				self.numPreviousTouches = self.numPreviousTouches - 1
				previousTouches[event.id] = nil
			end

			if ( #previousTouches > 0 ) then
				-- must be at least 2 touches remaining to pinch/zoom
				self.distance = nil
			else
				-- previousTouches is empty so no more fingers are touching the screen
				-- Allow touch events to be sent normally to the objects they "hit"
				display.getCurrentStage():setFocus( nil )

				self.isFocus = false
				self.distance = nil
				self.xScaleOriginal = nil
				self.yScaleOriginal = nil
				if stretchImage then
					stretchImage:removeSelf()
					stretchImage = nil
				end
				if self.newZoom and self.newZoom ~= self.originalZoom then
					osmTiles:zoomTo(self.newZoom)
				end
				self.originalZoom = nil
				self.newZoom = nil
				--[[if debuggingText then
					debugText:removeSelf()
					debugText = nil
				end]]

				-- reset array
				self.previousTouches = nil
				self.numPreviousTouches = nil
			end
		end
	end

	return result
end









local function displayTileFailed(n,what)
	if n >= 1 and n <= #tileGroup.tiles then
		what = what or "\nFAIL"
		tileGroup.tiles[n]:removeChildAt(1)
		if tileGroup.tiles[n]:getChildAt(1) or tileGroup.tiles[n]:getNumChildren() > 0 then
			print('displayTileFailed['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' ORPHAN!  from '..tileGroup.tiles[n].from)
		end

		local image = TextLabel { text=what, textSize=62 }
		image:fitSize()
		image:setColor( 1.0,0.0,0.0,1.0)
		image:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		image:setRect(-(tileSize/2), -(tileSize/2), (tileSize/2), (tileSize/2))
		--image:setColor( 0.5,0.5,0.5,0.5 )
	--	image:setLoc(tileSize/2,tileSize/2);
		image:setLoc(tileSize/2/tileScale, tileSize/2)
		tileGroup.tiles[n]:addChild(image)
		if tileGroup.tiles[n]:getNumChildren() > 1 then
			print('displayTileFailed['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' EXTRA!  from '..tileGroup.tiles[n].from)
		end
		tileGroup.tiles[n].from = 'displayTileFailed'
		--tileGroup.tile = image
if debugging then print(string.format("displayTileFailed:[%d]<-%d,%d,%d", n, -1,-1,-1)) end
		tileGroup.tiles[n].xTile, tileGroup.tiles[n].yTile, tileGroup.tiles[n].zTile = -1, -1, -1

		--if tapTimer then tileGroup.zoomGroup.alpha = 0.75 end	-- Allow zooming again
		--tileGroup.tiles[n][1].alpha = tileAlpha
	end
end

local function displayGrayTile(n, temp)
	if n >= 1 and n <= #tileGroup.tiles then
		if not temp then
			displayTileFailed(n,"\nGray")
		else
			tileGroup.tiles[n]:removeChildAt(1)
			if tileGroup.tiles[n]:getChildAt(1) or tileGroup.tiles[n]:getNumChildren() > 0 then
				print('displayGrayTile['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' ORPHAN!  from '..tileGroup.tiles[n].from)
			end
			--print("GrayTile["..n.."]")
			local image = display.newRect(0,0,tileSize,tileSize)
			image:setFillColor(128,128,128)
	--		image.x = tileSize/2
	--		image.y = tileSize/2
			image.x, image.y = tileSize/2/tileScale, tileSize/2
			tileGroup.tiles[n]:addChild(image)
			if tileGroup.tiles[n]:getNumChildren() > 1 then
				print('displayGrayTile['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' EXTRA!  from '..tileGroup.tiles[n].from)
			end
			tileGroup.tiles[n].from = 'displayGrayTile'
			if not temp then
				tileGroup.tiles[n].xTile, tileGroup.tiles[n].yTile, tileGroup.tiles[n].zTile = -1, -1, -1
if debugging then print(string.format("displayGrayTile:[%d]<-%d,%d,%d", n, -1,-1,-1)) end
			end
		end
	end
end

local function displayBusyTile(n, x, y, z)
	if n >= 1 and n <= #tileGroup.tiles then
		tileGroup.tiles[n]:removeChildAt(1)
		if tileGroup.tiles[n]:getChildAt(1) or tileGroup.tiles[n]:getNumChildren() > 0 then
			print('displayBusyTile['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' ORPHAN!  from '..tileGroup.tiles[n].from)
		end
		
		--print("BusyTile["..n.."]")
		local group = Group({left=1,top=1})	-- Need non-zero Left/Top to work
		group:setPos(0,0)	-- Don't ask me why it can't be initialized in Group()

	--[[
		local spinner = widget.newSpinner( {left=0, top=0})
		spinner.x = 256/2
		spinner.y = 256/2
		spinner:start()
		group:addChild(spinner)
	]]
	--[[
		displayTileFailed(n,"*BUSY*")	-- Temporary Spinner replacement
		tileGroup.tiles[n].xTile, tileGroup.tiles[n].yTile, tileGroup.tiles[n].zTile = x, y, z
		local busyText = tileGroup.tiles[n]:getChildAt(1)
		tileGroup.tiles[n]:removeChild(busyText)
		group:addChild(busyText)
	]]

		local text = TextLabel { text = tostring(z)..'\n'..tostring(x)..'\n'..tostring(y), textSize=62 }
		text:fitSize()
		text:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		text:setRect(-tileSize/2, -tileSize/2, tileSize/2, tileSize/2)
		text:setColor( 0.5,0.5,0.5,1.0)
		--text:setLoc(256-text:getWidth()/2, 256/2)
	--	text:setLoc(tileSize/2, tileSize/2)
		text:setLoc(tileSize/2/tileScale, tileSize/2)
		group:addChild(text)

		tileGroup.tiles[n]:addChild(group)

		if tileGroup.tiles[n]:getNumChildren() > 1 then
			print('displayBusyTile['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' EXTRA!  from '..tileGroup.tiles[n].from)
		end
		tileGroup.tiles[n].from = 'displayBusyTile'
	end
end




--local offscreenSymbols = display.newGroup()
--offscreenSymbols.alpha = 0
--local deletedSymbols = display.newGroup()
--deletedSymbols.alpha = 0

local allSymbols = {}
local activeTracks = {}
local trackGroup = Group()
tileGroup:addChild(trackGroup)

local activePolys = {}
local polyGroup = Group()
tileGroup:addChild(polyGroup)

local symbolGroup = Group()
symbolGroup.groupCount = 0
tileGroup:addChild(symbolGroup)

local labelGroup = Group()
local labelAlpha = 1.0 -- 0.7 -- 0.8
labelGroup:setColor(labelAlpha,labelAlpha,labelAlpha,labelAlpha)
tileGroup:addChild(labelGroup)
labelGroup.visible = true

function osmTiles:getGroupCounts()
	return symbolGroup:getNumChildren(), labelGroup:getNumChildren(), trackGroup:getNumChildren(), polyGroup:getNumChildren()
end

function osmTiles:showLabels(onOff)
	if type(onOff) == 'nil' then onOff = true end
	labelGroup.visible = onOff
	if labelGroup.visible then
		if symbolGroup.groupCount < MaxSymbols / 2 then
			tileGroup:addChild(labelGroup)
		end
	else tileGroup:removeChild(labelGroup)
	end
end

local function wrapX(x, xo)
	if tileGroup.wrapped and xo then
		local tile = tileGroup.tiles[1]	-- First tile is at center
		local dx = x+xo-tile.x-(tileSize/2)
		local zd = zoomDelta	-- Pixels to the "other side"
		local mabs = math.abs
		if dx < 0 then
			local tx = dx + zd
			if mabs(tx) < mabs(dx) then x = x+zd end
		else
			local tx = dx - zd
			if mabs(tx) < mabs(dx) then x = x-zd end
		end
	end
	return x
end

local function clearTrack(track)
	if track.lineBackground then
		if not trackGroup:removeChild(track.lineBackground) then
			print('Failed to remove trackLineBackground from trackGroup!')
		end
		track.lineBackground:dispose()
		track.lineBackground = nil
	end
	if track.line then
		if not trackGroup:removeChild(track.line) then
			print('Failed to remove trackLine from trackGroup!')
		end
		track.line:dispose()
		track.line = nil
	end
	if track.dots then
		if not trackGroup:removeChild(track.dots) then
			print('Failed to remove trackDots from trackGroup!')
		end
		track.dots:dispose()
		track.dots = nil
	end
	track.points = nil
end

function osmTiles:removeTrack(track)
	if track then
		clearTrack(track)
		if track.activeIndex then
			local index = track.activeIndex
			track.activeIndex = nil	-- make sure it remembers it's gone!
			local lastIndex = #activeTracks
			if index ~= lastIndex then
				activeTracks[index] = activeTracks[lastIndex]
				activeTracks[index].activeIndex = index	-- record the new index
			end
			activeTracks[lastIndex] = nil
		end
	end
end

local function fixupTrack(track, zoomed, stationID)
	stationID = stationID or track.stationID
	track.stationID = stationID
	stationID = stationID or "*unknown*"
	zoomed = zoomed or false
	if track then
		if zoomed
		or ((not track.showDots) and track.dots) then
			--print(stationID..' Clearing track')
			clearTrack(track)
		end
		if not track.points  then
			track.points = {}
		end	-- list of x,y for drawing
		local points = track.points
		local ref = track[#track]
		local lastx, lasty = -1, -1
		local mabs = math.abs
		local lineWidth, dotSize = 4, 7
		local oldest = os.time() - (60*60)	-- Only 1 hour
		for i=#track,1,-1 do
			local p = track[i]
			if p.when < oldest and not track.showDots then break end	-- shorten the tracks to one hour
			if not p.x20 or not p.y20 then
				p.x20, p.y20 = osmTileNum(p.lat, p.lon, 20)
				if p.lat == 0 and p.lon == 0 then
					local text = stationID..":track["..i.."] lat/lon:"..p.lat.."/"..p.lon.." at "..p.x20..","..p.y20
					toast.new(text)
				end
				if not p.x20 or not p.y20 then
					print("osmTiles:fixupTrack:"..stationID.."["..i.."] out of range, lat:"..p.lat.." lon:"..p.lon)
				end
			end
			p.x, p.y = wrapX(p.x20*zoomDiv,trackGroup.x), p.y20*zoomDiv
			if #points > 0 and mabs(p.x-lastx) > zoomDelta/2 then
				--print(string.format('%s:Truncating screen-crossing track dx:%i > %i @ %i/%i',
				--					tostring(stationID), mabs(p.x-lastx), zoomDelta/2, #track-i, #track))
				break	-- I really want to just split the lines, but not yet!
			end
			if #points == 0 or mabs(p.x-lastx) > lineWidth or mabs(p.y-lasty) > lineWidth then
				lastx, lasty = p.x, p.y
				if #points == 0 then
					track.minX, track.minY, track.maxX, track.maxY = p.x, p.y, p.x, p.y
				else
					if p.x < track.minX then track.minX = p.x end
					if p.x > track.maxX then track.maxX = p.x end
					if p.y < track.minY then track.minY = p.y end
					if p.y > track.maxY then track.maxY = p.y end
				end
				points[#points+1] = p.x
				points[#points+1] = p.y
				if #points >= 2048 then break end	-- Truncate to avoid drawLine exit
			end
		end

		if #points >= 4 then
--local text = "fixupTrack:showing "..(#points/2).." points for "..stationID.." min:"..track.minX..","..track.minY.." max:"..track.maxX..","..track.maxY
--print(text)
			for i=1,#points,2 do
				points[i] = points[i] - track.minX
				points[i+1] = points[i+1] - track.minY
			end
			local tw, th = track.maxX-track.minX, track.maxY-track.minY
			if track.showDots then	-- add a line background to highlight it
				track.lineBackground = Graphics { left=track.minX, top=track.minY, width=tw+2, height=th+2 }
				track.lineBackground:setPenColor(0,0,0,1):setPenWidth(lineWidth+2):drawLine(track.points)
				track.lineBackground:setPriority(1888886)
				trackGroup:addChild(track.lineBackground)
			end
			local myWidth = lineWidth
			if track.showDots then myWidth = math.max(math.floor((lineWidth+2)/2),2) end
			track.line = Graphics { left=track.minX, top=track.minY, width=tw+2, height=th+2 }
			track.line:setPenColor(track.color[1]/255,track.color[2]/255,track.color[3]/255,1):setPenWidth(myWidth):drawLine(track.points)
			track.line:setPriority(1888887)
			trackGroup:addChild(track.line)
			if Application:isDesktop() then
				if track.showDots and dotSize > lineWidth then
					track.dots = Graphics { left=track.minX, top=track.minY, width=tw+2, height=th+2 }
					track.dots:setPenColor(track.color[1]/255,track.color[2]/255,track.color[3]/255,1):setPointSize(dotSize):drawPoints(track.points)
					track.dots:setPriority(1888888)
					trackGroup:addChild(track.dots)
				end
			end
--print('osmTiles:fixupTrack:'..tostring(track.stationID)..':'..tostring(track)..' size:'..tw..'x'..th..' at '..ref.x..','..ref.y)
--print('osmTiles:fixupTrack:'..tostring(track.stationID)..':'..tostring(track)..':Background:'..tostring(track.lineBackground)..' line:'..tostring(track.line)..' dots:'..tostring(track.dots))
		end
	end
end

function osmTiles:showTrack(track, showDots, stationID)
--[[
	if true then
		if type(track) == 'table' then
			print(stationID..":NOT showing Track, "..tostring(#track).." points")
		else
			print(stationID..":NOT showing NIL Track")
		end
		return
	end
]]
	if type(track) == 'table' then
		if not track.activeIndex then
			track.activeIndex = #activeTracks + 1
			activeTracks[track.activeIndex] = track
			if not track.color then
				track.color = colors:getRandomTrackColorArray()
			end
			--print(string.format('showTrack:%d %s Tracks defined', #activeTracks, colors:getColorName(track.color)))
		end
		track.stationID = stationID
		track.showDots = showDots or nil	-- temporarily force it on for testing -- false becomes nil
		fixupTrack(track, true, stationID)	-- Not sure why I have to force a full line rebuild...
	end
end

local function clearPoly(polygon)
	if polygon.line then
		if not polyGroup:removeChild(polygon.line) then
			print('Failed to remove polyLine from polyGroup!')
		end
		polygon.line:dispose()
		polygon.line = nil
	end
	if polygon.arrows then
		for i, a in pairs(polygon.arrows) do
			if not polyGroup:removeChild(a) then
				print('Failed to remove arrow from polyGorup!')
			end
			a:dispose()
		end
		polygon.arrows = nil
	end
	polygon.points = nil
end

local function isPointOnScreen(x20, y20)
		return x20 >= tileGroup.minX20
		and x20 < tileGroup.maxX20
		and y20 >= tileGroup.minY20
		and y20 < tileGroup.maxY20
end

local function fixupPoly(polygon, stationID)
	stationID = stationID or polygon.stationID
	polygon.stationID = stationID
	stationID = stationID or "*unknown*"
	if polygon then
local tstart, telapsed
tstart = MOAISim.getDeviceTime()
		clearPoly(polygon)
		if not polygon.points then
			polygon.points = {}
		end	-- list of x,y for drawing
		local points = polygon.points
		local ref = { lat=polygon[1], long=polygon[2] }
		local lastx, lasty = -1, -1
		local mabs = math.abs
		local lineWidth = polygon.lineWidth or 1
		local width, height = tileGroup.width, tileGroup.height
		local minDim = math.min(width, height)
		local arrows = nil
		for i=1,#polygon,2 do
			local x20, y20 = osmTileNum(polygon[i], polygon[i+1], 20)
			if not x20 or not y20 then
				print("osmTiles:fixupPoly:"..stationID.."["..i.."] out of range, lat:"..polygon[i].." lon:"..polygon[i+1])
			--else print("osmTiles:fixupPoly:"..stationID.."["..i.."] lat:"..polygon[i].." lon:"..polygon[i+1].." x,y:"..x20..","..y20)
			end
			local x, y = wrapX(x20*zoomDiv,polyGroup.x), y20*zoomDiv
			if #points == 0 or mabs(x-lastx) > lineWidth or mabs(y-lasty) > lineWidth then
				if #points > 0 and mabs(x-lastx) > zoomDelta/2 then	-- Skip screen-crossing points
					-- I'd really like to split into two lines, but not yet!
				else
					if #points == 0 then
						polygon.minX, polygon.minY, polygon.maxX, polygon.maxY = x, y, x, y
					else

						if x < polygon.minX then polygon.minX = x end
						if x > polygon.maxX then polygon.maxX = x end
						if y < polygon.minY then polygon.minY = y end
						if y > polygon.maxY then polygon.maxY = y end
						
						local dx, dy = x-lastx, y-lasty
						local length = math.sqrt(dx*dx+dy*dy)
						if length > minDim/4 and polygon.showArrows then	-- Long enough for an arrow
	--						print("Need Arrow at "..tostring(lastx)..","..tostring(lasty).." to "..tostring(x)..","..tostring(y))
							if not arrows then arrows = {} end
							table.insert(arrows, {fromx=lastx, fromy=lasty, tox=x, toy=y})
						end
					end
					points[#points+1] = x
					points[#points+1] = y
					if #points >= 2048 then break end	-- Truncate to avoid drawLine exit
					lastx, lasty = x, y
				end
			end
		end
		if #points >= 4 then
--print('fixupPoly:'..stationID..' '..#points..'/'..#polygon)
			for i=1,#points,2 do
				points[i] = points[i] - polygon.minX
				points[i+1] = points[i+1] - polygon.minY
			end
			local tw, th = polygon.maxX-polygon.minX, polygon.maxY-polygon.minY
			local myWidth = lineWidth
			local alpha = 1.0
			if type(polygon.alpha) == 'string' then
				alpha = config[polygon.alpha] / 100	-- configs are in percent
			elseif type(polygon.alpha) == 'number' then
				alpha = polygon.alpha
			end
			local linealpha = alpha
			if polygon.filled then linealpha = 1 end
			polygon.line = Graphics { left=polygon.minX, top=polygon.minY, width=tw+2, height=th+2 }
			polygon.line:setColor(polygon.color[1]/255,polygon.color[2]/255,polygon.color[3]/255, linealpha)
			polygon.line:setPenWidth(myWidth)
			polygon.line:drawLine(polygon.points)
			if polygon.filled then
				polygon.line:setPenColor(polygon.color[1]/255*alpha,polygon.color[2]/255*alpha,polygon.color[3]/255*alpha,alpha):setPenWidth(myWidth):fillFan(polygon.points)
			end
			polygon.line:setPriority(1888887)
			polyGroup:addChild(polygon.line)
			
			if arrows then
				for i,t in pairs(arrows) do
					local dx, dy = t.tox-t.fromx, t.toy-t.fromy
					local atx, aty = t.fromx+dx/4, t.fromy+dy/4
					local ttx, tty = atx/zoomDiv, aty/zoomDiv
					local visible = (ttx >= tileGroup.minX20 and ttx <= tileGroup.maxX20
								and tty >= tileGroup.minY20 and tty <= tileGroup.maxY20)
--print(string.format("Arrow at %d %d or %d %d Tile %d->%d %d->%d %s",
--					atx, aty, atx/zoomDiv, aty/zoomDiv,
--					tileGroup.minX20, tileGroup.maxX20, tileGroup.minY20, tileGroup.maxY20,
--					visible and "visible" or "off-screen"))
					if visible then
						local a = math.atan2(dx, dy) - math.pi/2
						--a = 3*math.pi/4
						local s = config.Screen.scale * 4
						local arrowpoints = {}
						local function addPoint(x,y)
							local x1 = x*math.cos(a)+y*math.sin(a)
							local y1 = y*math.cos(a)-x*math.sin(a)
							table.insert(arrowpoints,atx-polygon.minX+x1*s)
							table.insert(arrowpoints,aty-polygon.minY+y1*s)
						end
						addPoint(-14,6) addPoint(0,0) addPoint(-14,-6) -- addPoint(4,0) addPoint(12,0)

						local arrow = Graphics { left=polygon.minX, top=polygon.minY, width=tw+2, height=th+2 }
						arrow:setColor(polygon.color[1]/255,polygon.color[2]/255,polygon.color[3]/255, linealpha*3/4)
						arrow:setPenWidth(math.max(myWidth/2,1))
						arrow:drawLine(arrowpoints)
		--[[			if polygon.filled then
				polygon.line:setPenColor(polygon.color[1]/255*alpha,polygon.color[2]/255*alpha,polygon.color[3]/255*alpha,alpha):setPenWidth(myWidth):fillFan(polygon.points)
			end]]
						arrow:setPriority(1888889)
						if not polygon.arrows then polygon.arrows = {} end
						table.insert(polygon.arrows, arrow)
						polyGroup:addChild(arrow)
					end
				end
			end
		end
telapsed = (MOAISim.getDeviceTime()-tstart)*1000
if telapsed > 10 then
	local pCount, aCount
	if points then pCount = #points else pCount = 0 end
	if arrows then aCount = #arrows else aCount = 0 end
	print("osmTiles:fixupPoly("..tostring(stationID)..") "..tostring(pCount).."/"..tostring(aCount).." points/arrows Took "..telapsed.."ms")
end
	end
end

function osmTiles:showPolygon(polygon, stationID)
--[[
	if true then
		if type(track) == 'table' then
			print(stationID..":NOT showing Track, "..tostring(#track).." points")
		else
			print(stationID..":NOT showing NIL Track")
		end
		return
	end
]]
--	print("showPolygon:"..tostring(stationID))
	if type(polygon) == 'table' then
		if not polygon.activeIndex then
			polygon.activeIndex = #activePolys + 1
			activePolys[polygon.activeIndex] = polygon
			if not polygon.color then
				polygon.color = colors:getRandomTrackColorArray()
			end
			if not polygon.alpha then polygon.alpha = 0.5 end
		end
		polygon.stationID = stationID
		fixupPoly(polygon, stationID)
	end
end

function osmTiles:removePolygon(polygon)
	if polygon then
		clearPoly(polygon)
		if polygon.activeIndex then
			local index = polygon.activeIndex
			polygon.activeIndex = nil	-- make sure it remembers it's gone!
			local lastIndex = #activePolys
			if index ~= lastIndex then
				activePolys[index] = activePolys[lastIndex]
				activePolys[index].activeIndex = index	-- record the new index
			end
			activePolys[lastIndex] = nil
		end
	end
end

function osmTiles:translateXY(x, y)	-- returns x,y translated from map to screen coords
	local tile = tileGroup.tiles[1]	-- First tile is at center
	local xo, yo = -tile.xTile*tileSize, -tile.yTile*tileSize
	local xl = xo+tile.x+tileGroup.tilesGroup.xOffset
	local yl = yo+tile.y+tileGroup.tilesGroup.yOffset
	return x+xl, y+yl
end

function osmTiles:whereIS(lat, lon)	-- returns x,y on screen or nil, nil if not visible
	local x20, y20 = osmTileNum(lat, lon, 20)
	local x, y = wrapX(x20*zoomDiv,trackGroup.x), y20*zoomDiv
	return x, y
end


local log2 = math.log(2)
local function getSymbolScale()
	local horzScale, vertScale = osmTiles:rangeLatLon()
	local scale = math.max(horzScale, vertScale)

	if (config.Screen.SymbolSizeAdjust ~= 0) then
		scale = scale / 2.0^config.Screen.SymbolSizeAdjust
	end

	-- 1.375 - log2(x) / 8  per Mykle N7JZT 
	local scale2 = math.log(scale)/log2	-- Log base 2
	local result2 = 1.375 - scale2/8
	result2 = math.min(2,math.max(0.5,result2))	-- Never >2x or smaller than x/2
	return result2
end

local function showSymbol(symbol)
	if not symbol.inGroup then
		symbolGroup.groupCount = symbolGroup.groupCount + 1
		symbolGroup:addChild(symbol.symbol)
		symbol.inGroup = true
	end
	if symbol.label and not symbol.label.inGroup then
		labelGroup:addChild(symbol.label)
		symbol.label.inGroup = true
	end
end

local function hideSymbol(symbol)
	if symbol.inGroup then
		symbolGroup.groupCount = symbolGroup.groupCount - 1
		if not symbolGroup:removeChild(symbol.symbol) then
			local text = 'osmTiles:hideSymbol:symbol('..type(symbol.symbol)..') NOT removed from symbolGroup!'
			print('******************* '..text)
			toast.new(text)
		end
		symbol.inGroup = false
	end
	if symbol.label and symbol.label.inGroup then
		if not labelGroup:removeChild(symbol.label) then
			local text = 'osmTiles:hideSymbol:label('..type(symbol.label)..') NOT removed from labelGroup!'
			print('******************* '..text)
			toast.new(text)
		end
		symbol.label.inGroup = false
	end
end

local function fixupSymbol(symbolLabel, scale)
--	print("fixupSymbol:"..symbolLabel.stationID)

	showSymbol(symbolLabel)

	if not scale then scale = getSymbolScale() end
--print("Symbol scale:"..tostring(scale).." individual "..tostring(symbolLabel.symbol.scale))
	if type(symbolLabel.symbol.scale) == 'nil' then symbolLabel.symbol.scale = 1.0 end
	symbolLabel.x, symbolLabel.y = wrapX(symbolLabel.x20*zoomDiv, symbolGroup.x), symbolLabel.y20*zoomDiv
	symbolLabel.symbol:setLoc(symbolLabel.x, symbolLabel.y)
	symbolLabel.symbol:setScl(scale*symbolLabel.symbol.scale, scale*symbolLabel.symbol.scale, 1.0)
--if shouldIShowIt(symbolLabel.stationID) then print("osmTiles:getsymbolLabel:"..symbolLabel.stationID.." size "..symbolLabel:getWidth().."x"..symbolLabel:getHeight().." scale:"..scale) end
	if symbolLabel.label then
		--symbolLabel.label:setRect(0, 0, TextLabel.MAX_FIT_WIDTH, TextLabel.MAX_FIT_HEIGHT)
		--symbolLabel.label:setTextSize(math.floor(symbolLabel.label.orgTextSize*scale))
		--symbolLabel.label:fitSize()
		symbolLabel.label:setLoc(symbolLabel.x+symbolLabel.label.xOffset*scale, symbolLabel.y)
		symbolLabel.label:setScl(scale, scale, 1.0)
	end
end

local function isSymbolVisible(symbol)
		return symbol.x20 >= tileGroup.minX20
		and symbol.x20 < tileGroup.maxX20
		and symbol.y20 >= tileGroup.minY20
		and symbol.y20 < tileGroup.maxY20
end

local function fixupSymbols(why, forceit)
--print("fixupSymbols("..tostring(why)..")")
	local start = MOAISim.getDeviceTime()
	local tile = tileGroup.tiles[1]	-- First tile is at center
	local xo, yo = -tile.xTile*tileSize, -tile.yTile*tileSize
	local xl = xo+tile.x+tileGroup.tilesGroup.xOffset
	local yl = yo+tile.y+tileGroup.tilesGroup.yOffset
	
	if not symbolGroup.offsetVersion
	or symbolGroup.offsetVersion ~= tileGroup.offsetVersion
	or forceit then

	if not labelGroup.x
	or math.abs(labelGroup.x-xl) > 0.5
	or math.abs(labelGroup.y-yl) > 0.5 then
	else print('osmTiles:fixupSymbols:'..tostring(why)..':NOT moving('..string.format("%.2f %.2f", labelGroup.x-xl, labelGroup.y-yl)..') '..#allSymbols..' symbols and '..#activeTracks..' tracks took '..((MOAISim.getDeviceTime()-start)*1000)..'ms **************************************************')
	end
	
	symbolGroup.offsetVersion = tileGroup.offsetVersion

	labelGroup.x, labelGroup.y = xl, yl
	labelGroup:setLoc(labelGroup.x, labelGroup.y)
	symbolGroup.x, symbolGroup.y = xl, yl
	symbolGroup:setLoc(symbolGroup.x, symbolGroup.y)
	trackGroup.x, trackGroup.y = xl, yl
	trackGroup:setLoc(trackGroup.x, trackGroup.y)
	polyGroup.x, polyGroup.y = xl, yl
	polyGroup:setLoc(polyGroup.x, polyGroup.y)
	
	if tileGroup.wrapped
	or forceit
	or not symbolGroup.tileVersion
	or not symbolGroup.sizeVersion 
	or symbolGroup.tileVersion ~= tileGroup.tileVersion
	or symbolGroup.sizeVersion ~= tileGroup.sizeVersion then

		symbolGroup.tileVersion = tileGroup.tileVersion
		symbolGroup.sizeVersion = tileGroup.sizeVersion

local tstart, telapsed
tstart = MOAISim.getDeviceTime()
		for n = 1, #activeTracks do
			fixupTrack(activeTracks[n], true)
		end
telapsed = (MOAISim.getDeviceTime()-tstart)*1000
if telapsed > 10 then print("osmTiles:fixupSymbols:fixupTracks("..tostring(#activeTracks)..") Took "..telapsed.."ms") end
tstart = MOAISim.getDeviceTime()
		for n = 1, #activePolys do
			fixupPoly(activePolys[n])
		end
telapsed = (MOAISim.getDeviceTime()-tstart)*1000
if telapsed > 10 then print("osmTiles:fixupSymbols:fixupPolys("..tostring(#activePolys)..") Took "..telapsed.."ms") end
tstart = MOAISim.getDeviceTime()
		local offScreen, onScreen = 0, 0
		local scale = getSymbolScale()
		for n = 1, #allSymbols do
			local symbol = allSymbols[n]
			if isSymbolVisible(symbol) then
				if symbol.inGroup or symbolGroup.groupCount < MaxSymbols then
					fixupSymbol(symbol, scale)
				else hideSymbol(symbol)
				end
				onScreen = onScreen + 1
			else
				hideSymbol(symbol)
				offScreen = offScreen + 1
			end
		end
		if labelGroup.visible then
			if symbolGroup.groupCount < MaxSymbols / 2 then
				tileGroup:addChild(labelGroup)
			else tileGroup:removeChild(labelGroup)
			end
		end
local elapsed = (MOAISim.getDeviceTime()-start)*1000
if elapsed > 10 then print('osmTiles:fixupSymbols:'..tostring(why)..':fixing '..#allSymbols..' symbols (on/off:'..onScreen..'/'..offScreen..')(group:'..tostring(symbolGroup.groupCount)..'?'..tostring(symbolGroup:getNumChildren())..') and '..#activeTracks..' tracks took '..elapsed..'ms zoom:'..zoom) end
	else
local elapsed = (MOAISim.getDeviceTime()-start)*1000
if elapsed > 10 then print('osmTiles:fixupSymbols:'..tostring(why)..':NOT fixing '..#allSymbols..' symbols and '..#activeTracks..' tracks took '..elapsed..'ms') end
--print(string.format("fixupSymbols:%s %s %d %d %d %d", (tileGroup.wrapped and "WRAPPED" or ""), (forceit and "FORCE " or ""),symbolGroup.tileVersion, tileGroup.tileVersion, symbolGroup.sizeVersion, tileGroup.sizeVersion))
	end	-- tile/sizeVersion
--else print(string.format("fixupSymbols:%s%d %d", (forceit and "FORCE " or ""), symbolGroup.offsetVersion, tileGroup.offsetVersion))
	end	-- offsetVersion
--[[
print(string.format('symbolGroup: @ %i,%i Tile %i,%i @ %i,%i Offset %i %i',
					symbolGroup.x, symbolGroup.y,
					tile.xTile, tile.yTile,
					tile.x, tile.y,
					tileGroup.tilesGroup.xOffset, tileGroup.tilesGroup.yOffset))
]]
--	if tileGroup:getChildAt(tileGroup:getNumChildren()) ~= symbolGroup then
--		print(string.format('tileGroup[%i]=%s symbols:%s', tileGroup:getNumChildren(), tostring(tileGroup:getChildAt(tileGroup:getNumChildren())), tostring(symbolGroup)))
--		tileGroup:addChild(trackGroup)
--		tileGroup:addChild(symbolGroup)
--		print(string.format('tileGroup[%i]=%s symbols:%s', tileGroup:getNumChildren(), tostring(tileGroup:getChildAt(tileGroup:getNumChildren())), tostring(symbolGroup)))
--	end
end

function osmTiles:refreshMap()
	fixupSymbols("refreshMap", true)
	invokeCallbacks('refresh')
end

function osmTiles:removeSymbol(symbolLabel)	-- caller must nil out reference!

	hideSymbol(symbolLabel)

	if symbolLabel.allIndex then
		local index = symbolLabel.allIndex
		symbolLabel.allIndex = nil	-- make sure it remembers it's gone!
		local lastIndex = #allSymbols
		if index ~= lastIndex then
			allSymbols[index] = allSymbols[lastIndex]
			allSymbols[index].allIndex = index	-- record the new index
		end
		allSymbols[lastIndex] = nil
		-- print('Removing allSymbols['..index..'] leaves '..#allSymbols..' (was '..lastIndex..')')
	end
end

function osmTiles:showSymbol(lat, lon, symbolLabel, stationID)

	if not symbolLabel then
		local info = debug.getinfo( 2, "Sl" )
		local where = info.source..':'..info.currentline
		if where:sub(1,1) == '@' then where = where:sub(2) end
		print("Attempt to show nil symbolLabel from "..where)
		return
	end
	
	symbolLabel.stationID = stationID
	
	local x20, y20 = osmTileNum(lat, lon, 20)
	if not x20 or not y20 then
		print('osmTiles:showSymbol:Invalid Lat=%.5f Lon=%.5f, relocated to 0,0', lat, lon)
		x20, y20 = osmTileNum(0, 0, 20)
	end

	if not symbolLabel.allIndex then
		symbolLabel.allIndex = #allSymbols+1
		symbolLabel.stationID = stationID
		allSymbols[symbolLabel.allIndex] = symbolLabel
		--print(symbolLabel.allIndex..' symbols defined')
	elseif allSymbols[symbolLabel.allIndex] ~= symbolLabel then
		text = 'allSymbols['..tostring(symbolLabel.allIndex)..'] for '..tostring(allSymbols[symbolLabel.allIndex].stationID)..' not '..tostring(stationID)
		toast.new(text)
		print('******************* allSymbols['..tostring(symbolLabel.allIndex)..'] is '..tostring(allSymbols[symbolLabel.allIndex])..' for '..tostring(allSymbols[symbolLabel.allIndex].stationID)..' not '..tostring(symbolLabel)..' for '..tostring(stationID))
	end
	symbolLabel.lat, symbolLabel.lon = lat, lon
	symbolLabel.x20, symbolLabel.y20 = x20, y20
--print(string.format('symbolLabel:%s %i @ %i,%i', tostring(symbolLabel), 20, symbolLabel.x20, symbolLabel.y20))

	--if not shouldIShowIt(stationID) then return end

	if isSymbolVisible(symbolLabel) then
		if symbolLabel.inGroup or symbolGroup.groupCount < MaxSymbols then
			fixupSymbol(symbolLabel)
			if labelGroup.visible then
				if symbolGroup.groupCount < MaxSymbols / 2 then
					tileGroup:addChild(labelGroup)
				else tileGroup:removeChild(labelGroup)
				end
			end
		end
	end
end

function osmTiles:showAll()
	if #allSymbols > 0 then
		local minx, miny, maxx, maxy
		minx, miny = allSymbols[1].x20, allSymbols[1].y20
		maxx, maxy = minx, miny

		for i, s in ipairs(allSymbols) do
			if s.x20 < minx then minx = s.x20 end
			if s.y20 < miny then miny = s.y20 end
			if s.x20 > maxx then maxx = s.x20 end
			if s.y20 > maxy then maxy = s.y20 end
		end
		local lat2, lon2 = osmTileLatLon((maxx+minx)/2,(maxy+miny)/2,20)
		local xs = (maxx - minx)
		local ys = (maxy - miny)
		local z = 20	-- zoom for xs/ys
		print("move starting with "..xs.."x"..ys.." at zoom 20")
		while xs > tileGroup.width or ys > tileGroup.height do
			z = z - 1
			xs = xs / 2
			ys = ys / 2
		end
		z = z - 8	-- Don't know WHY I need this!  (other than 2^8 = 256)
		print("moving to "..tostring(lat2).." "..tostring(lon2).." zoom "..z.." for "..xs..'x'..ys..' vs '..tileGroup.width.."x"..tileGroup.height)
		osmTiles:moveTo(lat2, lon2, z)
		print("moved to "..tostring(lat2).." "..tostring(lon2).." zoom "..z.." for "..xs..'x'..ys..' vs '..tileGroup.width.."x"..tileGroup.height)
	end
end

local function displayTileImage(n, image, x, y, z)
if debugging then print(string.format('displayTileImage:[%d] %d,%d,%d...', n, x, y, z)) end
	if image then
		tileGroup.tiles[n]:removeChildAt(1)
if tileGroup.tiles[n]:getChildAt(1) or tileGroup.tiles[n]:getNumChildren() > 0 then
	print('displayTileImage['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' ORPHAN!  from '..tileGroup.tiles[n].from)
	tileGroup.tiles[n]:removeChildren()
	print('displayTileImage['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' ORPHAN!  from '..tileGroup.tiles[n].from)
end
		tileGroup.tiles[n]:addChild(image)
if tileGroup.tiles[n]:getNumChildren() > 1 then
	print('displayTileImage['..n..'] '..tileGroup.tiles[n]:getNumChildren()..' EXTRA!  from '..tileGroup.tiles[n].from)
end
		tileGroup.tiles[n].from = 'displayTileImage'
--if debugging then print('displayTileImage:getWidth/Height') end
		image.x = image:getWidth()/2
		image.y = image:getHeight()/2
--if debugging then print('displayTileImage:gotWidth('..image.x..')/Height('..image.y..')') end

if debugging then print(string.format("displayTileImage:[%d]<-%d,%d,%d goodTile!", n, x, y, z)) end
		tileGroup.tiles[n].xTile, tileGroup.tiles[n].yTile, tileGroup.tiles[n].zTile = x, y, z
		tileGroup.tiles[n].goodTile = true
		
		--if tapTimer then tileGroup.zoomGroup.alpha = 0.75 end	-- Allow zooming again
		--tileGroup.tile.alpha = tileAlpha
		--fixupSymbols()
		--[[if tileGroup.symbolLabel then
			osmTiles:showSymbol(tileGroup.symbolLabel.lat, tileGroup.symbolLabel.lon, tileGroup.symbolLabel)
		end]]
	else
		print ('displayTileImage(NIL)!')
	end
if debugging then print('displayTileImage:Done') end
end

local function makeRequiredDirectory(file, dir)
	if file == '' then return nil end
	local path = string.match(file, "(.+)/.+")
	local fullpath = dir..'/'..path
	MOAIFileSystem.affirmPath(fullpath)
	return fullpath
end

local TileSets = {
	OSMTiles = { Name="OSMTiles", URLFormat="http://tile.openstreetmap.org/%z/%x/%y.png" },
	LynnsTiles = { Name="LynnsTiles", URLFormat="http://ldeffenb.dnsalias.net:6360/osm/%z/%x/%y.png" },
	LocalTiles = { Name="LynnsTiles", URLFormat="http://192.168.10.8:6360/osm/%z/%x/%y.png" },
	CTNPS = {Name='CT-NPS', URLFormat='http://s3-us-west-1.amazonaws.com/ctvisitor/nps/%z/%x/%y.png' },
	CTVisitor = {Name='CT-Visitor', URLFormat='http://s3-us-west-1.amazonaws.com/ctfun/visitor/%z/%x/%y.png' },
	CTTopo1545 = {Name='CT-Topo15-45', URLFormat='http://s3-us-west-1.amazonaws.com/ctfun/1930/%z/%x/%y.png' },
	}

local TileSet = TileSets.LynnsTiles --TileSets.CTNPS
--TileSet = TileSets.LocalTiles
--TileSet = TileSets.OSMTiles

local function osmTileDir()
	if config.Dir.Tiles ~= '' then return config.Dir.Tiles end
	return MOAIEnvironment.externalFilesDirectory or MOAIEnvironment.externalCacheDirectory or MOAIEnvironment.cacheDirectory or MOAIEnvironment.documentDirectory or "Cache/";
end

local function recurseDirCountSize(dir)
	local tCount, tSize = 0,0
	for file in lfs.dir(dir) do
		local mode = lfs.attributes(dir..'/'..file,"mode")
		if mode == 'directory' then
			if file ~= '.' and file ~= '..' then
				local count, size = recurseDirCountSize(dir..'/'..file)
				tCount = tCount + count
				tSize = tSize + size
			end
		elseif mode == 'file' then
			tCount = tCount + 1
			tSize = tSize + lfs.attributes(dir..'/'..file,"size")
		end
	end
	return tCount, tSize
end

local function summarizeTileSetUsage(root)
	local start = MOAISim.getDeviceTime()
	print("summarizeTileSetUsage("..tostring(root)..')')
	local count, size = recurseDirCountSize(root)
	local text = string.format('%i/%.1fMB (%ims)', count, size/1024/1024, (MOAISim.getDeviceTime()-start)*1000)
	print("summarizeTileSetUsage("..tostring(root)..') gives '..tostring(text))
	return text
end

local directoryInformed = false
local function summarizeTileUsage()
	dir = osmTileDir()..'/MapTiles'
	local tileSets = {}
	print('summaraizeTileUsage('..tostring(dir)..')')
	for file in lfs.dir(dir) do
		print('Checking '..file)
		local mode = lfs.attributes(dir..'/'..file,"mode")
		if mode == 'directory' then
			if file ~= '.' and file ~= '..' then
				tileSets[file] = file..':'..summarizeTileSetUsage(dir..'/'..file)
			end
		else print(tostring(file)..' mode is '..tostring(mode))
		end
	end

	local text = 'Tiles Stored In '..tostring(dir)
	for k,v in pairs(tileSets) do
		text = text..'\n'..v
	end
	toast.new(text)
end



local List = {}
function List.new ()
  return {first = 0, last = -1, count = 0, maxcount = 0, pushcount = 0, popcount = 0}
end

function List.getCount (list)
	return list.count
end

function List.pushleft (list, value)
  local first = list.first - 1
  list.first = first
  list[first] = value
  list.count = list.count + 1
  list.pushcount = list.pushcount + 1
  if list.count == 1 then list.maxcount = 1; list.pushcount = 1; list.popcount = 0 end
  if list.count > list.maxcount then list.maxcount = list.count end
end

function List.pushright (list, value)
  local last = list.last + 1
  list.last = last
  list[last] = value
  list.count = list.count + 1
  list.pushcount = list.pushcount + 1
  if list.count == 1 then list.maxcount = 1; list.pushcount = 1; list.popcount = 0 end
  if list.count > list.maxcount then list.maxcount = list.count end
end

function List.popleft (list)
  local first = list.first
  if first > list.last then error("list is empty") end
  local value = list[first]
  list[first] = nil        -- to allow garbage collection
  list.first = first + 1
  list.count = list.count - 1
  list.popcount = list.popcount + 1
  return value
end

function List.popright (list)
  local last = list.last
  if list.first > last then error("list is empty") end
  local value = list[last]
  list[last] = nil         -- to allow garbage collection
  list.last = last - 1
  list.count = list.count - 1
  list.popcount = list.popcount + 1
  return value
end





local luasql = require("luasql")

--[[
local function opendb(name, mode)
   local conn
   local env,err = luasql.sqlite3()
   if env then
      conn, err = env:connect(name, mode == "r" and "READONLY" or "")
      if conn then
         return env,conn
      end
      env:close()
   end
--   trace("Opening db failed",name,err)
   return nil,err
end
]]

--[[
[MOAI] 11:45:06 osmTiles:newMBTiles(D:/ldeffenb/Documents/MBTiles/ArcGISUSATopo.mbtiles) @osmTiles.lua:2046
osmTiles.lua:1931: LuaSQL: there are open cursors
stack traceback:
        [C] ?
        [C] in function 'close'
        osmTiles.lua:1931 in function 'closedb'
        osmTiles.lua:2056 in function 'newMBTiles'
        main.lua:683 in function 'action'
        myconfig.lua:111 in function 'fireActions'
        config_scene.lua:17 in function 'onStop'
        hp/display/Scene.lua:196 in function 'onStop'
        hp/manager/SceneManager.lua:294 in function 'closeScene'
        myconfig.lua:136 in function 'unconfigure'
        config_scene.lua:36 in function 'onKeyDown'
        hp/display/Scene.lua:234 in function 'onKeyDown'
        hp/manager/SceneManager.lua:84 in function 'callback'
        hp/event/EventListener.lua:28 in function 'call'
        hp/event/EventDispatcher.lua:107 in function 'dispatchEvent'
        hp/manager/InputManager.lua:130 in function <hp/manager/InputManager.lua:122>
]]

--[[
local function closedb(env,conn)
   if env then
      if conn then
		--MOAISim.forceGarbageCollection()	-- Try to force a cursor cleanup
        conn:close()
      end
      env:close()
   end
end
]]

function getMBTilesDirectory()

	if config.Dir.Tiles ~= '' then return config.Dir.Tiles..'/MBTiles/' end
	return (MOAIEnvironment.externalFilesDirectory or MOAIEnvironment.externalCacheDirectory or MOAIEnvironment.cacheDirectory or MOAIEnvironment.documentDirectory or "Cache/").."/MBTiles/";
--	return (MOAIEnvironment.externalFilesDirectory or MOAIEnvironment.documentDirectory or '/sdcard/'..MOAIEnvironment.appDisplayName)..'/MBTiles/'
end

local function EnsureMBTiles(MBTiles)
	local dir = getMBTilesDirectory()
	local fullpath = MOAIFileSystem.getAbsoluteFilePath(dir.."/"..MBTiles)
	if MOAIFileSystem.checkFileExists(fullpath) then
		print("sqlite:"..fullpath.." ALSO EXISTS!")
		MBTiles = fullpath
	elseif MOAIFileSystem.checkFileExists(MOAIFileSystem.getAbsoluteFilePath(MBTiles)) then
		print("sqlite:"..MOAIFileSystem.getAbsoluteFilePath(MBTiles).." EXISTS!")
		print("sqlite:"..fullpath.." NOT FOUND, attempting copy")
		if MOAIFileSystem.copy(MOAIFileSystem.getAbsoluteFilePath(MBTiles), fullpath) then
			print("sqlite:Copy succeeded!")
			MBTiles = fullpath
		else
			print("sqlite:Copy FAILED")
		end
	else print("sqlite:"..MBTiles.." NOT FOUND!")
	end
	return MBTiles
end

local function EnsureAllMBTiles()
	local files = MOAIFileSystem.listFiles(dir)
	if not files then files = {} end
	table.sort(files)
	for i, f in pairs(files) do
		if f:match("^.+%.mbtiles$") then
			EnsureMBTiles(f)
		end
	end
end



local MBTile = {}
MBTile.__index = MBTile

setmetatable(MBTile, {
  __call = function (cls, db, ...)
	if not cls.instances then cls.instances = {} end
	if cls.instances[db] then
		print("MBTile:Returning Existing Instance for "..db)
		return cls.instances[db]
	end
	print("MBTile:Making New Instance for "..db)
    local self = setmetatable({}, cls)
    cls.instances[db] = self:_init(db, ...)
    return cls.instances[db]
  end,
})

function MBTile:getMetaValue(key)
	local cur, err = self.conn:execute("select value from metadata where name='"..key.."'")
	if cur then
		local value = cur:fetch()	-- Get the actual value
		cur:close() -- already closed because all the result set was consumed (but this doesn't hurt)
		return value
	else print("sqlite:No "..key.." metadata in "..self.db.." err:"..tostring(err))
	end
	return nil
end

function MBTile:_init(db)
	local err
	self.db = db
	self.env, err = luasql.sqlite3()
	if not self.env then return nil, err end
	self.conn, err = self.env:connect(db, mode == "r" and "READONLY" or "")
	if not self.conn then
		self.env:close()
		return nil, err
	end

	print("sqlite:Got database connection to "..db)
	self.name = self:getMetaValue("name")
	if not self.name then
		self.conn:close()
		self.env:close()
		self.env, self.conn = nil, nil
		return nil, "Non-MBTiles Database"
	end
	self.URLFormat = self:getMetaValue("URLFormat")
	self.bounds = self:getMetaValue("bounds")
	if self.bounds then
		performWithDelay(1000, function()
			function mysplit(inputstr, sep)
					if sep == nil then
							sep = "%s"
					end
					local t={} ; i=1
					for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
							t[i] = str
							i = i + 1
					end
					return t
			end
			local b = mysplit(self.bounds,",")
			print(printableTable(db,b))
			if #b == 4 then	-- left, bottom, right, top
				self.min_lat = (b[2])
				self.max_lat = (b[4])
				self.min_lon = (b[1])
				self.max_lon = (b[3])
				print(string.format("Bounds(%s) are %s->%s %s->%s", db, self.min_lat, self.max_lat, self.min_lon, self.max_lon))


--[[
local function dumptrack(trkseg)
	if type(trkseg) == 'table' and type(trkseg.trkpt) == 'table' then
		print('New Track:')
		if #trkseg.trkpt > 0 then	-- More than one trkpt
			local points = {}
			for i, v in ipairs(trkseg.trkpt) do
				if v.lat and v.lon then
					points[#points+1] = tonumber(v.lat)
					points[#points+1] = tonumber(v.lon)
					--print("trkpt["..tostring(i).."] @ "..tostring(v.lat).." "..tostring(v.lon).." ele:"..tostring(v.ele))
				else print(printableTable("trkpt["..tostring(i).."]", v))
				end
			end
			return points
		else
			print("Single trkpt in ", printableTable("trkseg.trkpt",trkseg.trkpt))
		end
	else
		print("trkseg:"..tostring(trkseg))
		if type(trkseg) == 'table' then
			print(printableTable("trkseg",trkseg))
		end
	end
end
	
local function dumptracks(gpx, color, width, alpha, name)
	name = name or "GPX"
	local poly = nil
	if type(gpx) == 'table' and type(gpx.trk) == 'table' then
	print(printableTable("gpx.trk",gpx.trk))
	print("Has "..tostring(#gpx.trk).." Track(s)")
		if #gpx.trk > 0 then	-- More than one trk
			for i, v in ipairs(gpx.trk) do
				poly = dumptrack(v.trkseg)
				if poly then
					poly.name = name
					if color then poly.color = colors:getColorArray(color) else poly.color = colors:getColorArray("chocolate") end
					if width then poly.lineWidth = width else poly.lineWidth = 4 end
					if alpha then poly.alpha = alpha end
					poly.showArrows = true
					osmTiles:showPolygon(poly,name.."["..i.."]")
				end
			end
		elseif type(gpx.trk.trkseg) == 'table' then
			poly = dumptrack(gpx.trk.trkseg)
			if poly then
				poly.name = name
				if color then poly.color = colors:getColorArray(color) end
				if width then poly.lineWidth = width end
				if alpha then poly.alpha = alpha end
				poly.showArrows = true
				osmTiles:showPolygon(poly,name)
			end
		end
	end
	return poly
end
]]
				
				
				

			end
		end)
	end
--TileSet.Name = tostring(name)
--TileSet.URLFormat = URLFormat

	local start = MOAISim.getDeviceTime()
	local cur, err = self.conn:execute("SELECT zoom_level, count(*) as count, min(tile_column) as min_col, max(tile_column) as max_col, min(tile_row) as min_row, max(tile_row) as max_row from tiles group by zoom_level order by zoom_level")
	if cur then
		local row = cur:fetch({},"a")
		self.contents = {}
		while row do
			self.contents[row.zoom_level] = {count=row.count,
										max_y=(2^row.zoom_level)-row.min_row-1,
										min_y=(2^row.zoom_level)-row.max_row-1,
										min_x=row.min_col,
										max_x=row.max_col }
			print(string.format("sqlite:zoom:%i Count:%i Rows:%i-%i Cols:%i-%i",
								row.zoom_level, row.count,
								row.min_row, row.max_row,
								row.min_col, row.max_col))
			row = cur:fetch({},"a")
		end
		cur:close() -- already closed because all the result set was consumed	
		local elapsed = (MOAISim.getDeviceTime()-start)*1000
		--toast.new("Count took "..tostring(elapsed).."msec")
		self.contents.name = self.name
		self.contents.elapsed = elapsed
	end
	return self
end

function MBTile:getBlob(n,x,y,z)
	local blob = nil

	if self.env and self.conn then
		local row = (2^z)-y-1
		local zc = self.contents and self.contents[z] or nil

		if not zc
		or (y>=zc.min_y and y<=zc.max_y
			and x>=zc.min_x and x<=zc.max_x) then	-- Is it at least in range of the contents?
			-- retrieve a cursor
			local cur, err = self.conn:execute("SELECT tile_data from tiles where zoom_level="..tostring(z).." and tile_row="..tostring(row).." and tile_column="..tostring(x))
			if cur then
				-- print all rows, the rows will be indexed by field names
				blob = cur:fetch ()
				cur:close() -- already closed because all the result set was consumed	
--				if blob then
--					print("sqlite:Got "..tostring(#blob).." bytes for "..tostring(z).."/"..tostring(x).."/"..tostring(y))
--				else print("sqlite:no row for "..tostring(z).."/"..tostring(x).."/"..tostring(y))
--				end
			else print("sqlite:Got NIL cursor, err="..tostring(err))
			end
		end
	end

	return blob
end

function MBTile:checkTile(n,x,y,z)
	local start = MOAISim.getDeviceTime()

	local file = string.format('%s/%i/%i/%i.png', self.name, z, x, y)
	if not self.tileCache then
		self.tileCache = {}
		setmetatable(self.tileCache, { __mode = 'v' })
	end
	if self.tileCache[file] then
		local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
		--print("sqlite:checkTile "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." CACHE took "..tostring(elapsed).." msec")
		return true
	end
	
	return self:getBlob(n,x,y,z) ~= nil
end

function MBTile:getTile(n,x,y,z)
	local start = MOAISim.getDeviceTime()

	local file = string.format('%s/%i/%i/%i.png', self.name, z, x, y)
	if not self.tileCache then
		self.tileCache = {}
		setmetatable(self.tileCache, { __mode = 'v' })
	end
	if self.tileCache[file] then
		local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
--		print("sqlite:getTile "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." CACHE took "..tostring(elapsed).." msec")
		return self.tileCache[file]
	end

	local blob = self:getBlob(n,x,y,z)
	if blob then
		local buffer = MOAIDataBuffer.new()
		buffer:setString(blob)


		local image = MOAITexture.new()
		image:load(buffer, file)
--		local image = MOAIImage.new()
--		image:loadFromBuffer(buffer)


		local width, height = image:getSize()
		if width ~= 256 or height ~= 256 then
			print('getTile('..tostring(z).."/"..tostring(x).."/"..tostring(y)..') is '..tostring(width)..'x'..tostring(height)..' bytes:'..tostring(#blob))
			image = nil
--		else image = Sprite { texture = image, left=0, top=0 }
		end
		local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
--		print("sqlite:getTile "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." took "..tostring(elapsed).." msec")
		self.tileCache[file] = image
--		if not self.purgeList then self.purgeList = List.new()
--		self.purgeList:pushright(file)
--		if self.purgeList:getCount() > 500 then
--			local temp = self.purgeList:popleft()
--			print("sqlite:getTile:Purging "..file)
--			self.tileCache[file] = nil
--		end
		return image
	end
	return nil
end

function MBTile:saveTile(n,x,y,z,buffer)

	local start = MOAISim.getDeviceTime()

	local blob = nil

--	local env,conn = opendb("World0-8.mbtiles")
	if self.env and self.conn then
--		print("sqlite:saveTile "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." from buffer")

			local start2 = MOAISim.getDeviceTime()

			local row = (2^z)-y-1

			-- retrieve a cursor
			local stmt = "INSERT INTO tiles(zoom_level, tile_column, tile_row, tile_data) VALUES("..tostring(z)..","..tostring(x)..","..tostring(row)..",x'"..MOAIDataBuffer.hexEncode(buffer:getString()).."')"
			local start3 = MOAISim.getDeviceTime()
			if not self.trans or self.trans == 0 then
				local start = MOAISim.getDeviceTime()
				local count, err = self.conn:execute("BEGIN TRANSACTION")
				local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
				print("sqlite:saveTile:Begin Transaction returned "..tostring(count).." and "..tostring(err).." took "..elapsed.." msec")
				serviceWithDelay( "commit", 2*1000, function()
							if self.trans > 0 then
								local start = MOAISim.getDeviceTime()
								local count, err = self.conn:execute("COMMIT")
								local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
								print("sqlite:saveTile:Commit("..tostring(trans)..") took "..elapsed.." msec")
	--toast.new("Commit("..tostring(trans)..") in "..tostring(elapsed).." msec", 2000)
								self.trans = 0
							else
								print("sqlite:saveTile:Huh?  Trans is "..tostring(trans).."?")
							end
						end)
			end
			local count, err = 	self.conn:execute(stmt)
			self.trans = (self.trans and self.trans or 0) + 1
			local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
			local elapsed1 = string.format("%.2f", (start2 - start) * 1000)
			local elapsed2 = string.format("%.2f", (start3 - start2) * 1000)
			local elapsed3 = string.format("%.2f", (MOAISim.getDeviceTime() - start3) * 1000)
			if count == 1 then
--local info = debug.getinfo( 2, "Sl" )
--local where = info.source..':'..info.currentline
--if where:sub(1,1) == '@' then where = where:sub(2) end
--print(where..">sqlite:saveTile:INSERT="..tostring(count)..","..tostring(err).." "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." took "..tostring(elapsed1).."+"..tostring(elapsed2).."+"..tostring(elapsed3).."="..tostring(elapsed).." msec")
				if self.contents then
					local zc = self.contents and self.contents[z] or nil
					if not zc then
						self.contents[z] = {count=1,min_y=y,max_y=y,min_x=x,max_x=x}
					else
						zc.count = zc.count + 1
						if y < zc.min_y then zc.min_y = y end
						if y > zc.max_y then zc.max_y = y end
						if x < zc.min_x then zc.min_x = x end
						if x > zc.max_x then zc.max_x = x end
					end
				end
			else
				if not count then
					count = self:getBlob(n,x,y,z) ~= nil
				end
				if not count then
local info = debug.getinfo( 2, "Sl" )
local where = info.source..':'..info.currentline
if where:sub(1,1) == '@' then where = where:sub(2) end
print(where..">sqlite:saveTile:INSERT="..tostring(count)..","..tostring(err).." "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." took "..tostring(elapsed1).."+"..tostring(elapsed2).."+"..tostring(elapsed3).."="..tostring(elapsed).." msec")
				end
			end
	end
--	print("sqlite:close database")
--	closedb(env,conn)
	
end

function MBTile:saveTileFile(n,x,y,z,dir,file)
	local buffer = MOAIDataBuffer.new()
	if buffer:load(dir.."/"..file) then
		self:saveTile(n,x,y,z,buffer)
	else print("sqlite:saveTileFile:Load("..dir.."/"..file..") Failed")
	end
end



--local env,conn = opendb("World0-8.mbtiles")
--local MBTiles = ("./LynnsTiles.mbtiles")
--local MBTiles = ("./OpenStreetMaps.mbtiles")
--local MBTiles = ("./ArcGISWoldImagery.mbtiles")
local MBTiles = nil
local TopTiles = nil
local TopTiles2, TopTiles3, TopTiles4
local MBinited = false
--local env,conn = nil, nil
--local trans = 0
--local contents = nil

function osmTiles:getMBTilesCounts()
	return TopTiles and TopTiles.contents or nil
end

local function initMBTiles(force)

	if not force and MBinited then return end
	MBinited = true
	
	EnsureAllMBTiles()
	
	config.Map.MBTiles = config.Map.MBTiles or "./LynnsTiles.mbtiles"
	if MOAIFileSystem.getAbsoluteFilePath(config.Map.MBTiles) ~= config.Map.MBTiles then
		config.Map.MBTiles = EnsureMBTiles(config.Map.MBTiles)
	end
	config.Map.TopTiles = config.Map.TopTiles or "./LynnsTiles.mbtiles"
	if MOAIFileSystem.getAbsoluteFilePath(config.Map.TopTiles) ~= config.Map.TopTiles then
		config.Map.TopTiles = EnsureMBTiles(config.Map.TopTiles)
	end

	MBTiles = MBTile(config.Map.MBTiles, force)--("./LynnsTiles.mbtiles")
	if not MBTiles then
		MBTiles = MBTile(EnsureMBTiles("./LynnsTiles.mbtiles"))
	end

	if config.Map.TopTiles and config.Map.TopTiles ~= '' then
		TopTiles = MBTile(config.Map.TopTiles, force)
	else TopTiles = nil
	end
--	TopTiles2 = MBTile(EnsureMBTiles("CatalinaMtns_SAHC.mbtiles"))
--	TopTiles3 = MBTile(EnsureMBTiles("RinconMtnsTI.mbtiles"))
--	TopTiles4 = MBTile(EnsureMBTiles("TortolitaMtns_USA.mbtiles"))
	performWithDelay(force and 10 or 5000, function() toast.new(tostring(MBTiles.name).."\n"..tostring(MBTiles.URLFormat).."\n"..MBTiles.db, 10000) end)
	if TopTiles and TopTiles ~= MBTiles then
		performWithDelay(force and 10 or 5000, function() toast.new(tostring(TopTiles.name).."\n"..tostring(TopTiles.URLFormat).."\n"..TopTiles.db, 10000) end)
	else TopTiles = nil	-- Don't carry both if they are the same!
	end
--[[
	env,conn = opendb(MBTiles)
	if env and conn then
		print("sqlite:Got database connection to "..MBTiles)
		local cur, err = conn:execute("select value from metadata where name='name'")
		if cur then
			local name = cur:fetch()	-- Get the actual value
			cur:close() -- already closed because all the result set was consumed	
			print("sqlite:"..MBTiles.." -> "..tostring(name))
			TileSet.Name = tostring(name)
		else print("sqlite:No name metadata in "..MBTiles)
		end
		local cur, err = conn:execute("select value from metadata where name='URLFormat'")
		if cur then
			local URLFormat = cur:fetch()	-- Get the actual value
			cur:close() -- already closed because all the result set was consumed	
			print("sqlite:"..tostring(URLFormat).." -> "..MBTiles)
			if not URLFormat then
				print("sqlite:No URLFormat metadata in "..MBTiles)
			end
			TileSet.URLFormat = URLFormat
			performWithDelay(force and 10 or 5000, function() toast.new(TileSet.Name.."\n"..tostring(TileSet.URLFormat).."\n"..MBTiles, 10000) end)
		else print("sqlite:No URLFormat metadata in "..MBTiles)
		end
		
--		if not force then
--			performWithDelay(10000, function()
				local start = MOAISim.getDeviceTime()
				local cur, err = conn:execute("SELECT zoom_level, count(*) as count, min(tile_column) as min_col, max(tile_column) as max_col, min(tile_row) as min_row, max(tile_row) as max_row from tiles group by zoom_level order by zoom_level")
				if cur then
					local row = cur:fetch({},"a")
					contents = {}
					while row do
						contents[row.zoom_level] = {count=row.count,
													min_row=row.min_row,
													max_row=row.max_row,
													min_col=row.min_col,
													max_col=row.max_col }
						print(string.format("sqlite:zoom:%i Count:%i Rows:%i-%i Cols:%i-%i",
											row.zoom_level, row.count,
											row.min_row, row.max_row,
											row.min_col, row.max_col))
						row = cur:fetch({},"a")
					end
					cur:close() -- already closed because all the result set was consumed	
					local elapsed = (MOAISim.getDeviceTime()-start)*1000
					toast.new("Count took "..tostring(elapsed).."msec")
					contents.elapsed = elapsed
				else
					print("sqlite:Count Failed with "..err..", Closing connection to "..MBTiles)
					closedb(env,conn)
					env, conn = nil, nil
				end
--			end)
--		end

	else print("sqlite:Failed to connect to "..MBTiles.." reason "..tostring(conn))
	end
]]
end

function osmTiles:newMBTiles()
	print("osmTiles:newMBTiles("..tostring(config.Map.MBTiles)..")")
--[[
	if env or conn then
		if trans > 0 then
			local start = MOAISim.getDeviceTime()
			local count, err = conn:execute("COMMIT")
			local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
			print("sqlite:newMBTiles:Commit("..tostring(trans)..") took "..elapsed.." msec")
toast.new("Commit("..tostring(trans)..") in "..tostring(elapsed).." msec", 2000)
			trans = 0
		end
		closedb(env,conn)
		env, conn = nil, nil
	end
	MBinited = false
]]
	initMBTiles(true)
	self:moveTo()	-- All nils forces a map reloaded
end


--[[
local function osmLoadMBTile(n,x,y,z)
	if not env or not conn then initMBTiles() end
	local start = MOAISim.getDeviceTime()
	local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)

	local blob = nil

--	local env,conn = opendb("World0-8.mbtiles")
	if env and conn then
--		print("sqlite:osmLoadMBTile "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y))

		local row = (2^zoom)-y-1
		local zc = contents and contents[z] or nil
		
		if not zc
		or (row>=zc.min_row and row<=zc.max_row
			and x>=zc.min_col and x<=zc.max_col) then	-- Is it at least in range of the contents?
			-- retrieve a cursor
			local cur, err = conn:execute("SELECT tile_data from tiles where zoom_level="..tostring(z).." and tile_row="..tostring(row).." and tile_column="..tostring(x))
			if cur then
				-- print all rows, the rows will be indexed by field names
				blob = cur:fetch ()
				cur:close() -- already closed because all the result set was consumed	
	--			if blob then
	--				print("sqlite:Got "..tostring(#blob).." bytes for "..tostring(z).."/"..tostring(x).."/"..tostring(y))
	--			else print("sqlite:no row for "..tostring(z).."/"..tostring(x).."/"..tostring(y))
	--			end
			else print("sqlite:Got NIL cursor, err="..tostring(err))
			end
		end
	end
--	print("sqlite:close database")
--	closedb(env,conn)

	if blob then
		local buffer = MOAIDataBuffer.new()
		buffer:setString(blob)
		--local image = MOAIImage.new()
		--image:loadFromBuffer(buffer)
		local image = MOAITexture.new()
		image:load(buffer)
		local width, height = image:getSize()
		if width ~= 256 or height ~= 256 then
			print('osmLoadMBTile('..tostring(z).."/"..tostring(x).."/"..tostring(y)..') is '..tostring(width)..'x'..tostring(height)..' bytes:'..tostring(#blob))
			image = nil
		else image = Sprite { texture = image, left=0, top=0 }
		end
		local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
		--print("sqlite:osmLoadMBTile "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." took "..tostring(elapsed).." msec")
		return image
	end
	return nil
end

local function osmSaveMBTileBuffer(n,x,y,z,buffer)
	if not env or not conn then initMBTiles() end
	local start = MOAISim.getDeviceTime()

	local blob = nil

--	local env,conn = opendb("World0-8.mbtiles")
	if env and conn then
--		print("sqlite:osmSaveMBTileBuffer "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." from buffer")

			local start2 = MOAISim.getDeviceTime()
		
			local row = (2^zoom)-y-1
			if contents then
				local zc = contents and contents[z] or nil
				if not zc then
					contents[z] = {count=1,min_row=row,max_row=row,min_col=x,max_col=x}
				else
					zc.count = zc.count + 1
					if row < zc.min_row then zc.min_row = row end
					if row > zc.max_row then zc.max_row = row end
					if x < zc.min_col then zc.min_col = x end
					if x > zc.max_col then zc.max_col = x end
				end
			end

			-- retrieve a cursor
			local stmt = "INSERT INTO tiles(zoom_level, tile_column, tile_row, tile_data) VALUES("..tostring(z)..","..tostring(x)..","..tostring(row)..",x'"..MOAIDataBuffer.hexEncode(buffer:getString()).."')"
			local start3 = MOAISim.getDeviceTime()
			if trans == 0 then
				local start = MOAISim.getDeviceTime()
				local count, err = conn:execute("BEGIN TRANSACTION")
				local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
				print("sqlite:osmSaveMBTileBuffer:Begin Transaction returned "..tostring(count).." and "..tostring(err).." took "..elapsed.." msec")
				serviceWithDelay( "commit", 2*1000, function()
							if trans > 0 then
								local start = MOAISim.getDeviceTime()
								local count, err = conn:execute("COMMIT")
								local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
								print("sqlite:osmSaveMBTileBuffer:Commit("..tostring(trans)..") took "..elapsed.." msec")
	--toast.new("Commit("..tostring(trans)..") in "..tostring(elapsed).." msec", 2000)
								trans = 0
							else
								print("sqlite:osmSaveMBTileBuffer:Huh?  Trans is "..tostring(trans).."?")
							end
						end)
			end
			local count, err = conn:execute(stmt)
			trans = trans + 1
			local elapsed = string.format("%.2f", (MOAISim.getDeviceTime() - start) * 1000)
			local elapsed1 = string.format("%.2f", (start2 - start) * 1000)
			local elapsed2 = string.format("%.2f", (start3 - start2) * 1000)
			local elapsed3 = string.format("%.2f", (MOAISim.getDeviceTime() - start3) * 1000)
			print("sqlite:osmSaveMBTileBuffer:INSERT="..tostring(count)..","..tostring(err).." "..tostring(n).." for "..tostring(z).."/"..tostring(x).."/"..tostring(y).." took "..tostring(elapsed1).."+"..tostring(elapsed2).."+"..tostring(elapsed3).."="..tostring(elapsed).." msec")
	end
--	print("sqlite:close database")
--	closedb(env,conn)
	
end

local function osmSaveMBTileFile(n,x,y,z,dir,file)
	local buffer = MOAIDataBuffer.new()
	if buffer:load(dir.."/"..file) then
		osmSaveMBTileBuffer(n,x,y,z,buffer)
	else print("sqlite:osmSaveMBTileFile:Load("..dir.."/"..file..") Failed")
	end
end
]]












local function osmTileFileDir(x,y,z,MBTiles)
	local dir = osmTileDir()
	local file = string.format('MapTiles/%s/%i/%i/%i.png', MBTiles.name, z, x, y)
--	local URL = string.format(TileSet.URLFormat, z, x, y)
	local URL = ''

	if MBTiles.URLFormat then
		local f = MBTiles.URLFormat
		local DidOne = false;
		
		while f ~= "" do
			if f:sub(1,1) == '%' then
				local invert = false
				f = f:sub(2)
				if f:sub(1,1) == '!' then	-- %!X or %!Y inverts via (2^Z-n-1)
					invert = true
					f = f:sub(2)
				end
				if f:sub(1,1) == '%' then	-- %% is a single %
					URL = URL.."%"
					DidOne = true
				elseif f:sub(1,1) == 'z' then	-- %z is zoom
					URL = URL..tostring(z)
					DidOne = true
				elseif f:sub(1,1) == 'y' then	-- %y is y, but may be inverted
					URL = URL..tostring(invert and (2^z-y-1) or y)
					DidOne = true
				elseif f:sub(1,1) == 'x' then	-- %x is x but may be inverted
					URL = URL..tostring(invert and (2^z-x-1) or x)
					DidOne = true
				else							-- %<unknown> emits the original text
					URL = URL.."%"
					if invert then URL = URL.."!" end
					URL = URL..f:sub(1,1)
				end
			else URL = URL..f:sub(1,1)			-- Non-% copies right through
			end
			f = f:sub(2)
		end
		if not DidOne then
			if URL:sub(-1) ~= '\\' and URL:sub(-1) ~= '/' then URL = URL..'/' end
			URL = URL..string.format("%i/%i/%i.png", z, x, y)
		end

		local BSSID = MOAIEnvironment.BSSID
		if BSSID == "2c:b0:5d:ab:08:17" or BSSID == "08:86:3b:70:84:f6" then	-- My APs!
			URL = URL:gsub("ldeffenb.dnsalias.net","192.168.10.8",1)
		end
	end

	if not directoryInformed then
		local sayDir = dir
		directoryInformed = true
		performWithDelay(2000, function()
				local text = 'Tiles Stored In '..tostring(sayDir)
				toast.new(text, 5000)
				--summarizeTileUsage()	-- Takes too long!
			end)
	end
	if file == "MapTiles/LynnsTiles/0/0/0.png" then file='0-0-0.png'; dir=MOAIEnvironment.resourceDirectory end
	return file, dir, URL
end

local loadingList = List:new()
local loadRunning = 0
local loadedCount, skippedCount, errorCount, lateCount, soonCount
local queuedFiles = {}
local downloadingFiles = {}
local osmReallyLoadRemoteTile

function osmTiles:getQueueStats()	-- returns count, maxcount, pushcount, popcount
	return loadingList.count, loadingList.maxcount, loadingList.pushcount, loadingList.popcount
end

local function osmRemoteLoadTile(n, x, y, z, MBTiles)
	local now = MOAISim.getDeviceTime()*1000
	local file, dir = osmTileFileDir(x,y,z,MBTiles)
--local info = debug.getinfo( 2, "Sl" )
--local where = info.source..':'..info.currentline
--if where:sub(1,1) == '@' then where = where:sub(2) end
--print(where..">osmRemoteLoadTile:tile("..file..") queued:"..tostring(queuedFiles[file]).." download:"..tostring(downloadingFiles[file]))
	if queuedFiles[file] then
		if debugging then print(string.format('osmRemoteLoadTile['..n..']:NOT queueing %s queued %ims', file, (now-queuedFiles[file]))) end
	else
		queuedFiles[file] = now
		if loadRunning >= concurrentLoadingThreads then
			local v = { n=n, x=x, y=y, z=z, MBTiles=MBTiles }
			if debugging then print(string.format('[%i] queueing %i,%i,%i file:%s dir:%s', n, x, y, z, file, tostring(dir))) end
			List.pushright(loadingList, v)
			if debugging then print("loadingList now has "..loadingList.count..'/'..loadingList.maxcount..' elements') end
		else
			loadedCount, skippedCount, errorCount, lateCount, soonCount = 0, 0, 0, 0, 0
			--loadRunning = MOAISim.getDeviceTime()*1000
			loadRunning = loadRunning + 1
			loadedCount = loadedCount + 1
			osmReallyLoadRemoteTile(n,x,y,z,MBTiles)
		end
	end
end

local function osmLoadTile(n,x,y,z,force)
	x = math.floor(x)
	y = math.floor(y)
	if debugging then print(string.format("osmLoadTile[%d] %d,%d,%d expecting %d,%d,%d",
											n, x, y, z,
											tileGroup.tiles[n].xTile,
											tileGroup.tiles[n].yTile,
											tileGroup.tiles[n].zTile)) end
	if not force
	and tileGroup.tiles[n].goodTile
	and x == tileGroup.tiles[n].xTile
	and y == tileGroup.tiles[n].yTile
	and z == tileGroup.tiles[n].zTile then return end
	if x < 0 or x >= 2^z or y < 0 or y >= 2^z or z < 0 or z > zoomMax then
		print("osmLoadTile["..n..'] GRAY '..x..','..y..','..z)
		displayGrayTile(n)
		return
	end
if debugging then print(string.format("osmLoadTile:[%d]<-%d,%d,%d", n, x, y, z)) end
	tileGroup.tiles[n].xTile, tileGroup.tiles[n].yTile, tileGroup.tiles[n].zTile = x, y, z
	tileGroup.tiles[n].goodTile = false
	if not MBTiles then initMBTiles() end
	local tryImage, opaque = nil, false
	local file, dir = osmTileFileDir(x,y,z,MBTiles)
	if debugging then print('osmLoadTile['..n..'] is '..file..' in '..tostring(dir)) end
	if dir == MOAIEnvironment.resourceDirectory then
		--tryImage = display.newImage( file, dir, 0, 0 )
--print("Loading3 "..file)
		tryImage = Sprite { texture = file, left=0, top=0 }
	elseif downloadingFiles[file] then
		local now = MOAISim.getDeviceTime()*1000
		print(string.format('osmLoadTile['..n..']:ALREADY downloading %s for %ims', file, (now-downloadingFiles[file])))
	else
--[[
		local function isOpaque(image)
			if type(image.isOpaque) == 'function' then return image:isOpaque() end
			if type(image.getRGBA) ~= 'function' then
				print("type(image)="..type(image))
				return false
			end
			local width, height = image:getSize()
			for x=0,width-1 do
				for y=0,height-1 do
					local r,g,b,a = image:getRGBA(x,y)
					if a < 1 then return false end
				end
			end
			return true
		end
		local function isTransparent(image)
			if type(image.getRGBA) ~= 'function' then
				print("type(image)="..type(image))
				return false
			end
			local width, height = image:getSize()
			for x=0,width-1 do
				for y=0,height-1 do
					local r,g,b,a = image:getRGBA(x,y)
					if a > 0 then return false end
				end
			end
			return true
		end
]]
--		tryImage = osmLoadMBTile(n, x,y,z)
		local function addImage(image,priority)
			if image then
--				if isOpaque(image) then opaque = true end
				image = Sprite { texture = image, left=0, top=0 }
--				return image
				if not tryImage then
					tryImage = Group({width=256, height=256, left=1, top=1})	-- Need non-zero left/top to work
					tryImage:setPos(0,0)	-- Don't ask me why this is necessary
				end
				tryImage:addChild(image)
				if priority then image:setPriority(priority) end
			end
			return tryImage
		end
		
		local function addOrLoadImage(n,x,y,z,MBTiles,priority)
			local image = MBTiles:getTile(n, x,y,z)
			if image then
				tryImage = addImage(image,priority)
if debugging then print("osmLoadTile["..n..'] for '..x..','..y..','..z..' Loaded from '..MBTiles.name) end
			else
if debugging then print("osmLoadTile["..n..'] for '..x..','..y..','..z..' Not Found In '..MBTiles.name) end
				osmRemoteLoadTile(n, x,y,z, MBTiles)
			end
			return tryImage
		end

		if TopTiles and not opaque then tryImage = addImage(TopTiles:getTile(n, x,y,z),100) end
		if TopTiles2 and not opaque then tryImage = addImage(TopTiles2:getTile(n, x,y,z),90) end
		if TopTiles3 and not opaque then tryImage = addImage(TopTiles3:getTile(n, x,y,z),80) end
		if TopTiles4 and not opaque then tryImage = addImage(TopTiles4:getTile(n, x,y,z),70) end
		if MBTiles and not opaque then tryImage = addOrLoadImage(n, x,y,z, MBTiles, 0) end

		if tryImage then
--			tryImage = Sprite { texture = tryImage, left=0, top=0 }
		else
			local actualPath = system.pathForFile( file, dir )
			local mode, err1 = lfs.attributes(actualPath, 'mode')
			if mode then	-- this bit of stuff suppresses newImage complaints to stdout
				if mode == 'file' then
	--print("Loading4 "..dir..'\\'..file)

		--local deck = MOAIGfxQuad2D.new()
		--deck:setUVRect(0, 0, 1, 1)
		--deck:setRect(-128, -128, 128, 128)
		--deck:setTexture(dir..'/'..file)
		--tryImage = Sprite { texture=deck, left=0, top=0 }
		--tryImage = MOAIProp.new()
		--tryImage:setDeck(deck)
		--tryImage:setLoc(100, 100, 0)

					tryImage = Sprite { texture = actualPath, left=0, top=0 }
					local size = lfs.attributes(actualPath, 'size')
					local width, height = tryImage:getSize()
					if width ~= 256 or height ~= 256 then
						local size, err1 = lfs.attributes(actualPath, 'size')
						print('osmLoadTile('..file..') is '..tostring(width)..'x'..tostring(height)..' bytes:'..tostring(size))
	--[[
						local status, text = os.remove(actualPath)
						if not status then
							print('osmLoadTile:os.remove('..file..') returned '..tostring(text))
						else toast.new('Removed '..file)
						end
	]]
						tryImage = nil	-- Don't use this one!
					else
--						osmSaveMBTileFile(n,x,y,z,dir,file)
						MBTiles:saveTileFile(n,x,y,z,dir,file)
					end
				else
					print('osmLoadTile('..file..') mode:'..tostring(mode)..' should be "file"')
				end
			else
				if debugging then print('osmLoadTile['..file..'] attributes error:'..tostring(err1)) end
			end
		end
	end
	
	if tryImage then
		--print('osmLoadTile:Recovered '..file)
		--if busyImage then busyImage:removeSelf(); busyImage = nil end
		displayTileImage(n, tryImage, x, y, z)
		--print("Need to show256 from osmTiles:osmLoadTile()")
		--show256(file)
	--elseif osmLoading[n] then
		--print('osmLoadTile['..n..':BUSY!  Not Loading '..file)
	else
		--print('osmLoadTile:Remote Loading '..file)
		displayBusyTile(n, x,y,z)
		osmRemoteLoadTile(n, x,y,z, MBTiles)
	end
end

local function propagateLoadingList()
	if debugging then print('propagateLoadingList:Starting with '..loadingList.count); end
	local didOne = false
	if loadingList.count > 0 then
		while loadingList.count > 0 do
			local more = List.popleft(loadingList)
			if debugging then print("Popping Leaves "..tostring(loadingList.count)..'/'..tostring(loadingList.maxcount)) end
			if more.n == 0
			or (more.n <= #tileGroup.tiles and tileGroup.tiles[more.n].xTile == more.x and tileGroup.tiles[more.n].yTile == more.y and tileGroup.tiles[more.n].zTile == more.z) then
				loadedCount = loadedCount + 1
				osmReallyLoadRemoteTile(more.n, more.x, more.y, more.z, more.MBTiles)
				didOne = true
				break
			else
				for t = 1, #tileGroup.tiles do
					local tile = tileGroup.tiles[t]
					local x, y, z = tile.xTile,tile.yTile,tile.zTile
					if more.x==x and more.y==y and more.z==z then
if debugging then print('propagateLoadingList:Recovering['..t..'] '..x..','..y..','..z) end
						loadedCount = loadedCount + 1
						osmReallyLoadRemoteTile(more.n, more.x, more.y, more.z, more.MBTiles)
						didOne = true
						break
					end
				end
				if didOne then break end
				local file, dir = osmTileFileDir(more.x,more.y,more.z,more.MBTiles)
				skippedCount = skippedCount + 1
if debugging then print('propagateLoadingList['..tostring(more.n)..']: skipping '..tostring(more.x)..' '..more.y..' '..more.z..' wants '..tileGroup.tiles[more.n].xTile..' '..tileGroup.tiles[more.n].yTile..' '..tileGroup.tiles[more.n].zTile) end
				queuedFiles[file] = nil
			end
		end
	end
	if loadingList.count <= 0 and not didOne then
		local now = MOAISim.getDeviceTime()*1000
		--print(string.format("Remote Loading ran for %ims, max %i", now-loadRunning, loadingList.maxcount))
		loadRunning = loadRunning - 1
		for t = 1, #tileGroup.tiles do
			local tile = tileGroup.tiles[t]
			if not tile.goodTile then
				local x, y, z = tile.xTile,tile.yTile,tile.zTile
if debugging then print('propagateLoadingList:Double-checking['..t..'] '..x..','..y..','..z) end
				if x ~= -1 or y ~= -1 or z ~= -1 then
					osmLoadTile(t,x,y,z,true)
				end
			end
		end
	end
	if debugging then print('propagateLoadingList:Done'); end
end

local recentFailures = {}

local function purgeRecentFailures()
	local now = MOAISim.getDeviceTime()*1000
	local delCount, keepCount = 0, 0
	for k,v in pairs(recentFailures) do
		if now-v > 60000 then
			--print("Removing failure "..tostring(now-v).."ms "..tostring(k))
			recentFailures[k] = nil
			delCount = delCount + 1
		else	keepCount = keepCount + 1
		end
	end
--[[
	if delCount > 0 or keepCount > 0 then
		print(string.format("purgeRecentFailures deleted %i, retained %i", delCount, keepCount))
	end
	local queCount = 0
	for k,v in pairs(queuedFiles) do
		queCount = queCount + 1
	end
	if queCount > 0 then
		print(string.format('purgeRecentFailures:%d in queue', queCount))
	end
]]
end
performWithDelay(30000, purgeRecentFailures, 0)	-- do this forever

function osmReallyLoadRemoteTile(n, x, y, z, MBTiles)
	local file, dir, URL = osmTileFileDir(x, y, z, MBTiles)
if debugging then print(string.format('[%i] loading %i,%i,%i file:%s dir:%s', n, x, y, z, file, tostring(dir))) end
--print("osmReallyLoadRemoteTile:tile("..file..") queued:"..tostring(queuedFiles[file]).." download:"..tostring(downloadingFiles[file]))
	if true or makeRequiredDirectory(file, dir) then
		local now = MOAISim.getDeviceTime()*1000
		
--[[
		local server = URL:match("http://(.-)[:/].+")
		print("dns server "..tostring(server).." from "..tostring(URL))
		if server then
			local homeIP, text = socket.dns.toip(server)
			if not homeIP then
				print("dns.toip("..server..") returned "..tostring(text))
			else
				print(server..'=dns='..tostring(homeIP))
				--URL = URL:gsub(server,homeIP,1)
				print("dns URL:"..tostring(URL))
			end
		end
]]

		if URL and URL ~= '' then
		if (not recentFailures[URL]) or (now-recentFailures[URL] >= 60000) then
		
		if downloadingFiles[file] then
			print(string.format('osmReallyLoadRemoteTile['..n..']:ALREADY downloading %s for %ims', file, (now-downloadingFiles[file])))
		else
			downloadingFiles[file] = now
		end
		
--		local stream = MOAIFileStream.new ()
--		stream:open ( dir..'/'..file, MOAIFileStream.READ_WRITE_NEW )
		local stream = MOAIMemStream.new ()
		stream:open ( )

local function osmPlanetListener( task, responseCode )
	local now = MOAISim.getDeviceTime()*1000
	local expected = n >= 1 and n <= #tileGroup.tiles and tileGroup.tiles[n].xTile == x and tileGroup.tiles[n].yTile == y and tileGroup.tiles[n].zTile == z
	local itWorked = false
	local tryImage

local streamSize = stream:getLength()
if debugging then print('osmPlanetListener['..tostring(n)..'] completed with '..tostring(responseCode)..' got '..tostring(streamSize)..' bytes') end

	if responseCode ~= 200 then
		print ( "osmPlanetListener["..tostring(n).."]:Network error:"..responseCode..' on '..file..' in '..dir)
		if responseCode ~= 404 and responseCode ~= 0 then
			if not config or not config.Debug or config.Debug.TileFailure then
				toast.new(file..'\nFailure Response:'..tostring(responseCode)..' Bytes:'..tostring(streamSize))
			end
		end
	elseif streamSize == 4294967295 then
		print ( "osmPlanetListener["..tostring(n).."]:Size:"..streamSize..' on '..file..' in '..dir)
	else
if debugging then print("osmPlanetListener["..n.."]:Loading1 "..dir..'/'..file) end

		local buffer = MOAIDataBuffer.new()
		stream:seek(0)
		local content, readbytes = stream:read()
		buffer:setString(content)
if debugging then print("osmPlanetListener["..tostring(n).."]:read "..tostring(readbytes).."/"..tostring(streamSize).." bytes to buffer giving "..tostring(buffer:getSize())) end

--[[
		local fstream = MOAIFileStream.new ()
		fstream:open ( dir..'/'..file, MOAIFileStream.READ_WRITE_NEW )
		stream:seek(0)
		local wrote = fstream:writeStream(stream)
if debugging then print("osmPlanetListener["..tostring(n).."]:Wrote "..tostring(wrote).."/"..tostring(streamSize).." bytes to "..dir.."/"..file) end
		fstream:close()
if debugging then print("osmPlanetListener["..tostring(n).."]:"..file.." size:"..tostring(streamSize))	end
]]

--		tryImage = Sprite { texture = dir..'/'..file, left=0, top=0 }
		tryImage = MOAITexture.new()
		tryImage:load(buffer, file)
		tryImage = Sprite { texture = tryImage, left=0, top=0 }
if debugging then print("osmPlanetListener["..n.."]:Loading1.25 "..dir..'/'..file) end
		local width, height = tryImage:getSize()
if debugging then print("osmPlanetListener["..n.."]:Loading1.5 "..dir..'/'..file..' is '..tostring(width)..'x'..tostring(height)) end
--		if width ~= 256 or height ~= 256 then
--			local size, err1 = lfs.attributes(system.pathForFile( file, dir ), 'size')
--			if not size then print('osmPlanetListener["..tostring(n).."]:attributes('..file..',size) error('..err1..')') end
--			if size ~= streamBytes then
--				toast.new(file..'\nSize:'..tostring(size)..' Stream:'..tostring(streamSize))
--			end
--if debugging then print("osmPlanetListener["..n.."]:Loading2 "..dir..'/'..file) end
--			tryImage = Sprite { texture = dir..'/'..file, left=0, top=0 }
--			width, height = tryImage:getSize()
--			if width == 256 and height == 256 then
--				toast.new(file..'\nSize NOW:'..tostring(width)..'x'..tostring(height)..' Bytes:'..tostring(streamSize))
--			end
--		end

		if width == 256 and height == 256 then
			itWorked = true
--			osmSaveMBTileBuffer(n,x,y,z,buffer)
			MBTiles:saveTile(n,x,y,z,buffer)

			local function checkPrefetch(x2,y2,z2)
				if false and not MBTiles:checkTile(0, x2,y2,z2) then
					local file2, dir2 = osmTileFileDir(x2,y2,z2,MBTiles)
--					print("Prefetch "..file2.." or z="..tostring(z2).." x="..tostring(x2).." y="..tostring(y2))
					osmRemoteLoadTile(0, x2,y2,z2, MBTiles)
				end
			end
			if z>1 then
				checkPrefetch(math.floor(x/2), math.floor(y/2), z-1)
			end
			if n >= 1 and n <= 9 and z<15 then		-- Prefetch below center 3x3 square
				checkPrefetch(x*2, y*2, z+1)
				checkPrefetch(x*2+1, y*2, z+1)
				checkPrefetch(x*2, y*2+1, z+1)
				checkPrefetch(x*2+1, y*2+1, z+1)
			end
		
		else
			tryImage = nil
			print('osmPlanetListener["..tostring(n).."]:Failed To Load '..file..' in '..dir..' size:'..tostring(width)..'x'..tostring(height))
			toast.new(file..'\nFailure Size:'..tostring(width)..'x'..tostring(height)..' Bytes:'..tostring(streamSize))
		end
	end
	stream:close()

--print("osmPlanetListener:tile("..file..") queued:"..tostring(queuedFiles[file]).." download:"..tostring(downloadingFiles[file]))
	osmLoading[n] = nil
	queuedFiles[file] = nil
	downloadingFiles[file] = nil
	if itWorked then
		--print (string.format("Loaded in %ims", now-(osmLoading[n] or 0)))
		tilesLoaded = tilesLoaded + 1
		if expected then
if debugging then print('osmPlanetListener['..n..']: displaying '..x..' '..y..' '..z..' from '..URL) end
			--displayTileImage(n, tryImage, x, y, z)
			osmLoadTile(n,x,y,z,true)
			--print("need to call show256 from osmPlanetListener")
			--show256(event.response.filename)
			--tileGroup.tile.alpha = 0	-- and fade in the new tile
			--transition.to( tileGroup.tile, { alpha = 1.0, time=1000 } )
			if debugging then print (string.format("osmPlanetListener[%i]:Loaded %s/%s in %ims", n, dir, file, now-(osmLoading[n] or 0))) end
		else
if debugging and n > 0 then print('osmPlanetListener['..n..']:LATE '..x..','..y..','..z..' wants '..tileGroup.tiles[n].xTile..','..tileGroup.tiles[n].yTile..','..tileGroup.tiles[n].zTile) end
			lateCount = lateCount + 1
			local c = 0
			for t = 1, #tileGroup.tiles do
				local tile = tileGroup.tiles[t]
				if tile.xTile == x and tile.yTile == y and tile.zTile == z then
					print('osmPlanetListner['..n..'] LATE '..x..','..y..','..z..' wanted by '..t)
					if tryImage then
						--displayTileImage(t, tryImage, x, y, z)
						osmLoadTile(t,x,y,z,true)
-- Restore if using displayTileImage
--						tryImage = nil
					end
					c = c + 1
				end
			end
			if c > 0 then
				text = 'LATE:'..tostring(z)..'/'..tostring(x)..'/'..tostring(y)..' wanted by '..tostring(c)..' other'
				--toast.new(text, 2000)
				print (text)
			elseif tryImage then tryImage:dispose()	-- Don't leak tile image!
			end
		end
	else
		errorCount = errorCount + 1
		print("planetListener["..tostring(n).."]:Marking failure for "..tostring(URL))
		recentFailures[URL] = now
		print (string.format("planetListener[%d]:Loading FAILED in %ims", n, now-(osmLoading[n] or 0)))
--[[		do
			local server = URL:match("http://(.-)[:/].+")
			print("dns server "..tostring(server).." from "..tostring(URL))
			if server then
				local homeIP, text = socket.dns.toip(server)
				if not homeIP then
					print("dns.toip("..server..") returned "..tostring(text))
				else print(server..'=dns='..tostring(homeIP))
				end
			end
		end]]
		--if busyImage then busyImage:removeSelf(); busyImage = nil end
		if expected then
			displayTileFailed(n)
		else
			if n >= 1 and n <= #tileGroup.tiles then
				if tileGroup.tiles[n] then
					print('osmPlanetListener['..n..']: LATE:FAIL '..x..','..y..','..z..' wants '..tileGroup.tiles[n].xTile..','..tileGroup.tiles[n].yTile..','..tileGroup.tiles[n].zTile)
				else
					print('osmPlanetListener['..n..']: LATE:FAIL '..x..','..y..','..z..' NIL!')
				end
			else
				print('osmPlanetListener['..n..']: LATE:FAIL '..x..','..y..','..z..' OUT OF RANGE')
			end
			local c = 0
			for t = 1, #tileGroup.tiles do
				local tile = tileGroup.tiles[t]
				if tile.xTile == x and tile.yTile == y and tile.zTile == z then
					print('osmPlanetListner['..n..']: LATE:FAIL '..x..','..y..','..z..' wanted by '..t)
					displayTileFailed(t)
					c = c + 1
				end
			end
			if c > 0 then
				local text = 'LATE:FAIL:'..tostring(z)..'/'..tostring(x)..'/'..tostring(y)..' wanted by '..tostring(c)..' other'
				--toast.new(text, 2000)
				print (text)
			end
		end
	end
	if delayBetweenTiles <= 0 then
		propagateLoadingList()
	else performWithDelay(delayBetweenTiles, propagateLoadingList)
	end
end	-- osmPlanetListener
		osmLoading[n] = MOAISim.getDeviceTime()*1000
		--if tileGroup and tileGroup.tile then tileGroup.tile.alpha = tileGroup.tile.alpha/2 end	-- very dim

		local task = MOAIHttpTask.new ()
--		task:setVerbose(debugging)
		task:setVerbose(true)
		task:setVerb ( MOAIHttpTask.HTTP_GET )
		task:setUrl ( URL )
		task:setStream ( stream )
		task:setTimeout ( 30 )
		task:setCallback ( osmPlanetListener )
		task:setUserAgent ( string.format('%s from %s %s',
													tostring(config.StationID),
													MOAIEnvironment.appDisplayName,
													tostring(config.About.Version)) )
		--task:setHeader ( "Foo", "foo" )
		--task:setVerbose ( true )
		task:performAsync ()

		--if busyImage then busyImage:removeSelf(); busyImage = nil end
		--[[if not busyImage and tileGroup then
			busyImage = display.newText("Loading...", 0, 0, native.systemFont, 32)
			tileGroup:insert(2,busyImage)
			busyImage:setTextColor( 255,255,0,192)
			busyImage.x = tileGroup.contentWidth/2
			busyImage.y = tileGroup.contentHeight - busyImage.contentHeight/2
		end]]
		else
			--print("Too Soon("..tostring(now-recentFailures[URL])..'ms) for '..URL)
			local elapsed = now-recentFailures[URL]
			local percent = elapsed / 60000 * 100
			displayTileFailed(n,string.format('%.1f%%',100-percent).."\nTOO\nSOON")
			queuedFiles[file] = nil
			soonCount = soonCount + 1
			propagateLoadingList()
		end
		else
			local text = tostring(z)..'\n'..tostring(x)..'\n'..tostring(y)
			displayTileFailed(n,text)--"NO\nURL")
			queuedFiles[file] = nil
			--soonCount = soonCount + 1
			propagateLoadingList()
		end
	else
		print("makeRequiredDirectory("..file..','..dir..') FAILED!')
		displayTileFailed(n,"DIR\nFAIL")
		queuedFiles[file] = nil
		errorCount = errorCount + 1
		propagateLoadingList()
	end
end

--[[
local function deferLoadTile(n, x, y, z)
	if n == 1 then
		return osmTiles:osmLoadTile(n, x, y, z)
	else
		timer.performWithDelay(20*n/4, function()
										osmTiles:osmLoadTile(n,x,y,z)
										end)
	end
end
]]

function osmTiles:osmLoadTiles(x,y,z,force)
	--osmTiles:setSize(Application.viewWidth, Application.viewHeight)	-- Just to make sure the screen shape hasn't changed!

	if force or not (tileGroup.actualX == x and tileGroup.actualY == y and tileGroup.actualZ == z) then
		tileGroup.actualX, tileGroup.actualY, tileGroup.actualZ = x, y, z
		local xo, yo
		local reloaded = false
		x, xo = math.modf(x)
		y, yo = math.modf(y)
		if force or not (x == tileGroup.tiles[1].xTile and y == tileGroup.tiles[1].yTile and z == tileGroup.tiles[1].zTile) then
print("Reloading for "..x..','..y..','..z..' from '..tileGroup.tiles[1].xTile..','..tileGroup.tiles[1].yTile..','..tileGroup.tiles[1].zTile)
			tileGroup.tileVersion = newVersionID()
			tileGroup.wrapped = false
			reloaded = true
			for n = 1, #tileGroup.tiles do
				local xt = x+tileGroup.tiles[n].xOffset
				local yt = y+tileGroup.tiles[n].yOffset
				while xt < 0 do tileGroup.wrapped = true xt = xt + 2^z end
				while xt >= 2^z do tileGroup.wrapped = true xt = xt - 2^z end
				osmLoadTile(n, xt, yt, z, force)
				--deferLoadTile(n, xt, yt, z)
				if n == 1 then
					tileGroup.minX, tileGroup.minY = xt, yt
					tileGroup.maxX, tileGroup.maxY = xt, yt
				else
					if xt < tileGroup.minX then tileGroup.minX = xt end
					if xt > tileGroup.maxX then tileGroup.maxX = xt end
					if yt < tileGroup.minY then tileGroup.minY = yt end
					if yt > tileGroup.maxY then tileGroup.maxY = yt end
				end
			end
			tileGroup.maxX = tileGroup.maxX + 1	-- For < comparison
			tileGroup.maxY = tileGroup.maxY + 1	-- For < comparison
			local z20 = (2^(20-zoom))
			tileGroup.minX20 = tileGroup.minX*z20	-- Move out to zoom 20 coords
			tileGroup.maxX20 = tileGroup.maxX*z20	-- Move out to zoom 20 coords
			tileGroup.minY20 = tileGroup.minY*z20	-- Move out to zoom 20 coords
			tileGroup.maxY20 = tileGroup.maxY*z20	-- Move out to zoom 20 coords
print(string.format("osmTiles:osmLoadTiles:Loaded %.2f,%.2f-> %.2f,%.2f or %.2f,%.2f -> %.2f,%.2f",
					tileGroup.minX, tileGroup.minY,
					tileGroup.maxX, tileGroup.maxY,
					tileGroup.minX20, tileGroup.minY20,
					tileGroup.maxX20, tileGroup.maxY20))
		end
		tileGroup.tilesGroup.xOffset = math.floor(tileSize/2-tileSize*xo)
		tileGroup.tilesGroup.yOffset = math.floor(tileSize/2-tileSize*yo)
		if (z == 0) then	-- Zoom zero doesn't offset
			tileGroup.tilesGroup.xOffset = 0
			tileGroup.tilesGroup.yOffset = 0
		end
		if reloaded
		or not tileGroup.tilesGroup.x or not tileGroup.tilesGroup.y
		or tileGroup.tilesGroup.x ~= tileGroup.tilesGroup.xOffset
		or tileGroup.tilesGroup.y ~= tileGroup.tilesGroup.yOffset then

			if reloaded then
print("osmTiles:osmLoadTiles:Offset RELOADED!")
			elseif not tileGroup.tilesGroup.x or not tileGroup.tilesGroup.y then
print("osmTiles:osmLoadTiles:Offset INITIALIZING!")
			else
				local xo=tileGroup.tilesGroup.x-tileGroup.tilesGroup.xOffset
				local yo=tileGroup.tilesGroup.y-tileGroup.tilesGroup.yOffset
--print(string.format("osmTiles:osmLoadTiles:Offset moved %.3f %.3f", xo, yo))
			end
			tileGroup.offsetVersion = newVersionID()
		end

		tileGroup.tilesGroup.x = tileGroup.tilesGroup.xOffset
		tileGroup.tilesGroup.y = tileGroup.tilesGroup.yOffset
		tileGroup.tilesGroup:setLoc(tileGroup.tilesGroup.x, tileGroup.tilesGroup.y)
		--timer.performWithDelay(20*tileGroup.tilesGroup:getNumChildren()/4+20, fixupSymbols)
		fixupSymbols("osmLoadTiles")
		--[[if tileGroup.symbolLabel then
			osmTiles:showSymbol(tileGroup.symbolLabel.lat, tileGroup.symbolLabel.lon, tileGroup.symbolLabel)
		end]]
	else
		print('Not moving tileGroup @ ', x, y, z)
	end
end

--	Clean up all the old-style file names that we are orphaning...
--[[do
	local fullpath = system.pathForFile( "", system.TemporaryDirectory )
	for file in lfs.dir(fullpath) do
		if string.match(file,"^%d-%-%d-%-%d-.png$") then
			-- print( "Found file: " .. file )
			local fullfile = system.pathForFile( file, system.TemporaryDirectory )
			os.remove(fullfile)
		else	print("NOT "..file)
		end
	end
end]]

function osmTiles:setOrientation(orientation)
	if orientation:sub(1,8) == 'portrait' then
		tileGroup.x = display.screenOriginX
		tileGroup.y = display.screenOriginY --+ display.topStatusBarContentHeight
		tileGroup.square.rotation = 0
		tileGroup.square.x = Application.viewWidth / 2
		tileGroup.square.y = Application.viewHeight / 2 + display.topStatusBarContentHeight/2
		--tileGroup.square:setFillColor(255,255,255)
		for n=1, #tileGroup.tiles do
			local xo, yo = tileGroup.tiles[n].xOffset, tileGroup.tiles[n].yOffset
			tileGroup.tiles[n].x = (Application.viewWidth - tileSize)/2 + tileSize*xo
			tileGroup.tiles[n].y = (Application.viewHeight - tileSize)/2 + tileSize*yo + display.topStatusBarContentHeight/2
		end
		tileGroup.zoomGroup.alphaSlider.x = Application.viewWidth / 2
		tileGroup.zoomGroup.alphaSlider.y = Application.viewHeight - tileGroup.zoomGroup.alphaSlider.contentHeight/2
		tileGroup.zoomGroup.zoomSlider.x = tileGroup.zoomGroup.zoomSlider.contentWidth/2
		tileGroup.zoomGroup.zoomSlider.y = Application.viewHeight - 256 + tileGroup.zoomGroup.zoomSlider.contentHeight/2 + (256-tileGroup.zoomGroup.zoomSlider.contentHeight)/2
		showSliderText(tileGroup.zoomGroup.alphaSlider)
		showSliderText(tileGroup.zoomGroup.zoomSlider)
		tileGroup.zoomGroup.bwControl.x = tileGroup.zoomGroup.zoomSlider.contentWidth + tileGroup.zoomGroup.bwControl.contentWidth/2
		tileGroup.zoomGroup.bwControl.y = tileGroup.zoomGroup.alphaSlider.y - tileGroup.zoomGroup.alphaSlider.contentHeight/2 - tileGroup.zoomGroup.bwControl.contentHeight/2
		timer.performWithDelay(0,fixTileGroupSegments)
		fixupSymbols("setOrientation")
	elseif orientation:sub(1,9) == 'landscape' then
		tileGroup.x = display.screenOriginX
		tileGroup.y = display.screenOriginY --+ display.topStatusBarContentHeight
		tileGroup.square.rotation = 90
		tileGroup.square.x = Application.viewHeight / 2
		tileGroup.square.y = Application.viewWidth / 2 + display.topStatusBarContentHeight/2
		--tileGroup.square:setFillColor(0,0,0)
		-- tileGroup.y = Application.viewWidth/2 - tileGroup.contentHeight/2
		-- tileGroup.x = display.screenOriginX + Application.viewHeight - tileGroup.contentWidth
		for n=1, #tileGroup.tiles do
			local xo, yo = tileGroup.tiles[n].xOffset, tileGroup.tiles[n].yOffset
			tileGroup.tiles[n].x = (Application.viewHeight - tileSize)/2 + tileSize*xo
			tileGroup.tiles[n].y = (Application.viewWidth - tileSize)/2 + tileSize*yo + display.topStatusBarContentHeight/2
			tileGroup.tiles[n]:setLoc(tileGroup.tiles[n].x, tileGroup.tiles[n].y)
		end
		tileGroup.zoomGroup.alphaSlider.x = Application.viewWidth / 2
		tileGroup.zoomGroup.alphaSlider.y = Application.viewWidth - tileGroup.zoomGroup.alphaSlider.contentHeight/2
		tileGroup.zoomGroup.zoomSlider.x = tileGroup.zoomGroup.zoomSlider.contentWidth/2
		tileGroup.zoomGroup.zoomSlider.y = Application.viewWidth - 256 + tileGroup.zoomGroup.zoomSlider.contentHeight/2 + (256-tileGroup.zoomGroup.zoomSlider.contentHeight)/2
		tileGroup.zoomGroup.zoomSlider.y = Application.viewWidth / 2
		showSliderText(tileGroup.zoomGroup.alphaSlider)
		showSliderText(tileGroup.zoomGroup.zoomSlider)
		tileGroup.zoomGroup.bwControl.x = tileGroup.zoomGroup.zoomSlider.contentWidth + tileGroup.zoomGroup.bwControl.contentWidth/2
		tileGroup.zoomGroup.bwControl.y = tileGroup.zoomGroup.alphaSlider.y - tileGroup.zoomGroup.alphaSlider.contentHeight/2 - tileGroup.zoomGroup.bwControl.contentHeight/2
		timer.performWithDelay(0,fixTileGroupSegments)
		fixupSymbols("setOrientation")
	end
end

function osmTiles:insertUnderMap(group)
	tileGroup:insert(2,group)
end

function osmTiles:insertOverMap(group)
	tileGroup:insert(group)
end

function osmTiles:removeControl(newGroup)
	local myGroup = tileGroup.zoomGroup
	if myGroup.segments then
		for k,v in pairs(myGroup.segments) do
			if v == newGroup then myGroup.segments[k] = nil end
		end
	end
end

function osmTiles:insertControl(newGroup, isSegmented)
	local myGroup = tileGroup.zoomGroup
	if isSegmented then
		if not myGroup.segments then myGroup.segments = {} end
		table.insert(myGroup.segments, newGroup)
		newGroup.alpha = myGroup.alpha
	else myGroup:insert(newGroup)
	end
end

local function onSegmentPress( event )
   local target = event.target
   --print( "Segment Label is:", target.segmentLabel )
   --print( "Segment Number is:", target.segmentNumber )
   if target.segmentNumber == 1 then	-- Dim
		config.lastDim = true
		tileGroup:setClearColor ( 0,0,0,1 )
		--tileGroup.square:setFillColor(0,0,0,255)	-- Make the gray square turn black
	elseif target.segmentNumber == 2 then	-- Bright
		config.lastDim = false
		tileGroup:setClearColor ( 1,1,1,1 )
		--tileGroup.square:setFillColor(255,255,255,255)	-- Make the gray square turn white
	end
end

function osmTiles:getSize()
	return tileGroup.width, tileGroup.height
end

function osmTiles:resetSize(why)
	local width, height = osmTiles:getSize()
	osmTiles:removeCrosshair()
	tileGroup.sizeVersion = newVersionID()
	
	if tileGroup.tiles then
		print('osmTiles:setSize:clearing '..#tileGroup.tiles..' tiles and '..tileGroup.tilesGroup:getNumChildren()..' in group')
		do i=1,#tileGroup.tiles
			tileGroup.tiles[i]:removeChildren()	-- Remove all images
		end
		tileGroup.tilesGroup:removeChildren()	-- and empty the tile layer
	end
	tileGroup.tiles = {}	-- array of tiles covering visual surface
local function addTilePane(xo,yo)
	local n = #tileGroup.tiles + 1
	tileGroup.tiles[n] = Group()	-- One of the visual surface tiles
	tileGroup.tilesGroup:addChild(tileGroup.tiles[n])
	tileGroup.tiles[n].x = (width - tileSize)/2 + tileSize*xo
	tileGroup.tiles[n].y = (height - tileSize)/2 + tileSize*yo
	tileGroup.tiles[n].xOffset, tileGroup.tiles[n].yOffset = xo, yo
	tileGroup.tiles[n]:setLoc(tileGroup.tiles[n].x, tileGroup.tiles[n].y)
	tileGroup.tiles[n]:setScl(tileScale,tileScale,1)
if debugging then print(string.format("addTilePane:[%d]<-%d,%d,%d", n, -1,-1,-1)) end
	tileGroup.tiles[n].xTile, tileGroup.tiles[n].yTile, tileGroup.tiles[n].zTile = -1, -1, -1
end
--[[
	addTilePane(0,0)
	addTilePane(-1,0) addTilePane(1,0) addTilePane(0,-1) addTilePane(0,1)
	addTilePane(-1,-1) addTilePane(-1,1) addTilePane(1,-1) addTilePane(1,1)
	addTilePane(-2,0) addTilePane(2,0) addTilePane(0,-2) addTilePane(0,2)
	addTilePane(-2,-1) addTilePane(-1,-2) addTilePane(1,-2) addTilePane(2,-1)
	addTilePane(-2,1) addTilePane(2,1) addTilePane(-1,2) addTilePane(1,2)
]]
	local xc = math.floor(width/tileSize/2)+1
	local yc = math.floor(height/tileSize/2)+1
	print('osmTiles:setSize:'..width..'x'..height..' needs '..(xc*2+1)..'x'..(yc*2+1)..' tiles')
	addTilePane(0,0)	-- Always put this one first!
	if true then
		local x = -xc
		while (x <= xc) do
			local y = -yc
			while (y <= yc) do
				if x ~= 0 or y ~= 0 then
					--print('osmTiles:addTilePane['..x..','..y..']')
					addTilePane(x,y)
				end
				y = y + 1
			end
			x = x + 1
		end
	end
	print('osmTiles:setSize:Created '..#tileGroup.tiles..' tiles to cover '..width..'x'..height)
	table.sort(tileGroup.tiles, function(a,b)
								if a.xOffset == 0 and a.yOffset == 0 then return true end	-- 0,0 is first
								if b.xOffset == 0 and b.yOffset == 0 then return false end	-- 0,0 is first
								local da = math.sqrt(a.xOffset*a.xOffset+a.yOffset*a.yOffset)
								local db = math.sqrt(b.xOffset*b.xOffset+b.yOffset*b.yOffset)
								return da<db	-- closer to origin is first
							end)
	local x, y, z = tileGroup.actualX, tileGroup.actualY, tileGroup.actualZ
	tileGroup.actualX, tileGroup.actualY, tileGroup.actualZ = -1, -1, -1
	if x and y and z then osmTiles:osmLoadTiles(x,y,z) invokeCallbacks(why) end
	
--[[
	local points = {}
	for i = 0, 100 do
		points[#points+1] = i*width/100
		points[#points+1] = i*height/100
	end
]]
end

function osmTiles:setSize(width, height)
	if tileGroup.width == width and tileGroup.height == height then return end
	tileGroup.width, tileGroup.height = width, height
	osmTiles:resetSize('size')
end

function osmTiles:start()
	tileGroup.tilesGroup = Group()	-- for easy alpha setting
	tileGroup.tilesGroup.alpha = tileAlpha		-- Initial value

	osmTiles:setSize(Application.viewWidth, Application.viewHeight)
	
	tileGroup.x = 0 --display.screenOriginX
	tileGroup.y = 0 --display.screenOriginY
	tileGroup:addEventListener( "tap", tileTap )
	tileGroup:addEventListener( "touch", tileTouch )
	
	tileGroup.scale = 2
	--tileGroup:setScl(tileGroup.scale, tileGroup.scale, 1)

	--tileGroup.xScale = 0.8
	--tileGroup.yScale = 0.8

--[[
	local leftSquare = Graphics {width = Application.viewWidth/2, height = Application.viewHeight, left = 0, top = 0}
    leftSquare:setPenColor(0.25, 0.25, 0.25, 1):fillRect()	-- dark on the left
	tileGroup:addChild(leftSquare)
	local rightSquare = Graphics {width = Application.viewWidth/2, height = Application.viewHeight, left = Application.viewWidth/2, top = 0}
    rightSquare:setPenColor(0.75, 0.75, 0.75, 1):fillRect()	-- light on the right
	tileGroup:addChild(rightSquare)
]]

--print(string.format('tileGroup@%i,%i size %ix%i', tileGroup.x, tileGroup.y, tileGroup.contentWidth, tileGroup.contentHeight))

--[[
	tileGroup.square = display.newRect( 0, 0, Application.viewWidth, Application.viewHeight)
	tileGroup:insert(1,tileGroup.square)
	--tileGroup.square.x = (Application.viewWidth-display.screenOriginX)/2
	--tileGroup.square.y = (Application.viewHeight-display.screenOriginY)/2
	--tileGroup.square:setFillColor(255,255,255,255)	-- Make the gray square turn white
	if config.lastDim then	-- Dim
		tileGroup.square:setFillColor(0,0,0,255)	-- Make the gray square turn black
	else	-- Bright
		tileGroup.square:setFillColor(255,255,255,255)	-- Make the gray square turn white
	end
	--tileGroup.square.strokeWidth = 2
	--tileGroup.square:setStrokeColor(255,255,0,127)
]]
--[[
	if config.lastDim then	-- Dim
		tileGroup:setClearColor ( 0,0,0,1 )	-- Black background
	else	-- Bright
		tileGroup:setClearColor ( 1,1,1,1 )	-- White background
	end
]]
	tileGroup:addChild(tileGroup.tilesGroup)	 -- Just above the white "square"
	
	tileGroup.zoomGroup = Group()

--[[
	tileGroup.zoomGroup.alphaSlider = widget.newSlider
														{
														   orientation = "horizontal",
														   width = 200,
														   left = 56/2,
														   top = 128,
														   listener = alphaSliderListener
														}
	tileGroup.zoomGroup:insert(tileGroup.zoomGroup.alphaSlider)
	tileGroup.zoomGroup.alphaSlider.x = Application.viewWidth / 2
	tileGroup.zoomGroup.alphaSlider.y = Application.viewHeight - tileGroup.zoomGroup.alphaSlider.contentHeight/2
	tileGroup.zoomGroup.alphaSlider:setValue(math.floor(tileAlpha*100))
	showAlpha(tileAlpha)
	
	tileGroup.zoomGroup.zoomSlider = widget.newSlider
														{
														   orientation = "vertical",
														   height = 200,
														   left = 0,
														   top = 56/2,
														   listener = zoomSliderListener
														}
	tileGroup.zoomGroup:insert(tileGroup.zoomGroup.zoomSlider)
	tileGroup.zoomGroup.zoomSlider.x = tileGroup.zoomGroup.zoomSlider.contentWidth/2
	tileGroup.zoomGroup.zoomSlider.y = Application.viewHeight - 256 + tileGroup.zoomGroup.zoomSlider.contentHeight/2 + (256-tileGroup.zoomGroup.zoomSlider.contentHeight)/2
	tileGroup.zoomGroup.zoomSlider:setValue(math.floor(zoom/18*100+0.5))
	showZoom(zoom)

	tileGroup:insert(tileGroup.zoomGroup)
	tileGroup.zoomGroup.alpha = 0	-- Don't want to see it initially

local defaultSegment = 2	-- Bright
if config.lastDim then defaultSegment = 1 end	-- Dim

tileGroup.zoomGroup.bwControl = widget.newSegmentedControl
{
   left = 65,
   top = 110,
   segments = { "Dim", "Bright" },
   segmentWidth = 50,
   defaultSegment = defaultSegment,
   onPress = onSegmentPress
}
osmTiles:insertControl(tileGroup.zoomGroup.bwControl, true)
--]]

local function walkTiles()
	local lat, lon
	local walkToast
	local prevFetch = osmTiles:getTilesLoaded()
	for z = 6, 14 do
--			print(string.format("sqlite:zoom:%i Count:%i Rows:%i-%i Cols:%i-%i",
--								row.zoom_level, row.count,
--								row.min_row, row.max_row,
--								row.min_col, row.max_col))
		local yStart, yEnd = 0, 2^z-1
		local xStart, xEnd = 0, 2^z-1
		if MBTiles.contents then
			local pz = MBTiles.contents[z-1]
			if pz then
				yStart, yEnd = pz.min_y*2, pz.max_y*2+1
				xStart, xEnd = pz.min_x*2, pz.max_x*2+1
				--yStart = 6719 -- Temporary hack!
			end
		end
		for y = yStart, yEnd do
			for x = xStart, xEnd do
				while osmTiles:getQueueStats() > 0 do
					--print(string.format(tostring(coroutine.running ())..":walkTiles:%i Tiles in Queue", osmTiles:getQueueStats()))
					coroutine.yield(false)
				end
				if MBTiles:checkTile(0,math.floor(x/2),math.floor(y/2),z-1) then
					if not MBTiles:checkTile(0,x,y,z) then
						local lat, lon = osmTileLatLon(x+0.5,y+0.5,z)
						print(string.format(tostring(coroutine.running ())..":walkTiles:Moving to %i %.2f %.2f for %i/%i/%i", z, lat, lon, z, x, y))
						osmTiles:moveTo(lat, lon, z)
						coroutine.yield(false)
					--else print(string.format(tostring(coroutine.running ())..":walkTiles:Tile %i/%i/%i Found", z, x, y))
					end
				--else print(string.format(tostring(coroutine.running ())..":walkTiles:Tile %i/%i/%i Not Found", z, x, y))
				end
			end
			print(string.format(tostring(coroutine.running ())..":walkTiles:Finished Scanning %i/*/%i", z, y))
			local newFetch = osmTiles:getTilesLoaded()
			local deltaFetch = newFetch - prevFetch
			prevFetch = newFetch
			if walkToast then toast.destroy(walkToast, true) end
			walkToast = toast.new(string.format("Finished %i/*/%i\nFetched %i/%i", z, y, deltaFetch, newFetch), 0, nil, function() walkToast = nil end)
			if y%10 == 0 then coroutine.yield(false) end
		end
		print(string.format(tostring(coroutine.running ())..":walkTiles:Finished Scanning %i/*/*", z))
	end
	coroutine.yield(true)
end
--/nps/14/2557/5660.png
--[[
performWithDelay2("WalkBootstrap", 15000, function()
						local walker = coroutine.create(walkTiles)
						performWithDelay2("Walker", 100, function()
							local err, done = coroutine.resume(walker)
							if not err then print("walkTiles:resume error "..tostring(done)) end
							if not err or done then
								print("walkTiles:cancelling timer")
								return "cancel"
							end
							end, 0)
						end)
]]
end

return osmTiles
