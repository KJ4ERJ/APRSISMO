module(..., package.seeall)

local otp = require('otp')
local toast = require("toast");
local colors = require("colors");
local stations = require('stationList')
local QSOs = require('QSOs')
--local QSO = require('QSO')

local service = require("service")	-- Get the service-support set up
APRSIS = require("APRSIS")

osmTiles = require("osmTiles")	-- This currently sets the Z order of the map

local buttonAlpha = 0.8

local myWidth, myHeight

local function closeScene()
	local current = SceneManager:getCurrentScene()
	local name = current:getName()
	if name == "buttons_scene" then
		SceneManager:closeScene({animation="popOut"})
	else print("buttons_scene:NOT Closing "..tostring(name))
	end
end

local closeTimer
local function cancelTimer()
	if closeTimer then
		closeTimer:stop()
		closeTimer = nil
	end
end

local function resetTimer()
	cancelTimer()
	closeTimer = performWithDelay(5000, function() closeScene() end)
end

local squares	-- centering squares
local r, g, b	-- boundary squares
local o, ot, ot2, ob	-- DPI square and label

local function reCreateSquares(width, height)
	local partition = layer:getPartition()
--[[
	if r then partition:removeProp(r) r:dispose() end
	r = Graphics {width = width+2, height = height+2, left = -1, top = -1, layer = layer}
    r:setPenColor(1, 0, 0, 1):drawRect()
	if g then partition:removeProp(g) g:dispose() end
	g = Graphics {width = width+0, height = height+0, left = 0, top = 0, layer = layer}
    g:setPenColor(0, 1, 0, 1):drawRect()
	if b then partition:removeProp(b) b:dispose() end
	b = Graphics {width = width-2, height = height-2, left = 1, top = 1, layer = layer}
    b:setPenColor(0, 0, 1, 1):drawRect()
]]
--[[
	if MOAIEnvironment.screenDpi and MOAIEnvironment.screenDpi > 0 then
		local l = MOAIEnvironment.screenDpi
		if o then partition:removeProp(o) o:dispose() end
		o = Graphics {width = l, height = l, left = l/4, top = l/4, layer = layer}
		o:setPenColor(0, 0, 0, 1):setPenWidth(3):drawRect()
		if ot then partition:removeProp(ot) ot:dispose() end
		ot = TextLabel { text=tostring(MOAIEnvironment.screenDpi), textSize=l/4, layer=layer }
		ot:fitSize()
		ot:setColor(0,0,0,1)
		ot:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		ot:setLoc(l/2+l/4, l/2+l/4)
		if ot2 then partition:removeProp(ot2) ot2:dispose() end
		ot2 = TextLabel { text=tostring(width)..'x'..tostring(height), textSize=l/8, layer=layer }
		ot2:fitSize()
		ot2:setColor(0,0,0,1)
		ot2:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		ot2:setLoc(l/2+l/4, l-l/8+l/4)
		local obSize = l*3/8
		if ob then partition:removeProp(ob) ob:dispose() end
		ob = Graphics {width = obSize, height = obSize, left = 5, top = height-5-obSize, layer = layer}
		ob:setPenColor(0, 0, 0, 1):setPenWidth(3):drawRect()
	end
]]
--[[
	if squares then
		for k,v in pairs(squares) do
			partition:removeProp(v)
			v:dispose()
		end
	end
	squares = {}
	for i=50,1000,50 do
		squares[i] = Graphics { width=i*2, height=i*2, left=width/2-i, top = height/2-i, layer=layer }
		squares[i]:setPenColor(1,1,0,0.75):drawRect()
	end
]]
end
local function fixButtonColors()

	local tileScale, tileSize = osmTiles:getTileScale()
	for k,v in pairs(sButtons) do
		if v.value == tileScale then
			v:setColor(buttonAlpha/2, buttonAlpha/2, buttonAlpha/2, buttonAlpha/2)
		else v:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		end
	end

	local tileAlpha = osmTiles:getTileAlpha()
	for k,v in pairs(aButtons) do
		if k == tileAlpha then
			v:setColor(buttonAlpha/2, buttonAlpha/2, buttonAlpha/2, buttonAlpha/2)
		else v:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		end
	end

	local zoom, zoomMax = osmTiles:getZoom()
	if zoom == 0 then
		inButton:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		in3Button:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		outButton:setColor(buttonAlpha/2, buttonAlpha/2, buttonAlpha/2, buttonAlpha/2)
		out3Button:setColor(buttonAlpha/2, buttonAlpha/2, buttonAlpha/2, buttonAlpha/2)
	elseif zoom == zoomMax then
		inButton:setColor(buttonAlpha/2, buttonAlpha/2, buttonAlpha/2, buttonAlpha/2)
		in3Button:setColor(buttonAlpha/2, buttonAlpha/2, buttonAlpha/2, buttonAlpha/2)
		outButton:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		out3Button:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
	else
		inButton:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		in3Button:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		outButton:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		out3Button:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
	end
	if config.lastDim then
		--brightButton:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
		dimButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
		dimButton:setText("Dim")
	else
		dimButton:setColor(buttonAlpha, 1.0, buttonAlpha, buttonAlpha)
		dimButton:setText("Bright")
		--dimButton:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
	end
	if radarButton then
		if config.lastRadar then
			radarButton:setColor(buttonAlpha, 1.0, buttonAlpha, buttonAlpha)
		else
			radarButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
		end
	end
	if config.lastLabels then	-- lastLabels flags SUPPRESSION!
		labelButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
	else
		labelButton:setColor(buttonAlpha, 1.0, buttonAlpha, buttonAlpha)
	end
	if tempsButton then
		if config.lastTemps then
			tempsButton:setColor(buttonAlpha, 1.0, buttonAlpha, buttonAlpha)
		else
			tempsButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
		end
	end
	if gpxButton then
		local mapScene = SceneManager:findSceneByName("APRSmap")
		if mapScene and type(mapScene.isGPXVisible) == 'function' then
			if mapScene.isGPXVisible() then
				gpxButton:setColor(buttonAlpha, 1.0, buttonAlpha, buttonAlpha)
			else
				gpxButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
			end
		end
	end
	if btButton then
		if config.Bluetooth.Enabled then
			btButton:setColor(buttonAlpha, 1.0, buttonAlpha, buttonAlpha)
		else
			btButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
		end
	end
	if syslogButton then
		if config.Syslog.Enabled then
			syslogButton:setColor(buttonAlpha, 1.0, buttonAlpha, buttonAlpha)
		else
			syslogButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
		end
	end
	local onDivisor = 2
	if MOAIInputMgr.device.location then
		onDivisor = 1
	end
	if config.Enables.GPS then
		gpsButton:setColor(buttonAlpha/onDivisor, 1.0/onDivisor, buttonAlpha/onDivisor, buttonAlpha/onDivisor)
		--offButton:setColor(buttonAlpha, buttonAlpha, buttonAlpha, buttonAlpha)
	else
		--gpsButton:setColor(buttonAlpha/onDivisor, buttonAlpha/onDivisor, buttonAlpha/onDivisor, buttonAlpha/onDivisor)
		gpsButton:setColor(1.0, buttonAlpha, buttonAlpha, buttonAlpha)
	end
