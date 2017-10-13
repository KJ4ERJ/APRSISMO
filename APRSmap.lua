local debugging = false

module(..., package.seeall)

local toast = require("toast");
local colors = require("colors");
local stations = require('stationList')
local APRS = require("APRS")
local QSOs = require('QSOs')
local LatLon = require("latlon")
--local QSO = require('QSO')

print("APRSmap:Loading service and  APRSIS")
service = require("service")
APRSIS = require("APRSIS")

print("APRSmap:Loading osmTiles")
osmTiles = require("osmTiles")	-- This currently sets the Z order of the map
print("APRSmap:Loaded osmTiles="..tostring(osmTiles))

local myWidth, myHeight

local RenderPassCount, totalDrawCount, totalRenderCount, totalRenderTime = 0, 0, 0, 0
local lastRenderWhen = 0

if MOAIRenderMgr and type(MOAIRenderMgr.setCallback) == 'function' then	-- was setRenderCallback
	MOAIRenderMgr:setCallback(
				function(lastDrawCount, lastRenderCount, lastRenderTime)
					RenderPassCount = RenderPassCount + 1
					totalDrawCount = totalDrawCount + lastDrawCount
					totalRenderCount = totalRenderCount + lastRenderCount
					totalRenderTime = totalRenderTime + lastRenderTime
--local now = MOAISim.getDeviceTime()
--print("APRSmap:renderCallback["..RenderPassCount.."]:Draw:"..lastDrawCount.." Render:"..lastRenderCount.." in:"..math.floor(lastRenderTime*1000).."ms dt:"..math.floor((now-lastRenderWhen)*1000))
--lastRenderWhen = now
				end)
end

local memoryText, messageButton
local lastFrameCount = 0
if type(MOAISim.getElapsedFrames) == 'function' then
	lastFrameCount = MOAISim.getElapsedFrames()
elseif type(MOAIRenderMgr.getRenderCount	) == 'function' then
	lastFrameCount = MOAIRenderMgr.getRenderCount()
elseif type(MOAISim.getStepCount) == 'function' then
	lastFrameCount = MOAISim.getStepCount()
end
local lastMemoryTime = MOAISim.getDeviceTime()
local entryCount = 0

local hasProcStatm

local function getVirtualResident()
	if hasProcStatm == nil or hasProcStatm then
		local hFile, err = io.open("/proc/self/statm","r")
		if hFile and not err then
			local xmlText=hFile:read("*a"); -- read file content
			io.close(hFile);
			local s, e, virtual, resident = string.find(xmlText, "(%d+)%s(%d+)")
			if virtual and resident then
				hasProcStatm = true
				return tonumber(virtual)*4096, tonumber(resident)*4096
			else
				hasProcStam = false
			end
		else
			hasProcStatm = false
			print( err )
		end
	end
	return nil
end

local memoryLast = 0
local lastPerf = nil

local function updateMemoryUsage()
	local newCount = 0
	if type(MOAISim.getElapsedFrames) == 'function' then
		newCount = MOAISim.getElapsedFrames()
	elseif type(MOAIRenderMgr.getRenderCount	) == 'function' then
		newCount = MOAIRenderMgr.getRenderCount()
	elseif type(MOAISim.getStepCount) == 'function' then
		newCount = MOAISim.getStepCount()
	end
	local localCount = newCount - lastFrameCount
	lastFrameCount = newCount
	local now = MOAISim.getDeviceTime()
	local elapsed = now-lastMemoryTime
	local fps = 0
	if elapsed > 0 then
		fps = localCount / (now-lastMemoryTime)
	end
	lastMemoryTime = now
	local memuse = MOAISim:getMemoryUsage()
	if not (type(memuse._sys_vs) == 'number' and type(memuse._sys_rss) == 'number') then
		memuse._sys_vs, memuse._sys_rss = getVirtualResident()
	end

	local avgDraws, avgRenders, avgRenderTime, renderPercent = 0,0,0,0
	
	if MOAIRenderMgr
	and type(MOAIRenderMgr.setCallback) ~= 'function' then
--[[
	@lua	getPerformance
	@text	Returns an estimated frames per second and other performance counters 
			based on measurements taken at every render.

	@out	number fps		1 Estimated frames per second.
	@out	number seconds	2 Last ActionTree update duration
	@out	number seconds  3 Last NodeMgr update duration
	@out	number seconds  4 Last sim duration
	@out	number seconds  5 Last render duration
	@out	number count    6 Total render count
	@out	number seconds  7 Total render duration
]]
		if type(MOAISim.getPerformance) == 'function' then
			local newPerf = {MOAISim.getPerformance()}
			if not lastPerf then lastPerf = newPerf end
