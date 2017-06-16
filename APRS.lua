-- Project: APRS
--
-- Date: Jun 14, 2013
--
-- Version: 0.1
--
-- File name: APRS.lua
--
-- Author: Lynn Deffenbaugh, KJ4ERJ
--
-- Abstract: Support routines for the APRS Amateur Radio protocol
--
-- Demonstrates: 
--
-- File dependencies: 
--
-- Target devices: Simulator and Device
--
-- Limitations: Requires internet access; no error checking if connection fails
--
-- Update History:
--	v1.1		Added ActivityIndicator during download; also app title on screen
--
-- Comments: 
-- Uses LuaSocket libraries that ship with Corona. 
--
-- Note that this method blocks program execution during the download process. 
-- This can be addressed using Lua coroutines for a more "threaded" structure; 
-- future example code should demonstrate this.
--
-- Copyright (C) 2013 Homeside Software, Inc. All Rights Reserved.
---------------------------------------------------------------------------------------

local APRS = { VERSION = "0.0.1" }

local mybits = require("mybits")

-- Load the relevant LuaSocket modules (no additional files required for these)

function metersToFeet(v)
	if not v then return v end
	return v * 3.28084
end

function feetToMeters(v)
	if not v then return v end
	return v * 0.3048
end

function kphToKnots(v)
	if not v then return v end
	return v * 0.539956803
end

function knotsToKph(v)
	if not v then return v end
	return v * 1.85200
end

function knotsToMph(v)
	if not v then return v end
	return v * 1.15078
end

function kmToMiles(v)
	if not v then return v end
	return v * 0.621371
end

function milesToKm(v)
	if not v then return v end
	return v / 0.621371
end


local function round(val, decimal)
	if (decimal) then
		return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
	else
		return math.floor(val+0.5)
	end
end

-- trim whitespace from both ends of string
function trim(s)
	if not s then return s end
	return s:find'^%s*$' and '' or s:match'^%s*(.*%S)'
end
 
-- trim whitespace from left end of string
local function triml(s)
	if not s then return s end
	return s:match'^%s*(.*)'
end
 
-- trim whitespace from right end of string
local function trimr(s)
	if not s then return s end
	return s:find'^%s*$' and '' or s:match'^(.*%S)'
end

local function checkend(source, check)	-- returns (negative) index of character BEFORE check, may be zero!
	local ls, le = #source, #check
	--print('checkend('..source..') for ('..check..')')
	if ls >= le then	-- Got a chance to actually have it on there
		if source:sub(-le) == check then return (-le)-1, nil end	-- found it the cheap way!
		if source:sub(-1) == ' ' and ls > le then	-- still a chance before the space(s)
			local e = checkend(source:sub(1,-2), check)	-- Check with the space removed
			--if e then print('Found('..check..') in('..source..') with trailing space') end
			if e then e = e - 1 end
			return e, 'Trailing'
		end
	end
	if le == 2 and check:sub(-1) == ' ' then	-- Check for one without the trailing space
		local e = checkend(source, check:sub(1,-2))
		--if e then print('Found('..check..') without space in('..source..')') end
		return e, 'Truncated'
	end
	return nil
end

function APRS:GridSquare(lat, lon, digits)
	local function DoPair(lat, lon, digits, base)
		local fLat, fLon = math.floor(lat), math.floor(lon)
		local target = string.char(fLon+base:byte(), fLat+base:byte())
		if digits < 2 then return target end
		lat, lon = lat-fLat, lon-fLon
		if base == 'A' or base == 'a' then
			lat, lon = lat*10, lon*10
			target = target..DoPair(lat, lon, digits-2, '0')
		elseif base == '0' then
			lat, lon = lat*24, lon*24
			target = target..DoPair(lat, lon, digits-2, 'a')
		end
		return target
	end
	lat, lon = lat+90, lon+180	-- 0-180 S->N 0-360 W->E
	if lat < 0 or lat >= 180 or lon < 0 or lon >= 360 then return "Bogus" end
	return DoPair(lat/10, lon/20, digits-2, 'A')
end
	
function APRS:GridSquare2LatLon(GS)
	local function fromPair(pair, base, factor)
		local lat, lon
		if not pair or #pair < 2 then
			lat, lon = factor/2, factor/2
		else
			lat, lon = pair:byte(2)-base:byte(), pair:byte(1)-base:byte()
			if base == 'A' then
				local dlat, dlon = fromPair(pair:sub(3), '0', 10)
				lat, lon = lat+dlat/10, lon+dlon/10
			elseif base == '0' then
				local dlat, dlon = fromPair(pair:sub(3), 'A', 24)
				lat, lon = lat+dlat/24, lon+dlon/24
			end
		end
		return lat, lon
	end
	local lat, lon = fromPair(GS:upper(), 'A', 18)
	lat, lon = lat*10-90, lon*20-180
	return lat, lon
end

function APRS:Altitude(alt)	-- Assumes meters!
	alt = tonumber(alt)
	if not alt then return '' end
	if alt < 0 then return '' end
	return string.format('/A=%06i ', round(metersToFeet(alt)))
end

function APRS:CSESPD(course, speed) -- assumes degrees and knots
	course = tonumber(course)
	speed = tonumber(speed)
	if not course then return '' end
	if not speed then return '' end
	if course < 0 or speed < 0 then return '' end
	course = math.fmod(course, 360)
	if course == 0 then course = 360 end
	return string.format('%03i/%03i ', round(course), round(speed))
end

function APRS:Coordinate(lat, lon, sym, tab, ambiguity)	-- digits to blank (0-4 for accurate or 0.1 1.0, 10.0 60.0 nautical miles)
	if not ambiguity then ambiguity = 0 end
	if not sym then sym = ' '; tab = ' ' end
	tab = tab or '/'
	local function APRSDDmm(v,d,chars)
		v = v or 0.0
		d = d or 2
		chars = chars or '??'
		v = tonumber(v)
		-- print ('APRSDDmm:', v, d, chars)
		local c
		if v < 0 then c = chars:sub(2,2); v = math.abs(v) else c = chars:sub(1,1) end
		local degree, minute = math.modf(v)
		minute = minute * 60
		local fmt = string.format('%%0%di%%05.2f%%s', d)	-- (d)ddmm.mmX
		local result = string.format(fmt, degree, minute, c)
		-- print ('APRSDDmm:', fmt, degree, minute, result)
		if ambiguity >= 4 then
			result = result:sub(1,-6)..'  .  '..result:sub(-1)
		elseif ambiguity == 3 then
			result = result:sub(1,-5)..' .  '..result:sub(-1)
		elseif ambiguity == 2 then
			result = result:sub(1,-4)..'  '..result:sub(-1)
		elseif ambiguity == 1 then
			result = result:sub(1,-3)..' '..result:sub(-1)
		end
		return result
	end
	return APRSDDmm(lat, 2, 'NS')..tab..APRSDDmm(lon, 3, 'EW')..sym