end

local function reCreateButtons(width,height)
	if buttonView then buttonView:setScene(nil) buttonView:setLayer(nil) buttonView:dispose() end
	
    buttonView = View {
        scene = scene,
		priority = 2000000000,
    }
--	buttonView = layer

    configureButton = Button {
        text = "Config",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
						config:configure()
					end,

    }
	configureButton:setScl(config.Screen.scale,config.Screen.scale,1)

	local mapScene = SceneManager:findSceneByName("APRSmap")
	if mapScene and type(mapScene.countGPX) == 'function' and mapScene.countGPX() > 0 then
		walkButton = Button {
			text = "WalkGPX...",
			red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
			size = {160, 66},
			parent = buttonView, priority=2000000000,
			onClick = function()
							local mapScene = SceneManager:findSceneByName("APRSmap")
							if mapScene and type(mapScene.getGPXs) == 'function' and mapScene.countGPX() > 0 then

	local entries = { }
	for i,g in pairs(mapScene.getGPXs()) do
		print(string.format("GPXs[%d]=%s color %s",i,tostring(g.name),tostring(g.color)))
		table.insert(entries, {label=g.name, value=i, labelcolor={0,0,0}, --g.color,
								detail=string.format("%d points - %s",#g/2,colors:getColorName(g.color)),
								detailcolor=g.color})
	end
	local function newValue(newV)
		if type(mapScene.walkGPX) == 'function' then
			mapScene.walkGPX(newV)
		end
	end
	cancelTimer()
	SceneManager:openScene("chooser_scene", {config=config, titleText="Walk GPX", entries=entries, newValue=newValue, animation = "popIn", backAnimation = "popOut", })

							elseif mapScene and type(mapScene.walkGPX) == 'function' then
								mapScene.walkGPX(1)
							end
						end,
		}
		walkButton:setScl(config.Screen.scale,config.Screen.scale,1)
		gpxButton = Button {
			text = tostring(mapScene.countGPX()).." GPX", textSize = 20,
			red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
			size = {100, 66},
			parent = buttonView, priority=2000000000,
			onClick = function()
							local mapScene = SceneManager:findSceneByName("APRSmap")
print("gpxButton:"..tostring(mapScene).." "..type(mapScene.showGPXs).." "..tostring(mapScene.hideGPXs))
							if mapScene and type(mapScene.showGPXs) == 'function' and type(mapScene.hideGPXs) == 'function' and type(mapScene.isGPXVisible) == 'function' then
								if mapScene:isGPXVisible() then
									mapScene.hideGPXs()
								else mapScene.showGPXs()
								end
							end
							fixButtonColors()
							resetTimer()
						end,
		}
		gpxButton:setScl(config.Screen.scale,config.Screen.scale,1)
	end

	if MOAIEnvironment.BTDevices and MOAIEnvironment.BTDevices ~= "" then
	if config.Bluetooth and config.Bluetooth.Device ~= '' then
		btButton = Button {
			text = "BT!",
			red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
			size = {100, 66},
			parent = buttonView, priority=2000000000,
			onClick = function()
							config.Bluetooth.Enabled = not config.Bluetooth.Enabled
							updateBluetooth()
							fixButtonColors()
							resetTimer()
						end,
		}
		btButton:setScl(config.Screen.scale,config.Screen.scale,1)
	end
	end
	if type(otp) == 'table' and type(otp.secret) == 'table' and config.OTP.Target and config.OTP.Target ~= '' then
		if config.StationID:sub(1,6) == 'KJ4ERJ' then
			pulseButton = Button {
					text = "Pulse",
					red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
					size = {100, 66},
					parent = buttonView, priority=2000000000,
					onClick = function()
									toast.new('Tap here to pulse', 2000,
												function()
													local pass = otp:getPassword(config.OTP.Sequence)
													otp:setSequence(config.OTP.Sequence + 1)
													local msg = 'CMD'..pass..' PULSE'
													local status = sendAPRSMessage(config.OTP.Target, msg)
													toast.new(status or "PULSE Sent!", 3000)
													config:save("OTPSequence")
												end)
									resetTimer()
								end,
			}
			pulseButton:setScl(config.Screen.scale,config.Screen.scale,1)
		end

		if config.StationID:sub(1,6) == 'KJ4DXK' then
			openButton = Button {
					text = "Open",
					red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
					size = {100, 66},
					parent = buttonView, priority=2000000000,
					onClick = function()
									toast.new('Tap here to OPEN', 2000,
												function()
													local pass = otp:getPassword(config.OTP.Sequence)
													otp:setSequence(config.OTP.Sequence + 1)
													local msg = 'CMD'..pass..' OPEN'
													local status = sendAPRSMessage(config.OTP.Target, msg)
													toast.new(status or "OPEN Sent!", 3000)
													config:save("OTPSequence")
												end)
									resetTimer()
								end,
			}
			openButton:setScl(config.Screen.scale,config.Screen.scale,1)
			closeButton = Button {
					text = "Close",
					red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
					size = {100, 66},
					parent = buttonView, priority=2000000000,
					onClick = function()
									toast.new('Tap here to CLOSE', 2000,
												function()
													local pass = otp:getPassword(config.OTP.Sequence)
													otp:setSequence(config.OTP.Sequence + 1)
													local msg = 'CMD'..pass..' CLOSE'
													local status = sendAPRSMessage(config.OTP.Target, msg)
													toast.new(status or "CLOSE Sent!", 3000)
													config:save("OTPSequence")
											end)
									resetTimer()
								end,
			}
			closeButton:setScl(config.Screen.scale,config.Screen.scale,1)
			queryButton = Button {
					text = "Query",
					red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
					size = {100, 66},
					parent = buttonView, priority=2000000000,
					onClick = function()
									local status = sendAPRSMessage(config.OTP.Target, "?DOOR")
									resetTimer()
								end,
			}
			queryButton:setScl(config.Screen.scale,config.Screen.scale,1)
		end
	end
	
	
    debugButton = Button {
        text = "Debug",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
						toggleDebugLines()
						resetTimer()
					end,
    }
	debugButton:setScl(config.Screen.scale,config.Screen.scale,1)

    messageButton = Button {
        text = "QSOs",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
						SceneManager:openNextScene("QSOs_scene", {animation = "popIn", backAnimation = "popOut", })
					end,
    }
	messageButton:setScl(config.Screen.scale,config.Screen.scale,1)

	if type(otp) == 'table' and type(otp.secret) == 'table' then
		otpButton = Button {
			text = "otp",
			red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
			size = {100, 66},
			parent = buttonView, priority=2000000000,
			onClick = function()
							local pass = ''
							for i=0, 3 do
								pass = pass..' '..otp:getPassword((config.OTP.Sequence or 0)+i)
							end
							toast.new('otp['..tostring(config.OTP.Sequence)..']'..pass)
							resetTimer()
						end,
		}
		otpButton:setScl(config.Screen.scale,config.Screen.scale,1)

		if config.OTP.Target ~= '' then
			numsButton = Button {
				text = "seq",
				red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
				size = {100, 66},
				parent = buttonView, priority=2000000000,
				onClick = function()
								local status = sendAPRSMessage(config.OTP.Target, "?SEQ")
								resetTimer()
							end,
			}
			numsButton:setScl(config.Screen.scale,config.Screen.scale,1)
		end
	end
	
    inButton = Button {
        text = "+", textSize = 32,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:deltaZoom(1) fixButtonColors() resetTimer() end,
    }
	inButton:setScl(config.Screen.scale,config.Screen.scale,1)
    in3Button = Button {
        text = "+++", textSize = 16,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:deltaZoom(3) fixButtonColors() resetTimer() end,
    }
	in3Button:setScl(config.Screen.scale,config.Screen.scale,1)
    outButton = Button {
        text = "-", textSize = 32,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:deltaZoom(-1) fixButtonColors() resetTimer() end,
    }
	outButton:setScl(config.Screen.scale,config.Screen.scale,1)
    out3Button = Button {
        text = "- - -", textSize = 20,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:deltaZoom(-3) fixButtonColors() resetTimer() end,
    }
	out3Button:setScl(config.Screen.scale,config.Screen.scale,1)
    oneButton = Button {
        text = "One",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
					local zoom, zoomMax = osmTiles:getZoom()
						osmTiles:zoomTo(zoomMax)
						stations:updateCenterStation()	-- re-center on current center
						fixButtonColors()
						resetTimer()
					end,
    }
	oneButton:setScl(config.Screen.scale,config.Screen.scale,1)
    allButton = Button {
        text = "All",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
--[[
						local xs = myWidth / 256
						local ys = myHeight / 256
						osmTiles:zoomTo(math.min(xs,ys))
]]
						osmTiles:showAll()
						fixButtonColors()
						resetTimer()
					end,
    }
	allButton:setScl(config.Screen.scale,config.Screen.scale,1)

	
    a75Button = Button {
        text = "75", textSize = 20,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:setTileAlpha(0.75) fixButtonColors() resetTimer() end,
    }
	a75Button:setScl(config.Screen.scale,config.Screen.scale,1)
    a100Button = Button {
        text = "100", textSize = 16,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:setTileAlpha(1.00) fixButtonColors() resetTimer() end,
    }
	a100Button:setScl(config.Screen.scale,config.Screen.scale,1)
    a50Button = Button {
        text = "50", textSize = 20,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:setTileAlpha(0.50) fixButtonColors() resetTimer() end,
    }
	a50Button:setScl(config.Screen.scale,config.Screen.scale,1)
    a25Button = Button {
        text = "25", textSize = 20,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {50, 66},
        parent = buttonView, priority=2000000000,
        onClick = function() osmTiles:setTileAlpha(0.25) fixButtonColors() resetTimer() end,
    }
	a25Button:setScl(config.Screen.scale,config.Screen.scale,1)
	aButtons = {}
	aButtons[1.00] = a100Button
	aButtons[0.75] = a75Button
	aButtons[0.50] = a50Button
	aButtons[0.25] = a25Button
	
	local function checkSetTileScale(n)
		local tileScale, tileSize = osmTiles:getTileScale()
		if tileScale == n then
			osmTiles:setTileScale(1)
		else	osmTiles:setTileScale(n)
		end
		fixButtonColors()
		resetTimer()
	end


	sButtons = {}
	for i = 1, math.min(tostring(config.Screen.ScaleButtons):len(),4) do
		local m = tonumber(tostring(config.Screen.ScaleButtons):sub(i,i)) or 1
		local b = Button {		text = tostring(m).."x", textSize = 20,
								red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
								size = {50, 66},
								parent = buttonView, priority=2000000000,
								onClick = function() checkSetTileScale(m) end,
							}
		b:setScl(config.Screen.scale,config.Screen.scale,1)
		b.value = m
		table.insert(sButtons,1,b)
	end

--[[
    brightButton = Button {
        text = "Bright",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
						config.lastDim = false
						if type(APRSmap.backLayer.setClearColor) == 'function' then
							APRSmap.backLayer:setClearColor ( 1,1,1,1 )	-- White background
						end
						fixButtonColors()
						resetTimer()
					end,
    }
	brightButton:setScl(config.Screen.scale,config.Screen.scale,1)
]]
    radarButton = Button {
        text = "Radar",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
						config.lastRadar = not config.lastRadar
						radar = require("radar")
						if radar then radar:setEnable(config.lastRadar) end
						fixButtonColors()
						resetTimer()
					end,
    }
	radarButton:setScl(config.Screen.scale,config.Screen.scale,1)

    dimButton = Button {
        text = "Dim",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66}, priority=2000000000,
        parent = buttonView, priority=2000000000,
        onClick = function()
						config.lastDim = not config.lastDim
						if type(APRSmap.backLayer.setClearColor) == 'function' then
							if config.lastDim then
								APRSmap.backLayer:setClearColor ( 0,0,0,1 )	-- Black background
							else APRSmap.backLayer:setClearColor ( 1,1,1,1 )	-- White background
							end
						end
						fixButtonColors()
						resetTimer()
					end,
    }
	dimButton:setScl(config.Screen.scale,config.Screen.scale,1)
    gpsButton = Button {
        text = "GPS",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
						config.Enables.GPS = not config.Enables.GPS
						updateGPSEnabled()
						fixButtonColors()
						resetTimer()
					end,
    }
	gpsButton:setScl(config.Screen.scale,config.Screen.scale,1)
