local M = {version="0.0.1"}

local toast = require("toast");
local APRS = require("APRS")
local APRSIS = require("APRSIS")
local stationList = require("stationList")

module(..., package.seeall)

local formatsRaw = {"!http://data.blitzortung.org/Data_1/Protected/Strokes/%Y/%m/%d/%H/%M.log",
				"!http://data.blitzortung.org/Data_2/Protected/Strokes/%Y/%m/%d/%H/%M.log",
				"!http://data.blitzortung.org/Data_3/Protected/Strokes/%Y/%m/%d/%H/%M.log"}

M.formats = {}
for i,f in pairs(formatsRaw) do
	table.insert(M.formats,{format=f})
end

local function showLightning()
	if config.lastTemps then
		local text = ""
		for x,f in ipairs(M.formats) do
			if f.last then
				text = text..string.format("%s %7d %s\r\n",
								f.lastTime and "GASP" or "....",
								f.got or 0, f.last:sub(-20))
			end
		end
		if temptext and (temptext.last ~= text) then
			print(text)
			local x,y = temptext:getLoc()
			temptext:setString ( text );
			temptext:fitSize()
			temptext:setLoc(x,y)
			temptext.last = text
		end
	elseif not temptext.last or temptext.last ~= "" then
		temptext:setString ("")
		temptext.last = ""
	end
end

performWithDelay( 1000, showLightning, 0)

function M:getRecentStrokes()
-- http://data.blitzortung.org/Data_1/Protected/Strokes/2016/10/21/20/20.log

	if not self.nextFormat then
		self.nextFormat = 1
		self.delay = 10000
	else
		self.nextFormat = self.nextFormat+1
		if self.nextFormat > #self.formats then
			self.nextFormat = 1
			self.delay = math.floor(2*60*1000/#self.formats)
		end
	end
	local thisFormat = self.formats[self.nextFormat]
	local tNow = os.time()
	local t = math.floor(tNow/(10*60))*10*60
	local URL = os.date(thisFormat.format, t)
	local lsSentCount = 0

	local function gotStrokes( task, responseCode )
		if responseCode == 206 then
			local gotString = task:getString()
			print("lightning:Got "..#gotString.." bytes from "..URL)
			print("lightning:Range:"..tostring(task:getResponseHeader("Content-Range")).." vs "..tostring(thisFormat.got))
			thisFormat.got = thisFormat.got + #gotString;
		elseif responseCode == 200 then
			local gotString = task:getString()
			print("lightning:Got "..#gotString.." bytes from "..URL)
			print("lightning:Range:"..tostring(task:getResponseHeader("Content-Range")).." vs "..tostring(thisFormat.got))
			thisFormat.got = thisFormat.got + #gotString;
		elseif responseCode == 416 then
			print("lightning:416 received, nothing new from "..tostring(thisFormat.got).." in "..tostring(task:getResponseHeader("Content-Range")))
		else
			print ( "lightning:gotStrokes:Network error:"..responseCode.." from "..URL)
			toast.new("gotStrokes:Network error:"..responseCode.." from "..URL, 10000)
		end

		performWithDelay(self.delay, function() self:getRecentStrokes() end)
	end

	if thisFormat.last ~= URL then
		if thisFormat.last and not thisFormat.lastTime then
			thisFormat.lastTime = true
			URL = thisFormat.last
			print("lightning:OneLastTime for "..tostring(URL))
			self.delay = 10000
			self.nextFormat = self.nextFormat - 1	-- Do me again!
		else
			if thisFormat.lastTime then
				self.delay = 10000
			end
			thisFormat.got = 0
			thisFormat.last = URL
			thisFormat.lastTime = nil
			print("lightning:Switching to "..tostring(URL))
		end
	end
	if (tNow-t) < 30 and not thisFormat.lastTime then
		local delay = 30-(tNow-t)
		print("lightning:Delaying "..URL.." "..tostring(delay).." seconds")
		--toast.new("lighting Delaying "..URL.." "..tostring(delay).." seconds", delay*1000)
		performWithDelay( delay*1000, function() self:getRecentStrokes() end)
	else
		print("lightning:Fetching "..URL.." from "..tostring(thisFormat.got))
		local task = MOAIHttpTask.new ()
		task:setVerb ( MOAIHttpTask.HTTP_GET )
		task:setUrl ( URL )
		task:setHeader("Range", "bytes="..tostring(thisFormat.got).."-")
		task:setTimeout ( 15 )
		task:setCallback ( gotStrokes )
	--[[		task:setUserAgent ( string.format('%s from %s %s',
													tostring(config.StationID),
													MOAIEnvironment.appDisplayName,
													tostring(config.About.Version)) )
	]]
		task:setVerbose ( true )
		task:performAsync ()
	end
end

performWithDelay( 5000, function() M:getRecentStrokes() end)

return M