end

function APRS:unpackTime(value, from)
	local s, e, one, two, three, which = value:find("^(%d%d)(%d%d)(%d%d)(.)$")
	if not s then return nil, 'APRS:unpackTime('..value..') Invalid' end
	if which == 'z' or which == '/' then
		local result = {}
		result.day, result.hour, result.minute = one, two, three
		result.which = which
		return result
	elseif which == 'h' then
		local result = {}
		result.hour, result.minute, result.second = one, two, three
		result.which = which
		return result
	end
	return nil, 'APRS:unpackTime('..value..') Invalid Time Type '
end

function APRS:unpackMicECoordinate(dst, latTabSym, from)
--lat, lon, symbol, course, speed, miceMessage, error = APRS:unpackMicECoordinate(info.dst, comment:sub(1,9))
	if #dst ~= 6 and dst:sub(7,7) ~= '-' then return nil, nil, nil, nil, nil, nil, 'APRS:unpackMicECoordinat: dst('..dst..') Must be 6 characters' end
	if #latTabSym ~= 8 then return nil, nil, nil, nil, nil, nil, 'APRS:unpackMicECoordinat: Mic-E('..latTabSym..') too short' end
local miclatvalid = "[0123456789ABCDEFGHIJKLPQRSTUVWXYZ]";	-- match set for Mic-E dests
local miclat = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',	-- 1..10
				':', ';', '<', '=', '>', '?', '@', '0', '1', '2',	-- 11..20
				'3', '4', '5', '6', '7', '8', '9', ' ', ' ', 'M',	-- 21..30
				'N', 'O', '0', '1', '2', '3', '4', '5', '6', '7',	-- 31..40
				'8', '9', ' '};	-- 41..43
	local d0, d1, d2, d3, d4, d5 = dst:byte(1,6)	-- from zero since we use the whole thing
	local p1, p2, p3, p4, p5, p6, p7, p8 = latTabSym:byte(1,8)	-- from 1 because C code was packet_data which started with datatype
	if not dst:find(miclatvalid:rep(6)) then
		return nil, nil, nil, nil, nil, nil, 'APRS:unpackMicECoordinate: Mic-E Lat('..dst..') invalid 0:'..d0..' 1:'..d1..' 2:'..p2..' 3:'..d3..' 4:'..d4..' 5:'..d5
	end
-- Need to validate d1..d6 against miclatvalid
	if (p1 < 38 or p1 > 127) 
	or (p2 < 38 or p2 > 97) 
	or (p3 < 28 or p3 > 127)
	or (p4 < 28 or p4 > 127) 
	or (p5 < 28 or p5 > 125) 
	or (p6 < 28 or p6 > 127) then
		return nil, nil, nil, nil, nil, nil, 'APRS:unpackMicECoordinate: Mic-E Lon('..latTabSym..') invalid 1:'..p1..' 2:'..p2..' 3:'..p3..' 4:'..p4..' 5:'..p5..' 6:'..p6
	end
	local MicEMessage = nil
	local pMsg, cMsg = 0, 0 -- primary and custom "messages"
	if d0 >= 80 and d0 <= 90 then pMsg = pMsg + 4			-- 'P'..'Z'
	elseif d0 >= 65 and d0 <= 75 then cMsg = cMsg + 4 end	-- 'A'..'K'
	if d1 >= 80 and d1 <= 90 then pMsg = pMsg + 2			-- 'P'..'Z'
	elseif d1 >= 65 and d1 <= 75 then cMsg = cMsg + 2 end	-- 'A'..'K'
	if d2 >= 90 and d2 <= 90 then pMsg = pMsg + 1			-- 'P'..'Z'
	elseif d2 >= 65 and d2 <= 75 then cMsg = cMsg + 1 end	-- 'A'..'K'
	if pMsg ~= 0 and cMsg ~= 0 then
		return nil, nil, nil, nil, nil, nil, 'APRS:unpackMicECoordinate: Mic-E pMsg('..pMsg..') and cMsg('..cMsg..') Both Specificed'
	elseif cMsg == 0 and pMsg == 0 then
		MicEMessage = 'EMERGENCY!'
	elseif pMsg ~= 0 then
		local primaryMessages = { "EMERGENCY!", "Priority", "Special", "Committed", "Returning", "In Service", "En Route", "Off Duty" }
		MicEMessage = primaryMessages[pMsg+1]
	elseif cMsg ~= 0 then
		local customMessages = { "EMERGENCY!", "Custom-6", "Custom-5", "Custom-4", "Custom-3", "Custom-2", "Custom-1", "Custom-0" }
		MicEMessage = customMessages[pMsg+1]
	else
		return nil, nil, nil, nil, nil, nil, 'APRS:unpackMicECoordinate: Mic-E pMsg('..pMsg..') and cMsg('..cMsg..') Cannot Get HERE!'
	end
	
	local latd, latm, lond, lonm
	latd = miclat[d0-48+1]..miclat[d1-48+1]
	latm = miclat[d2-48+1]..miclat[d3-48+1]..'.'..miclat[d4-48+1]..miclat[d5-48+1]
	
	if not tonumber(latd) or not tonumber(latm) then 
		return nil, nil, nil, nil, nil, nil, 'APRS:unpackMicECoordinate: Mic-E Lat('..latd..' '..latm..') NonNumeric!'
	end

	lond = p1 - 28
	if d4 >= 80 then lond = lond + 100 end	-- 'P'
	if lond >= 180 and lond <= 189 then lond = lond - 80
	elseif lond >= 190 and lond <= 199 then lond = lond - 190 end
	lonm = p2 - 28
	if lonm >= 60 then lonm = lonm - 60 end
	lonm = lonm + (p3-28)/100
	
	local lat, lon = tonumber(latd)+tonumber(latm)/60, lond+lonm/60
	if d3 < 80 then lat = - lat end	-- 'P' < 80 is South
	if d5 >= 80 then lon = - lon end	-- 'P'	>= 80 is West
	--print (string.format('Mic_E d(%s) p(%s) is Latd(%s)Latm(%s) or %f Lond(%f)Lonm(%f) or %f', dst, latTabSym, latd, latm, lat, lond, lonm, lon))
	