--[[
    offButton = Button {
        text = "Off",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66}, priority=2000000000,
        parent = buttonView, priority=2000000000,
        onClick = function()
						config.Enables.GPS = false
						updateGPSEnabled()
						fixButtonColors()
						resetTimer()
					end,
    }
	offButton:setScl(config.Screen.scale,config.Screen.scale,1)
]]

    labelButton = Button {
        text = "Labels",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66},
        parent = buttonView, priority=2000000000,
        onClick = function()
						config.lastLabels = not config.lastLabels
						osmTiles:showLabels(not config.lastLabels)	-- lastLables flags suppression
						fixButtonColors()
						resetTimer()
					end,
    }
	labelButton:setScl(config.Screen.scale,config.Screen.scale,1)
	tempsButton = Button {
		text = "Counts",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
		size = {100, 66},
		parent = buttonView, priority=2000000000,
		onClick = function()
						if config.StationID:sub(1,6) == 'KJ4ERJ' then
							if not config.lastTemps then
								config.lastTemps = 1
							else
								if type(config.lastTemps) == 'number' then
									config.lastTemps = config.lastTemps + 1
								else config.lastTemps = 2
								end
								if config.lastTemps > 2 then config.lastTemps = false end
							end
						else config.lastTemps = not config.lastTemps
						end
						fixButtonColors()
						resetTimer()
					end,
	}
	tempsButton:setScl(config.Screen.scale,config.Screen.scale,1)
	if config.Syslog.Server and config.Syslog.Server ~= '' then
		syslogButton = Button {
			text = "Syslog",--..tostring(syslogIP),
			red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
			size = {100, 66},
			parent = buttonView, priority=2000000000,
			onClick = function()
							config.Syslog.Enabled = not config.Syslog.Enabled
							print("Syslog "..(config.Syslog.Enabled and "enabled" or "disabled"))
							fixButtonColors()
							resetTimer()
							if config.Syslog.Enabled then
								toast.new("Syslog to "..tostring(syslogIP), 10000)
							end
						end,
		}
		syslogButton:setScl(config.Screen.scale,config.Screen.scale,1)
	end
