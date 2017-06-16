-- Look for CRPTOR for hard-coded weather polygon test

local APRSIS = { VERSION = "0.0.1" }

local debugging = false

local toast = require("toast");
local APRS = require("APRS")

--	Forward references for callbacks
local getConnection
local closeConnection

packetCount = 0

local packetCallback

local config = nil	-- set by APRSIS:start(config) below
local appName, appVersion = "APRSIS", "*unknown*"

function APRSIS:setAppName(name, version)
	appName = name or appName
	appVersion = version or appVersion
end

function APRSIS:setPacketCallback(callback)	-- is passed a single received APRS packet + self
	if type(callback) == 'function' then
		packetCallback = callback
		
		--performWithDelay(15000, function() packetCallback("CRPTOR>APRS,qAO,AE5PL-WX:;CRPTORKlA*212145z2759.84N\\08000.53Wt112/005 TORNADO }a0IE;IFDIEPHQHWWY^4\\9X8R=Q<Q6W4O3E;{LKlAA", nil, APRSIS) end)
		--performWithDelay(16000, function() packetCallback("KJ4ERJ-AP>APWW10,TCPIP*,qAC,KJ4ERJ-5:;TriplNWMA*030356z2807.82N\\08101.12W;Triple N WMA - Hiking!!w*r!", nil, APRSIS) end)
		--performWithDelay(17000, function() packetCallback("KJ4ERJ-AP>APWW10,TCPIP*,qAC,KJ4ERJ-5:;GCYQ45   *030357z2807.07N/08101.17W.Triple N Ranch!wE*!", nil, APRSIS) end)
	end
end

local connectedCallback

function APRSIS:setConnectedCallback(callback)
	if type(callback) == 'function' then	-- gets server:port or nil on disconnect
		connectedCallback = callback
	end
end

function APRSIS:triggerReconnect(why, delay)
	serviceWithDelay('Reconnect', tonumber(delay) or 0, function() closeConnection(why or "Reconnect") end)
end

local client, clientServer

function APRSIS:getPortName()
	return "APRS-IS("..clientServer..")"
end

local socket = require("socket")

local client
local lastReceive, lastPackets, lastIdle

local clientConnecting
local function timedConnection()
--print('timedConnection:client='..tostring(client)..' connecting='..tostring(clientConnecting)..' server='..tostring(clientServer))
	if config.APRSIS.Enabled then
		if not client then
			local status, text = pcall(getConnection)
			if not status then
				scheduleNotification(0,{alert = 'getConnection:'..tostring(text)})
			end
--		else
--			local text = os.date("%H:%M:%S:")..tostring(clientServer)..' '..tostring(clientConnecting)
--			print(text)
		end
--	else
--		local text = os.date("%H:%M:%S:APRS-IS Disabled!")
--		print(text)
	end
	serviceWithDelay('timedConnection', 60*1000, timedConnection)
end

closeConnection = function (why)
	print('closeConnection('..why..')')
	if client then
		setSyslogIP(false)	-- in myinit.lua (just in case our IP address changed)
		client:close()	-- Close it down
		client = nil	-- and clean it up so getConnection will recover
		clientServer = nil
		if connectedCallback then
			local status, text = pcall(connectedCallback,nil)
			if not status then
				scheduleNotification(0,{alert = 'connectedCallback:'..tostring(text)})
			end
		end
		local alert = "APRS-IS Lost("..tostring(why)..")"
		if not config.APRSIS.Notify then
			toast.new(alert, 2000)
		else
			local options = { alert = alert, --badge = #notificationIDs+1, --sound = "???.caf",
								custom = { name="flushClient", Verified=Verified } }
			scheduleNotification(0,options)
		end
	end
	serviceWithDelay('getConnection', 5*1000, getConnection)
end

local function getLuaMemory()
	if type(MOAISim.getMemoryUsagePlain) == "function" then
		return MOAISim.getMemoryUsagePlain()
	end
	local m = MOAISim.getMemoryUsage()
	return m.lua or 0
end

