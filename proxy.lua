local socket = require("socket")	-- for socket.gettime()
local toast = require("toast");

local proxyCount, proxySend, proxyRecv = 0,0,0

local function proxyReadWrite(incoming, outgoing)
	local gotStuff, err, partial = incoming:receive(8192)
	if not gotStuff then
		if not partial or err ~= 'timeout' then
			print("readwrite: Error reading was "..tostring(err))
			return 0
		else gotStuff = partial
		end
	end
	if gotStuff ~= "" then
		--print("Sending("..tostring(gotStuff)..")")
		local success, err, sent = outgoing:send(gotStuff)
		if not success then print("readwrite: Error sending was "..tostring(err).." sent "..tostring(sent).." bytes"); return 0; end
		--print("readwrite success!")
	else
		toast.new("readwrite:NOOP")
	end
	if #gotStuff == 0 then toast.new("Read ZSERO bytes!") end
	return #gotStuff;
end

local function proxyRun(incoming, outgoing)

	local sockets = { incoming, outgoing }
	local readable, writeable, err = socket.select( sockets, nil, 0)
	
	--print("Readable:"..printableTable("Readable", readable).." Writeable:"..printableTable("Writeable", writeable));

	if not err then
		if readable[incoming] then
			--print("incoming readable")
			local bytes = proxyReadWrite(incoming, outgoing)
			proxySend = proxySend + bytes
			if bytes == 0 then err = "Incoming Error" end
		end
		
		if readable[outgoing] then
			--print("outgoing readable")
			local bytes = proxyReadWrite(outgoing, incoming)
			proxyRecv = proxyRecv + bytes
			if bytes == 0 then err = "Outgoing Error" end
		end
	end

	if err and err ~= 'timeout' then
		print("Closing Proxy from "..tostring(incoming:getpeername()).." to "..tostring(outgoing:getpeername()).." err:"..err);
		incoming:close()
		outgoing:close()
print("proxy used 2*("..tostring(proxySend).."+"..tostring(proxyRecv)..")="..tostring(2*(proxySend+proxyRecv)).." bytes")
pxyUpdate = tostring(proxyCount).." Proxys used 2*("..tostring(proxySend).."+"..tostring(proxyRecv)..")="..tostring(2*(proxySend+proxyRecv)).." bytes"
		return 'cancel'
	end
end

local function proxyStart(incoming)
	local readable, writeable, err = socket.select( {incoming}, nil, 0)

	proxyCount = proxyCount + 1
	if not err then
		if readable[incoming] then
			local first, err, partial = incoming:receive("*l")
			if not first then
				if not partial or err ~= 'timeout' then
					print("Missing First Line, Closing Proxy from "..tostring(incoming:getpeername()))
					incoming:close(incoming)
					return 'cancel'
				else first = partial
				end
			end

			print("proxyStart: First("..tostring(first)..")")
			
			local method, URL = first:match("(.-) (.-) ")
			print("Method("..tostring(method)..") URL("..tostring(URL)..")")
			
			if method and URL then
			
				local host, URI = URL:match("http://(.-)/(.+)")
				print("Host("..tostring(host)..") URI("..tostring(URI)..")")

				if host and URI then
					URI = '/'..URI	-- put the / back on the URI
					local IP, port = host:match("(.-):(.*)")
					print("IP("..tostring(IP)..") port("..tostring(port)..")")
print("Connecting to "..tostring(IP)..":"..tostring(port))
if config and config.APRSIS.Notify then toast.new("Proxy->"..tostring(IP)) end
					local outgoing, err = socket.connect(IP, tonumber(port))
					if outgoing then
print(tostring(IP).." connected, sending "..method.." "..URI)
if config and config.APRSIS.Notify then toast.new("Proxy "..method.." "..URI) end
						outgoing:settimeout(0)	-- Need no blocking
						outgoing:send(method.." "..URI.." HTTP/1.1\r\n")
						proxySend = proxySend + #method + 1 + #URI + 9 + 2
print("Sent, running proxy")
						serviceWithDelay("proxyRun", 100, function() return proxyRun(incoming, outgoing) end, 0)
						return 'cancel'
					else
if config and config.APRSIS.Notify then toast.new("Proxy Connect Failed!") end
						print("Outgoing Connection Failed With "..tostring(err))
						err = "Outgoing Failed"
					end
				else
					print("Unrecognized Proxy Request("..tostring(first)..")")
					incoming:send("HTTP/1.0 200 OK\r\n\r\n<H1>Nothing To See Here!</H1>")
					incoming:close()
					return 'cancel'

				end
			else
				print("Unrecognized Proxy Request("..tostring(first)..")")
				incoming:send("HTTP/1.0 200 OK\r\n\r\n<H1>Nothing To See Here!</H1>")
				incoming:close()
				return 'cancel'
			end
	
--[[
print("Connecting to thingspeak")
			local outgoing, err = socket.connect("api.thingspeak.com", 80)
			if outgoing then
print("Thingspeak connected, sending first")
				outgoing:settimeout(0)	-- Need no blocking
				outgoing:send(first.."\r\n")
print("Sent, running proxy")
				serviceWithDelay("proxyRun", 100, function() return proxyRun(incoming, outgoing) end, 0)
				return 'cancel'
			else
				print("Outgoing Connection Failed With "..tostring(err))
				err = "Outgoing Failed"
			end
]]			
		end
	end
			

	if err and err ~= 'timeout' then
		print("Closing Proxy from "..tostring(incoming:getpeername()));
		incoming:close()
		return 'cancel'
	end
end

local function proxyAccept(server)
	local incoming, err = server:accept()
	if incoming ~= nil then
		if config and config.APRSIS.Notify then toast.new("proxy accept from "..incoming:getpeername()) end
		print("Accepted connection from "..tostring(incoming:getpeername()))
		incoming:settimeout(0) -- Need no blocking
		serviceWithDelay("proxyStart", 100, function() return proxyStart(incoming) end, 0)
	elseif err ~= 'timeout' then print("proxyAccept: Got err("..tostring(err)..")"); return 'cancel'
	end
end

gserver = socket.bind("*", 12345, 8)
gserver:settimeout(0)	-- no timeouts for instant complete
serviceWithDelay("proxyAccept", 100, function() return proxyAccept(gserver) end, 0)

pxyUpdate = "Proxy Running!"
toast.new("proxy running!")