--[[
    off2Button = Button {
        text = "Off",
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66}, priority=2000000000,
        parent = buttonView, priority=2000000000,
        onClick = function()
						osmTiles:showLabels(false)
						resetTimer()
					end,
    }
	off2Button:setScl(config.Screen.scale,config.Screen.scale,1)
]]
	
--        textSize = 24,

    meButton = Button {
        text = "ME", textSize = 24,	-- default is 24
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66}, priority=2000000000,
        parent = buttonView, priority=2000000000,
        onClick = function()
						--osmTiles:removeTapGroup()
						local tileGroup = osmTiles:getTileGroup()
						local lat, lon = tileGroup.lat, tileGroup.lon
						local center = stations:getCenterStation()

						myStation.gotLocation = true
						print(center.stationID..' vs '..myStation.stationID..' delta '..lat-myStation.lat..' '..lon-myStation.lon)
						--if center == myStation or (lat == myStation.lat and lon == myStation.lon) then
							stations:updateCenterStation(myStation)	-- move and track
						--else								-- otherwise just move and require a center tap
						--	osmTiles:moveTo(myStation.lat, myStation.lon)
						--end
						resetTimer()	-- Only if not closing scene
						-- closeScene()	-- Don't close scene as I'm normally zooming too
						return true
					end,
    }
	meButton:fitSize()
	meButton:setScl(config.Screen.scale,config.Screen.scale,1)

	--local tempWidth = display.newText("WWWWWW-WW", 0, 0, native.systemFont, 14)	-- 14 is the default for buttons
	local whoStation = stations:getCenterStation()
	local whoButton
	if whoStation ~= myStation then
		local whoLabel
		if not whoStation or not whoStation.stationID then whoLabel = "WWWWWW-WW" else whoLabel = whoStation.stationID end
		whoButton = Button {
			text = whoLabel, --textSize = 12,	-- default is 24
			red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
			size = {100, 66}, priority=2000000000,
			parent = buttonView, priority=2000000000,
			onClick = function()
							--osmTiles:removeTapGroup()
							print('whoButton:click:centerStation='..tostring(stations:getCenterStation()))
							stations:updateCenterStation(whoStation)
							resetTimer()	-- Only if not closing scene
							--closeScene()
							return true
						end,
		}
		whoButton:fitSize()
		whoButton:setScl(config.Screen.scale,config.Screen.scale,1)
	end
	--tempWidth:removeSelf()

    xmitButton = Button {
        text = "Xmit", textSize = 24,
		--styles = { textSize = 12, },	-- default is 24
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66}, priority=2000000000,
        parent = buttonView, priority=2000000000,
        onClick = function()
