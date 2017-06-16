local BTPort = { VERSION = "0.0.1" }

local toast = require("toast");
local APRS = require("APRS")
local APRSIS = require("APRSIS")

local openCmds = nil
local closeCmds = nil
local preCmds = nil
local postCmds = nil
local xmitFormat = nil
local doingCmds = nil
local doingParts = nil
local commanding = false
local cmdCallback = nil
local nextCmd	-- Forward function reference
local xmitQueue = nil
local currentState = nil

local function KISSFormatHex(p)
	if not p then return "<nil>" end
	local o = ""
	for i = 1,#p do
		o = o .. string.format("%02X ",p:byte(i,i))
	end
	return o
end

local function setKissUpdate(text)
	print("kissUpdate:"..text)
	kissUpdate = os.date("%H:%M:%S ")..text
end

local function cmdResponse(text)
	print("Bluetooth:cmdResponse:"..KISSFormatHex(text))
	if doingParts and doingParts[2] and #doingParts[2] > 0 and text:find(doingParts[2]) then
		nextCmd()
		return nil	-- We found our expected response, eat the whole buffer
	end
	return text
end

nextCmd = function()
	if type(doingCmds) ~=  'table' or #doingCmds < 1 then
		commanding = false
		doingCmds = nil
		setKissUpdate("Commands Complete")
		if cmdCallback then serviceWithDelay(nil,500,cmdCallback) end
	else
		local function deEscape(s)
			s = s:gsub("(%^%d%d%d)", function(m) return string.char(tonumber(m:sub(2))) end)
			s = s:gsub("%^%^", "^")
			return s
		end
		commanding = true
		doingParts = doingCmds[1]:split('!')
		print(printableTable("Bluetooth:cmd", doingParts))
		if not doingParts[2] then doingParts[2] = 'cmd:' end
		if not doingParts[3] then doingParts[3] = '1' end
		local cmd = doingParts[1]
		if not cmd then cmd = doingCmds[1] end	-- Command without anything following (no !)
		setKissUpdate(doingParts[4] and doingParts[4] or doingCmds[1])
		table.remove(doingCmds,1)
		if cmd:sub(-1,-1) == '~' then	-- Trailing ~ suppresses the default \r
			cmd = cmd:sub(1,-2)
		else cmd = cmd.."\r"			-- Add the default \r
		end
		cmd = deEscape(cmd)
		doingParts[2] = deEscape(doingParts[2])
		print(string.format("cmd(%s)->%s Rsp(%s)->%s", doingParts[1], KISSFormatHex(cmd), doingParts[2], KISSFormatHex(doingParts[2])))
		if MOAIAppAndroid
		and type(MOAIAppAndroid.transmitBluetooth) == 'function' then
			MOAIAppAndroid.transmitBluetooth(cmd)
		else print("Bluetooth:transmitBluetooth="..type(MOAIAppAndroid.transmitBluetooth))
		end
		cmdTimeout = MOAISim.getDeviceTime() + (tonumber(doingParts[3]) and tonumber(doingParts[3]) or 1)
		serviceWithDelay(nil, 100, function()
			if not commanding or not cmdTimeout then return 'cancel' end
			if MOAISim.getDeviceTime() > cmdTimeout then
print("Bluetooth:cmdTimout:"..tostring(MOAISim.getDeviceTime()).." vs "..tostring(cmdTimeout))
				nextCmd()
				return 'cancel'
			end
		end, 0)
	end
end

function BTPort:doCmds(which, callback)
	if not which then
		callback()
	elseif type(which) == 'table' then
		if #which == 0 then return end
		doingCmds = {unpack(which)}	-- Copy the table so we can eliminate as we go
	elseif type(which) == 'string' then
		doingCmds = {which}	-- Make a single entry table
	end
	cmdCallback = callback
	nextCmd()
end

function BTPort:setCommands(cmdFile)
	if cmdFile and cmdFile ~= '' then
		local dir, file = cmdFile:match("(.+)/(.+)")