--[[
			local text = ''
			if #newPerf >= 5 then
				text = text..string.format("getPerformance:fps:%d msec(Action:%.2f Node:%.2f Sim:%.2f Render:%.2f)",
											newPerf[1], newPerf[2]*1000, newPerf[3]*1000, newPerf[4]*1000, newPerf[5]*1000)
				if #newPerf >= 7 then
					local deltaRender = newPerf[6]-lastPerf[6]
					local deltaRenderTime = (newPerf[7]-lastPerf[7])*1000
					if deltaRender > 0 then
						text = text..string.format(" Renders:%d*%.2f=%.2f",
												deltaRender, deltaRenderTime/deltaRender, deltaRenderTime)
					end
				end
			end
			if text ~= '' then print(text) end
]]
			if #newPerf == 7 then
				RenderPassCount = newPerf[6]-lastPerf[6]
				totalRenderCount = newPerf[6]-lastPerf[6]
				totalRenderTime = newPerf[7]-lastPerf[7]
			elseif #newPerf == 5 then
				avgRenders = 1
				avgRenderTime = newPerf[5]
			end
			lastPerf = newPerf
		end

		if type(MOAIRenderMgr.getPerformanceDrawCount) == 'function' then
			totalDrawCount = MOAIRenderMgr.getPerformanceDrawCount()
			if totalDrawCount > 0 then
				print("getPerformanceDrawCount returned "..tostring(totalDrawCount))
			end
		end
	end
	if RenderPassCount > 0 then
		avgDraws = totalDrawCount / RenderPassCount
		avgRenders = totalRenderCount / RenderPassCount
		avgRenderTime = totalRenderTime / RenderPassCount
	end
	if elapsed > 0 then
		renderPercent = totalRenderTime / elapsed * 100
	end
	local memoryNow = memuse.lua or 0
	local memoryDelta = (memoryNow - memoryLast) / 1024
	memoryLast = memoryNow
	local mbMult = 1/1024/1024
	local text
	if Application.viewWidth > Application.viewHeight then	-- wider screens get more info
		text = string.format('%.1f+%.1f=%.1fMB%s fps:%.1f/%.1f/%i %i(%i)@%.1fms=%.1f%%',
								memuse.lua*mbMult,
								memuse.texture*mbMult,
								memuse.total*mbMult,
	((type(memuse._sys_vs) == 'number' and type(memuse._sys_rss) == 'number')
		and ("("..math.floor(memuse._sys_rss*mbMult).."/"..math.floor(memuse._sys_vs*mbMult).."MB)")
		or ""),
								fps, MOAISim.getPerformance(), RenderPassCount,
								avgRenders, avgDraws, avgRenderTime*1000, renderPercent)
		text = text..string.format(" Delta:%.2fKB", memoryDelta)
	else text = string.format('%.0f+%.0f=%.0fMB%s %ifps %i(%i)=%.0f%%',
								memuse.lua*mbMult,
								memuse.texture*mbMult,
								memuse.total*mbMult,
	((type(memuse._sys_vs) == 'number' and type(memuse._sys_rss) == 'number')
		and ("("..math.floor(memuse._sys_rss*mbMult).."/"..math.floor(memuse._sys_vs*mbMult).."MB)")
		or ""),
								RenderPassCount,
								avgRenders, avgDraws, renderPercent)
	end
	RenderPassCount, totalDrawCount, totalRenderCount, totalRenderTime = 0, 0, 0, 0

	if memoryText then
		--if debugging then print(os.date("%H:%M:%S ")..text)
--		if debugging or (Application and type(Application.isDesktop) == 'function' and Application:isDesktop()) then
--			print(text)
--		end
		memoryText:setString(text)
--		memoryText:fitSize()
--		memoryText:setLoc(Application.viewWidth/2, 55*config.Screen.scale)
		--memoryText:fitSize(#text)
	else print(text)
	end
end
performWithDelay2("updateMemoryUsage", 1000, updateMemoryUsage, 0)

local function positionMessageButton(width, height)
    if messageButton then messageButton:setRight(width-10) messageButton:setTop(50*config.Screen.scale) end
end

local function runQSOsButton(layer, myWidth, myHeight)
	local function checkQSOsButton()
		local current = SceneManager:getCurrentScene()
		local new = QSOs:getMessageCount()	-- Get all new message count
		if current.name == 'APRSmap' then	-- Only if I'm current
			if new > 0 then
				if not messageButton then
					local alpha = 0.75
					messageButton = Button {
						text = "QSOs",
						red=0*alpha, green=240/255*alpha, blue=0*alpha, alpha=alpha,
						size = {100, 66},
						layer=layer, priority=2100000000,
						onClick = function()
										SceneManager:openScene("QSOs_scene", {animation = "popIn", backAnimation = "popOut", })
									end,
					}
					messageButton:setScl(config.Screen.scale,config.Screen.scale,1)
					positionMessageButton(Application.viewWidth, Application.viewHeight)
					--messageButton:setRight(myWidth-10) messageButton:setTop(50*config.Screen.scale)
				end
			elseif messageButton then
				--layer:getPartition():removeProp(messageButton)
				messageButton:dispose()
				messageButton = nil
			end
			performWithDelay2("checkQSOs",5000,checkQSOsButton)
		elseif messageButton then
			--layer:getPartition():removeProp(messageButton)
			messageButton:dispose()
			messageButton = nil
		end
	end
	performWithDelay(1000,checkQSOsButton)
end

local function resizeHandler ( width, height )
	myWidth, myHeight = width, height
	--print('APRSmap:onResize:'..tostring(width)..'x'..tostring(height))
	APRSmap.backLayer:setSize(width,height)
	if service then service:mapResized(width,height) end
	tileLayer:setSize(width,height)
	layer:setSize(width,height)
	positionMessageButton(width, height)
	stilltext:setLoc(stilltext:getWidth()/2+config.Screen.scale, height-stilltext:getHeight()/2)		--0*config.Screen.scale)
	whytext:setLoc ( width/2, height-32*config.Screen.scale )
	gpstext:setLoc ( width/2, height-65*config.Screen.scale )
	speedtext:setRight(width) speedtext:setTop(125*config.Screen.scale)
	memoryText:setLoc ( width/2, 55*config.Screen.scale)
	lwdtext:setLoc ( width/2, 80*config.Screen.scale )	-- was 75
	if kisstext then kisstext:setLoc ( width/2, 105*config.Screen.scale ) end	-- was 90
	if temptext then temptext:setLoc ( width/2, height/2 ) end
	if pxytext then pxytext:setLoc ( width/2, 95*config.Screen.scale ) end
--	if titleBackground then
--		titleGroup:removeChild(titleBackground)
--		titleBackground:dispose()
--	end
	titleBackground:setSize(width,40*config.Screen.scale)
--	titleBackground = Graphics {width = width, height = 40*config.Screen.scale, left = 0, top = 0}
--    titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
--	titleBackground:setPriority(2000000000)
--	titleGroup:addChild(titleBackground)
	local x,y = titleText:getSize()
	titleText:setLoc(width/2, 25*config.Screen.scale)
	if osmTiles then osmTiles:setSize(width, height) end
end

local function dumpTable(k,v)
	print(tostring(k)..':'..tostring(v))
	if type(v) == 'table' then
		for k1,v1 in pairs(v) do
			dumpTable(k..'.'..k1, v1)
		end
	end
end

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

local function showGPX(gpxFile, color, width, alpha)
	local xmlapi = require( "xml" ).newParser()
	local gpx = xmlapi:loadFile( gpxFile, "." )
	if not gpx then return gpx end
	simplified = xmlapi:simplify( gpx )
	--print(printableTable(gpxFile, simplified))
	--dumpTable(gpxFile, simplified)
	return dumptracks(simplified, color, width, alpha, gpxFile)
