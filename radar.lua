-- http://radar.weather.gov/ridge/Conus/RadarImg/latest_radaronly.gfw
-- http://radar.weather.gov/ridge/Conus/RadarImg/latest_radaronly.gif
-- http://radar.weather.gov/ridge/Conus/RadarImg/mosaic_times.txt

--[[ from view-source:http://radar.weather.gov/ridge/Conus/southmissvly_lite_loop.php

http://radar.weather.gov/ridge/graphics/southplainsth.gif

<td rowspan="2" align="center">National<br>Radar<br>Mosaic<br>Sectors<br><strong>Loops</strong><br><br>(click image)</td>
<td><a href="alaska_lite_loop.php"><img src="../graphics/alaskath.gif" 
			alt="Go to the Alaska sector loop" width="52" height="50" border="0"></a></td>
<td><a href="pacnorthwest_lite_loop.php"><img src="../graphics/pacnorthwestth.gif" 
			alt="Go to the Pacific Northwest sector loop" width="52" height="50" border="0"></a></td>
<td><a href="northrockies_lite_loop.php"><img src="../graphics/northrockiesth.gif" 
			alt="Go to the Northern Rockies sector loop" width="52" height="50" border="0"></a></td>
<td><a href="uppermissvly_lite_loop.php"><img src="../graphics/uppermissvlyth.gif" 
			alt="Go to the Upper Mississippi Valley sector loop" width="52" height="50" border="0"></a></td>
<td><a href="centgrtlakes_lite_loop.php"><img src="../graphics/centgrtlakesth.gif" 
			alt="Go to the Central Great Lakes sector loop" width="52" height="50" border="0"></a></td>
<td><a href="northeast_lite_loop.php"><img src="../graphics/northeastth.gif" 
			alt="Go to the Northeast sector loop" width="52" height="50" border="0"></a></td>
</tr>
 <tr align="center">
<td><a href="hawaii_lite_loop.php"><img src="../graphics/hawaiith.gif" 
			alt="Go to the Hawaii sector loop" width="52" height="50" border="0"></a></td>
<td><a href="pacsouthwest_lite_loop.php"><img src="../graphics/pacsouthwestth.gif" 
			alt="Go to the Pacific Southwest sector loop" width="52" height="50" border="0"></a></td>
<td><a href="southrockies_lite_loop.php"><img src="../graphics/southrockiesth.gif" 
			alt="Go to the Southern Rockies sector loop" width="52" height="50" border="0"></a></td>
<td><a href="southplains_lite_loop.php"><img src="../graphics/southplainsth.gif" 
			alt="Go to the Southern Plains sector loop" width="52" height="50" border="0"></a></td>
<td bgcolor="#ffff00" align="center"><img src="../graphics/southmissvlyth.gif" 
			alt="Currently at the Southern Mississippi Valley sector loop" width="52" height="50" border="0"></td>
<td><a href="southeast_lite_loop.php"><img src="../graphics/southeastth.gif" 
			alt="Go to the Southeast sector loop" width="52" height="50" border="0"></a></td>
</tr></table>
</div>
]]


local M = {}

--local json = require("json")
local toast = require("toast");
--local APRS = require("APRS")
--local APRSIS = require("APRSIS")
local osmTiles = require("osmTiles")
--local stationList = require("stationList")

local verbose = true

local myConfig = nil
local myConfigChanged = nil

local radarImage = nil
local radarEnabled = true
local radarFetching = false
local radarGroup = nil

local radarConfig = nil
local radarConfiguring = false
local radarConfigured = false
local radarSuffix = "_radaronly"

local fetches = {}

local runRadar	-- forward function declaration
local refreshRadar -- forward function declaration

local function fixRadar(why)
	print("Radar:fixRadar("..tostring(why)..")")
	if radarImage then
		if not radarGroup then
			radarGroup = Group{parent=osmTiles:getTileGroup(), priority=2000000000}
		else radarGroup:removeChildren()
		end

		local x, y = radarImage:getSize()
		print("Radar:newImage:size="..tostring(x)..'x'..tostring(y))

		local xLeft, yTop = osmTiles:whereIS(radarImage.latTop, radarImage.lonLeft)
		local xRight, yBottom = osmTiles:whereIS(radarImage.latBottom, radarImage.lonRight)
		local imgWidth, imgHeight = xRight-xLeft, yBottom-yTop
		local imgX, imgY = osmTiles:translateXY(xLeft, yTop)
		local xScale, yScale = imgWidth/x, imgHeight/y
		local xPixel, yPixel = xScale/240/myConfig.Screen.scale, yScale/240/myConfig.Screen.scale	-- Calculate inches