local lastRCount = 0
local residualReceived = ""
local function flushClient()
	local packetInfo = nil
	if client then
		local rcvTime, callTime, gcTime = 0, 0, 0
		local count = 0
		local startTime = MOAISim.getDeviceTime()
		local maxTime = startTime + (1.0/30.0)
		local mStart = getLuaMemory()
		local gotoStation
		repeat
			local rcvStart = MOAISim.getDeviceTime()
			if rcvStart > maxTime then break end	-- Don't spend too long receiving!
			local line, err, residual = client:receive('*l')
			if line then
				line = residualReceived..line	-- add back in what we had on the last timeout
				residualReceived = ""	-- and clear it out since we just used it!
--local org, path, packet = line:match('(.+)>(.+):(.+)')
--if not org then print("flushClient:after["..tostring(lastRCount).."]received["..tostring(count).."]:"..line)
--else print("org["..tostring(count).."]:"..tostring(org).." path:"..tostring(path).." packet:"..tostring(packet))
--end
				count = count + 1
				lastRCount = count
				packetCount = packetCount + 1
				if packetCallback then
					local callStart = MOAISim.getDeviceTime()
					rcvTime = rcvTime + (callStart-rcvStart)
					if debugging then
						packetCallback(line, APRSIS)
					else
						local status, text = pcall(packetCallback, line, APRSIS)
						if not status then
							scheduleNotification(0,{alert='APRSIS:packetCallback:'..tostring(text)})
						end
					end
					callTime = callTime + (MOAISim.getDeviceTime()-callStart)
				end
--				local gcStart = MOAISim.getDeviceTime()
--				collectgarbage("step")
--				gcTime = gcTime + (MOAISim.getDeviceTime()-gcStart)
			else
				residualReceived = residualReceived..residual
				--if residual and residual ~= "" then print("flushClient:err:"..tostring(err).." residual:"..tostring(residual)) end
				if err ~= 'timeout' then
					closeConnection('Receive Error:'..err)
				end
			end
		until not line
		if client then
			local mEnd = getLuaMemory()
			local mDelta = (mEnd - mStart) / 1024
			local thisTime = MOAISim.getDeviceTime()
			local text = string.format('%i Packets in %.2fms(%.2f+%.2f) %.2fK',
										count, (thisTime-startTime)*1000,
										rcvTime*1000, callTime*1000, mDelta)
			local idle = ""
			if lastReceive then idle = ' Idle '..(math.floor((thisTime-lastReceive)*1)/1)..'s' end
			if count > 0 then
				lastPackets = text
				lwdUpdate = lastPackets..idle
				lastIdle = idle
			elseif idle ~= lastIdle then
				lwdUpdate = (lastPackets or "")..idle
				lastIdle = idle
			end

			--lwdtext:setString ( text );
			--lwdtext:fitSize()
			--lwdtext:setLoc(Application.viewWidth/2, 75*config.Screen.scale)

			if lwdtext then
				if not lwdtext.touchup then
					lwdtext.touchup = true
					lwdtext:addEventListener("touchUp",
								function()
									print("lwdtext touched!")
									local text = tostring(clientServer)..' '..tostring(clientConnecting)
									if MOAIEnvironment.SSID and MOAIEnvironment.SSID ~= "" then
										text = text.."\nWiFi:"..MOAIEnvironment.SSID
									end
									if MOAIEnvironment.BSSID and MOAIEnvironment.BSSID ~= "" then
										text = text.."\nAP:"..MOAIEnvironment.BSSID
									end
									toast.new(text)
								end)
				end
			end

			if count > 0 then
				lastReceive = thisTime
			elseif lastReceive
			--and config.APRSIS.QuietTime > 0
			and (thisTime-lastReceive) > 60 then
				text = string.format('No Data in %i/%is',
												math.floor((thisTime-lastReceive)),
												60)
				closeConnection(text)
				lastReceive = nil
			end
		else
			lwdUpdate = "APRS-IS Lost"
			--flushStatus.text = "APRS-IS Connection Lost"
			lastReceive = nil
		end
		serviceWithDelay('flushClient', 50, flushClient)
		--coroutine.yield()
	else
		print ('No Client Connection')
	end
end

