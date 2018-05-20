-----------------------------------------------------
-- Spoon web server. Like the Ladle server it is derived from,
-- this is a simple web server designed to provide the bare 
-- minimum of functionality needed to receive a request and 
-- return a page. Unlike Ladle, Spoon has a very limited view 
-- of what pages exist and what is possible.
--
-- Unlike Ladle, Spoon is built as a module so that it can be 
-- embedded in a larger script.
--
-- Derived from the Ladle web server by Samuel Saint-Pettersen.
-- https://code.google.com/p/lua-web-server/
-- Released under the MIT License
-----------------------------------------------------

local socket = require("socket")
local url = require("socket.url")
--local pretty = require "pl.pretty"

-- simplest module framework
local M = {
  _NAME=(...) or "Spoon",
  _DESCRIPTION="A single serving web server.",
  _VERSION="0.003",
  
  escape = url.escape,
  unescape = url.unescape,
}


---
-- Start the web server.
--
-- The single argument is a table containing options and callback functions.
-- If the table is missing, then the server waits for a single HTTP request 
-- on port 8080 to which it will respond "501 Not Implemented".
--
-- Fields in the opt table include:
--
--     port      The port to listen to. Defaults to 8080.
--     loop      True to handle multiple requests
--     verbose   True to print progress and general chatter
--
-- Callbacks are named for the HTTP request they implement. GET is likely the 
-- only important one, but any well-formed HTTP request will be parsed and
-- the method name looked up and called if found.
--
--     GET       function(opt, method, uri, httpver, request)
--
-- The method callback's arguments are the Spoon options, the request method
-- The request URI, the request HTTP version, and a table containing the full
-- details of the request with fields headers containing a hash table of of all 
-- the request headers and body containing any document body.
--
-- The method callback function should return the complete HTTP response 
-- including both headers and body.
--
function M.spoon(opt)
    opt = opt or {}
    
    -- display initial program information
    if M.debug or opt.verbose then 
      print(M._NAME..": "..M._DESCRIPTION.."\nVersion "..M._VERSION)
    end
    
    -- if no port is specified, use port 8080
    if opt.port == nil then opt.port = 8080 end

    -- create tcp socket on localhost:port
    local server = assert(socket.bind("*", opt.port))

    -- display message to show web server is running
    if M.debug or opt.verbose then
      print("\nRunning on localhost:" .. opt.port)
      if opt.loop then
        print "Handling multiple requests, press Ctrl+C to exit"
      end
    end
    
    -- handle one or more client requests
    if not opt.loop then
      M.oneClient(server, opt) -- handle a single client requests
    else 
      while opt.loop do 
        M.oneClient(server, opt) -- handle a single client requests
      end
    end
end


--[[

Summary of ABNF for HTTP messages, both request and response. Requests 
begin with a request-line and responses with a status-line. Both forms
be distinguished by examining the first word. If the line begins with 
"HTTP" the packet is a response; otherwise it begins with a method and 
is a request.

     HTTP-message   = start-line
                      *( header-field CRLF )
                      CRLF
                      [ message-body ]
                      
     start-line     = request-line / status-line
     request-line   = method SP request-target SP HTTP-version CRLF
     status-line    = HTTP-version SP status-code SP reason-phrase CRLF
     status-code = 3DIGIT
     method         = token
     request-target = <path and query parameters>
     HTTP-version   = "HTTP" "/" DIGIT "." DIGIT

     header-field   = field-name ":" OWS field-value OWS

     field-name     = token
     field-value    = *( field-content / obs-fold )
     field-content  = field-vchar [ 1*( SP / HTAB ) field-vchar ]
     field-vchar    = VCHAR / obs-text

     obs-fold       = CRLF 1*( SP / HTAB )
                    ; obsolete line folding
                    ; see Section 3.2.4

--]]

-- read the complete HTTP request from a socket, returning it 
-- as a table containging the request line, a table of headers, 
-- a body string, and the raw headers string.
--
-- Returns the result table or nil and a status code
--
-- See Chapter 3 of RFC7230
local function readrequest(client)
  local res = {}
  local t = {}
  local h = {}
  
    local me = MOAICoroutine:currentThread()
	
	local function receive(client, option)
		if me then
	--	  print("Running under MOAICoroutine, non-blocking yield")
		  client:settimeout(0)   -- do not block
		  local sofar = ''
		  while true do
			  request, err = client:receive(option)
			  if err == "timeout" and (not request or request == "") then
				local start = MOAISim.getDeviceTime()
				coroutine.yield(client)
				local elapsed = (MOAISim.getDeviceTime() - start) * 1000
	--			print(string.format("timeout yield took %.2fmsec", elapsed))
			  elseif err then
				return request, err
			  else
				sofar = sofar..request
				if type(option) == 'number' and #sofar < option then