print("Loading command XML from dir("..tostring(dir)..") file("..tostring(file)..")")
		if dir and file then
			local xmlapi = require( "xml" ).newParser()
			local status, raw = pcall(xmlapi.loadFile, xmlapi, file, dir )
			if status then
				local use = xmlapi:simplify( raw )
				local function adjustTable(t)
					if type(t) == "string" then
						t = {t}
					elseif type(t) ~= "table" then
						t = nil
					end
					return t
				end
				openCmds = adjustTable(use.OpenCmd)
				closeCmds = adjustTable(use.CloseCmd)
				preCmds = adjustTable(use.PreXmitCmd)
				postCmds = adjustTable(use.PostXmitCmd)
				xmitFormat = use.XmitFormat
				print(printableTable(file.."-openCmds",openCmds,"\r\n"))
				print(printableTable(file.."-closeCmds",closeCmds,"\r\n"))
				print(printableTable(file.."-preCmds",preCmds,"\r\n"))
				print(printableTable(file.."-postCmds",postCmds,"\r\n"))
			else toast.new("xmlapi.loadFile("..tostring(file)..") Failed with "..tostring(raw))
			end
		end
	end
end

local bit = bit
if type(bit) ~= 'table' then
	if type(bit32) == 'table' then
		print('bit:using internal bit32 module')
		bit = bit32
	else
		print('bit:using mybits type(bit)='..type(bit))
		bit = require("mybits")
		bit.lshift = bit.blshift
		bit.rshift = bit.blogic_rshift
	end
else print('bit:using internal bit module!')
end

local function KISSify(packet)
	local function KISSCall(packet)
		local i = 1
		local o = ""
		while packet:sub(i,i) ~= '*'
		and packet:sub(i,i) ~= '>'
		and packet:sub(i,i) ~= ':'
		and packet:sub(i,i) ~= ','
		and packet:sub(i,i) ~= '-' do
			if i > 6 then return nil end
			o = o..string.char(bit.lshift(packet:byte(i),1))	-- Left shift callsign one bit
			i = i + 1
		end
		for j=i,6 do
			o = o..string.char(bit.lshift(32,1))	-- Left shift space padding
		end
		local final = 0
		local ssidStart, ssidEnd = packet:sub(i):find("%-%d%d?")
		if ssidStart and ssidStart == 1 then
print("SSIDStart:"..tostring(ssidStart+1).." End:"..tostring(ssidEnd+1).." in "..packet)
print("KISS-SSID="..tostring(packet:sub(ssidStart+i,ssidEnd+i-1)))
			final = bit.lshift(tonumber(packet:sub(ssidStart+i,ssidEnd+i-1)),1)
			i = ssidEnd + i
		end
		if packet:sub(i,i) == '*' then
			i = i + 1
			final = bit.bor(final,0x80)
		end
		final = bit.bor(final,0x60)
		o = o..string.char(final)
print("KISSCall("..packet:sub(1,9)..")="..KISSFormatHex(o).." leaving:"..packet:sub(i))
		return o, packet:sub(i)
	end

	local p = string.char(0xC0, 0x00)	-- KISS and channel 0 data
	local srcCall, dstCall, pathCall, remainder
	srcCall, remainder = KISSCall(packet)
	if remainder:sub(1,1) ~= '>' then
		print("KISS:Missing >, Possible invalid -SSID in "..packet)
		return nil
	end
	dstCall, remainder = KISSCall(remainder:sub(2))
	if remainder:sub(1,1) ~= ',' and remainder:sub(1,1) ~= ':' then
		print("KISS:Missing path or payload, Possible invalid -SSID in "..packet)
		return nil
	end
	-- The following Sets the H bit on Dest, not Source (1 0 = Command)
	dstCall = dstCall:sub(1,6)..string.char(bit.bor(dstCall:byte(7,7),0x80))
	p = p..dstCall..srcCall
	while remainder:sub(1,1) == ',' do
		pathCall, remainder = KISSCall(remainder:sub(2))
		p = p..pathCall
	end
	if remainder:sub(1,1) ~= ':' then
		print("KISS:Missing payload, Possible invalid -SSID in "..packet)
		return nil
	end
	p = p:sub(1,-2)..string.char(bit.bor(p:byte(-1),0x01)) -- Set the last address flag
	p = p..string.char(0x03, 0xF0)	-- UI packet and No Level 3 Protocol
	p = p .. remainder:sub(2)	-- And add the remaining payload to the output packet
	p = p .. string.char(0xC0)
	return p
end

local function KISSFormatReceive(p)
	local function KISSTranslateCall(c, includeUsed)
		local r = ""
		for i=1,6 do
			if c:byte(i,i) ~= bit.lshift(32,1) then
				r = r..string.char(bit.band(bit.rshift(c:byte(i,i),1),0x7f))
			end
		end
		local ssid = bit.band(bit.rshift(c:byte(7,7),1),0x0f)
		if ssid ~= 0 then
			r = r..string.format("-%d",ssid)
		end
		if includeUsed and bit.band(c:byte(7,7),0x80) ~= 0 then
			r = r.."*"
		end