--[[
2017-06-02 11:54:56 EDT KC4LU-7: 50 bytes
0x00 K C 4 L U - 7 > S V Q Q 9 P , W I D E 1 - 1 , q A R , K C 4 L U 
     4b43344c552d373e5356515139502c57494445312d312c7141522c4b43344c55
0x20 - 2 : ` o 6 M m > - v / ] " 7 p } = 
     2d323a606f364d6d3e2d762f5d2237707d3d
]]

	local speed
	speed = p4 - 28
	if speed > 80 then speed = speed - 80 end
	speed = speed * 10
	local ts, course = math.modf((p5-28)/10)
	speed = speed + ts
	course = math.floor(course * 10 + 0.5)	-- Course needs integers
	if course >= 4 then course = course - 4 end
	course = course * 100
	course = course + p6 - 28
	if course == 360 then course = 0 end
	local symbol = string.char(p8,p7)

	return lat, lon, symbol, course, speed, MicEMessage, nil
end

--[[
int newbase91decode(char *s, int len, signed long *l)
{
	unsigned char c;
//printf("newbase91decode:Converting(%.*s)\n", len, s);
	for (c=0, *l=0; c<len; c++)
	if (s[c] < '!' || s[c] > '|') return FALSE;
	else
	{	*l *= 91;
		*l += s[c] - 33;
	}
//printf("Conversion(%.*s) is %ld\n", len, s, (long) *l);
	return TRUE;
}


]]

function base91Encode(n,l)	-- n==# to encode, l==pad/truncate length
	local r = ''
	while n > 0 do
		local v = (n % 91) + 33
		r = r..string.char(v)
		n = math.floor(n / 91)
	end
	if l ~= 0 then	-- 0 means just return the value
		if #r > l then r = r:sub(1,l) end
		while #r < l do r = '!'..r end
	end
	return r
end

function base91Decode(s)
	local r = 0
	for i=1,#s do
		if s:sub(i,i) < '!' or s:sub(i,i) > '|' then return nil
		else
			local c = s:byte(i,i) - 33
			r = r * 91 + c
		end
	end
	return r
end

function APRS:unpackCompressedCoordinate(latTabLonSym, from)	-- returns lat, lon, symbol, alt, course, speed, range
	if #latTabLonSym < 13 then return nil end	-- Too short!
	local symbol = latTabLonSym:sub(1,1)..latTabLonSym:sub(10,10)
	local b1, b2, b3, b4 = latTabLonSym:byte(2,5)
	local lat = (((b1-33)*91+(b2-33))*91+(b3-33))*91+(b4-33)
	local lat2 = base91Decode(latTabLonSym:sub(2,5))
	b1, b2, b3, b4 = latTabLonSym:byte(6,9)
	local lon = (((b1-33)*91+(b2-33))*91+(b3-33))*91+(b4-33)
	local lon2 = base91Decode(latTabLonSym:sub(6,9))
	if not lat2 or not lon2 then
		print('Invalid Compressed Coordinate')
		return nil
	end
	if lat2 ~= lat or lon2 ~= lon then
		print(string.format('base91Decode Failed %i ~= %i(%s) or %i ~= %i(%s)', lat, lat2, latTabLonSym:sub(2,5), lon, lon2, latTabLonSym:sub(6,9)))
	end
	lat = 90 - lat/380926	-- per aprs101.pdf page 38
	lon = lon/190463 - 180	-- Yep, it goes backwards!

	local alt, course, speed, range = nil, nil, nil
	if latTabLonSym:sub(11,11) ~= ' ' then
		--print('Need to unpackCompressedCoordinate('..latTabLonSym:sub(11,13)..') from('..from..') at '..APRS:Coordinate(lat,lon)..' sym('..symbol..')')
		local c, s, T = latTabLonSym:byte(11,13)
		c, s = c-33, s-33
		local TTab = mybits.tobits(T)
		local sT
		sT = ''
		for k,v in pairs(TTab) do sT = v..sT end sT = '00000000'..sT; sT = sT:sub(-8)
		--print('T['..T..'] is '..sT..' from '..from)
		if sT:sub(4,5) == '10' then	-- from GGA means cs = altitude
			local cs = c*91 + s
			alt = (1.002^cs) / 3.2808399
			--print('cst('..c..' '..s..' '..T..') is alt:'..alt..' from '..from)
		elseif c >= 0 and c <= 89 then	-- We have course/speed
			course = c * 4
			speed = (1.08^s) - 1	-- aprs101.pdf page 39
			--print('cst('..c..' '..s..' '..T..') is course:'..course..' speed:'..speed..' from '..from)
		elseif c == (123-33) then	-- 123 is { which is Pre-Calculated Radio Range
			range = 2 * (1.08^s)
			--print('cst('..c..' '..s..' '..T..' is range:'..range..' from '..from)
		else
			print('Unrecognized csT('..latTabLonSym:sub(11,13)..') or '..c..' '..s..' '..T)
		end
	end
	return lat, lon, symbol, alt, course, speed, range
end

function APRS:unpackStandardCoordinate(latTabLonSym, from)	-- returns lat, lon, symbol
	if #latTabLonSym ~= 19 then return nil end
	local first = latTabLonSym:sub(1,1)
	if latTabLonSym:sub(5,5) ~= '.' or latTabLonSym:sub(15,15) ~= '.' then return nil end
			--           1111111111
			--  1234567890123456789
			--	ddmm.mmNTdddmm.mmWS
	local symbol = latTabLonSym:sub(9,9)..latTabLonSym:sub(19,19)
	local function ddmm(v, N)
		local s = 1
		local c = v:sub(#v):upper()
		if c == N:sub(2,2) then s = -1 elseif c ~= N:sub(1,1) then return nil end
		local v1 = tonumber(v:sub(1,#v-1))
		if not v1 then return nil end
		local d, m = math.modf(v1/100)
		--print('ddmm', v, v1, d, m, s*(d+m*100/60))
		return s * (d + m*100/60)	-- Need the integer rounded up of m
	end
	local lat = ddmm(latTabLonSym:sub(1,8), 'NS')
	local lon = ddmm(latTabLonSym:sub(10,18), 'EW')
	if not lat or not lon then return nil end
	if lat < -90 or lat > 90 or lon < -180 or lon > 180 then
		print("APRS:unpackStandardCoordinate:Bogus Lat("..latTabLonSym:sub(1,8)..") Lon("..latTabLonSym:sub(10,18)..")")
		return nil
	end
	return lat, lon, symbol
end

function APRS:SymTab(symbol)	-- Takes 1 or 2 character table/symbol and returns symbol,table
	symbol = symbol or '  '
	if #symbol == 1 then symbol = '/'..symbol end
	if #symbol ~= 2 then symbol = '  ' end
	return symbol:sub(2,2), symbol:sub(1,1)
end

function APRS:Posit(components)	-- components should have lat/lon, symbol
								-- optionally alt (meters), course/speed (knots), comment
								-- optionally ambiguity digits (0..4)
	local c = components
--[[	for k,v in pairs(c)
	do
		print('APRSPosit',k,v)
	end ]]--
	local sym, symtab = APRS:SymTab(c.symbol)
	local posit = APRS:Coordinate(c.lat, c.lon, sym, symtab, c.ambiguity)..APRS:CSESPD(c.course, c.speed)..APRS:Altitude(c.alt)..c.comment
	--print ('APRSPosit:'..posit)
	return posit
end

function APRS:ddhhmmz(day, hour, minute)
	day = tonumber(day) or 0
	hour = tonumber(hour) or 0
	minute = tonumber(minute) or 0
	return string.format('%02i%02i%02iz', day, hour, minute)
end

function APRS:hhmmssh(hour, minute, second)
	hour = tonumber(hour) or 0
	minute = tonumber(minute) or 0
	second = tonumber(second) or 0
	return string.format('%02i%02i%02ih', hour, minute, second)
end

-- ! = w/o timestamp... / = with timestamp (both no messaging)
function APRS:Object(objname, day, hour, minute, components, kill)	-- See APRS:Posit for components
	if kill then kill = '_' else kill = '*' end
	return string.format(';%-9s%s%s%s', objname, kill, APRS:ddhhmmz(day,hour,minute), APRS:Posit(components))
end

function APRS:ObjectHHMMSS(objname, hour, minute, second, components, kill)	-- See APRS:Posit for components
	if kill then kill = '_' else kill = '*' end
	return string.format(';%-9s%s%s%s', objname, kill, APRS:hhmmssh(hour,minute,second), APRS:Posit(components))
end

-- APRS:Parse returns nil on failure
-- or returns a table with the following elements
-- (* means always present, all others are packet dependant)
--
-- src* = Source callsign-SSID
-- dst* = Destination callsign-SSID
-- path* = Path (may be empty, but not nil)
-- payload* = Entire packet payload (including datatype)
-- packetType* = First character of payload
-- comment* = remaining text after parsing (may be empty, but shouldn't be nil)
-- original* = Entire original packet, unmodified
--
-- error = If not nil, then why some parse component failed
--
-- messageable - true if platform indicates message-capable, nil otherwise
--
-- lat/lon - lat/lon from the packet, if any
-- alt - altitude from packet, if any (in meters)
-- symbol - table/symbol from the packet, if any
-- course/speed - course and speed from packet, if any (in knots)
-- range - radio range from packet, if any
-- obj - If not nil, object or item ID (src is owner)
-- killed - If not nil, object or item had the kill flag set
--
-- msg.addressee/body/ack(maybe nil) for message packets
-- telemetry.seq/values[]/digital(maybe nil) for telemetry packets
-- time.day/hour/minute/second depending on time.type(maybe nil)
-- miceMessage - "Message" from Mic-E protocol (aprs101.pdf page 45)
-- miceTrailing - If present, Mic-E type code has trailing space issues
-- capabilies - Text of station capabilities ('<')
-- statusReport - Text of status report ('>')
-- gridsquare -- if one is found in (statusReport or []) packet
-- platform - inferred platform if one is recognized (Mic-E Type, >APxxxx, {text})

local unsupporteds, lastUnsupported	-- for accumulating unsupported datatypes

function APRS:Parse(Packet)

	if not Packet or (#Packet < 4) or (string.sub(Packet,1,1) == '#') then return nil end
--print (Packet)
	local s, e, src, path, payload = string.find(Packet, "^(.-)%>(.-)%:(.+)$")
	if not s then return nil end
	local info = {}
	info.src = src
	local _
	_, _, info.dst, info.path = string.find(path, "^(.-)%,(.-)$")
	if not info.dst then
		info.dst = path
		info.path = ''
	end
	info.payload = payload
	info.packetType = string.sub(payload,1,1)
	info.original = Packet
	local comment = payload	-- for reduction during parsing

	if info.packetType == '!' or info.packetType == '=' then
		if comment:sub(1,2) == '!!' then
			--print('PEET Weather from '..info.src)
		else
			local first = comment:sub(2,2)
			if first < '0' or first > '9' then
				info.lat, info.lon, info.symbol, info.alt, info.course, info.speed, info.range = APRS:unpackCompressedCoordinate(comment:sub(2,14), info.src)
				if info.symbol then
					comment = comment:sub(15)
				else print('Invalid Compressed Coordinate from('..info.src..') in '..comment)
				end
			else
			--           11111111112
			--  12345678901234567890
			--	=ddmm.mmNTdddmm.mmWS
				info.lat, info.lon, info.symbol = APRS:unpackStandardCoordinate(comment:sub(2,20), info.src)
				if info.symbol then
					comment = comment:sub(21)
				else print('Invalid Standard Coordinate from('..info.src..') in '..comment)
				end
			end
			info.messageable = (info.packetType == '=')
		end
	elseif info.packetType == '/' or info.packetType == '@' then
			--           111111111122222222
			--  123456789012345678901234567
			--	@ddhhmmhddmm.mmNTdddmm.mmWS
			--	/hhmmsszddmm.mmNTdddmm.mmWS
		info.time, info.error = APRS:unpackTime(comment:sub(2,8), info.src)
		if info.time then
			local first = comment:sub(9,9)
			if first < '0' or first > '9' then
				info.lat, info.lon, info.symbol, info.alt, info.course, info.speed, info.range = APRS:unpackCompressedCoordinate(comment:sub(9,21), info.src)
				if info.symbol then
					comment = comment:sub(15)
				else print('Invalid Compressed Coordinate from('..info.src..') in '..comment)
				end
			else
				info.lat, info.lon, info.symbol = APRS:unpackStandardCoordinate(comment:sub(9,27), info.src)
				if info.symbol then
					comment = comment:sub(28)
				else print('Invalid Standard Coordinate from('..info.src..') in '..comment)
				end
			end
			info.messageable = (info.packetType == '@')
		end
	elseif info.packetType == ';' then
		local ka = comment:sub(11,11)
		if ka == '*' or ka == '_' then
			info.obj = trimr(comment:sub(2,10))
			info.killed = (ka=='_')
			info.time, info.error = APRS:unpackTime(comment:sub(12,18), info.src)
			if info.time then
				local first = comment:sub(19,19)
				if first < '0' or first > '9' then
					info.lat, info.lon, info.symbol, info.alt, info.course, info.speed, info.range = APRS:unpackCompressedCoordinate(comment:sub(19,31), info.src)
					if info.symbol then
						comment = comment:sub(32)
						-- print('Object('..info.obj..') owned by('..info.src..')')
					else print('Invalid object Compressed Coordinate from('..info.src..') in '..comment)
					end
				else
					info.lat, info.lon, info.symbol = APRS:unpackStandardCoordinate(comment:sub(19,37), info.src)
					if info.symbol then
						comment = comment:sub(38)
						-- print('Object('..info.obj..') owned by('..info.src..')')
					else print('Invalid object Coordinate from('..info.src..') in '..comment)
					end
				end
			else print('Invalid object time from('..info.src..') in '..comment)
			end
		else print('Invalid object */_ from('..info.src..') in '..comment)
		end
	elseif info.packetType == ')' then
		local s, e, id = comment:find('^%)(..-)[%!%_]')
		if id then
			if #id > 9 then print('invalid ItemID('..id..') from '..info.src) end
			local ka = comment:sub(e,e)
			if ka == '!' or ka == '_' then
				info.obj = trimr(id)
				info.killed = (ka=='_')
				local first = comment:sub(e+1,e+1)
				if first < '0' or first > '9' then
					info.lat, info.lon, info.symbol, info.alt, info.course, info.speed, info.range = APRS:unpackCompressedCoordinate(comment:sub(e+1,e+13), info.src)
					if info.symbol then
						comment = comment:sub(e+14)
						--print('Item('..info.obj..') owned by('..info.src..')')
					else print('Invalid item Compressed Coordinate from('..info.src..') in '..comment)
					end
				else
					info.lat, info.lon, info.symbol = APRS:unpackStandardCoordinate(comment:sub(e+1,e+19), info.src)
					if info.symbol then
						comment = comment:sub(e+20)
						--print('Item('..info.obj..') owned by('..info.src..')')
					else print('Invalid item Coordinate from('..info.src..') in '..comment)
					end
				end
			else print('Invalid item */_ from('..info.src..') in '..comment)
			end
		else print('Invalid item ID from('..info.src..') in '..comment)
		end
	elseif info.packetType == '`' or info.packetType == "'" then
		info.lat, info.lon, info.symbol, info.course, info.speed, info.miceMessage, info.alt, info.error = APRS:unpackMicECoordinate(info.dst, comment:sub(2,9), info.src)
		if info.error then print('Packet('..info.src..') Mic-E Error:'..info.error) end
		if info.miceMessage then	-- indicates that it worked! (altitude is optional)
			--info.dst = 'MICE'	-- Replace the seemingly random text
			comment = comment:sub(10)

			-- parse and strip off Mic-E platform per http://aprs.org/aprs12/mic-e-types.txt
			if comment:sub(1,1) == ' ' then	-- Original non-message Mic-E
				info.platform = 'Mic-E'
				comment = comment:sub(2)
			elseif comment:sub(1,1) == ']' then	-- D700
				info.platform = 'Kenwood D700'
				comment = comment:sub(2)
				info.messageable = true
				local e, w = checkend(comment, '=')
				if e ~= nil then
					info.platform = 'Kenwood D710'
					comment = comment:sub(1,e)
info.miceTrailing = w
--if w then print('Mic-e Type('..info.src..') '..info.platform..' '..w..' via '..info.path..' Now('..comment..')') end
				else
					e, w = checkend(comment,'v')
					if e ~= nil then
						info.platform = 'future D7xx'
						comment = comment:sub(1,e)
info.miceTrailing = w
--if w then print('Mic-e Type('..info.src..') '..info.platform..' '..w..' via '..info.path..' Now('..comment..')') end
					end
				end
			elseif comment:sub(1,1) == '>' then	-- D7
				info.platform = 'Kenwood D7'
				comment = comment:sub(2)
				info.messageable = true
				local e, w = checkend(comment, '=')
				if e ~= nil then
					info.platform = 'Kenwood D72'
					comment = comment:sub(1,e)
info.miceTrailing = w
--if w then print('Mic-e Type('..info.src..') '..info.platform..' '..w..' via '..info.path..' Now('..comment..')') end
				else
					e, w = checkend(comment,'^')
					if e ~= nil then
						info.platform = 'Kenwood D74'
						comment = comment:sub(1,e)
info.miceTrailing = w
--if w then print('Mic-e Type('..info.src..') '..info.platform..' '..w..' via '..info.path..' Now('..comment..')') end
					else
						e, w = checkend(comment,'v')
						if e ~= nil then
							info.platform = 'future TH-D7A'
							comment = comment:sub(1,e)
info.miceTrailing = w
--if w then print('Mic-e Type('..info.src..') '..info.platform..' '..w..' via '..info.path..' Now('..comment..')') end
						end
					end
				end
			elseif comment:sub(1,1) == '`' then	-- Messaging other Mic-E
				info.platform = 'Mic-E msg'
				comment = comment:sub(2)
				info.messageable = true
				if #comment >= 2 then info.platform = info.platform..'('..comment:sub(-2)..')' end
local yaesuPlatforms = {}
yaesuPlatforms["_ "] = 'Yaesu VX-8R'
yaesuPlatforms['_"'] = 'Yaesu FTM-350'
yaesuPlatforms["_%"] = 'Yaesu FTM-400'
yaesuPlatforms["_#"] = 'Yaesu VX-8G'
yaesuPlatforms["_$"] = 'Yaesu FT-1D'
yaesuPlatforms["_)"] = 'Yaesu FTM-100D'
yaesuPlatforms["_("] = 'Yaesu FT-2D'
				local foundit = false
				for s,p in pairs(yaesuPlatforms) do
					local e,w = checkend(comment,s)
					if e ~= nil then
						info.platform = p
						comment = comment:sub(1,e)
						info.miceTrailing = w
						foundit = true
						break
					end
				end
if not foundit then print('Mic-E msg('..info.src..') Platform:'..info.platform) end
			elseif comment:sub(1,1) == "'" then	-- Non-Message capable Other Mic-E
				info.platform = 'Mic-E trk'
				comment = comment:sub(2)
				if #comment >= 2 then info.platform = info.platform..'('..comment:sub(-2)..')' end
				local e, w = checkend(comment, '|3')
				if e ~= nil then
					info.platform = 'Byonics TT3'
					comment = comment:sub(1,e)
info.miceTrailing = w
--if w then print('Mic-e Type('..info.src..') '..info.platform..' '..w..' via '..info.path..' Now('..comment..')') end
				else
					e, w = checkend(comment,'|4')
					if e ~= nil then
						info.platform = 'Byonics TT4'
						comment = comment:sub(1,e)
info.miceTrailing = w
--if w then print('Mic-e Type('..info.src..') '..info.platform..' '..w..' via '..info.path..' Now('..comment..')') end
					else
						print('Mic-E trk('..info.src..') Platform:'..info.platform)
					end
				end
			elseif comment:sub(1,1) == 'T' then -- Manufacturer in next-to-last byte, version in last
-- && strchr("\\/`'^:;.*~",comment[strlen(comment-2)]))	/* is it a valid one? */
				info.platform = 'Mic-E T'
				comment = comment:sub(2)
				if #comment >= 2 then info.platform = info.platform..'('..comment:sub(-2)..')' end
				if comment:sub(-2,-2) == '\\' then
					info.platform = 'Hamhud('..comment:sub(-1)..')'	-- Unconfirmed
					comment = comment:sub(1,-3)
print('Confirm: Mic-e T('..info.src..') '..info.platform)
				else
					if comment:sub(-2,-2) == '/' then	-- OpenTrack?
						info.platform = 'Argent('..comment:sub(-1)..')'	-- Unconfirmed
						comment = comment:sub(1,-3)
print('Confirm: Mic-e T('..info.src..') '..info.platform)
					else
						if comment:sub(-2,-2) == '/' then	-- HinzTec anyfrog?
							info.platform = 'HinzTec('..comment:sub(-1)..')'	-- Unconfirmed
							comment = comment:sub(1,-3)
print('Confirm: Mic-e T('..info.src..') '..info.platform)
						else
							if comment:sub(-2,-2) == '*' then	-- * APOZxx www.KissOZ.dk Tracker
								info.platform = 'KissOZ('..comment:sub(-1)..')'	-- Unconfirmed
								comment = comment:sub(1,-3)
print('Confirm: Mic-e T('..info.src..') '..info.platform)
							else
								-- ` ' : ; . are still undefined (20130622)
								if comment:sub(-2,-2) == '~' then	-- OTHER (used when all others are allocated
									info.platform = 'Mic-E Other('..comment:sub(-1)..')'	-- Unconfirmed
									comment = comment:sub(1,-3)
print('Confirm: Mic-e T('..info.src..') '..info.platform)
								else
									print('Mic-E T('..info.src..') Platform:'..info.platform)
								end
							end
						end
					end
				end
			else
				info.platform = 'Mic-E'
				if #comment < 4 or comment:sub(4,4) ~= '}' then	-- short or not altitude
					info.platform = info.platform..'('..comment:sub(1,5)..')'
				else
					info.platform = 'Mic-E+alt'
					if #comment > 4 then
						info.platform = info.platform..'('..comment:sub(5,10)..')'
					end
				end
			end
--	Finally check for Mic-E altitude
			if comment:sub(4,4) == '}' then	-- Mic-E Altitude
				local b0, b1, b2 = comment:byte(1,3)
				info.alt = (b0-33)*8281 + (b1-33)*91 + (b2-33) - 10000	-- 1. In Mic-E format, the altitude in meters relative to 10km below mean sea level.
				comment = comment:sub(5)
				--print('Mic-E('..info.src..') altitude:'..info.alt..' from '..comment:sub(1,3)..' or '..b0..' '..b1..' '..b2)
			end
			--print('MicE('..info.platform..') comment('..comment..')')
		elseif not info.error then print('Mic-E nil message from '..info.src..' payload '..info.payload) end
	elseif info.packetType == ':' then	-- APRS message
--print('Possible message('..tostring(comment)..')')
		if #comment >= 11 and comment:sub(11,11) == ':' then
			info.msg = {}
			info.msg.addressee = trimr(comment:sub(2,10))
			comment = comment:sub(12)
			_, _, info.msg.text, info.msg.ack = comment:find('(.*)%{(.+)')
			info.msg.text = info.msg.text or comment
			-- print ('Message from ('..src..') to ('..info.msg.addressee..') body('..info.msg.text..') ack:',info.msg.ack)
		end
	elseif info.packetType == '<' then	-- Station capabilities
		comment = trim(comment:sub(2))
		if #comment then
			info.capabilities = comment;
			comment = ''
		end
	elseif info.packetType == '>' then	-- Status report (may have time or gridsquare)
		if comment:sub(8,8) == 'z' and APRS:unpackTime(comment:sub(2,8), info.src) then
			info.time, info.error = APRS:unpackTime(comment:sub(2,8), info.src)
			comment = comment:sub(9)
		elseif comment:find('^>[A..Ra..r][A..Ra..r][0..9][0..9][A..Xa..x][A..Xa..x]..%s') then	-- long form gridsquare
			info.gridsquare = comment:sub(2,7)
			info.symbol = comment:sub(8,9)
			if comment:sub(10,10) ~= ' ' then print('Station('..info.src..') StatusReport NOT space('..comment:sub(10,10)..')') end
			comment = comment:sub(11)	-- 10 should be the space
		elseif comment:find('^[A..Ra..r][A..Ra..r][0..9][0..9]..%s') then -- short form gridsquare
			info.gridsquare = comment:sub(2,5)
			info.symbol = comment:sub(6,7)
			if comment:sub(8,8) ~= ' ' then print('Station('..info.src..') StatusReport NOT space('..comment:sub(8,8)..')') end
			comment = comment:sub(9)	-- 8 should be the space
		else
			comment = comment:sub(2)	-- Remove >
		end
		if comment:sub(-3) == '^' then	-- Beam/ERP?
			print('Beam/ERP('..info.src..') is('..comment:sub(-3)..')')
		end
		info.statusReport = trim(comment)	-- Remove leading and trailing whitespace
		comment = ''
	elseif info.packetType == '[' then	-- (obsolete) gridsquare
		local s, e
		s, e, info.gridsquare = comment:find('^%[([A..Ra..r][A..Ra..r][0..9][0..9][A..Xa..x][A..Xa..x])%]')	-- include closing ]
		if info.gridsquare then
			info.symbol = '/G'	-- 3x3 GridSquare (/q = 2x2)
			if comment:sub(1,1) ~= '[' or comment:sub(8,8) ~= ']' then print('Station('..info.src..') Gridsquare[] ('..comment:sub(1,8)..')') end
			comment = comment:sub(9)
		else
			info.error = 'Station('..info.src..') Sent Invalid GridSquare('..comment:sub(1,8)..')'
		end
	elseif info.packetType == 'T' then	-- Telemetry
		if comment:sub(2,2) == '#' then	-- Anything else is probably plain text status starting with T
			info.telemetry = {}
			if comment:sub(3,5) == 'MIC' then
				print('Station('..info.src..') sent '..comment)
				info.telemetry.seq = 0	-- Not sure what T#MIC is though!
				if comment:sub(6,6) ~= ',' then print ('Station('..info.src..') TMIC('..comment..')') end
				comment = comment:sub(6)
			else
				comment = comment:gsub('^T%#(%d+)', function(v) info.telemetry.seq = v; return '' end, 1)
			end
			local found
			info.telemetry.values = {}
			comment, found = comment:gsub(',([%d%.]+)', function(v) info.telemetry.values[#info.telemetry.values+1] = v; return '' end, 6)
			if found == 6 then info.telemetry.digital = tostring(info.telemetry.values[6]); info.telemetry.values[6] = nil end
		else
			print ('Telemetry('..info.src..') is '..comment)
		end
--[[		if (ValueCount < 5)
		{	comment = &packet_data[0];
			nolatlon = 1;
			break;
		}

		Info->Valid |= APRS_TELEMETRY_VALID;	/* Mark it valid */
		Info->symbol = '~';	/* } = Tilde for Telemetry */
		Info->Valid |= APRS_SYMBOL_DEFAULTED;
		return TRUE;
	}
]]	
	else
		info.error = 'Station('..info.src..') DataType('..info.packetType..') Not Supported'
if info.packetType == "'" then print(info.error) end
		if not unsupporteds then unsupporteds = {} end
		if not unsupporteds[info.packetType] then
			unsupporteds[info.packetType] = 0;
			--print(info.error)
		end
		unsupporteds[info.packetType] = unsupporteds[info.packetType] + 1
		--local now = system.getTimer()
		if not lastUnsupported then lastUnsupported = 0 end
--[[
		if (lastUnsupported + 30000) < now then
			lastUnsupported = now
			for k,v in pairs(unsupporteds)
			do
				print(string.format('Unsupported[%s] %i',k,v))
			end
		end
]]
	end
	
-- Now check for additional comment-contained components	
	
	if info.lat and info.lon then	-- Position-based packets might have data extension
		if comment:sub(1,3) == 'PHG' then
			local s,e,P,H,G,D = comment:find('^PHG(%d)(%d)(%d)(%d)')
			if D then
				info.PHG = {}
				if comment:sub(1,7) == 'PHG0000' then	-- "magic" reset string
					info.PHG.Power, info.PHG.Height, info.PHG.Gain, info.PHG.Directivity = 0,0,0,0
				else
					info.PHG.Power = (P:byte(1,1)-48)^2	-- watts
					info.PHG.Height = (2^(H:byte(1,1)-48))*10	-- feet
					info.PHG.Gain = (G:byte(1,1)-48)	-- dB
					info.PHG.Directivity = (D:byte(1,1)-48)*45	-- 0 = Omni, degrees otherwise
					
					local g = 10^(info.PHG.Gain/10)
					if info.PHG.Power > 0	-- sqrt(0) or negative is a bad idea
					and info.PHG.Height > 0
					and g > 0 then
						info.range = math.sqrt(2*info.PHG.Height*math.sqrt((info.PHG.Power/10.0)*(g/2)))
						--print(info.src..' PHG Range('..comment:sub(1,7)..') is '..(info.range or '???'))
					else
						print(info.src..' PHG Range('..comment:sub(1,7)..') has P:'..info.PHG.Power..' H:'..info.PHG.Height..' G:'..info.PHG.Gain..' D:'..info.PHG.Directivity)
					end
					comment = triml(comment:sub(8))
				end
			end
		elseif comment:sub(1,3) == 'RNG' then
			local s,e,R = comment:find('^RNG(%d%d%d%d)')
			if R then
				info.range = tonumber(R)
				comment = triml(comment:sub(8))
			end
		elseif comment:sub(1,3) == 'DFS' then
			local s,e,S,H,G,D = comment:find('^DFS(%d)(%d)(%d)(%d)')
			if D then
				info.DFS = {}
				info.DFS.Strength = S:byte(1,1)-48
				info.DFS.Height = (2^(H:byte(1,1)-48))*10
				info.DFS.Gain = G:byte(1,1)-48
				info.DFS.Directivity = (D:byte(1,1)-48)*45
				comment = triml(comment:sub(8))
			end
		elseif comment:sub(4,4) == '/' then
			local l,r = comment:sub(1,3), comment:sub(5,7)
			-- if l == '...' or l == '   ' then l = '000' end
			-- if r == '...' or r == '   ' then r = '000' end
			if info.symbol and info.symbol == '\\l' then	-- Area Object Descriptor
				print('Station('..info.src..') has AreaObject('..comment:sub(1,7))
				-- comment = comment:sub(8)
			else
				local gotCSESPD = false
				if l == '000' or l == '   ' or l == '...' then	-- If Course is not known, remove the extension
					gotCSESPD = true	-- Technically we got something
					comment = comment:sub(8)
				else	-- Course is known, process it
					local symbol = (info.symbol or '??'):sub(2,2)
					if info.weather	-- Not sure, maybe positionless weather?
					or symbol == 'H'	-- Hazards have this
					or symbol == 'w'		-- as does water?
					or symbol == '_' then	-- Weather direction/speed
						if not info.weather then info.weather = {} end
						info.weather.direction = tonumber(l)
						info.weather.windspeed = tonumber(r)
						if info.weather.direction and info.weather.windspeed then
							comment = comment:sub(8)
							--print('Need '..info.src..' Weather('..info.symbol..') from '..comment)
						end
					else	 -- Must be CSE/SPD
						info.course = tonumber(l)
						info.speed = tonumber(r)
						if info.course and info.speed then
							gotCSESPD = true	-- We got something
							comment = triml(comment:sub(8))
						end
					end
				end
				if gotCSESPD and comment:sub(1,1)=='/' and comment:sub(5,5)=='/' then	-- Maybe /BRG/NRQ beyond?
					local l,r = comment:sub(2,4), comment:sub(6,8)
					if tonumber(l) and tonumber(r) then
						info.BRGNRQ = {}
						info.BRGNRQ.bearing = tonumber(l)
						info.BRGNRQ.number = comment:byte(6,6)-48;
						info.BRGNRQ.range = 2^(comment:byte(7,7)-48);
						info.BRGNRQ.quality = comment:byte(8,8)-48;
						if info.BRGNRQ.quality > 0 then	-- 0 is 0
							if info.BRGNRQ.quality == 1 then
								info.BRGNRQ.quality = 240;
							elseif info.BRGNRQ.quality == 2 then
								info.BRGNRQ.quality = 60;
							else info.BRGNRQ.quality = 2^(9-info.BRGNRQ.quality);
							end
						end
						comment = triml(comment:sub(10))
						print('****** Station('..info.src..') has /BRG/NRQ bearing:'..info.BRGNRQ.bearing..' N:'..info.BRGNRQ.number..' rng:'..info.BRGNRQ.range..' q:'..info.BRGNRQ.quality..' remaining '..comment)
					end
				end
			end
		end
--	Parse out the !DAO!xp. extension(s)
		local i = 0
		local function sign(x) return (x<0 and -1) or 1 end
		while true do
			i = string.find(comment,"![Ww]..!",i+1)
			if i == nil then break end
			if comment:sub(i+1,i+1) == 'W' then	-- Single digit !DAO!
				local y, x = tonumber(comment:sub(i+2,i+2)), tonumber(comment:sub(i+3,i+3))
				if y and x then
					info.lat = info.lat + sign(info.lat)*y/1000/60
					info.lon = info.lon + sign(info.lon)*x/1000/60
				else print("Invalid Single digit DAO("..comment:sub(i,i+4)..") in "..Packet)
				end
			elseif comment:sub(i+1,i+1) == 'w' then	-- Double digit !DAO!
				local y, x = base91Decode(comment:sub(i+2,i+2)), base91Decode(comment:sub(i+3,i+3))
				if y and x then
					info.lat = info.lat + sign(info.lat)*y*1.1/10000/60
					info.lon = info.lon + sign(info.lon)*x*1.1/10000/60
--print(string.format("%s Add %.5f %.5f", info.src, y*1.1/10000, x*1.1/10000))
					if comment:sub(i+7,i+7) == '.' then	-- xPrec, additional 2 digits
						local y, x = base91Decode(comment:sub(i+5,i+5)), base91Decode(comment:sub(i+6,i+6))
						if y and x then
							info.lat = info.lat + sign(info.lat)*y*1.1/1000000/60
							info.lon = info.lon + sign(info.lon)*x*1.1/1000000/60
--print(string.format("%s Add %.7f %.7f", info.src, y*1.1/1000000, x*1.1/1000000))
--print(string.format("%s %.6f %.6f", info.src, info.lat*60, info.lon*60))
						else
							print("Invalid Four digit DAO("..comment:sub(i,i+7)..") in "..Packet)
						end
					end
				else
					print("Invalid Double digit DAO("..comment:sub(i,i+4)..") in "..Packet)
				end
			else print("Unrecognized !DAO! datum("..comment:sub(i+1,i+1)..") in "..Packet)
			end
		end
	end
	local s,e,a = comment:find('%/[aA]%=([%-%d]%d%d%d%d%d)')
	if a then
		info.alt = tonumber(a)
		comment = triml(comment:sub(1,s-1)..comment:sub(e+1))
		--if info.alt < 0 then
			--print('Station('..info.src..'>'..info.dst..') has NEGATIVE altitude='..a..' new comment '..comment)
		--end
	end

	if comment:sub(1,1) == '/' then comment = triml(comment:sub(2)) end	-- strip of any excess leading /
	info.comment = trim(comment)	-- return what's left as comment (space trimmed on both ends)
	return info
end

--[[
local testTab = bits.tobits(255)
local s
		s = ''
		for k,v in pairs(testTab)
		do
			print('testTab',k,v)
			s = v..s
		end
print('255='..s)
		--testTab = {}
		s = ''
		testTab = bits.tobits(64+32+16+1)
		for k,v in pairs(testTab)
		do
			print('testTab',k,v)
			s = v..s
		end
print('64+32+16+1='..s)
local testInt = bits.tonumb({'1','0','1','0','1','0','1','0'})
	print ('10..=', testInt)
local testInt2 = bits.tonumb({'0','1','0','1','0','1','0','1'})
	print ('01..=', testInt2)
]]
--[[
testTab 1       1
testTab 2       1
testTab 3       1
testTab 4       1
testTab 5       1
testTab 6       1
testTab 7       1
testTab 8       1

testTab 1       1
testTab 2       0
testTab 3       0
testTab 4       0
testTab 5       1
testTab 6       1
testTab 7       1

10..=   85
01..=   170
]]

--[[local station = APRS:Parse("VE2WMG>BEACON,WIDE2-2,qAR,VE2PCQ-3:= !4539.39N/07233.66Wy >Je suis Qrt INFO:RAQI.CA/BRAQ")
if station.lat < -85.0511 or station.lat > 85.0511 or station.lon < -180 or station.lon > 180 then
print(string.format('%s invalid lat=%.5f lon=%.5f', station.src, station.lat, station.lon))
else
print(string.format('%s lat=%s lon=%s', station.src, tostring(station.lat), tostring(station.lon)))
end
local station = APRS:Parse("SV4FFD>XY6PP0,SZ4SRM-11,YM1TKR*,J44VAA,TRACE2-2,qAR,LZ0BGR-1:'vX l  >/]QRV 145500")
if station.lat < -85.0511 or station.lat > 85.0511 or station.lon < -180 or station.lon > 180 then
print(string.format('%s invalid lat=%.5f lon=%.5f', station.src, station.lat, station.lon))
else
print(string.format('%s lat=%s lon=%s', station.src, tostring(station.lat), tostring(station.lon)))
end
]]

local transmitCallbacks = {}
local receiveCallbacks = {}

function APRS:addTransmitListener(callback)	-- Invoked with what, packet
	table.insert(transmitCallbacks, callback)
end

function APRS:addReceiveListener(callback)	-- Invoked with packet, port
	table.insert(receiveCallbacks, callback)
end

function APRS:transmit(what, packet)
	print("APRS:transmit:invoking "..tostring(#transmitCallbacks).." transmit callbacks")
	for i,c in pairs(transmitCallbacks) do
		local status, text = pcall(c, what, packet)
		if not status then print ('transmitCallback failed with '..text) end
	end
end

function APRS:received(packet, port)
	for i,c in pairs(receiveCallbacks) do
		local status, text = pcall(c, packet, port)
		if not status then print ('receiveCallback failed with '..text) end
	end
end

return APRS