--		toast.new(string.format('fixRadar(%s) xScale:%.2f yScale:%.2f or %.2fx%.2fin/pix', why, xScale, yScale, xPixel, yPixel))

		local maxPixel = myConfig.Radar and myConfig.Radar.Pixelization and tonumber(myConfig.Radar.Pixelization) and tonumber(myConfig.Radar.Pixelization) or 0.1

		if xPixel < maxPixel and yPixel < maxPixel then	-- No bigger than configured
			radarImage:setPriority(2000000000)
			radarGroup:addChild(radarImage)
			--radarImage:setParent(radarGroup)
			if why ~= 'move' and why ~= 'size' and why ~= 'zoom' then
				if radarGroup:getNumChildren() ~= 1 then
					local text = "Radar:Group has "..radarGroup:getNumChildren().." children"
					for k,v in pairs(radarGroup:getChildren()) do
						text = text.."\r\n["..tostring(k).."] "..tostring(os.date("%d %H:%M:%S",v.modified)).." "..tostring(os.date("%d %H:%M:%S",v.serverTime)).." "..tostring(os.date("%d %H:%M:%S",v.expires))
					end
					toast.new(text,15000)
				end
			end
			radarGroup:setLoc(imgX, imgY)
print(string.format("Radar:newImage:at %d,%d -> %d,%d or %dx%d", xLeft, yTop, xRight, yBottom, imgWidth, imgHeight))
print(string.format("Radar:newImage:relocating to %d,%d scale %.2f,%.2f", imgX, imgY, imgWidth/x, imgHeight/y))
			radarGroup:setScl(xScale, yScale, 1)
			local alpha = myConfig.Radar and myConfig.Radar.Opacity and tonumber(myConfig.Radar.Opacity) and tonumber(myConfig.Radar.Opacity)/100 or 0.3
			radarGroup:setColor(alpha,alpha,alpha,alpha)
		end
	end
end

local function hideRadar()
	if radarGroup then
		local tileGroup = osmTiles:getTileGroup()
		tileGroup:removeChild(radarGroup)
		radarGroup:dispose()
		radarGroup = nil
	end
	osmTiles:removeCallback(fixRadar)
end

local function showRadar()
	if radarEnabled then
		osmTiles:addCallback(fixRadar)
		fixRadar('show')
	end
end

function M:setEnable(enabled)
print("Radar:setEnable("..tostring(enabled)..")")
	radarEnabled = enabled
	if enabled then
		for k,v in pairs(fetches) do
			print(tostring(k).." "..v)
		end
		showRadar()
	else
		hideRadar()
	end
end

local function radarFetch(name, callback)	-- Callback gets passed name, filepath, task
	radarFetching = true
--http://radar.weather.gov/ridge/graphics/southplainsth.gif	
	local URL = "https://radar.weather.gov/ridge/Conus/RadarImg/"..name..radarSuffix..".gif"

	print(os.date("%H:%M:%S").." Radar:Fetching "..URL)
	
	local dir = MOAIEnvironment.externalFilesDirectory or MOAIEnvironment.externalCacheDirectory or MOAIEnvironment.cacheDirectory or MOAIEnvironment.documentDirectory or "Cache/"
	dir = dir .. "/radar"
	MOAIFileSystem.affirmPath(dir)
	local file = name..".gif"
	local stream = MOAIFileStream.new ()
	stream:open ( dir..'/'..file, MOAIFileStream.READ_WRITE_NEW )

	local function radarListener( task, responseCode )
		if responseCode ~= 200 then
			print (os.date("%H:%M:%S").." Radar:Network error:"..responseCode.." from "..URL)
			toast.new("Radar:Network error:"..responseCode.." from "..URL)
		else
			local streamSize = stream:getLength()
			stream:close()
			print(os.date("%H:%M:%S").." Radar:streamSize:"..tostring(streamSize).." bytes")
			--toast.new(os.date("%H:%M:%S").." Radar:streamSize:"..tostring(streamSize).." bytes")
			print(os.date("%H:%M:%S").." radarFetch:invoking callback...")
			callback(name, dir..'/'..file, task)
		end	
		radarFetching = false
	end
	local task = MOAIHttpTask.new ()
	task:setVerb ( MOAIHttpTask.HTTP_GET )
	task:setUrl ( URL )
	task:setStream ( stream )
	task:setTimeout ( 15 )
	task:setCallback ( radarListener )
	task:setUserAgent ( string.format('radar viewer by KJ4ERJ') )
	task:setVerbose ( verbose )
	task:performAsync ()