function APRSIS:sendPacket(packet)
	print ('APRSIS:sendPacket:'..packet)
	if client then
		local n, err = client:send(packet..'\r\n')
		if type(n) ~= 'number' or n == 0 then
			closeConnection('sendPacket Error:'..tostring(err))
			return 'Send Error'
		end
		return nil
	end
	return 'No Client Connection'
end

local function formatFilter()
	local range = tonumber(config.Range) or 50
	local filter = config.Filter or "u/APWA*/APWM*/APWW*"
	if range >= 1 then
		return string.format('r/%.2f/%.2f/%i m/%i %s', myStation.lat, myStation.lon, range, range, filter)
	elseif #filter > 0 then
		return filter
	else return 'p/KJ4ERJ'	-- hopefully not too many people get this!
	end
end

local lastFilter, ackFilter

function APRSIS:sendFilter(ifChanged)
	if client then
		if myStation.lat ~= 0.0 or myStation.lon ~= 0.0 then
			local filter = formatFilter()
			if filter ~= lastFilter or not ifChanged then
				ackFilter = ackFilter or 1
				--filter = filter..' g/BLT p/K/N/W'	-- Temporary hack!
				local msg = string.format('%s>APWA00,TCPIP*::SERVER   :filter %s{%s', config.StationID, filter, ackFilter)
				msg = '#filter '..filter	-- send to SERVER doesn't work on non-verified connections :(
				local n, err = client:send(msg..'\r\n')
				if type(n) ~= 'number' or n == 0 then closeConnection('sendFilter Error:'..tostring(err)) end
				ackFilter = ackFilter + 1
				if ackFilter > 9999 then ackFilter = 1 end
				print ('sendFilter:'..msg)
				filtered = true
				lastFilter = filter
			else
				--print('sendFilter:Suppressed Redundant Filter:'..filter)
			end
		end
	end
end

local function clientConnected()
	if client then
		--Get IP and Port from client
		local ip, port = client:getsockname()
		--Print the ip address and port to the terminal
		print("APRS-IS@"..ip..":"..port.." Remote: "..tostring(client:getpeername()))
		setSyslogIP(ip, config.StationID)	-- in myinit.lua
		if connectedCallback then
			if debugging then
				connectedCallback(clientServer)
			else
				local status, text = pcall(connectedCallback,clientServer)
				if not status then
					scheduleNotification(0,{alert="connectedCallback:"..tostring(text)})
				end
			end
		end
	
		client:settimeout(0)	-- no timeouts for instant complete
		client:setoption('keepalive',true)
		client:setoption('tcp-nodelay',true)
		local myVersion = appVersion:gsub("(%s)", "-")

		local n, err
		local filter = formatFilter()
		local logon = string.format('user %s pass %s vers %s %s filter %s',
									config.StationID, config.PassCode,
									appName, myVersion, filter)
print(logon)
		n, err = client:send(logon..'\r\n')
print("logon sent:"..type(n)..' '..tostring(n))
		if type(n) ~= 'number' or n == 0 then
			closeConnection('sendLogon Error:'..tostring(err))
		else
			serviceWithDelay('flushClient', 10, flushClient)
			--local flushThread = MOAICoroutine.new()
			--flushThread:run(flushClient)
		end
--[[		local homeIP, text = socket.dns.toip('ldeffenb.dnsalias.net')
		if not homeIP then
			toast.new("dns.toip(ldeffenb.dnsalias.net) returned "..tostring(text))
		else toast.new('ldeffenb.dnsalias.net='..tostring(homeIP))
		end]]
	else
		print ('Failed to connect to the APRS-IS')
	end
end

local chkCount = 0