--[[
local tileGroup = osmTiles:getTileGroup()
if not config.Enables.GPS
and MOAIDialog and type(MOAIDialog.showDialog) == 'function'
and not AreCoordinatesEquivalent(tileGroup.lat, tileGroup.lon,
							myStation.lat, myStation.lon, 2) then
	MOAIDialog.showDialog('Move ME', "Move ME To Center?", 'Yes', nil, 'No', true, 
				function(result)
print("MoveME:result="..tostring(result))
					if result == MOAIDialogAndroid.DIALOG_RESULT_POSITIVE then
						moveME(tileGroup.lat, tileGroup.lon)
						local status = service:triggerPosit('Moved')
						toast.new(status or 'Posit Sent', 2000)
					elseif result == MOAIDialogAndroid.DIALOG_RESULT_NEUTRAL then
					elseif result == MOAIDialogAndroid.DIALOG_RESULT_NEGATIVE then
						myStation.gotLocation = true
						local status = service:triggerPosit('FORCE')
						toast.new(status or 'Posit Sent', 2000)
					elseif result == MOAIDialogAndroid.DIALOG_RESULT_CANCEL then
					end
				end)
else]]
	myStation.gotLocation = true
	local status = service:triggerPosit('FORCE')
	toast.new(status or 'Posit Sent', 2000)