end

local function radarFetchThumb(name)	-- Callback gets passed name, filepath, task
--http://radar.weather.gov/ridge/graphics/southplainsth.gif	
	local URL = "https://radar.weather.gov/ridge/graphics/"..name.."th.gif"

	print(os.date("%H:%M:%S").." Radar:Fetching Thumb:"..URL)
	
	local dir = MOAIEnvironment.externalFilesDirectory or MOAIEnvironment.externalCacheDirectory or MOAIEnvironment.cacheDirectory or MOAIEnvironment.documentDirectory or "Cache/"
	dir = dir .. "/radar"
	MOAIFileSystem.affirmPath(dir)
	local file = name.."th.gif"
	local stream = MOAIFileStream.new ()
	stream:open ( dir..'/'..file, MOAIFileStream.READ_WRITE_NEW )

	local function radarListener( task, responseCode )
		if responseCode ~= 200 then
			print (os.date("%H:%M:%S").." Radar:Network error:"..responseCode.." from "..URL)
			toast.new("Radar:Network error:"..responseCode.." from "..URL)
		else
			local streamSize = stream:getLength()
			stream:close()
			print(os.date("%H:%M:%S").." Radar:streamSize:"..tostring(streamSize).." bytes")
			radarConfig[name].thumb = dir..'/'..file
		end	
	end
	local task = MOAIHttpTask.new ()
	task:setVerb ( MOAIHttpTask.HTTP_GET )
	task:setUrl ( URL )
	task:setStream ( stream )
	task:setTimeout ( 15 )
	task:setCallback ( radarListener )
	task:setUserAgent ( string.format('radar viewer by KJ4ERJ') )
	task:setVerbose ( verbose )
	task:performAsync ()
end

local function radarFleshOutSizes()
	local didOne = false
	for k,v in pairs(radarConfig) do 
		if type(v.gotSize) == 'nil' then	-- Need to try this one
			didOne = true
			radarConfiguring = "Finalizing "..k
			toast.new("Finalizing "..k, 2000)
			--radarFetchThumb(k)	-- Get the thumbnail for configuration adornment
			radarFetch(k, function(name, filepath, task)	-- Callback gets passed name, filepath, task
print(os.date("%H:%M:%S").." radarFleshOutSizes:Callback("..name..","..filepath..")")
								local tryImage = MOAIImage.new()
								tryImage:load(filepath, MOAIImage.PREMULTIPLY_ALPHA)
								local x, y = tryImage:getSize()
print(os.date("%H:%M:%S").." radarFleshOutSizes:"..name..":Size:"..tostring(x)..'x'..tostring(y))
								if x > 0 and y > 0 then
									v.lonRight = v.lonLeft + x*v.xpixel
									v.latBottom = v.latTop + y*v.ypixel
									v.latCenter = (v.latTop+v.latBottom)/2
									v.lonCenter = (v.lonLeft+v.lonRight)/2
									v.gotSize = true	-- All is well!
									radarFleshOutSizes()	-- Go get the next one now
else print(os.date("%H:%M:%S").." radarFleshOutSizes:Failed:"..filepath)
								end
							end)
			break;
		end
	end
	if not didOne then
		print(os.date("%H:%M:%S").." Done Fleshing Out Sizes")
		radarConfiguring = false
		radarConfigured = true
		toast.new("Radar Initialized", 2000)
		refreshRadar()	-- Kickstart the actual image display
	end
