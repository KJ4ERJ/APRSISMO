--==============================================================
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
--==============================================================

	package.path = "?;?.lua"

	print ( "load:" .. "\t" .. "running assets\\lua\\init.lua" )
	
local printCallback

	function setPrintCallback(callback)	-- Called with (output,where)
		if type(callback) == 'function' or type(callback) == nil then
			printCallback = callback
		end
	end

	----------------------------------------------------------------
	-- this function supports all the ways a user could call print
	----------------------------------------------------------------
	print = function ( ... )

	local arg={...}

	if (arg) then
	
		local argCount = #arg
		
		if argCount == 0 then
			MOAILogMgr.log ( "" )
			return
		end
		
		local output = tostring ( arg [ 1 ])
		
		for i = 2, argCount do
			output = output .. "\t" .. tostring ( arg [ i ])
		end

		local info = debug.getinfo( 2, "Sl" )
		local where = info.source..':'..info.currentline
		if where:sub(1,1) == '@' then where = where:sub(2) end

		MOAILogMgr.log ( os.date("!%H:%M:%S ")..output..' @'..where..'\n' )
		if printCallback then
			local status, text = pcall(printCallback, output, where)
			if not status then MOAILogMgr.log('printCallback failed with '..text) end
		end
	else
		MOAILogMgr.log ( os.date("%H:%M:%S ")..'arg=NIL\n' )
	end
	end

	print ( "assets\\lua\\init.lua ran" )

	----------------------------------------------------------------
	-- error function that actually prints the error
	----------------------------------------------------------------
	local superError = error
	
	error = function ( message, level )
	
		print ( "error: " .. message )
		print ( debug.traceback ( "", 2 ))
		superError ( message, level or 1 )
	end