--end
					closeScene()
					return true
				end
    }
	xmitButton:fitSize()
	xmitButton:setScl(config.Screen.scale,config.Screen.scale,1)
	if not config.Enables.GPS
	and osmTiles and osmTiles:getZoom() > 15 then
    moveButton = Button {
        text = "Move", textSize = 24,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66}, priority=2000000000,
        parent = buttonView, priority=2000000000,
        onClick = function()
local tileGroup = osmTiles:getTileGroup()
if not config.Enables.GPS
and not AreCoordinatesEquivalent(tileGroup.lat, tileGroup.lon,
							myStation.lat, myStation.lon, 2) then
if MOAIDialog and type(MOAIDialog.showDialog) == 'function' then
	MOAIDialog.showDialog('Move ME', "Move ME To Center?", 'Yes', nil, 'No', true, 
				function(result)
print("MoveME:result="..tostring(result))
					if result == MOAIDialogAndroid.DIALOG_RESULT_POSITIVE then
						addCrumb(tileGroup.lat, tileGroup.lon, nil, "MoveME")
						moveME(tileGroup.lat, tileGroup.lon)
						service:triggerPosit('Moved')
						toast.new('ME Moved', 2000)
					elseif result == MOAIDialogAndroid.DIALOG_RESULT_NEUTRAL then
					elseif result == MOAIDialogAndroid.DIALOG_RESULT_NEGATIVE then
					elseif result == MOAIDialogAndroid.DIALOG_RESULT_CANCEL then
					end
				end)
else
	addCrumb(tileGroup.lat, tileGroup.lon, nil, "MoveME")
	moveME(tileGroup.lat, tileGroup.lon)
	service:triggerPosit('Moved')
	toast.new('ME Moved', 2000)
end
					closeScene()