end

local function getGPXs()
	return gpxFiles
end

local function countGPX()
	return #gpxFiles
end

local function isGPXVisible()
	return gpxVisible
end

local function showGPXs()
	if not gpxVisible then
		for i,p in pairs(gpxFiles) do
			osmTiles:showPolygon(p,p.stationID)
		end
		gpxVisible = true
	end
end

local function hideGPXs()
	if gpxVisible then
		for i,p in pairs(gpxFiles) do
			osmTiles:removePolygon(p)
		end
		gpxVisible = false
	end
end

function onStart()
    print("APRSmap:onStart()")

	local iniLat, iniLon, iniZoom = 27.996683, -80.659083, 12
	if tonumber(config.lastMapLat) then iniLat = tonumber(config.lastMapLat) end
	if tonumber(config.lastMapLon) then iniLon = tonumber(config.lastMapLon) end
	if tonumber(config.lastMapZoom) then iniZoom = tonumber(config.lastMapZoom) end
	print("APRSmap:Starting osmTiles")
	osmTiles:start()
	print('APRSmap:moveTo:'..iniLat..' '..iniLon..' zoom:'..iniZoom)
	if debugging then
		osmTiles:moveTo(iniLat, iniLon, iniZoom)
	else
		local s, text = pcall(osmTiles.moveTo, osmTiles, iniLat, iniLon, iniZoom)
		if not s then print("APRSmap:onStart:moveTo Failed with "..tostring(text)) end
	end

	local iniScale = 1
	if tonumber(config.lastMapScale) then iniScale = tonumber(config.lastMapScale) end
	print('APRSmap:setTileScale:'..iniScale)
	osmTiles:setTileScale(iniScale)

	local iniAlpha = 0.5
	if tonumber(config.lastMapAlpha) then iniAlpha = tonumber(config.lastMapAlpha) end
	print('APRSmap:setTileAlpha:'..iniAlpha)
	osmTiles:setTileAlpha(iniAlpha)

	osmTiles:showLabels(not config.lastLabels)	-- lastLabels flags suppression

	print("APRSmap:setupME w/osmTiles")
	stations:setupME(osmTiles)	-- Have to tell the station list about the map module

	print("APRSmap:starting service and APRSIS w/config")
	service:start(config)
	APRSIS:start(config)
	
	--showGPX("TripleN.gpx")
	--showGPX("R4R_100_309nodes.gpx", "crimson", 9)
	--showGPX("R4R_60_226nodes.gpx", "darkgreen", 7)
	--showGPX("R4R_30_106nodes.gpx", "red", 5)
	--showGPX("R4R_10_64nodes.gpx", "darkcyan", 3)
	--showGPX("CTC2015-100.gpx", "darkgreen", 9)
	--showGPX("CTC2015-062.gpx", "red", 5)
	--showGPX("HH100-2015_406nodes.gpx", "crimson", 9)
	--showGPX("HH70-2015_306nodes.gpx", "darkgreen", 6)
	--showGPX("HH35-2015_304nodes.gpx", "red", 3)
	--showGPX("R4R_10_64nodes.gpx", "crimson", 9)
	gpxFiles = {}
	gpxVisible = true