local function checkClientConnect(master, startTime)
	local elapsed = (MOAISim.getDeviceTime() - startTime)*1000
	print('checkClientConnect('..tostring(master)..') elapsed '..tostring(elapsed)..'ms')
	chkCount = chkCount + 1
	local text = 'Chk'..tostring(chkCount)..'@'..tostring(clientConnecting)..' '..tostring(math.floor(elapsed))..'ms'
	print(text)
	local readable, writeable, err = socket.select(nil, { master }, 0)
	if err then print('master.select('..tostring(master)..' returned '..tostring(err)) end
	if writeable and #writeable > 0 then
		print(tostring(#writeable)..' writeable sockets!  is '..tostring(master)..'=='..tostring(writeable[1])..'?')
		if writeable[1] == master then
			client = master
			text = 'good@'..tostring(clientConnecting)..' '..tostring(math.floor(elapsed))..'ms'
			clientServer = clientConnecting..' ('..tostring(client:getpeername()).."<"..tostring(client:getsockname())..')'
			clientConnecting = nil
			clientConnected()
		else
			master:close()
			clientConnecting = nil
			lwdUpdate = "Master Socket not Writeable"
			text = 'Fail1@'..tostring(ip)..':'..tostring(port)..' '..tostring(math.floor(elapsed))..'ms'
			--flushStatus.text = "APRS-IS Connect Failed in "..tostring(elapsed)..'ms'
		end
	elseif elapsed > 30*1000 then
		print('Giving up and closing '..tostring(master)..' after '..tostring(math.floor(elapsed))..'ms')
		clientConnecting = nil
		master:close()
		text = 'Fail2@'..tostring(ip)..':'..tostring(port)..' '..tostring(math.floor(elapsed/1000))..'s'
		lwdUpdate = "APRS-IS Connect Timeout"
		--flushStatus.text = "APRS-IS Connect Failed in "..tostring(elapsed)..'ms'
	else
		local delay = math.min(elapsed/4, 1000)
		serviceWithDelay('checkConnect', delay, function() checkClientConnect(master, startTime) end)
		lwdUpdate = string.format("APRS-IS Connecting %d/%d...", math.floor(elapsed/1000), 30)
	end
end

local getCount = 0
getConnection = function ()
	if config.APRSIS.Enabled then

print('getConnection:client='..tostring(client)..' connecting='..tostring(clientConnecting))

	getCount = getCount + 1
	text = 'get'..tostring(getCount)..':'..tostring(client)..' '..tostring(clientConnecting)..' '..tostring(clientServer)
	print(text)

--Connect to the client
	if not client and not clientConnecting then
		getCount = 0
		chkCount = 0
		print ('Connecting to the APRS-IS')
		if config.APRSIS.Server and config.APRSIS.Port then
			clientConnecting = config.APRSIS.Server..':'..config.APRSIS.Port
			--lastStation.text = config.StationID
			text = 'Connecting@'..tostring(clientConnecting)
			print(text)
			serviceWithDelay('connectMaster', 1, function()
				local startTime = MOAISim.getDeviceTime()
				local master = socket.tcp()	-- Get a master socket
					--client = socket.connect(config.APRSIS.Server, config.APRSIS.Port)
					master:settimeout(0)	-- No timeouts on this socket
					print ('REALLY Connecting to the APRS-IS')
				local i, err = master:connect(config.APRSIS.Server, config.APRSIS.Port)
				if i then	-- Must have accepted it
					print('connect('..tostring(master)..') initiated with '..tostring(i)..':'..tostring(err))
					serviceWithDelay('checkConnect', 10, function() checkClientConnect(master, startTime) end)
				else
					print('connect('..tostring(master)..') failed with '..tostring(err))
					if err == 'timeout' then
						serviceWithDelay('checkConnect', 10, function() checkClientConnect(master, startTime) end)
					else
						master:close()
						text = 'Fail3@'..tostring(clientConnecting)..' '..tostring(err)
						print(text)
						lwdUpdate = err
						clientConnecting = nil
					end
				end
			end	) -- timer.performWithDelay closure
			print ('Connect initiated')
		end	-- if Server and Port
	end	-- if not client

	end	-- If Enabled
end

function APRSIS:start(configuration)

print("APRSIS:start - Starting with "..tostring(configuration))

	if type(configuration) == 'table' and type(configuration.APRSIS) == 'table' then
		config = configuration

		serviceWithDelay('bootstrap', 1000, timedConnection)	--jump start the whole thing!

	else
		print('APRSIS:start() requires table configuration with .APRSIS table inside!, got '..type(configuration)..' and '..type(configuration.APRSIS))
	end
end

APRS:addTransmitListener(function(what,packet)
							APRSIS:sendPacket(config.StationID..">"..config.ToCall..",TCPIP*:"..packet)
						end)

return APRSIS