end
					return true
					end,
    }
	moveButton:fitSize()
	moveButton:setScl(config.Screen.scale,config.Screen.scale,1)
	else moveButton = nil
	end

	--local issAck
    issButton = Button {
        text = "ISS", textSize = 24,
		red=buttonAlpha, green=buttonAlpha, blue=buttonAlpha, alpha=buttonAlpha,
        size = {100, 66}, priority=2000000000,
        parent = buttonView, priority=2000000000,
        onClick = function()
					performWithDelay(500,function()
							--issAck = (issAck or 0) + 1
							local whoFor = "ME"
							local centerStation = stations:getCenterStation()
							if centerStation ~= myStation then whoFor = centerStation.stationID end
							--local msg = string.format('%s{%i', whoFor, issAck)
							--local payload = string.format('%s>APWA00,TCPIP*::%-9s:%s', config.StationID, 'ISS', msg)
							--local status = APRSIS:sendPacket(payload)
							--print ('msgISS:'..msg)
							--QSOs:newMessage("ME", "ISS", msg)
							local status = sendAPRSMessage("ISS", whoFor)
							toast.new(status or "Next Pass Requested", 3000)
						end
					)
					closeScene()
					return true
				end
    }
	print('issButton:'..issButton:getWidth()..'x'..issButton:getHeight())
	issButton:fitSize()
	print('issButton:'..issButton:getWidth()..'x'..issButton:getHeight())
	issButton:setScl(config.Screen.scale,config.Screen.scale,1)
	print('issButton:'..issButton:getWidth()..'x'..issButton:getHeight())

    configureButton:setLeft(10) configureButton:setTop(50*config.Screen.scale)
    debugButton:setLeft(configureButton:getRight()) debugButton:setTop(50*config.Screen.scale)
    if walkButton then
		walkButton:setLeft(10) walkButton:setTop(configureButton:getBottom()+10)
		if pulseButton then pulseButton:setLeft(10) pulseButton:setTop(walkButton:getBottom()+10) end
		if openButton then openButton:setLeft(10) openButton:setTop(walkButton:getBottom()+10)
			if closeButton then closeButton:setLeft(10) closeButton:setTop(openButton:getBottom()+10)
				if queryButton then queryButton:setLeft(10) queryButton:setTop(closeButton:getBottom()+10) end
			end
		end
	else	-- No GPXs
		if pulseButton then pulseButton:setLeft(10) pulseButton:setTop(configureButton:getBottom()+10) end
		if openButton then openButton:setLeft(10) openButton:setTop(walkButton:getBottom()+10)
			if closeButton then closeButton:setLeft(10) closeButton:setTop(openButton:getBottom()+10)
				if queryButton then queryButton:setLeft(10) queryButton:setTop(closeButton:getBottom()+10) end
			end
		end
	end
	
    messageButton:setRight(width-10) messageButton:setTop(50*config.Screen.scale)
    if otpButton then
		otpButton:setRight(width-10) otpButton:setTop(messageButton:getBottom()+10)
		if numsButton then
			numsButton:setRight(width-10) numsButton:setTop(otpButton:getBottom()+10)
		end
	end

    in3Button:setRight(width-10) in3Button:setBottom(height-10)
    inButton:setRight(in3Button:getLeft()) inButton:setBottom(height-10)
    outButton:setRight(inButton:getLeft()) outButton:setBottom(height-10)
    out3Button:setRight(outButton:getLeft()) out3Button:setBottom(height-10)

    oneButton:setRight(width-10) oneButton:setBottom(inButton:getTop()-10)
    allButton:setRight(oneButton:getLeft()) allButton:setBottom(outButton:getTop()-10)

    a25Button:setRight(width-10) a25Button:setBottom(oneButton:getTop()-10)
    a50Button:setRight(a25Button:getLeft()) a50Button:setBottom(oneButton:getTop()-10)
    a75Button:setRight(a50Button:getLeft()) a75Button:setBottom(allButton:getTop()-10)
    a100Button:setRight(a75Button:getLeft()) a100Button:setBottom(allButton:getTop()-10)
	
	do	-- Keep x and y from showing up elsewhere
		local x, y = width-10, a25Button:getTop()-10
		for i, b in pairs(sButtons) do
			b:setRight(x) b:setBottom(y)
			x = b:getLeft()
		end
	end

    dimButton:setLeft(10) dimButton:setBottom(height-10)
    --brightButton:setLeft(dimButton:getRight()) brightButton:setBottom(height-10)
    if radarButton then
		radarButton:setLeft(dimButton:getRight()) radarButton:setBottom(height-10)
	end
	gpsButton:setLeft(10) gpsButton:setBottom(dimButton:getTop()-10)
	--gpsButton:setLeft(offButton:getRight()) gpsButton:setBottom(dimButton:getTop()-10)
	labelButton:setLeft(10) labelButton:setBottom(gpsButton:getTop()-10)
    if tempsButton then
		tempsButton:setLeft(labelButton:getRight()) tempsButton:setBottom(labelButton:getBottom())
	end
    if syslogButton then
		syslogButton:setLeft(gpsButton:getRight()) syslogButton:setBottom(gpsButton:getBottom())
	end
	--labelButton:setLeft(off2Button:getRight()) labelButton:setBottom(gpsButton:getTop()-10)
	
	if gpxButton then
		gpxButton:setLeft(10) gpxButton:setBottom(labelButton:getTop()-10)
	end
	
	if btButton then
		if gpxButton then
			btButton:setLeft(gpxButton:getRight()) btButton:setBottom(gpxButton:getBottom())
		else
			btButton:setLeft(10) btButton:setBottom(labelButton:getTop()-10)
		end
	end
	
    meButton:setLeft((width-meButton:getWidth())/2) meButton:setTop(height/2+meButton:getHeight()*0.5)
    if moveButton then moveButton:setRight(width/2-meButton:getWidth()/2) moveButton:setTop(meButton:getTop()) end
    if whoButton then whoButton:setLeft((width-whoButton:getWidth())/2) whoButton:setBottom(height/2-whoButton:getHeight()*0.5) end
    if xmitButton then xmitButton:setRight(width/2-meButton:getWidth()/2) xmitButton:setBottom((height+xmitButton:getHeight())/2) end
    if issButton then issButton:setLeft(width/2+meButton:getWidth()/2) issButton:setBottom((height+issButton:getHeight())/2) end

	fixButtonColors()