--	gpxFiles[#gpxFiles+1] = showGPX("2016_TDC_101_360nodes.gpx", "crimson", 9)
--	gpxFiles[#gpxFiles+1] = showGPX("2016_TDC_63_202nodes.gpx", "darkgreen", 7)
--	gpxFiles[#gpxFiles+1] = showGPX("2016_TDC_50_170nodes.gpx", "red", 5)
--	gpxFiles[#gpxFiles+1] = showGPX("2016_TDC_25_170nodes.gpx", "darkcyan", 3)

--	gpxFiles[#gpxFiles+1] = showGPX("2017TDC_101_mi_386nodes.gpx", "crimson", 9)
--	gpxFiles[#gpxFiles+1] = showGPX("2017TDC_63_mi_278nodes.gpx", "darkgreen", 7)
--	gpxFiles[#gpxFiles+1] = showGPX("2017TDC_50_mi_250nodes.gpx", "red", 5)
--	gpxFiles[#gpxFiles+1] = showGPX("2017TDC_25_mi_200nodes.gpx", "darkcyan", 3)

	--gpxFiles[#gpxFiles+1] = showGPX("2016_R4R_100_MilesA_316nodes.gpx", "crimson", 9)
	--gpxFiles[#gpxFiles+1] = showGPX("2016_R4R_60_MilesA_170nodes.gpx", "darkgreen", 7)
	--gpxFiles[#gpxFiles+1] = showGPX("2016_R4R_30_MilesA_130nodes.gpx", "red", 5)
	--gpxFiles[#gpxFiles+1] = showGPX("2016_R4R_10_MilesA_64nodes.gpx", "darkcyan", 3)

	performWithDelay(1000, function()

--		table.insert(gpxFiles,showGPX("TSE-2017-August-21-Umbral-Path.gpx", "crimson", 9, 0.6))
	
--		table.insert(gpxFiles,showGPX("2017_-_101_mi_TDC_462nodes.gpx", "crimson", 9, 0.6))
--		table.insert(gpxFiles,showGPX("2017_-_63_mi_TDC_340nodes.gpx", "darkgreen", 7, 0.5))
--		table.insert(gpxFiles,showGPX("2017_-_50_mi_TDC_330nodes.gpx", "red", 5, 0.4))
--		table.insert(gpxFiles,showGPX("2017_-_25_mi_TDC_354nodes.gpx", "darkblue", 3, 0.3))
--		table.insert(gpxFiles,showGPX("2017_-_10_mi_TDC_190nodes.gpx", "purple", 1, 0.2))

--		table.insert(gpxFiles,showGPX("5-SWFL_TdC-100_Mile_Route-Red+_266nodes.gpx", "red", 9, 0.6))
--		table.insert(gpxFiles,showGPX("4-SWFL_TdC-62_Mile_Route-Orange+_242nodes.gpx", "orange", 7, 0.5))
--		table.insert(gpxFiles,showGPX("3-SWFL_TdC-35_Mile_Route-Green+_196nodes.gpx", "green", 5, 0.4))
--		table.insert(gpxFiles,showGPX("2-SWFL_TdC-20_Mile_Route-Purple+_140nodes.gpx", "purple", 3, 0.3))
--		table.insert(gpxFiles,showGPX("1-SWFL_TdC-10_Mile_Route-Blue+_96nodes.gpx", "blue", 1, 0.2))

--		table.insert(gpxFiles,showGPX("2016MSC_102_400nodes.gpx", "crimson", 9, 0.6))
--		table.insert(gpxFiles,showGPX("2016MSC_77_252nodes.gpx", "darkgreen", 7, 0.5))
--		table.insert(gpxFiles,showGPX("2016MSC_50_206nodes.gpx", "red", 5, 0.4))
--		table.insert(gpxFiles,showGPX("2016MSC_21_83nodes.gpx", "darkblue", 3, 0.3))

		local function addGPX(path)
			if path then table.insert(gpxFiles,path) end
		end

		addGPX(showGPX("2017R4R/2017_R4R_60_Mile_Actual_63_342nodes.gpx", "crimson", 9, 0.6))
		addGPX(showGPX("2017R4R/2017_R4R_30_Mile_Actual_33_186nodes.gpx", "darkgreen", 7, 0.5))
		addGPX(showGPX("2017R4R/2017_R4R_10_Mile_Actual_10_138nodes.gpx", "red", 5, 0.4))
		addGPX(showGPX("2017R4R/2017_R4R_3.5_Mile_Actual_3.5_50nodes.gpx", "darkblue", 3, 0.3))


--		table.insert(gpxFiles,showGPX("Panhandle_96nodes.gpx", "crimson", 9, 0.4))

		hideGPXs()
	end)
	--gpxFiles[#gpxFiles+1] = showGPX("TripleN.gpx", "crimson", 9)

--	gpxFiles[#gpxFiles+1] = showGPX("PA-East-1000-1000.gpx", "darkcyan", 6, 1)
--	gpxFiles[#gpxFiles+1] = showGPX("PA-West-1000-1000.gpx", "crimson", 3, 1)

end

--[[

function osmTiles:getCenter()
	return tileGroup.lat, tileGroup.lon, zoom

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
self.distanceTo = function(point, precision)
self.bearingTo = function(point)
self.destinationPoint = function(brng, dist)	/* Dist in km */
function milesToKm(v)
function kmToMiles(v)
]]
local function gpxWalker(gpx, i, wasLat, wasLon, startTiles)
	print("gpxWalker:"..tostring(i).."/"..tostring(#gpx))
	if i < #gpx then
		local count = osmTiles:getQueueStats()
		local tolat, tolon = wasLat, wasLon
		local atlat, atlon = osmTiles:getCenter()
		if atlat == tolat and atlon == tolon then	-- Only keep going if no one panned the map!
			if count <= 0 then
				tolat, tolon = gpx[i], gpx[i+1]
				local hRange, vRange = osmTiles:rangeLatLon()
				local mRange = math.min(hRange,vRange)
				local atPoint = LatLon.new(atlat, atlon)
				local toPoint = LatLon.new(tolat, tolon)
				local dist = kmToMiles(atPoint.distanceTo(toPoint))
				if dist > mRange/2 then	-- Goes outside circle, adjust along path
					local bearing = atPoint.bearingTo(toPoint)
					local usePoint = atPoint.destinationPoint(bearing, milesToKm(mRange/2))
					print("gpxWalker:Split distance, "..tostring(dist).." too far, using "..tostring(mRange))
					tolat, tolon = usePoint.getlat(), usePoint.getlon()
				else
					local j
					local mDist = dist	-- remember the furthest we moved away
					i = i + 2	-- We made it to this point!
					for j=i,#gpx,2 do
						local tlat, tlon = gpx[j], gpx[j+1]
						local tPoint = LatLon.new(tlat,tlon)
						local tDist = kmToMiles(atPoint.distanceTo(tPoint))
						if tDist > mRange/4 or tDist < mDist then	-- Don't let it go too far or get closer
							if j > i then	-- Make sure we're skipping at least one
								i = j		-- Pick up at this point next time
								j = j - 2	-- Back to the previoulsy ok point
								tolat, tolon = gpx[j], gpx[j+1]
							end
							break
						end
						mDist = tDist
					end
				end
				osmTiles:moveTo(tolat, tolon)
			else print("gpxWalker:"..tostring(count).." Pending Tiles")
			end
			performWithDelay(500, function() gpxWalker(gpx,i,tolat,tolon,startTiles) end)
			osmTiles:showCrosshair()
		else toast.new("GpxWalk Aborted!  "..tostring(osmTiles:getTilesLoaded()-startTiles).." Loaded")
		end
	else toast.new("GpxWalk Complete!  "..tostring(osmTiles:getTilesLoaded()-startTiles).." Loaded")
	end
end

local function walkGPX(g)
	if g > 0 and g <= #gpxFiles then
		local gpx = gpxFiles[g]
		toast.new("Walking "..gpx.stationID, 5000)
		local lat, lon = gpx[1], gpx[2]
		osmTiles:moveTo(lat, lon)	-- Jump to the starting point
		performWithDelay(500, function() gpxWalker(gpx, 3, lat, lon, osmTiles:getTilesLoaded()) end)
	end
end

function onResume()
    print("APRSmap:onResume()")
	if Application.viewWidth ~= myWidth or Application.viewHeight ~= myHeight then
		print("APRSmap:onResume():Resizing...")
		resizeHandler(Application.viewWidth, Application.viewHeight)
	end
	runQSOsButton(layer, Application.viewWidth, Application.viewHeight)
end

function onPause()
    print("APRSmap:onPause()")
end

function onStop()
    print("APRSmap:onStop()")
end

function onDestroy()
    print("APRSmap:onDestroy()")
end

function onEnterFrame()
    --print("onEnterFrame()")
end

function onKeyDown(event)
    print("APRSmap:onKeyDown(event)")
	print(printableTable("KeyDown",event))
	if event.key then
		print("processing key "..tostring(event.key))
		if event.key == 615 or event.key == 296 then	-- Down, zoom out
			osmTiles:deltaZoom(-1)
		elseif event.key == 613 or event.key == 294 then	-- Up, zoom in
			osmTiles:deltaZoom(1)
		elseif event.key == 612 or event.key == 293 then	-- Left, fade out
			osmTiles:deltaTileAlpha(-0.1)
		elseif event.key == 614 or event.key == 295 then	-- Right, fade in
			osmTiles:deltaTileAlpha(0.1)
		elseif event.key == 112 then		-- P = Print
			MOAIRenderMgr.grabNextFrame ( MOAIImage.new(), function ( img ) img:write ( 'APRSISMO-capture.png' ) end )
		end
	end
end

function onKeyUp(event)
    print("APRSmap:onKeyUp(event)")
	print(printableTable("KeyUp",event))
end

local touchDowns = {}
local startPinchD = 0
local pinchDelta = 120*config.Screen.scale

local function getTouchCount()
	if MOAIInputMgr.device.touch then
		if MOAIInputMgr.device.touch.countTouches then
			return MOAIInputMgr.device.touch:countTouches()
		elseif MOAIInputMgr.device.touch.getActiveTouches then
			local touches = {MOAIInputMgr.device.touch:getActiveTouches()}
			return #touches
		end
	end
	return 0
end

function pinchDistance()
	local touches = {MOAIInputMgr.device.touch:getActiveTouches()}
	if #touches == 2 then
		local x1, y1, t1 = MOAIInputMgr.device.touch:getTouch(touches[1])
		local x2, y2, t2 = MOAIInputMgr.device.touch:getTouch(touches[2])
		local dx, dy = x2-x1, y2-y1
		local d = math.sqrt(dx*dx+dy*dy)
--print(string.format("APRSmap:onTouchMove:dx=%i dy=%i d=%i", dx, dy, d))
		return d
	end
	return nil
end

function onTouchDown(event)
	local touchCount = getTouchCount()
	local wx, wy = layer:wndToWorld(event.x, event.y, 0)
    print("APRSmap:onTouchDown(event)["..tostring(event.idx).."]@"..tostring(wx)..','..tostring(wy).." "..tostring(touchCount).." touches")
--    print("APRSmap:onTouchDown(event)["..tostring(event.idx).."]@"..tostring(wx)..','..tostring(wy)..printableTable(' onTouchDown', event))
	touchDowns[event.idx] = {x=event.x, y=event.y}
	if touchCount == 2 then
		startPinchD = pinchDistance()
	else
--		osmTiles:getTileGroup():setScl(1,1,1)
		tileLayer:setLoc(0,0)
		tileLayer:setScl(1,1,1)
	end
end

function onTouchUp(event)
	local touchCount = getTouchCount()
	local wx, wy = layer:wndToWorld(event.x, event.y, 0)
    print("APRSmap:onTouchUp(event)["..tostring(event.idx).."]@"..tostring(wx)..','..tostring(wy).." "..tostring(touchCount).." touches")
--    print("APRSmap:onTouchUp(event)["..tostring(event.idx).."]@"..tostring(wx)..','..tostring(wy)..printableTable(' onTouchUp', event))
	if touchDowns[event.idx] then
		local dy = event.y - touchDowns[event.idx].y
		if math.abs(dy) > Application.viewHeight * 0.10 then
			local dz = 1
			if dy > 0 then dz = -1 end
--[[			osmTiles:deltaZoom(dz)
		else
			config.lastDim = not config.lastDim
			if config.lastDim then	-- Dim
				backLayer:setClearColor ( 0,0,0,1 )	-- Black background
			else	-- Bright
				backLayer:setClearColor ( 1,1,1,1 )	-- White background
			end
]]		end
	end
--[[
		local props = {layer:getPartition():propListForPoint(wx, wy, 0, sortMode)}
		for i = #props, 1, -1 do
			local prop = props[i]
			if prop:getAttr(MOAIProp.ATTR_VISIBLE) > 0 then
				print('APRSmap:Found prop..'..tostring(prop)..' with '..tostring(type(prop.onTap)))
			end
		end
]]
--    SceneManager:closeScene({animation = "popOut"})
	touchDowns[event.idx] = nil
	local count = 0
	for i,t in pairs(touchDowns) do
		count = count + 1
	end
	if touchCount ~= 2 or count ~= 2 then
--		osmTiles:getTileGroup():setScl(1,1,1)
		tileLayer:setLoc(0,0)
		tileLayer:setScl(1,1,1)
	end
end

function onTouchMove(event)
	local touchCount = getTouchCount()
	if touchDowns[event.idx] then
		local dx = (event.x - touchDowns[event.idx].x)
		local dy = (event.y - touchDowns[event.idx].y)
--		print(string.format('APRSmap:onTouchMove:dx=%i dy=%i moveX=%i moveY=%i (%i touches)', dx, dy, event.moveX, event.moveY, touchCount))
		if touchCount <= 1 then
			osmTiles:deltaMove(event.moveX, event.moveY)
		elseif touchCount == 2 then
			local touches = {MOAIInputMgr.device.touch:getActiveTouches()}
			if #touches == 2 then
				local x1, y1, t1 = MOAIInputMgr.device.touch:getTouch(touches[1])
				local x2, y2, t2 = MOAIInputMgr.device.touch:getTouch(touches[2])
				local dx, dy = x2-x1, y2-y1
				local d = math.sqrt(dx*dx+dy*dy)
				local delta = d-startPinchD
--print(string.format("APRSmap:onTouchMove:dx=%i dy=%i d=%.2f vs %.2f Delta=%.2f", dx, dy, d, startPinchD, delta))
				if math.abs(math.modf(delta/pinchDelta)) >= 1 then
					osmTiles:deltaZoom(math.modf(delta/pinchDelta))
					startPinchD = startPinchD + math.modf(delta/pinchDelta)*pinchDelta
				end
				local scale = 2^((d-startPinchD)/pinchDelta)
				tileLayer:setScl(scale,scale,1)
				local width, height = tileLayer:getSize()
				local nw, nh = width*scale, height*scale
--print(string.format('APRSmap:onTouchMove: %i x %i *%.2f %i x %i off:%i %i', width, height, scale, nw, nh, xo, yo))
				tileLayer:setLoc((width-nw)/2,(height-nh)/2)
			end
		end
	end
end

local objectCounts

function onCreate(e)
	print('APRSmap:onCreate')
--[[
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?()&/-"
	local index = 1
	local sprite, temptext, sizetext
	local paused = false
	performWithDelay(1000, function()
	if not paused then
	local c = chars:sub(index,index)
	index = index + 1
	if index > #chars then index = 1 end
	if sprite then sprite:dispose() end
	if sizetext then sizetext:dispose() end
	if temptext then temptext:dispose() end
	print("Doing:"..c)
	local font = FontManager:getRecentFont()
	local fontImage, xBearing, yBearing = font:getGlyphImage(c, 18*.7)
	if fontImage then
		local width, height = fontImage:getSize()
		fontImage:drawLine(0,yBearing,width-1,yBearing,0,0,0,1.0)
		fontImage:drawLine(0,yBearing+1,width-1,yBearing+1,0,0,0,1.0)
		fontImage:drawLine(0,height-1,width-1,height-1,0,0,0,1.0)
		fontImage:drawLine(xBearing,0,xBearing,height-1,0,0,0,1.0)
		sprite = Sprite{texture=fontImage, layer=layer}
		print("getGlyphImage("..c..") returned "..tostring(fontImage).." size "..sprite:getWidth().." x "..sprite:getHeight().." Bearing:"..xBearing.." "..yBearing)
		--sprite:setColor(1,0,0,0.5)
		sprite:setLeft(0) sprite:setTop(titleBackground:getBottom())
		sprite:addEventListener( "touchUp", function() paused = not paused end )
	sizetext = TextLabel { text=tostring(width)..'x'..tostring(height)..' '..tostring(xBearing)..' '..tostring(yBearing), layer=layer }
	sizetext:setColor(0,0,0, 1.0)
	sizetext:fitSize()
	sizetext:setLeft(sprite:getRight()) sizetext:setTop(sprite:getTop()+sprite:getHeight()/2)

	end
	temptext = TextLabel { text=c..".", layer=layer, textSize=18*.7 }
	temptext:setColor(0,0,0, 1.0)
	temptext:fitSize()
	temptext:setLeft(0) temptext:setTop(sprite:getBottom())
	end
	end, 0)
end
]]

	print("APRSmap:setting APRS callbacks")
	APRS:addReceiveListener(stations.packetReceived)

	print("APRSmap:setting APRSIS callbacks")
	APRSIS:setAppName(MOAIEnvironment.appDisplayName,MOAIEnvironment.appVersion)
	APRSIS:setPacketCallback(function(line, port) APRS:received(line,port) end)	-- Tie the two together!
	APRSIS:setConnectedCallback(function(clientServer) print("APRSmap:connected:"..tostring(clientServer)) end)

	local width, height = Application.viewWidth, Application.viewHeight
	myWidth, myHeight = width, height

	scene.getGPXs = getGPXs
	scene.countGPX = countGPX
	scene.walkGPX = walkGPX
	scene.isGPXVisible = isGPXVisible
	scene.showGPXs = showGPXs
	scene.hideGPXs = hideGPXs
	scene.resizeHandler = resizeHandler
	scene.menuHandler = function()
							SceneManager:openScene("buttons_scene", {animation="overlay"})
						end

	APRSmap.backLayer = Layer {scene = scene }
	if type(APRSmap.backLayer.setClearColor) == 'function' then 
	if config.lastDim then	-- Dim
		APRSmap.backLayer:setClearColor ( 0,0,0,1 )	-- Black background
	else	-- Bright
		APRSmap.backLayer:setClearColor ( 1,1,1,1 )	-- White background
	end
	else print('setClearColor='..type(APRSmap.backLayer.setClearColor))
	end

	tileLayer = Layer { scene = scene, touchEnabled = true }
	--tileLayer:setAlpha(0.9)
	local alpha = 0.75
	alpha = 1.0
	tileLayer:setColor(alpha,alpha,alpha,alpha)
	osmTiles:getTileGroup():setLayer(tileLayer)

    layer = Layer {scene = scene, touchEnabled = true }
	local textColor = {0,0,0,1}
	
--	stilltext = TextLabel { text="nil\n hh:mm:ss. ", layer=layer, textSize=28*config.Screen.scale }
	stilltext = TextBackground { text="nil\n hh:mm:ss. ", layer=layer, textSize=28*config.Screen.scale }
_G["stilltext"] = stilltext
	stilltext:setColor(unpack(textColor))
	stilltext:fitSize()
	stilltext:setAlignment ( MOAITextBox.LEFT_JUSTIFY )
	stilltext:setLoc(stilltext:getWidth()/2+config.Screen.scale, height-stilltext:getHeight()/2)		--0*config.Screen.scale)
	stilltext:setPriority(2000000000)

--	lwdtext = TextLabel { text="lwdText", layer=layer, textSize=20*config.Screen.scale }
	lwdtext = TextBackground { text="lwdText", layer=layer, textSize=math.floor(20*config.Screen.scale+0.5) }
--	local font = MOAIFont.new ()
--	if Application:isDesktop() then
--		font:load ( "cour.ttf" )
--	else
--		font:load ( "courbd.ttf" )
--	end
--	lwdtext:setFont(font)
--	lwdtext:setBackgroundRGBA(0.75, 0.75, 0.75, 0.75)
_G["lwdtext"] = lwdtext
--	lwdtext:setColor(0.25, 0.25, 0.25, 1.0)
	lwdtext:setColor(unpack(textColor))
--	lwdtext:setBackgroundRGBA(0.25, 0.25, 0.25, 0.25)
	lwdtext:fitSize()
	--lwdtext:setWidth(width)
	lwdtext:setAlignment ( MOAITextBox.CENTER_JUSTIFY )	-- Was CENTER_JUSTIFY (LEFT might fix dropped trailer)
	lwdtext:setLoc(width/2, 75*config.Screen.scale)
local x,y = lwdtext:getSize()
	lwdtext:setPriority(2000000000)

if MOAIAppAndroid and type(MOAIAppAndroid.setBluetoothDevice) == 'function' then
if MOAIAppAndroid and type(MOAIAppAndroid.setBluetoothEnabled) == 'function' then
	kisstext = TextBackground { text="KISS Placeholder", layer=layer, textSize=20*config.Screen.scale }
_G["kisstext"] = kisstext
	kisstext:setColor(unpack(textColor))
	kisstext:fitSize()
	--kisstext:setWidth(width)
	kisstext:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	kisstext:setLoc(width/2, 95*config.Screen.scale)
local x,y = kisstext:getSize()
	kisstext:setPriority(2000000000)
end
end

--	if config.StationID:sub(1,6) == 'KJ4ERJ' then

		temptext = TextBackground { text="tempText", layer=layer, textSize=24*config.Screen.scale }
		local font = MOAIFont.new ()
		if Application:isDesktop() then
			font:load ( "cour.ttf" )
		else
			font:load ( "courbd.ttf" )
		end
		temptext:setFont(font)
	_G["temptext"] = temptext
		temptext:setColor(unpack(textColor))
		temptext:fitSize()
		temptext:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		temptext:setLoc(width/2, height/2)
		temptext:setPriority(2000000000)
--	end

	if config.Debug.RunProxy then
		pxytext = TextBackground { text="pxyText", layer=layer, textSize=20*config.Screen.scale }
	_G["pxytext"] = pxytext
		pxytext:setColor(unpack(textColor))
		pxytext:fitSize()
		--pxytext:setWidth(width)
		pxytext:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		pxytext:setLoc(width/2, 95*config.Screen.scale)
	local x,y = pxytext:getSize()
		pxytext:setPriority(2000000000)
	end

	whytext = TextBackground { text="whyText", layer=layer, textSize=32*config.Screen.scale }
_G["whytext"] = whytext
	whytext:setColor(unpack(textColor)) --0.5, 0.5, 0.5, 1.0)
	whytext:fitSize()
	--whytext:setWidth(width)
	whytext:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	whytext:setLoc(width/2, height-32*config.Screen.scale)
local x,y = whytext:getSize()
	whytext:setPriority(2000000000)

	gpstext = TextBackground { text="gpsText", layer=layer, textSize=22*config.Screen.scale }
_G["gpstext"] = gpstext
	gpstext:setColor(unpack(textColor)) --0.5, 0.5, 0.5, 1.0)
	gpstext:fitSize()
	gpstext:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	gpstext:setLoc(width/2, height-65*config.Screen.scale)
	gpstext:setPriority(2000000000)

	speedtext = TextLabel { text="199", layer=layer, textSize=80*config.Screen.scale, align={"center","top"} }
_G["speedtext"] = speedtext
	speedtext:setColor(unpack(textColor))
	speedtext:fitSize()
	--speedtext:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	speedtext:setRight(width) speedtext:setTop(125*config.Screen.scale)
	--speedtext:setLoc(width/2, height-65*config.Screen.scale)
	speedtext:setPriority(2000000000)
	speedtext:setString("")
	speedtext:addEventListener('touchUp', function() print("speed touched!") end)
--[[	performWithDelay(1000,function()
			local speed = math.random(0,110)
			if speed < 10 then speed = string.format("%.1f",speed) else speed = tostring(math.floor(speed)) end
			print("new speed="..speed)
			speedtext:setString(speed)
		end, 0)
]]

	memoryText = TextBackground { text="memoryText", layer=layer, textSize=20*config.Screen.scale }
	memoryText:setColor(unpack(textColor))
	memoryText:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	memoryText:setLoc(width/2, 55*config.Screen.scale)
--	memoryText:setPriority(2000000000)
	memoryText:setPriority(1999999999)
	memoryText:addEventListener("touchUp",
			function()
				print("Collecting Garbage")
if Application:isDesktop() then
				stations:clearStations()
end
				MOAISim:forceGarbageCollection()	-- This does it iteratively!
if Application:isDesktop() then
	print ( "REPORTING HISTOGRAM" )
	if type(MOAISim.reportHistrogram) == 'function' then MOAISim.reportHistogram () end
	MOAISim.reportLeaks(true)	-- report leaks and reset the bar for next time
	print ()
	
	if not objectCounts then objectCounts = {} end
	local didOne = false
	local histogram = MOAISim.getHistogram ()
	for k, v in pairs ( histogram ) do
		if objectCounts[k] and objectCounts[k] ~= v then
			print('memoryText:Delta('..tostring(v-objectCounts[k])..') '..k..' objects')
			didOne = true
		end
		objectCounts[k] = v
	end
	if didOne then print() end
end
				print("memoryText:touchUp\n")
				updateMemoryUsage()
			end)

			
    titleGroup = Group { layer=layer }
	titleGroup:setLayer(layer)

	titleGradientColors = { "#BDCBDC", "#BDCBDC", "#897498", "#897498" }
--	local colors = { "#DCCBBD", "#DCCBBD", "#987489", "#987489" }
 --	{ 189, 203, 220, 255 }, 
--	{ 89, 116, 152, 255 }, "down" )

    -- Parameters: left, top, width, height, colors
    --titleBackground = Mesh.newRect(0, 0, width, 40, titleGradientColors )
	titleBackground = Graphics {width = width, height = 40*config.Screen.scale, left = 0, top = 0}
    --titleBackground:setPenColor(0.707, 0.8125, 0.8125, 0.75):fillRect()	-- 181,208,208 from OSM zoom 0 map
    titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
	titleBackground:setPriority(2000000000)
	titleGroup:addChild(titleBackground)

	titleText = TextLabel { text="APRSISMO", textSize=28*config.Screen.scale }
	titleText:fitSize()
	titleText:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	titleText:setLoc(width/2, 20*config.Screen.scale)
	titleText:setPriority(2000000001)
	titleGroup:addChild(titleText)
	--titleGroup:setRGBA(1,1,1,0.75)
_G["titleText"] = titleText

    --titleGroup:resizeForChildren()
	--titleGroup:setLoc(0,0)
	titleGroup:addEventListener("touchUp",
			function()
				print("Tapped TitleGroup")
				scene.menuHandler()
--[[
				local text = tostring(MOAIEnvironment.appDisplayName)..' '..tostring(MOAIEnvironment.appVersion)
				text = text..' @ '..tostring(MOAIEnvironment.screenDpi)..'dpi'
				text = text..'\r\ncache:'..tostring(MOAIEnvironment.cacheDirectory)
				text = text..'\r\ndocument:'..tostring(MOAIEnvironment.documentDirectory)
				text = text..'\r\nextCache:'..tostring(MOAIEnvironment.externalCacheDirectory)
				text = text..'\r\nextFiles:'..tostring(MOAIEnvironment.externalFilesDirectory)
				text = text..'\r\nresource:'..tostring(MOAIEnvironment.resourceDirectory)
				toast.new(text)
				print(text)
]]
			end)
			
	performWithDelay(1000, function()
		updateCommands()	-- get the config applied
		updateBluetooth()	-- get the config applied
		updateGPSEnabled()	-- get the config applied
		updateKeepAwake()	-- get the config applied
		updateTelemetryEnabled()	-- get the config applied
	end)
	
--[[
	testWedge = Graphics { layer=layer, left=0, top=0, width=100, height=100 }
	testWedge:setPenColor(0,0,0,0.25):setPenWidth(1):fillFan({0,0,100,90,90,100,75,200,0,0})
	--testWedge:setScl(2,2,2)
	testWedge:setPriority(3000000)
]]

	local temps = {}
	local function ctof(v) return v/10*9/5+32 end
	local function addTemp(stationID, which, name, convert, fmt)
		table.insert(temps,{ID=stationID, which=which, name=name, f=(convert or ctof), fmt=(fmt or "%4.1f")})
	end

	if config.StationID:sub(1,6) == 'KJ4ERJ'
--	and config.StationID ~= "KJ4ERJ-TS"
	and config.StationID ~= "KJ4ERJ-LS" then

		addTemp("KJ4ERJ-TD", 1, "Power", function(v) return v/10 end)
		addTemp("KJ4ERJ-S1", 3, "Server")
		addTemp("KJ4ERJ-E1", 3, "Return")
		addTemp("KJ4ERJ-E1", 4, "Kitchen")
		addTemp("KJ4ERJ-E1", 5, "Thermo")
		addTemp("KJ4ERJ-TD", 5, "TEDTemp", function(v) return v/10 end)
		addTemp("KJ4ERJ-E2", 3, "Office")
		addTemp("KJ4ERJ-E2", 4, "Ambient")
		addTemp("KJ4ERJ-E2", 5, "Guest")
		addTemp("KJ4ERJ-E3", 4, "Family")
		addTemp("KJ4ERJ-MB", 3, "Master")
		addTemp("KJ4ERJ-HW", 3, "Garage")
		addTemp("KJ4ERJ-HP", 3, "Butter")
		addTemp("KJ4ERJ-E3", 3, "Water")
		addTemp("KJ4ERJ-LS", 1, "GSZones", function(v) return v end, "%4d")
		addTemp("KJ4ERJ-LS", 2, "Strikes", function(v) return v*5 end, "%4d")
		addTemp("KJ4ERJ-LS", 3, "Squares", function(v) return v*4 end, "%4d")

	end
	local function showTelemetry()
		if config.lastTemps then
			local text = ""
			if config.StationID:sub(1,6) == 'KJ4ERJ' and config.lastTemps == 3 then
				for x,i in ipairs(temps) do
					if stationInfo[i.ID] and stationInfo[i.ID].telemetry then
						local station = stationInfo[i.ID]
						text = text..string.format("%s[%3d] %7s %s %d\n",
										i.ID:sub(-2,-1), station.telemetry.seq,
										i.name,
										string.format(i.fmt, i.f(station.telemetry.values[i.which])),
										station.telemetryPackets)
					end
				end
			elseif config.lastTemps == 2 then
				local function addIf(which)
					local key = "Battery"..which
					if type(MOAIEnvironment[key]) ~= 'nil' then
						text = text..string.format("%s: %s\n", which, tostring(MOAIEnvironment[key]))
					end
				end
				for _, v in pairs({"Percent", "Health", "Status", "Plugged", "ChargeRate", "Technology", "Temperature", "Voltage"}) do
					addIf(v)
				end
				if text == '' then text = "No Battery Statistics"
				else text = 'Battery Status\n'..text end
			else
				local function compare(one,two)
					if type(one) == 'number' and type(two) == 'number' then
						return one < two
					else return tostring(one) < tostring(two)
					end
				end
				local counts = osmTiles:getMBTilesCounts()
				if counts then
					for z, c in pairsByKeys(counts, compare) do
						if z == 'name' then
							text = c.."\n"..text
						elseif z == 'elapsed' then
							text = string.format("Count took %.2fmsec\n",c)..text
						elseif type(c) == 'table' then
							local range = 2^z
							local ztotal = range * range
							local ctotal = (c.max_y-c.min_y+1)*(c.max_x-c.min_x+1)
							local d2 = math.floor(math.log10((2^z)*(2^z))+0.999999)
							local digits = math.floor(math.log10(2^z)+0.999999)
							local f = "%"..tostring(digits).."d"
							f = " "..f.."-"..f
							f = "%d %3d%%/%3d%%"..f..f.."\n"
							text = text..string.format(f, z, c.count/ctotal*100, ctotal/ztotal*100,
														c.min_y, c.max_y,
														c.min_x, c.max_x)
						else text = text.."*UNKNOWN("..tostring(c)..")*\n"
						end
					end
				end
			end

			if temptext and text ~= "" and (temptext.last ~= text) then
--					print(text)
--					local x,y = temptext:getLoc()
				temptext:setString ( text );
--					temptext:fitSize()
--					temptext:setLoc(x,y)
				temptext.last = text
			end
		elseif not temptext.last or temptext.last ~= "" then
			temptext:setString ("")
			temptext.last = ""
		end
	end

	performWithDelay2("showTelemetry", 1000, showTelemetry, 0)

end