print(string.format("Only have %d/%d bytes, yielding", #sofar, option))
					local start = MOAISim.getDeviceTime()
					coroutine.yield(client)
					local elapsed = (MOAISim.getDeviceTime() - start) * 1000
		--			print(string.format("timeout yield took %.2fmsec", elapsed))
				else
					return sofar, err
				end
			  end
		  end
		else
		  print("Not running on MOAICoroutine, blocking on receive")
		  return client:receive(option)	-- was request, err =
		end
	end
	
	
  local request, err = receive(client, '*l')

  if M.debug then 
    print("X",request,err)
  end
  if not request then 
    -- TODO: log errors somehow?
    return nil, 500, err -- Internal error if socket failed
  end
  t[#t+1] = request
  
  -- check request line for proper form
  local method, uri, httpver = request:match"^(%S+)%s(%S+)%s(%S+)%s*$"
  if not (method and uri and httpver) then
    return nil, 400, ("Bad request-line:%q"):format(request) -- Bad request if not well formed per 3.1.1
  end
  res.request_line = request
  res.method, res.uri, res.httpver  = method, uri, httpver 
  res.headers = h
  
  -- collect the header lines until the first blank line
  local lname = nil
  while request and #request >= 1 do
    request, err = receive(client,'*l')
    if M.debug then 
      print("X",request,err)
    end
    if not request then 
      -- TODO: log errors somehow?
      return nil, 500, err -- Internal error if socket failed
    end
    t[#t+1] = request
    if #request == 0 then break end
    local name,value = request:match"^([^:%s]+):%s*(.-)%s*$"
    if name then 
      lname = name:lower()
      -- check for extra copies of headers and either collapse
      -- into a single copy or handle as special cases.
      if h[lname] then
        if lname == "set-cookie" then
          -- special cookie handling: make an array of cookies
          if type(h[lname]) == 'string' then
            h[lname] = { h[lname] }
          end
          h[lname][#h[lname]+1] = value
        elseif lname == "content-length" then
          -- repeated content-length headers must all have the same value
          -- per 3.3.2 or the message should be rejected.
          if h[lname] ~= value then
            return nil, 400, "content-length repeated"
          end
        else
          h[lname] = h[lname] .. ',' .. value
        end
      else
        -- preserve the header in the hash table using lower case name
        h[lname] = value
      end
    elseif request:match"^%s+" then  -- obs-fold lines
      if lname then
        h[lname] = h[lname] .. ' ' .. value
      else
        return nil, 400, "folded nothing" -- Bad request because obs-fold has no prior header 
      end
    else
      return nil, 400, ("Bad header:%q"):format(request) -- Badly formed header line
    end
  end
  t[#t+1] = ""
  
  -- collect the body 
  local n = tonumber(h["content-length"])
  if n then
    res.body, err = receive(client, n)
    if M.debug then 
        print("X",res.body,err)
    end
    if not res.body then
      -- TODO: log errors somehow?
      return nil, 400, err
    end
  else
    if h["transfer-encoding"] then
      return nil, 501, "Transfer encodings not implemented" -- not implemented
    end
    res.body = ""
  end
  t[#t+1] = res.body
  res.message = table.concat(t,"\r\n")
  return res  
end

local function handleclient(client, opt)
-- accept a client request
--  local client = server:accept()
  -- set timeout - 0.1 minute.
  client:settimeout(6)

  -- receive the request from the client
  local req, err, why = readrequest(client)
  local response, status 
  if not req then
	local text = why or tostring(err) or "huh?"
	print("readrequest failed with "..text)
    response = M.Errorpage(err, text)
  else 
    local u = url.parse(req.uri)
    local p = u.path and url.parse_path(u.path)
    u.ppath = p
    req.puri = u
    -- Build a table of all the query parameters.
    -- Notice the careful use of URL encoding and '+' for space done here 
    -- so that the form content doesn't change when submitted.
    local q = {}
    u.pquery = q
    if u.query and #u.query > 0 then
      for k,v in u.query:gsub("+"," "):gmatch"([^&=]+)=([^&=]*)" do
        k = url.unescape(k)
        v = url.unescape(v)
        q[#q+1] = k
        q[k] = v
      end
    end

    if M.debug then 
      print("request = "..tostring(req))
    end
    
    -- if there's no error, begin serving content or kill server
    if not err then
      local method = req.method
      if opt[method] then 
        response, status = opt[method](opt, req)
      elseif method == "TRACE" then
        response, status = M.response(200, req.message, "message/http")
      else
        response, status = M.Errorpage(501, 
          '<pre>'
          ..'Method: '..tostring(method)..'\r\n'
          ..'URI: '..tostring(req.uri)..'\r\n'
          ..'ver: '..tostring(req.httpver)..'\r\n'
          ..'</pre>\r\n')
      end
    else
      response, status = M.Errorpage(500, '<pre>\r\n'..err..'\r\n</pre>\r\n')
    end
  end
  if opt.verbose then print(req and req.request_line or "?", status) end
  client:send(response)
  client:close()
end


---
-- Wait for and handle a client request. 
--
-- Parse the request and pass it to handlers for each method provided via the opt
-- table. Be aware of escaping issues, and unescape the parsed request appropriately
-- for each part. 
function M.oneClient(server, opt)

  local client
  
  local ip, port = server:getsockname()
  
  print("Listening for http on "..tostring(ip)..":"..tostring(port))
  
-- Check if we're on a Coroutine and loop waiting for the server socket to be ready to accept
	local me = MOAICoroutine:currentThread()
	if me then
--	  print("Running under MOAICoroutine, non-blocking yield")
      server:settimeout(0)   -- do not block
	  while true do
		  local c, status = server:accept()
		  if status == "timeout" then
			local start = MOAISim.getDeviceTime()
		    coroutine.yield(server)
			local elapsed = (MOAISim.getDeviceTime() - start) * 1000
--			print(string.format("timeout yield took %.2fmsec", elapsed))
		  else
			client = c
			break
		  end
	  end
	else
	  print("Not running on MOAICoroutine, blocking on accept")
	  client = server:accept()
    end
	
	print("Accepted connection from "..client:getpeername())

	if me then
		MOAICoroutine.new ():run ( function()
									handleclient(client, opt)
								end)
	else
		handleclient(client, opt)
	end
	
end

M.statusmsg = {
  [200] = "200 OK",
  [400] = "400 Bad Request",
  [403] = "403 Forbidden",
  [404] = "404 Not Found",
  [500] = "500 Internal Server Error",
  [501] = "501 Not Implemented",
}

-- Construct an error document in a full HTTP response for the
-- given HTTP error code (which must be a 3-digit decimal number).
-- If the description is present, it is assumed to be an HTML fragment
-- that will be included in the page body. The fragment should contain
-- some block tag as its outermost element.
function M.Errorpage(err, description)
  local pagetop = [[
<html>
<head>
<title>Spoon full of error</title>
</head>
<body>
<h1>Error</h1>
]]
  local pagebot = [[
</body>
</html>
]]
  local body = (pagetop 
    .. '<p>' .. M.status(err) .. '</p>' 
    .. (description and ('\r\n'..description) or "")
    .. pagebot):gsub("\n","\r\n")
  return M.response(err, body)
end

-- Convert a status code to text, including the reason phrase for recognized codes.
function M.status(status)
  return M.statusmsg[status] or ("%03d Status unheard of by Spoon"):format(status)
end

-- Wrap a text document into an HTTP response with status, mime-type,
-- informative headers, and length. Assumes that the document is ready 
-- for the wire and needs no further encoding.
--
-- If the mime type is not specified, assumes "text/html". Types like "text/plain" 
-- "application/json" should be safe to use. Others may need additional work.
function M.response(status, document, mime)
  local resp = {
    "HTTP/1.1 "..M.status(status),
    "Server: Spoon v"..M._VERSION,
    "Content-Type: ".. (mime or "text/html"),
    "Content-Length: "..tostring(#document),
    "",
    document
  }
  return table.concat(resp,"\r\n"), status
end

return M