end

local function radarFleshOutList()
	local didOne = false
	for k,v in pairs(radarConfig) do 
		if type(v.gotInfo) == 'nil' then	-- Need to try this one
			didOne = true
			local URL = "https://radar.weather.gov/ridge/Conus/RadarImg/"..k..radarSuffix..".gfw"	-- Get the world file

			radarConfiguring = "Fleshing "..k
			print(os.date("%H:%M:%S").." Radar:Fetching gfw "..URL)
	
			local function radarListener( task, responseCode )
				v.gotInfo = false	-- We at least attempted it!
				if responseCode ~= 200 then
					print (os.date("%H:%M:%S").." Radar:Network error:"..responseCode.." from "..URL)
					toast.new("Radar:Network error:"..responseCode.." from "..URL)
				else
					local body = task:getString()
					print(os.date("%H:%M:%S").." Radar:"..k..".gfw:"..tostring(#body).." bytes")
					local lines = {}
					for number in string.gfind(body, "[^\r\n]+") do
						if tonumber(number) then	-- Ignore non-numeric lines
							lines[#lines+1] = number
						end
					end
--[[	http://radar.weather.gov/ridge/Conus/RadarImg/southeast_radaronly.gif
http://radar.weather.gov/ridge/Conus/RadarImg/southeast_radaronly.gfw
Line 1: x-dimension of a pixel in map units
Line 2: rotation parameter
Line 3: rotation parameter
Line 4: NEGATIVE of y-dimension of a pixel in map units
Line 5: x-coordinate of center of upper left pixel
Line 6: y-coordinate of center of upper left pixel
0.017971305190311	-- x-dimension of a pixel in degrees lon (m)
0.000000000000000	-- rotation
0.000000000000000	-- rotation
-0.017971305190311	-- y-dimension of a pixel in degrees lat (m)
-90.24006072802854	-- Upper left x coordinate (degrees lon) (lonLeft)
36.928147474567794	-- Upper left y coordinate (degrees lat) (latTop)
]]
					if #lines == 6 then
						v.xpixel = tonumber(lines[1])
						v.rot1 = tonumber(lines[2])
						v.rot2 = tonumber(lines[3])
						v.ypixel = tonumber(lines[4])
						v.lonLeft = tonumber(lines[5])
						v.latTop = tonumber(lines[6])
						v.gotInfo = true	-- All is well!
					else print("line count isn't 6")
					end
					radarFleshOutList()
				end	-- responseCode check
			end
			local task = MOAIHttpTask.new ()
			task:setVerb ( MOAIHttpTask.HTTP_GET )
			task:setUrl ( URL )
			task:setTimeout ( 15 )
			task:setCallback ( radarListener )
			task:setUserAgent ( string.format('radar viewer by KJ4ERJ') )
			task:setVerbose ( verbose )
			task:performAsync ()
			break	-- Only fetch one at a time
		end
	end
	if not didOne then
		print(os.date("%H:%M:%S").." Done Fetching gfws")
		toast.new("Finalizing Radar Details", 2000)
		radarFleshOutSizes()
	end
end

local function radarGetList()

	radarConfiguring = "Get List"

	local URL = "https://radar.weather.gov/ridge/Conus/RadarImg/"	-- Get list of files, looking for *.gfw

--[[	http://radar.weather.gov/ridge/Conus/RadarImg/southeast_radaronly.gif
http://radar.weather.gov/ridge/Conus/RadarImg/southeast_radaronly.gfw
Line 1: x-dimension of a pixel in map units
Line 2: rotation parameter
Line 3: rotation parameter
Line 4: NEGATIVE of y-dimension of a pixel in map units
Line 5: x-coordinate of center of upper left pixel
Line 6: y-coordinate of center of upper left pixel
0.017971305190311	-- x-dimention of a pixel in degrees lon (m)
0.000000000000000	-- rotation
0.000000000000000	-- rotation
-0.017971305190311	-- y-dimension of a pixel in degrees lat (m)
-90.24006072802854	-- Upper left x coordinate (degrees lon) (lonLeft)
36.928147474567794	-- Upper left y coordinate (degrees lat) (latTop)
]]

	print(os.date("%H:%M:%S").." Radar:Fetching List "..URL)
	
	toast.new("Fetching Radar List", 2000)
	
	local function radarListener( task, responseCode )
		if responseCode ~= 200 then
			print (os.date("%H:%M:%S").." Radar:Network error:"..responseCode.." from "..URL)
		else
			local body = task:getString()
			print(os.date("%H:%M:%S").." Radar:gotList:"..tostring(#body).." bytes")
			for name in string.gfind(body, ".-%"..radarSuffix.."%.gfw\"%>(.-)%"..radarSuffix.."%.gfw%<") do
				print('Found List('..tostring(name)..')')
				if not radarConfig then radarConfig = {} end
				if not radarConfig[name] then radarConfig[name] = {} end
				radarConfig[name].name = name
			end
			toast.new("Fetching Radar Details", 2000)
			radarFleshOutList()
		end	-- responseCode check
	end
	local task = MOAIHttpTask.new ()
	task:setVerb ( MOAIHttpTask.HTTP_GET )
	task:setUrl ( URL )
	task:setTimeout ( 15 )
	task:setCallback ( radarListener )
	task:setUserAgent ( string.format('radar viewer by KJ4ERJ') )
	task:setVerbose ( verbose )
	task:performAsync ()
end

function M:getImage()
	return radarImage
end

local function radarGotNewOne(name, filepath, task)	-- Callback gets passed name, filepath, task

	print("radarGotNewOne:"..name..":Info:"..tostring(radarConfig[name].gotInfo).." Size:"..tostring(radarConfig[name].gotSize))

	if radarConfig[name].gotInfo and radarConfig[name].gotSize then
		local mx, my = radarConfig[name].xpixel, radarConfig[name].ypixel
		local latTop, lonLeft = radarConfig[name].latTop, radarConfig[name].lonLeft

		print(os.date("%H:%M:%S").." Radar:Got "..filepath)
	
		local newOne = false
		local modified = task:getResponseHeader('Last-Modified')
		local expires = task:getResponseHeader('Expires')
		local serverTime = task:getResponseHeader('Date')
		print("Radar:server:"..tostring(serverTime).." mod:"..tostring(modified).." exp:"..tostring(expires))
			
		if radarImage and radarImage.originalModified and modified and radarImage.originalModified == modified then
			fetches[#fetches+1] = os.date("%H:%M:%S")..":server:"..tostring(serverTime).." mod:"..tostring(modified).." exp:"..tostring(expires).." DUPE!"
			--toast.new("Radar: Ignoring duplicate "..modified, 30000)
			print("Radar: Ignoring duplicate "..modified)
		else
--toast.new("Radar:New:"..tostring(radarImage).." "..tostring(radarImage and radarImage.originalModified).." "..tostring(modified).." "..tostring((radarImage and radarImage.originalModified) == modified))
			print("Radar:New:"..tostring(radarImage).." "..tostring(radarImage and radarImage.originalModified).." "..tostring(modified).." "..tostring((radarImage and radarImage.originalModified) == modified))
			fetches[#fetches+1] = os.date("%H:%M:%S")..":server:"..tostring(serverTime).." mod:"..tostring(modified).." exp:"..tostring(expires).." New"

			local tryImage = MOAIImage.new()
			tryImage:load(filepath, MOAIImage.PREMULTIPLY_ALPHA)
			local x, y = tryImage:getSize()
			--toast.new(os.date("%H:%M:%S").." Radar:"..name..":Size:"..tostring(x)..'x'..tostring(y))
			if x > 0 and y > 0 then

				local latBottom, lonRight = latTop+y*my, lonLeft+x*mx

local function osmPixelNum(lat_deg, lon_deg, n)	-- lat/lon in degrees gives xTile, yTile
	local xtile = n * ((lon_deg + 180) / 360)
	local lat_rad = math.rad(lat_deg)
	local ytile = n * (1 - (math.log(math.tan(lat_rad) + (1/math.cos(lat_rad))) / math.pi)) / 2
	return xtile, ytile
end
				local n = math.floor(360/mx+0.5)
		
				local xpLeft, ypTop = osmPixelNum(latTop, lonLeft, n)
				local xpRight, ypBottom = osmPixelNum(latBottom, lonRight, n)
				local pWidth, pHeight = xpRight-xpLeft, ypBottom-ypTop
				--toast.new(string.format("Radar:Stretch(%d) %dx%d to %dx%d", n, x, y, pWidth, pHeight))
--02:21:22 Image(20032) is 840x800 Pixel is 840x925
				local stretch = MOAIImage.new()
				stretch:init(pWidth,pHeight,tryImage:getFormat())
				local dyNext = 0
				for rsy=0, y do
					local rdx, rdy = osmPixelNum(latTop+rsy*my, lonLeft+rsy*mx, n)
					rdx, rdy = math.floor(rdx-xpLeft+0.5), math.floor(rdy-ypTop+0.5)
					local dy = rdy - dyNext + 1
--					print(string.format("Radar:Stretch %d, %d -> %d, %d-%d (dy:%d) Lat %.5f vs %.5f", rsy, rsy, rdx, dyNext, rdy, dy, latTop-rsy*m, latBottom))
					stretch:copyBits(tryImage, 0, rsy, 0, dyNext, x, dy)
					dyNext = rdy + 1
				end
				radarImage = Sprite { texture=stretch }
				radarImage.latTop, radarImage.lonLeft = latTop, lonLeft
				radarImage.latBottom, radarImage.lonRight = latBottom, lonRight
		
				newOne = true
			end	-- size check
		end	-- duplicate check

local function parseTime(gmtTime)		
-- Thu, 17 Oct 2013 11:53:49 GMT
	if not gmtTime then return nil end
	local pattern="%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT"
	local day,month,year,hour,min,sec=gmtTime:match(pattern)
	local MON={Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
	month=MON[month]
	local offset=os.time()-os.time(os.date("!*t"))
	local result = os.time({day=day,month=month,year=year,hour=hour,min=min,sec=sec})+offset
	print("Radar:Was:"..tostring(gmtTime).." Is:"..os.date("!%c", result).." or:"..os.date("%c", result))
	return result
end
		radarImage.originalModified = modified
		radarImage.modified, radarImage.expires, radarImage.serverTime = parseTime(modified), parseTime(expires), parseTime(serverTime)
		if radarImage.expires and radarImage.serverTime then
			radarImage.remaining = radarImage.expires - radarImage.serverTime
			radarImage.refetch = os.time() + radarImage.remaining
			print(os.date("%H:%M:%S").." Radar:"..radarImage.remaining.." seconds remaining, refetch at "..os.date("%c", radarImage.refetch))
			if radarImage.modified and radarImage.expires < radarImage.modified+10*60 then
				radarImage.refetch = os.time() + 10*60+30 - (radarImage.serverTime-radarImage.modified)	-- Give it at least 10 minutes + 30 seconds slop
				--toast.new("Radar:"..tostring(os.date("%d %H:%M:%S",radarImage.modified)).." valid until "..tostring(os.date("%d %H:%M:%S",radarImage.expires)).." but refetching at "..tostring(os.date("%d %H:%M:%S",radarImage.refetch)), 5000)
			--else toast.new("Radar:"..tostring(os.date("%d %H:%M:%S",radarImage.modified)).." valid "..radarImage.remaining.." seconds", 5000)
			end
		else
			radarImage.refetch = os.time() + 10*60	-- Refetch every 10 minutes
			toast.new("Radar:"..tostring(os.date("%d %H:%M:%S",radarImage.modified)).." No Expiration!")
		end
		if newOne then showRadar() end
		if myConfigChanged then
			myConfig:save(myConfigChanged)
			myConfigChanged = nil
		end
	end
end

local function radarGetNewOne()
	if myConfig.Radar and myConfig.Radar.Name and myConfig.Radar.Name ~= "" then
		radarFetch(myConfig.Radar.Name, radarGotNewOne)
	elseif Application:isDesktop() then
		radarFetch("latest", radarGotNewOne)
	else print("Radar.Name not configured")
	end
end

function refreshRadar()	-- Made local above by forward reference
	local nextTime = 5000
	if radarEnabled then
		if not radarConfigured then
			if not radarConfiguring then
				radarGetList()
			else	print("Radar:Configuring:"..tostring(radarConfiguring))
			end
		elseif not radarFetching then
			if not radarImage then
				toast.new("Radar:Fetching Initial Radar", 2000)
				radarGetNewOne()
				nextTime = 30000
			elseif radarImage.refetch then
				if radarImage.refetch <= os.time() then
					toast.new("Radar:Re-Fetching Radar", 2000)
					radarGetNewOne()
					nextTime = 30000
				else
					local dtime = radarImage.refetch-os.time()
					--toast.new("Radar:expires in "..dtime.." seconds", 1000)
					nextTime = math.max(dtime/2,1)*1000
				end
			else
				print("Radar:No way to refresh radar!")
				nextTime = 10000
			end
		else	print("Radar:Fetch:"..tostring(radarFetching))
		end
--	else	print("Radar:Enabled:"..tostring(radarEnabled))
	end
	return nextTime
end

function runRadar()
	local nextTime = refreshRadar()
--	print("Radar:sleeping "..nextTime.."ms")
	performWithDelay(nextTime, runRadar)
end

local function imageChooser(config, id, newValue)
	if radarConfig then
		local names = {}
		for k, v in pairs(radarConfig) do
			names[#names+1] = k
		end
		table.sort(names)
		local entries = {}
		for i, name in ipairs(names) do
			local entry = {}
			local v = radarConfig[name]
			entries[#entries+1] = entry
			entry.value = name
			if v.gotSize then
				entry.detail = FormatLatLon(v.latTop, v.lonLeft).." to "..FormatLatLon(v.latBottom, v.lonRight)
			end
			if v.thumb then
				entry.image = MOAIImage.new()
				entry.image:load(v.thumb, MOAIImage.PREMULTIPLY_ALPHA)
				local x, y = entry.image:getSize()
				--toast.new(os.date("%H:%M:%S").." Radar:"..name..":Size:"..tostring(x)..'x'..tostring(y))
				if x <= 0 or y <= 0 then entry.image = nil end
			end
		end
		SceneManager:openScene("chooser_scene", {config=config, titleText="NWS Radar Image", values=names, entries=entries, newValue=newValue, animation = "popIn", backAnimation = "popOut", })
	else
		SceneManager:openScene("chooser_scene", {config=config, titleText="NWS Radar Not Initialized", values={"** No Known Images **", "Please Enable Radar"}, newValue=function() end, animation = "popIn", backAnimation = "popOut", })
	end
end

local function imageChanged()
	if radarImage then
		toast.new("Expiring Radar Image, Config Changed")
		radarImage.refetch = os.time()
		radarImage.originalModified = nil
	end
	performWithDelay(1000, refreshRadar)
end

function M:start(config)
	if config then
		myConfig = config
		if not myConfig.Radar then myConfig.Radar = {} end
		myConfig:addGroup("Radar", "NWS Ridge Radar Overlay")
		myConfig:addChooserString("Radar", "Radar.Name", "Radar Composite Name", 128, "", imageChooser, imageChanged)
		myConfig:addNumber("Radar", "Radar.Opacity", "Radar Overlay Opacity", 30, 0, 100, function () osmTiles:refreshMap() end)
		myConfig:addNumberF("Radar", "Radar.Pixelization", "Max Pixelization (Inches)", 0.1, 0.01, 1.0, function () osmTiles:refreshMap() end)
	end
	print("Radar:Starting monitor! ("..type(myConfig)..")")
	
--[[
	if not myConfig.radar then myConfig.radar = {} end

	if not myConfig.balloons then myConfig.balloons = {} end
print("M:start:balloons = "..type(balloons).."("..tostring(balloons)..")")
	print(printableTable('myConfig.balloons(before)', myConfig.balloons))
	for k,v in pairs(balloons) do
		if not myConfig.balloons[k] then
			myConfig.balloons[k] = {}
			myConfig.balloons[k].enabled = true
		end
	end
	print(printableTable('myConfig.balloons(after)', myConfig.balloons))
]]
	performWithDelay(10000, runRadar)
	
end

return M