--		print("KISSTranslateCall("..tostring(KISSFormatHex(c:sub(1,7)))..")="..tostring(r))
		return r
	end
	
	if #p < 1 then return nil end	-- Gotta have SOMETHING to parse!
	while #p >= 1 and p:byte(1,1) == 0xC0 do p = p:sub(2) end	-- Remove (residual) leading <C0>s
	if #p < 1 then return nil end	-- Ate the whole "packet"
	if bit.band(p:byte(1,1),0x0F) ~= 0 then
		local hasC0 = (p:byte(-1,-1) == 0xC0)
		print("KISS:Missing Command 0"..(hasC0 and ", found C0" or ", no C0").." in "..KISSFormatHex(p))
		return nil
	end
	if p:byte(-1,-1) ~= 0xC0 then
		print("KISS:Missing closing <C0>")
		return nil
	end
--[[
	if (p[0]&0x80)	/* SMACK packet? */
	{	PortDumpHex(NULL, "KISS:Ignoring SMACK Checksum", OrgLen, Pkt);
		e[-1] = e[-2] = 0xC0;	/* Stomp checksum with C0s */
		Len -= 2;	/* And don't process them */
	}
]]
	if bit.band(p:byte(1,1),0x70) ~= 0 then
		print(string.format("KISS:Processing MultiPort[%d] as 0",bit.band(p:byte(1,1),0x70)))
	end