end

local function resizeHandler ( width, height )
	myWidth, myHeight = width, height
	local mapScene = SceneManager:findSceneByName("APRSmap")
	if mapScene and type(mapScene.resizeHandler) == 'function' then
		mapScene.resizeHandler(width, height)
	end
	layer:setSize(width,height)
	reCreateSquares(width, height)
	reCreateButtons(width,height)
	titleBackground:setSize(width, 40*config.Screen.scale)
	local x,y = titleText:getSize()
	titleText:setLoc(width/2, 25*config.Screen.scale)
	resetTimer()
end

function onStart()
    print("Buttons:onStart()")
	resetTimer()
end

function onResume()
    print("Buttons:onResume()")
	if Application.viewWidth ~= myWidth or Application.viewHeight ~= myHeight then
		print("Buttons:onResume():Resizing...")
		resizeHandler(Application.viewWidth, Application.viewHeight)
	end
	resetTimer()
end

function onPause()
    print("Buttons:onPause()")
	cancelTimer()
end

function onStop()
    print("Buttons:onStop()")
	cancelTimer()
end

function onDestroy()
    print("Buttons:onDestroy()")
	cancelTimer()
end

function onEnterFrame()
    --print("onEnterFrame()")
end

function onKeyDown(event)
    print("Buttons:onKeyDown(event)")
	if event.key then
		print("processing key "..tostring(event.key))
		if event.key == 283 then	-- Escape
			closeScene()
		end
	end
end

function onKeyUp(event)
    print("Buttons:onKeyUp(event)")
end

local touchDowns = {}

function onTouchDown(event)
	local wx, wy = layer:wndToWorld(event.x, event.y, 0)
--    print("Buttons:onTouchDown(event)@"..tostring(wx)..','..tostring(wy)..printableTable(' onTouchDown', event))
	touchDowns[event.idx] = {x=event.x, y=event.y}
	cancelTimer()
end

function onTouchUp(event)
	local wx, wy = layer:wndToWorld(event.x, event.y, 0)
--    print("Buttons:onTouchUp(event)@"..tostring(wx)..','..tostring(wy)..printableTable(' onTouchUp', event))
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
--    SceneManager:closeScene({animation = "popOut"})
	resetTimer()
end

function onTouchMove(event)
    --print("Buttons:onTouchMove(event)")
	if touchDowns[event.idx] then
		local dx = event.x - touchDowns[event.idx].x
		local dy = event.y - touchDowns[event.idx].y
		--print(string.format('Buttons:onTouchMove:dx=%i dy=%i moveX=%i moveY=%i',
		--					dx, dy, event.moveX, event.moveY))
		osmTiles:deltaMove(event.moveX, event.moveY)
	end
end

function onCreate(e)
	print('buttons:onCreate')
	local width, height = Application.viewWidth, Application.viewHeight
	myWidth, myHeight = width, height

	scene.resizeHandler = resizeHandler
	scene.backHandler = closeScene
	scene.menuHandler = closeScene

    layer = Layer {scene = scene, touchEnabled = true }
	
	reCreateSquares(width,height)
	reCreateButtons(width,height)

    titleGroup = Group { layer=layer }
	titleGroup:setLayer(layer)

	titleBackground = Graphics {width = width, height = 40*config.Screen.scale, left = 0, top = 0}
    titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
	titleBackground:setPriority(2000000000)
	titleGroup:addChild(titleBackground)
	
--[[
	fontImage = FontManager:getRecentImage()
	if fontImage then
		print("FontImage is "..tostring(fontImage))
		local sprite = Sprite{texture=fontImage, layer=layer}
		sprite:setPos((width-sprite:getWidth())/2, (height-sprite:getHeight())/2)
	end
]]

	titleText = TextLabel { text=tostring(MOAIEnvironment.appDisplayName)..' '..tostring(MOAIEnvironment.appVersion), textSize=28*config.Screen.scale }
	titleText:fitSize()
	titleText:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	titleText:setLoc(width/2, 20*config.Screen.scale)
	titleText:setPriority(2000000001)
	titleGroup:addChild(titleText)

	titleGroup:addEventListener("touchUp",
			function()
				print("Tapped Button:TitleGroup")
				closeScene()
			end)
end