--[[
	if (Len>=7 && Pkt[1]=='$' 	/* $....*cc (Optionally <CR> or <CR><LF>) */
	&& (Pkt[Len-4]=='*' || Pkt[Len-5]=='*' || Pkt[Len-6] == '*'))
	{	TraceLog("NMEA", FALSE, NULL, "Parsing KISS[%ld] NMEA(%.*s)\n", (long) (p[0]&0x70)>>4, (int)Len-2, Pkt+1);
		NMEAFormatReceive(Len-2, Pkt+1, rLen);
		*rLen += 2;	/* Account for Cmd/Port and C0*/
		return NULL;	/* got nothing from this one as far as APRS */
	}
]]
	if #p < 18 then
		print("KISS:Not Long Enough, Need 18 Got "..tostring(#p))
		return nil
	elseif #p > 400 then
		print("KISS:Too Long, Max 400 Got "..tostring(#p))
		return nil
	end
	
	local r = ""
	r = KISSTranslateCall(p:sub(9), false)..">"..KISSTranslateCall(p:sub(2), false)
	p = p:sub(15)	-- Keep the last character for the "More" bit
	while #p > 7 and bit.band(p:byte(1),0x01)==0 do
		r = r..","..KISSTranslateCall(p:sub(2), true)
		p = p:sub(8)
	end
	if #p > 3 and p:byte(2,2) == 0x03 and p:byte(3,3) == 0xF0 then
		p = p:sub(4)
		r = r..":"
		while #p>0 and (p:sub(1,1)=='\r' or p:sub(1,1)=='\n') do
			p = p:sub(2)
		end
		r = r..p:sub(1,-2)	-- Drop the trailing <C0>
		while r:byte(-1,-1)== 0 or r:sub(-1,-1)=='\r' or r:sub(-1,-1)=='\n' do
			r = r:sub(1,-2)
		end
--[[
{	BOOL HasNULL = KissStrnChr(Out-Packet, Packet, '\0') != NULL;
	if (HasNULL)
		PortDumpHex("Packets(NULL)", "KISS:NULL-Truncated", (int)(Out-Packet), Packet);
	TraceLog(NULL, FALSE, NULL, "KISS:%.*s  (%ld)\n",(int)(Out-Packet), Packet, (long) Out[-2]);
}
]]
		return r
	else
		print("KISS:Missing 03 F0")
		return nil
	end
end

if MOAIAppAndroid and type(MOAIAppAndroid.setListener) == 'function' and type(MOAIAppAndroid.BLUETOOTH_CALLBACK) == 'number' then

local function KISSTransmit(packet)
	local k = KISSify(packet)
	if k then
		if MOAIAppAndroid
		and type(MOAIAppAndroid.transmitBluetooth) == 'function' then
			MOAIAppAndroid.transmitBluetooth(k)
		else print("Bluetooth:transmitBluetooth="..type(MOAIAppAndroid.transmitBluetooth))
		end
	else
		toast.new("Invalid KISS Packet!")
	end
end

local udpSock = socket.udp()
udpSock:setpeername("aprsisce.dnsalias.net", 3000)
local udpSeq = 1
local function IGate(p)
	if APRS then
		APRS:received(p,BTPort)
	end
	while #p>0 and (p:byte(-1,-1)== 0 or p:sub(-1,-1)=='\r' or p:sub(-1,-1)=='\n') do
		p = p:sub(1,-2)
	end
	local payload = p:find(':')
	if not payload then
		print("IGate:Missing Payload In "..p)
		setKissUpdate("NoPayload:"..p:sub(1,22))
		return false
	end
	local datatype = p:sub(payload+1,payload+1)
	if datatype == '}' then	-- 3rd party
		print("IGate:3rdParty:"..p)
		setKissUpdate("3rdParty:"..p:sub(1,23))
		return false
	end
	if p:find(",NOGATE") or p:find(",RFONLY") then
		print("IGate:NOGATE/RFONLY:"..p)
		setKissUpdate("NOGATE/RFONLY:"..p:sub(1,18))
		return false
	end
	if p:find(",q") then
		print("IGate:q-Constructed:"..p)
		setKissUpdate("q-Construct:"..p:sub(1,20))
		return false
	end
	p = p:sub(1,payload-1)..",qAO,"..config.StationID..p:sub(payload)
	print("IGate:"..tostring(p))
	setKissUpdate(datatype..' '..p:sub(1,32))
	if APRSIS and config.Bluetooth.IGate then
		APRSIS:sendPacket(p)
	end
	local u = os.date("!%Y-%m-%dT%H:%M:%S")
	u = string.format("%s IGated:%s:[%d]%s", u, config.StationID, udpSeq, p)
--	print("UDP:"..tostring(u))
	local status, text = udpSock:send(u)	-- Tell the back-end about the gated packet
	if not status then
		print("udpSock failed with "..tostring(text))
		udpSock:close()
		udpSock = socket.udp()
		udpSock:setpeername("aprsisce.dnsalias.net", 3000)
	end
	udpSeq = udpSeq + 1
--[[
	SYSTEMTIME stUTCTime;
	GetSystemTime(&stUTCTime);
	int Len = sprintf(Buffer,"%04ld-%02ld-%02ldT%02ld:%02ld:%02ld %s:%s:[%ld]%s",
						(long) stUTCTime.wYear, 
						(long) stUTCTime.wMonth, 
						(long) stUTCTime.wDay, 
						(long) stUTCTime.wHour, 
						(long) stUTCTime.wMinute, 
						(long) stUTCTime.wSecond,
						(pPort->RfBaud!=-1)?"IGated":"IStoIS",
						CALLSIGN, (long) UDPSeq++,
						Packet);
	if (!tcp_send_udp("aprsisce.dnsalias.net", 3000, Len+1, Buffer, 1))	/* Single shot */
]]
	return true
end

local function NMEA(p)
end

	print("btPort:start:Registering MOAIAppAndroid's BluetoothCallback as "..tostring(MOAIAppAndroid.BLUETOOTH_CALLBACK))
	local pending = nil
	local C0 = string.char(192)
	MOAIAppAndroid.setListener ( MOAIAppAndroid.BLUETOOTH_CALLBACK,
									function(what, text)
										if what == 'receive' then
											if pending then print("Bluetooth:Pending:"..KISSFormatHex(pending)) end
											print("Bluetooth:Receive:"..KISSFormatHex(text))
											if pending then text=pending..text pending=nil end
											if commanding then
												pending = cmdResponse(text)
											else
												if text == C0 then-- Received just a C0, buffer it
													print("Bluetooth:Only:"..KISSFormatHex(text))
													pending = text
													setKissUpdate("Lone C0")
												elseif text:sub(1,1) == C0 then	-- <C0>
													local c = 0
													for line in text:gmatch(".-"..C0) do
														if line ~= C0 then
	--														print("Bluetooth:KISS:"..KISSFormatHex(line))
															local p = KISSFormatReceive(text)
															print("Bluetooth:KISS:"..tostring(p))
															if type(p) == 'string' then
																IGate(p)
															else
																print("KISS:FAILED:"..KISSFormatHex(p))
															end
														end
														c = c + #line
													end
													text = text:sub(c+1)
													if text ~= "" then
														print("Bluetooth:Residual:"..KISSFormatHex(text))
														pending = C0..text
														setKissUpdate("Residual "..tostring(#pending).." kiss!")
													end
													if pending and #pending > 2048 then
														print("Bluetooth:Flushing:"..KISSFormatHex(pending))
														setKissUpdate("Flushed "..tostring(#pending).." kiss!")
														pending = nil
													end
												else
													local nonPrint = false
													for i=1,#text do
														local b = text:byte(i,i)
														if b<28 or b>127 then	-- 28-31 are used in Mic-E
															if b ~= 10 and b~= 13 then	-- Embedded \n and \r are ok
																nonPrint = true
																break
															end
														end
													end
													if nonPrint then
														local o = ""
														for i = 1,#text do
															o = o .. string.format("%02X ",text:byte(i,i))
														end
														print("Bluetooth:NonPrint:"..o)
													else
														text = text:gsub("\r","\n")
														local c = 0
														for line in text:gmatch(".-\n") do
															if line ~= '\n' then
																if line:sub(1,1) == "$" then	-- NMEA string
																	NMEA(line)
																else
																	IGate(line)
																end
															end
															c = c + #line
														end
														text = text:sub(c+1)
														if text ~= "" then
															print("Bluetooth:Residual:"..text)
															pending = text
															setKissUpdate("Residual "..tostring(#pending).." text!")
														end
														if pending and #pending > 2048 then
															print("Bluetooth:Flushing:"..pending)
															setKissUpdate("Flushed "..tostring(#pending).." text!")
															pending = nil
														end
													end
												end
											end
										elseif what == "sent" then
											print("Bluetooth:"..tostring(what)..":"..KISSFormatHex(text))
										elseif what == 'state' then
											print("Bluetooth:"..tostring(what)..":"..tostring(text))
											setKissUpdate(tostring(what)..":"..tostring(text))
											currentState = text
											if text == 'Connected' then
												BTPort:doCmds(openCmds, function() end)
											end
										else
											print("Bluetooth:"..tostring(what)..":"..tostring(text))
											setKissUpdate(tostring(what)..":"..tostring(text))
										end
									end )

	APRS:addTransmitListener(function(what, packet)
print("btPort:state:"..tostring(currentState).." transmit:"..what.." "..packet)
								if currentState == 'Connected' then
									if ((config.Bluetooth.TransmitPosits and what == 'posit')
										or (config.Bluetooth.TransmitMessages and what == "message"))
									and xmitFormat == 'KISS' then
										local header = config.StationID..">"..config.ToCall
										if config.Bluetooth.Path ~= "" then
											header = header..","..config.Bluetooth.Path
										end
										packet = header..":"..packet
										if xmitQueue then
											table.insert(xmitQueue, packet)
										else
											xmitQueue = {packet}
											BTPort:doCmds(preCmds, function()
																print("Bluetooth:Transmitting "..tostring(#xmitQueue).." packet(s)")
																for i, p in pairs(xmitQueue) do
																	KISSTransmit(p)
																end
																xmitQueue = {}
																BTPort:doCmds(postCmds, function()
																							if #xmitQueue > 0 then
																								print("Bluetooth:Dumping "..tostring(#xmitQueue).." Transmit packet(s)")
																							end
																							xmitQueue = nil
																						end)
															end)
										end
									end
								end
							end)
	APRS:addReceiveListener(function(packet, port) end)
									
end

--[[do
	local packet = "KJ4ERJ-12>APWA01,KJ4ERJ-7*,WIDE2-1:>Test Status Packet"
	print("KISSPacket="..packet)
	local p = KISSify(packet)
	print("KISS="..KISSFormatHex(p))
	print("deKISS="..KISSFormatReceive(p))
end]]

--[[
local text = "C0 00 82 A0 A4 A6 40 40 60 96 86 64 84 A4 84 62 AE 86 68 A0 8A 9A FC AE 92 88 8A 64 40 63 03 F0 40 32 35 31 33 34 37 7A 32 38 33 31 2E 30 37 4E 2F 30 38 31 34 32 2E 39 32 57 5F 30 30 30 2F 30 30 30 67 30 30 30 74 30 36 38 72 30 30 30 70 30 30 30 50 30 30 30 68 39 34 62 31 30 31 37 37 2E 44 73 56 50 0D 0A C0 "
local p = ""
for i=1,#text,3 do
	local function Hex(c)
		local b = c:byte(1,1)
		if b >= 65 then b = b - 65 + 10
		else b = b - 48 end
		print(string.format("Hex(%s) is %d", c, b))
		return b
	end
	local n = Hex(text:sub(i,i))*16+Hex(text:sub(i+1,i+1))
	print(string.format("Hex(%s) is %X", text:sub(i,i+1), n))
	p = p..string.char(n)
end
print("KISSFormatReceive:"..tostring(KISSFormatReceive(p)))
]]

return BTPort
